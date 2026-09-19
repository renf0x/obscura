"""HTTP API for the mobile app. Every route except /api/health and /api/pair needs a device token."""

import asyncio
import contextlib
import json
import re
import time
from typing import Annotated, Literal

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request, Response
from fastapi.responses import FileResponse, JSONResponse, StreamingResponse
from pydantic import BaseModel, Field, field_validator
from starlette.background import BackgroundTask

from . import __version__, discovery, security, tapo
from .config import Settings
from .hub import PRESETS, Hub, capabilities
from .storage import BACKEND_FIELDS, SECRET_FIELDS, valid_remote_name, valid_remote_path
from .worker import DEFAULT_CONFIG, camera_config, clip_path

MAX_BODY = 64 * 1024
MAX_TALK_BODY = 1024 * 1024  # ~30 s of phone AAC
TALK_PATH = re.compile(r"^/api/cameras/\d+/talk$")
HHMM = r"^([01]\d|2[0-3]):[0-5]\d$"
Name = Annotated[str, Field(min_length=1, max_length=40)]


# --- schemas ------------------------------------------------------------------

class PairIn(BaseModel):
    code: str = Field(min_length=6, max_length=20)
    device_name: Name


class PushIn(BaseModel):
    endpoint: str = Field(max_length=1000)
    key: str = Field(max_length=64)


class Zone(BaseModel):
    id: str = Field(pattern=r"^[A-Za-z0-9_-]{1,32}$")
    name: str = Field(default="Zone", max_length=40)
    points: list[tuple[float, float]] = Field(min_length=3, max_length=32)
    motion: bool = True
    person: bool = True

    @field_validator("points")
    @classmethod
    def normalized(cls, pts):
        if any(not (0 <= x <= 1 and 0 <= y <= 1) for x, y in pts):
            raise ValueError("points must be normalized to 0..1")
        return pts


class Schedule(BaseModel):
    mode: Literal["always", "window"] = "always"
    start: str = Field(default="22:00", pattern=HHMM)
    end: str = Field(default="07:00", pattern=HHMM)
    days: list[Annotated[int, Field(ge=0, le=6)]] = Field(default=[0, 1, 2, 3, 4, 5, 6], max_length=7)


class CameraConfig(BaseModel):
    motion: bool = True
    person: bool = True
    sensitivity: Literal["low", "medium", "high"] = "medium"
    zones: list[Zone] = Field(default=[], max_length=16)
    schedule: Schedule = Schedule()
    notify_motion: bool = True
    notify_person: bool = True
    siren_on_person: bool = False
    siren_seconds: int = Field(default=30, ge=5, le=300)
    # "low" records the camera's sub stream: ~3x smaller clips and one stream pulled instead of two.
    record_quality: Literal["high", "low"] = "high"


class CameraIn(BaseModel):
    name: Name
    vendor: Literal["tapo", "hikvision", "dahua", "reolink", "generic"] = "generic"
    host: str = Field(min_length=1, max_length=253)
    port: int = Field(default=554, ge=1, le=65535)
    username: str = Field(default="", max_length=64)
    password: str | None = Field(default=None, max_length=128)  # None on update = keep current
    main_path: str | None = Field(default=None, max_length=200)
    sub_path: str | None = Field(default=None, max_length=200)
    enabled: bool = True
    # TP-Link account ("cloud") password: Tapo two-way audio and siren. None = keep, "" = remove.
    cloud_password: str | None = Field(default=None, max_length=128)
    two_way: bool = False  # other brands: camera has a speaker (RTSP backchannel)

    @field_validator("host")
    @classmethod
    def host_ok(cls, v):
        v = v.strip()
        if not security.valid_host(v):
            raise ValueError("invalid host")
        return v

    @field_validator("main_path", "sub_path")
    @classmethod
    def path_ok(cls, v):
        if v not in (None, "") and not security.valid_path(v):
            raise ValueError("path must start with / and contain no spaces or '#'")
        return v

    @field_validator("username", "password", "cloud_password")
    @classmethod
    def printable(cls, v):
        if v and any(ord(c) < 32 for c in v):
            raise ValueError("control characters are not allowed")
        return v


class CameraPatch(BaseModel):
    name: Name | None = None
    enabled: bool | None = None
    config: CameraConfig | None = None


class StorageIn(BaseModel):
    retention_days: int = Field(ge=1, le=365)
    max_gb: float = Field(ge=0.5, le=10000)
    cloud_enabled: bool = False
    cloud_type: Literal["none", "s3", "webdav", "custom"] = "none"
    cloud_path: str = Field(default="obscura", max_length=200)
    custom_remote: str = Field(default="", max_length=64)

    @field_validator("cloud_path")
    @classmethod
    def path_ok(cls, v):
        if not valid_remote_path(v):
            raise ValueError("invalid remote path")
        return v


class BackendIn(BaseModel):
    type: Literal["s3", "webdav"]
    options: dict[str, str] = Field(max_length=10)


class NtfyIn(BaseModel):
    enabled: bool = False
    server: str = Field(default="https://ntfy.sh", max_length=200)
    topic: str = Field(default="", pattern=r"^[A-Za-z0-9_-]{0,64}$")
    token: str | None = Field(default=None, max_length=200)  # None = keep current

    @field_validator("server")
    @classmethod
    def server_ok(cls, v):
        if not security.valid_push_endpoint(v):
            raise ValueError("server must be an http(s) URL")
        return v.rstrip("/")


class NameIn(BaseModel):
    name: Name


class SirenIn(BaseModel):
    on: bool
    seconds: int = Field(default=30, ge=5, le=300)


# --- helpers ------------------------------------------------------------------

def cloud_hashes(password: str | None) -> tuple[str, str]:
    """Only hashes of the TP-Link account password are stored (that is all the camera needs)."""
    return tapo.password_hashes(password) if password else ("", "")


def public_camera(hub: Hub, cam: dict) -> dict:
    """Camera as the app sees it. The password never leaves the hub."""
    worker = hub.workers.get(cam["id"])
    return {
        "id": cam["id"], "name": cam["name"], "vendor": cam["vendor"],
        "host": cam["host"], "port": cam["port"], "username": cam["username"],
        "has_password": bool(cam["password"]),
        "has_cloud_password": bool(cam["cloud_md5"]), "two_way": bool(cam["two_way"]),
        "capabilities": capabilities(cam), "control_error": hub.control_status.get(cam["id"]),
        "main_path": cam["main_path"], "sub_path": cam["sub_path"],
        "enabled": bool(cam["enabled"]),
        "online": bool(worker and worker.online),
        "resolution": worker.resolution if worker else None,
        "config": camera_config(cam["config"]),
    }


def public_event(ev: dict, cam_names: dict[int, str]) -> dict:
    return {
        "id": ev["id"], "camera_id": ev["camera_id"], "camera": cam_names.get(ev["camera_id"], "?"),
        "kind": ev["kind"], "started_at": ev["started_at"], "ended_at": ev["ended_at"],
        "score": round(ev["score"], 3), "zones": json.loads(ev["zones"]),
        "has_clip": bool(ev["clip"]), "has_thumb": bool(ev["thumb"]), "has_track": bool(ev.get("track")),
        "size": ev["size"], "uploaded": bool(ev["uploaded"]),
    }


SECURITY_HEADERS = [
    (b"x-content-type-options", b"nosniff"),
    (b"x-frame-options", b"DENY"),
    (b"referrer-policy", b"no-referrer"),
    (b"content-security-policy", b"default-src 'none'; frame-ancestors 'none'"),
]


class HardeningMiddleware:
    """Pure ASGI (not BaseHTTPMiddleware) so endless live/SSE streams pass through untouched."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        headers = dict(scope["headers"])
        length = headers.get(b"content-length", b"0")
        limit = MAX_TALK_BODY if TALK_PATH.match(scope.get("path", "")) else MAX_BODY
        if not length.isdigit() or int(length) > limit or b"chunked" in headers.get(b"transfer-encoding", b""):
            return await JSONResponse({"detail": "request too large"}, status_code=413)(scope, receive, send)

        async def send_wrapper(message):
            if message["type"] == "http.response.start":
                names = {k.lower() for k, _ in message.get("headers", [])}
                extra = [(k, v) for k, v in SECURITY_HEADERS if k not in names]
                if b"cache-control" not in names:
                    extra.append((b"cache-control", b"no-store"))
                message["headers"] = list(message.get("headers", [])) + extra
            await send(message)

        await self.app(scope, receive, send_wrapper)


def create_app(settings: Settings, hub: Hub | None = None) -> FastAPI:
    hub = hub or Hub(settings)
    pair_limiter = security.RateLimiter(per_key=5, global_limit=20, window=600)

    @contextlib.asynccontextmanager
    async def lifespan(_app):
        hub.bus.bind(asyncio.get_running_loop())
        await hub.start()
        task = asyncio.create_task(hub.keep_registered())
        yield
        task.cancel()
        await hub.stop()

    app = FastAPI(title="Obscura hub", version=__version__, lifespan=lifespan,
                  docs_url=None, redoc_url=None, openapi_url=None)
    app.state.hub = hub

    app.add_middleware(HardeningMiddleware)

    def device(authorization: str = Header(default="")) -> dict:
        scheme, _, token = authorization.partition(" ")
        if scheme.lower() != "bearer" or not token or len(token) > 200:
            raise HTTPException(401, "not paired", headers={"WWW-Authenticate": "Bearer"})
        dev = hub.db.one("SELECT * FROM devices WHERE token_hash = ?", (security.hash_secret(token),))
        if not dev:
            raise HTTPException(401, "not paired", headers={"WWW-Authenticate": "Bearer"})
        if time.time() - dev["last_seen"] > 60:
            hub.db.execute("UPDATE devices SET last_seen = ? WHERE id = ?", (time.time(), dev["id"]))
        return dev

    Auth = Annotated[dict, Depends(device)]

    def get_camera(cam_id: int) -> dict:
        cam = hub.db.camera(cam_id)
        if not cam:
            raise HTTPException(404, "camera not found")
        return cam

    # --- pairing & devices ------------------------------------------------
    @app.get("/api/health")
    def health():
        return {"ok": True, "app": "obscura"}

    @app.post("/api/pair")
    def pair(body: PairIn, request: Request):
        client = request.client.host if request.client else "?"
        if not pair_limiter.allow(client):
            raise HTTPException(429, "too many attempts, wait 10 minutes")
        hub.db.purge_expired_pairing()
        code_hash = security.hash_secret(security.normalize_code(body.code))
        # Single use: the DELETE either consumes the code or matches nothing.
        if hub.db.execute("DELETE FROM pairing WHERE code_hash = ?", (code_hash,)) != 1:
            raise HTTPException(403, "invalid or expired code")
        token = security.new_token()
        now = time.time()
        dev_id = hub.db.execute(
            "INSERT INTO devices(name, token_hash, created_at, last_seen) VALUES(?, ?, ?, ?)",
            (body.device_name, security.hash_secret(token), now, now),
        )
        return {"token": token, "device_id": dev_id, "hub_name": hub.db.get_kv("hub_name", "Obscura hub")}

    @app.post("/api/pairing-code")
    def pairing_code(_: Auth):
        return {"code": hub.new_pairing_code(), "expires_in": security.PAIRING_TTL}

    @app.get("/api/devices")
    def devices(dev: Auth):
        rows = hub.db.query("SELECT id, name, created_at, last_seen, push_endpoint IS NOT NULL AS push FROM devices")
        return [{**r, "push": bool(r["push"]), "current": r["id"] == dev["id"]} for r in rows]

    @app.delete("/api/devices/{dev_id}", status_code=204)
    def revoke(dev_id: int, _: Auth):
        if hub.db.execute("DELETE FROM devices WHERE id = ?", (dev_id,)) != 1:
            raise HTTPException(404, "device not found")

    @app.put("/api/devices/me/push", status_code=204)
    def set_push(body: PushIn, dev: Auth):
        if not security.valid_push_endpoint(body.endpoint) or not security.valid_push_key(body.key):
            raise HTTPException(422, "invalid push endpoint or key")
        hub.db.execute("UPDATE devices SET push_endpoint = ?, push_key = ? WHERE id = ?",
                       (body.endpoint, body.key, dev["id"]))

    @app.delete("/api/devices/me/push", status_code=204)
    def clear_push(dev: Auth):
        hub.db.execute("UPDATE devices SET push_endpoint = NULL, push_key = NULL WHERE id = ?", (dev["id"],))

    # --- overview ---------------------------------------------------------
    @app.get("/api/overview")
    def overview(_: Auth):
        cams = hub.db.cameras()
        online = sum(1 for c in cams if (w := hub.workers.get(c["id"])) and w.online)
        day_ago = time.time() - 86400
        counts = {r["kind"]: r["n"] for r in hub.db.query(
            "SELECT kind, COUNT(*) AS n FROM events WHERE started_at > ? GROUP BY kind", (day_ago,))}
        return {
            "hub_name": hub.db.get_kv("hub_name", "Obscura hub"), "version": __version__,
            "uptime": int(time.time() - hub.started_at),
            "cameras": len(cams), "online": online, "offline": len(cams) - online,
            "alerts_24h": sum(counts.values()), "people_24h": counts.get("person", 0),
            "person_detection": hub.person is not None,
            "storage": hub.storage.usage(),
        }

    # --- cameras ----------------------------------------------------------
    @app.get("/api/presets")
    def presets(_: Auth):
        return PRESETS

    @app.get("/api/discover")
    async def discover(_: Auth):
        found = await asyncio.to_thread(discovery.discover)
        known = {c["host"] for c in hub.db.cameras()}
        return [{**d, "added": d["host"] in known} for d in found]

    @app.get("/api/cameras")
    def cameras(_: Auth):
        return [public_camera(hub, c) for c in hub.db.cameras()]

    @app.post("/api/cameras", status_code=201)
    async def add_camera(body: CameraIn, _: Auth):
        if hub.db.one("SELECT COUNT(*) AS n FROM cameras")["n"] >= 32:
            raise HTTPException(400, "camera limit reached")
        preset = PRESETS[body.vendor]
        main = body.main_path or preset["main"]
        sub = body.sub_path if body.sub_path is not None else preset["sub"]
        md5, sha = cloud_hashes(body.cloud_password)
        cam_id = hub.db.execute(
            "INSERT INTO cameras(name, vendor, host, port, username, password, main_path, sub_path, enabled, config, "
            "cloud_md5, cloud_sha256, two_way) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (body.name, body.vendor, body.host, body.port, body.username, body.password or "",
             main, sub, int(body.enabled), json.dumps(DEFAULT_CONFIG), md5, sha, int(body.two_way)),
        )
        await hub.apply_camera(cam_id)
        return public_camera(hub, hub.db.camera(cam_id))

    @app.get("/api/cameras/{cam_id}")
    def camera(cam_id: int, _: Auth):
        return public_camera(hub, get_camera(cam_id))

    @app.put("/api/cameras/{cam_id}")
    async def update_connection(cam_id: int, body: CameraIn, _: Auth):
        cam = get_camera(cam_id)
        preset = PRESETS[body.vendor]
        hub.db.execute(
            "UPDATE cameras SET name = ?, vendor = ?, host = ?, port = ?, username = ?, password = ?, "
            "main_path = ?, sub_path = ?, enabled = ? WHERE id = ?",
            (body.name, body.vendor, body.host, body.port, body.username,
             cam["password"] if body.password is None else body.password,
             body.main_path or preset["main"], body.sub_path if body.sub_path is not None else preset["sub"],
             int(body.enabled), cam_id),
        )
        hub.db.execute("UPDATE cameras SET two_way = ? WHERE id = ?", (int(body.two_way), cam_id))
        if body.cloud_password is not None or body.host != cam["host"]:
            md5, sha = (cam["cloud_md5"], cam["cloud_sha256"]) if body.cloud_password is None \
                else cloud_hashes(body.cloud_password)
            hub.db.execute("UPDATE cameras SET cloud_md5 = ?, cloud_sha256 = ?, cloud_algo = '' WHERE id = ?",
                           (md5, sha, cam_id))
        await hub.apply_camera(cam_id)
        return public_camera(hub, get_camera(cam_id))

    @app.patch("/api/cameras/{cam_id}")
    async def patch_camera(cam_id: int, body: CameraPatch, _: Auth):
        get_camera(cam_id)
        if body.name is not None:
            hub.db.execute("UPDATE cameras SET name = ? WHERE id = ?", (body.name, cam_id))
        if body.enabled is not None:
            hub.db.execute("UPDATE cameras SET enabled = ? WHERE id = ?", (int(body.enabled), cam_id))
        if body.config is not None:
            hub.db.execute("UPDATE cameras SET config = ? WHERE id = ?", (body.config.model_dump_json(), cam_id))
        if body.enabled is not None:
            await hub.apply_camera(cam_id)
        else:
            await hub.reconfigure_camera(cam_id)
        return public_camera(hub, get_camera(cam_id))

    @app.delete("/api/cameras/{cam_id}", status_code=204)
    async def delete_camera(cam_id: int, _: Auth, delete_events: bool = False):
        get_camera(cam_id)
        hub.db.execute("DELETE FROM cameras WHERE id = ?", (cam_id,))
        await hub.apply_camera(cam_id)
        if delete_events:
            for ev in hub.db.query("SELECT * FROM events WHERE camera_id = ?", (cam_id,)):
                hub.storage.delete_event(ev)

    @app.get("/api/cameras/{cam_id}/snapshot")
    async def snapshot(cam_id: int, _: Auth):
        cam = get_camera(cam_id)
        if not cam["enabled"]:
            raise HTTPException(409, "camera is in privacy mode")
        try:
            data = await hub.go2rtc.frame(cam_id)
        except httpx.HTTPError:
            data = None
        if not data:
            raise HTTPException(503, "camera unavailable")
        return Response(data, media_type="image/jpeg")

    @app.get("/api/cameras/{cam_id}/live")
    async def live(cam_id: int, _: Auth, quality: Literal["main", "sub"] = "sub", audio: bool = False):
        cam = get_camera(cam_id)
        if not cam["enabled"]:
            raise HTTPException(409, "camera is in privacy mode")
        try:
            upstream = await hub.go2rtc.client.send(hub.go2rtc.mp4_request(cam_id, quality == "sub", audio), stream=True)
        except httpx.HTTPError:
            raise HTTPException(503, "camera unavailable")
        if upstream.status_code != 200:
            await upstream.aclose()
            raise HTTPException(503, "camera unavailable")
        return StreamingResponse(upstream.aiter_raw(), media_type="video/mp4",
                                 background=BackgroundTask(upstream.aclose))

    @app.post("/api/cameras/{cam_id}/record", status_code=202)
    def record(cam_id: int, _: Auth):
        get_camera(cam_id)
        worker = hub.workers.get(cam_id)
        if not worker or not worker.online:
            raise HTTPException(409, "camera is offline")
        worker.trigger("manual", 1.0, [])
        return {"seconds": 30}

    @app.delete("/api/cameras/{cam_id}/record", status_code=204)
    def stop_record(cam_id: int, _: Auth):
        get_camera(cam_id)
        worker = hub.workers.get(cam_id)
        if worker:
            worker.stop_manual()

    def live_camera(cam_id: int) -> dict:
        cam = get_camera(cam_id)
        if not cam["enabled"]:
            raise HTTPException(409, "camera is in privacy mode")
        return cam

    @app.post("/api/cameras/{cam_id}/talk", status_code=204)
    async def talk(cam_id: int, _: Auth, request: Request):
        cam = live_camera(cam_id)
        if not capabilities(cam)["talk"]:
            raise HTTPException(409, "two-way audio is not set up for this camera")
        data = await request.body()
        if len(data) < 100:
            raise HTTPException(422, "empty recording")
        try:
            await hub.talk(cam_id, data)
        except ValueError as exc:
            raise HTTPException(422, str(exc))
        except (RuntimeError, httpx.HTTPError):
            raise HTTPException(503, "camera speaker not reachable")

    @app.post("/api/cameras/{cam_id}/siren")
    async def siren(cam_id: int, body: SirenIn, _: Auth):
        cam = live_camera(cam_id)
        if not capabilities(cam)["siren"]:
            raise HTTPException(409, "siren is not set up for this camera")
        try:
            await hub.siren(cam_id, body.on, body.seconds)
        except (RuntimeError, httpx.HTTPError) as exc:
            raise HTTPException(503, str(exc) or "camera not reachable")
        return {"on": body.on, "seconds": body.seconds if body.on else 0}

    @app.post("/api/cameras/{cam_id}/control/test")
    async def control_test(cam_id: int, _: Auth):
        get_camera(cam_id)
        ok, message = await hub.check_control(cam_id)
        return {"ok": ok, "message": message}

    @app.get("/internal/audio/{token}")
    def internal_audio(token: str, request: Request):
        """go2rtc fetches talk/siren audio here. No bearer token (go2rtc can't send one): the link is a
        random one-off name, and only the local machine may ask for it."""
        if not request.client or request.client.host not in ("127.0.0.1", "::1"):
            raise HTTPException(404)
        path = hub.shares.get(token) if len(token) <= 64 else None
        if not path:
            raise HTTPException(404)
        return FileResponse(path, media_type="audio/wav")

    # --- events -----------------------------------------------------------
    def cam_names() -> dict[int, str]:
        return {c["id"]: c["name"] for c in hub.db.query("SELECT id, name FROM cameras")}

    def get_event(ev_id: int) -> dict:
        ev = hub.db.one("SELECT * FROM events WHERE id = ?", (ev_id,))
        if not ev:
            raise HTTPException(404, "event not found")
        return ev

    @app.get("/api/events")
    def events(_: Auth, camera_id: int | None = None,
               kind: Literal["motion", "person", "manual"] | None = None,
               before: float | None = None, limit: int = Query(default=50, ge=1, le=200)):
        sql, args = "SELECT * FROM events WHERE 1 = 1", []
        if camera_id is not None:
            sql += " AND camera_id = ?"
            args.append(camera_id)
        if kind:
            sql += " AND kind = ?"
            args.append(kind)
        if before is not None:
            sql += " AND started_at < ?"
            args.append(before)
        sql += " ORDER BY started_at DESC LIMIT ?"
        args.append(limit)
        names = cam_names()
        return [public_event(e, names) for e in hub.db.query(sql, tuple(args))]

    @app.get("/api/events/stream")
    async def stream(_: Auth, request: Request):
        queue = hub.bus.subscribe()

        async def gen():
            try:
                yield "retry: 5000\n\n"
                while not await request.is_disconnected():
                    try:
                        msg = await asyncio.wait_for(queue.get(), timeout=20)
                    except asyncio.TimeoutError:
                        yield ": ping\n\n"
                        continue
                    if msg.get("type") == "event":
                        msg = {**msg, "event": public_event(msg["event"], cam_names())}
                    yield f"data: {json.dumps(msg)}\n\n"
            finally:
                hub.bus.unsubscribe(queue)

        return StreamingResponse(gen(), media_type="text/event-stream",
                                 headers={"Cache-Control": "no-store", "X-Accel-Buffering": "no"})

    @app.get("/api/events/{ev_id}")
    def event(ev_id: int, _: Auth):
        return public_event(get_event(ev_id), cam_names())

    @app.get("/api/events/{ev_id}/clip")
    def clip(ev_id: int, _: Auth):
        path = clip_path(settings.clips_dir, get_event(ev_id)["clip"])
        if not path:
            raise HTTPException(404, "clip not ready")
        return FileResponse(path, media_type="video/mp4", filename=f"obscura-{ev_id}.mp4",
                            headers={"Cache-Control": "private, max-age=3600"})

    @app.get("/api/events/{ev_id}/track")
    def track(ev_id: int, _: Auth):
        """Trigger zones and where motion / people were, timed to the clip."""
        data = get_event(ev_id).get("track")
        if not data:
            raise HTTPException(404, "no track")
        return json.loads(data)

    @app.get("/api/events/{ev_id}/thumb")
    def thumb(ev_id: int, _: Auth):
        path = clip_path(settings.clips_dir, get_event(ev_id)["thumb"])
        if not path:
            raise HTTPException(404, "no thumbnail")
        return FileResponse(path, media_type="image/jpeg", headers={"Cache-Control": "private, max-age=86400"})

    @app.delete("/api/events")
    def delete_events(_: Auth, camera_id: int | None = None):
        sql, args = "SELECT * FROM events", ()
        if camera_id is not None:
            sql, args = sql + " WHERE camera_id = ?", (camera_id,)
        rows = hub.db.query(sql, args)
        for ev in rows:
            hub.storage.delete_event(ev)
        return {"deleted": len(rows)}

    @app.delete("/api/events/{ev_id}", status_code=204)
    def delete_event(ev_id: int, _: Auth):
        hub.storage.delete_event(get_event(ev_id))

    # --- settings ---------------------------------------------------------
    @app.get("/api/settings/storage")
    def get_storage(_: Auth):
        cfg = hub.storage.config()
        return {**cfg, "usage": hub.storage.usage(), "backends": {k: sorted(v) for k, v in BACKEND_FIELDS.items()},
                "secret_fields": sorted(SECRET_FIELDS)}

    @app.put("/api/settings/storage")
    def put_storage(body: StorageIn, _: Auth):
        if body.cloud_type == "custom" and not valid_remote_name(body.custom_remote):
            raise HTTPException(422, "invalid rclone remote name")
        hub.db.set_kv("storage", {
            "retention_days": body.retention_days, "max_gb": body.max_gb,
            "cloud": {"enabled": body.cloud_enabled and body.cloud_type != "none", "type": body.cloud_type,
                      "path": body.cloud_path, "remote": body.custom_remote},
        })
        return hub.storage.config()

    @app.post("/api/settings/storage/backend", status_code=204)
    async def set_backend(body: BackendIn, _: Auth):
        try:
            await asyncio.to_thread(hub.storage.configure_backend, body.type, body.options)
        except ValueError as exc:
            raise HTTPException(422, str(exc))

    @app.post("/api/settings/storage/test")
    async def test_storage(_: Auth):
        ok, message = await asyncio.to_thread(hub.storage.test)
        return {"ok": ok, "message": message}

    @app.get("/api/settings/ntfy")
    def get_ntfy(_: Auth):
        cfg = hub.db.get_kv("ntfy") or {}
        return {"enabled": cfg.get("enabled", False), "server": cfg.get("server", "https://ntfy.sh"),
                "topic": cfg.get("topic", ""), "has_token": bool(cfg.get("token"))}

    @app.put("/api/settings/ntfy")
    def put_ntfy(body: NtfyIn, _: Auth):
        old = hub.db.get_kv("ntfy") or {}
        hub.db.set_kv("ntfy", {"enabled": body.enabled, "server": body.server, "topic": body.topic,
                               "token": old.get("token") if body.token is None else body.token})
        return get_ntfy(_)

    @app.put("/api/settings/name")
    def set_name(body: NameIn, _: Auth):
        hub.db.set_kv("hub_name", body.name.strip())
        return {"name": body.name.strip()}

    return app
