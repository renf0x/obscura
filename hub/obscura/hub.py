"""Wires cameras, go2rtc registrations and per-camera workers together."""

import asyncio
import contextlib
import logging
import time

import httpx

from . import audio, security
from .config import Settings
from .db import Database
from .detect import load_person_detector
from .go2rtc import Go2rtc, stream_names
from .notify import EventBus, Notifier
from .storage import Storage
from .tapo import TapoClient, TapoError
from .worker import CameraWorker, camera_config

log = logging.getLogger(__name__)

# RTSP paths of common camera families. "generic" lets the user type their own.
PRESETS = {
    "tapo": {"label": "TP-Link Tapo (C100/C110/C200/C210/C310...)", "port": 554, "main": "/stream1", "sub": "/stream2"},
    "hikvision": {"label": "Hikvision / HiLook", "port": 554, "main": "/Streaming/Channels/101", "sub": "/Streaming/Channels/102"},
    "dahua": {"label": "Dahua / Imou / Amcrest", "port": 554, "main": "/cam/realmonitor?channel=1&subtype=0",
              "sub": "/cam/realmonitor?channel=1&subtype=1"},
    "reolink": {"label": "Reolink", "port": 554, "main": "/h264Preview_01_main", "sub": "/h264Preview_01_sub"},
    "generic": {"label": "Other RTSP / ONVIF camera", "port": 554, "main": "/", "sub": ""},
}


def camera_urls(cam: dict) -> tuple[str, str | None, str | None]:
    """(main RTSP, sub RTSP, two-way audio source) for go2rtc."""
    main = security.build_rtsp_url(cam["host"], cam["port"], cam["username"], cam["password"], cam["main_path"])
    sub = None
    if cam["sub_path"]:
        sub = security.build_rtsp_url(cam["host"], cam["port"], cam["username"], cam["password"], cam["sub_path"])
    return main, sub, tapo_talk_url(cam)


def has_tapo_control(cam: dict) -> bool:
    return cam["vendor"] == "tapo" and bool(cam["cloud_md5"])


def tapo_talk_url(cam: dict) -> str | None:
    """go2rtc's tapo:// source (Tapo's own protocol) carries the speaker channel. It takes the uppercase
    hash of the TP-Link account password; which hash depends on the firmware (learned at login)."""
    if not has_tapo_control(cam) or not security.valid_host(cam["host"]):
        return None
    secret = cam["cloud_sha256"] if cam["cloud_algo"] == "sha256" else cam["cloud_md5"]
    host = f"[{cam['host']}]" if ":" in cam["host"] else cam["host"]
    return f"tapo://admin:{secret}@{host}"


def capabilities(cam: dict) -> dict:
    """What the app may offer for this camera. Other brands talk through the RTSP backchannel, which
    go2rtc uses automatically; the user tells us the camera has a speaker."""
    tapo = has_tapo_control(cam)
    return {
        "talk": tapo or bool(cam["two_way"]),
        "siren": "tapo" if tapo else ("speaker" if cam["two_way"] else None),
    }


class Hub:
    def __init__(self, settings: Settings):
        self.s = settings
        settings.clips_dir.mkdir(parents=True, exist_ok=True)
        settings.buffer_dir.mkdir(parents=True, exist_ok=True)
        self.db = Database(settings.db_path)
        self.bus = EventBus()
        self.notifier = Notifier(self.db, self.bus)
        self.storage = Storage(settings, self.db)
        self.go2rtc = Go2rtc(settings.go2rtc_api, settings.go2rtc_rtsp)
        self.person = load_person_detector(settings.model_path)
        self.workers: dict[int, CameraWorker] = {}
        self.started_at = time.time()
        self.shares = audio.Shares()
        self.audio_dir = settings.buffer_dir / "audio"  # RAM (tmpfs) in the Docker setup
        self.audio_dir.mkdir(parents=True, exist_ok=True)
        self.control_status: dict[int, str] = {}  # last Tapo login problem, shown in the app
        self._tapo: dict[int, TapoClient] = {}
        self._siren_off: dict[int, asyncio.TimerHandle] = {}
        self._loop: asyncio.AbstractEventLoop | None = None

    async def start(self) -> None:
        self._loop = asyncio.get_running_loop()
        self.storage.start()
        for cam in self.db.cameras():
            try:
                await self.apply_camera(cam["id"])
            except Exception:
                log.exception("camera %s failed to start", cam["id"])
        if not self.db.one("SELECT id FROM devices LIMIT 1"):
            code = self.new_pairing_code()
            log.warning("No phone paired yet. Pairing code (valid 10 min): %s", code)

    async def stop(self) -> None:
        for worker in list(self.workers.values()):
            await asyncio.to_thread(worker.stop)
        self.storage.stop()
        for client in self._tapo.values():
            client.close()

    async def reconfigure_camera(self, cam_id: int) -> None:
        """Settings that don't touch the streams are swapped into the running worker; others restart it."""
        cam = self.db.camera(cam_id)
        worker = self.workers.get(cam_id)
        if cam and cam["enabled"] and worker \
                and camera_config(cam["config"])["record_quality"] == worker.cfg["record_quality"]:
            worker.reconfigure(cam)
        else:
            await self.apply_camera(cam_id)

    async def apply_camera(self, cam_id: int) -> None:
        """(Re)start everything for one camera after it was created, edited or deleted."""
        old = self.workers.pop(cam_id, None)
        if old:
            await asyncio.to_thread(old.stop)  # joins threads; keep the event loop free
        client = self._tapo.pop(cam_id, None)
        if client:
            client.close()
        self.control_status.pop(cam_id, None)
        cam = self.db.camera(cam_id)
        if not cam:
            await self.go2rtc.unregister(cam_id)
            return
        if not cam["enabled"]:  # privacy mode: no detection, no recording, no live
            await self.go2rtc.unregister(cam_id)
            return
        try:
            await self.go2rtc.register(cam_id, *camera_urls(cam))
        except httpx.HTTPError as exc:  # keep_registered() retries; the worker reconnects on its own
            log.warning("go2rtc not reachable: %s", exc)
        main_name, sub_name = stream_names(cam_id)
        record_name = sub_name if camera_config(cam["config"])["record_quality"] == "low" else main_name
        worker = CameraWorker(cam, self.s, self.db, self.notifier, self.storage, self.person,
                              sub_url=self.go2rtc.rtsp_url(sub_name), main_url=self.go2rtc.rtsp_url(record_name),
                              on_person=self._on_person)
        if old:
            worker.last_frame = old.last_frame  # still "online" while the new worker reconnects
        self.workers[cam_id] = worker
        worker.start()
        if has_tapo_control(cam) and not cam["cloud_algo"]:
            asyncio.create_task(self.check_control(cam_id))

    # --- speaker, siren -----------------------------------------------------
    def _tapo_client(self, cam: dict) -> TapoClient:
        client = self._tapo.get(cam["id"])
        if not client:
            client = self._tapo[cam["id"]] = TapoClient(cam["host"], cam["cloud_md5"], cam["cloud_sha256"])
        return client

    async def check_control(self, cam_id: int) -> tuple[bool, str]:
        """Log in to the Tapo control API; remembers which password hash the firmware wants."""
        cam = self.db.camera(cam_id)
        if not cam or not has_tapo_control(cam):
            return False, "no TP-Link account password set"
        try:
            algo = await asyncio.to_thread(self._tapo_client(cam).check)
        except (TapoError, httpx.HTTPError) as exc:
            message = str(exc) if isinstance(exc, TapoError) else "camera control port not reachable"
            self.control_status[cam_id] = message
            return False, message
        self.control_status.pop(cam_id, None)
        if algo != cam["cloud_algo"]:
            self.db.execute("UPDATE cameras SET cloud_algo = ? WHERE id = ?", (algo, cam_id))
            cam = self.db.camera(cam_id)
            if cam and cam["enabled"]:
                with contextlib.suppress(httpx.HTTPError):
                    await self.go2rtc.register(cam_id, *camera_urls(cam))
        return True, "ok"

    def _audio_src(self, token: str) -> str:
        # go2rtc and the hub share the host network; #input=file makes ffmpeg read at real-time speed.
        return f"ffmpeg:http://127.0.0.1:{self.s.port}/internal/audio/{token}#audio=pcma#input=file"

    async def talk(self, cam_id: int, recording: bytes) -> None:
        name = security.new_token()
        src, dst = self.audio_dir / f"{name}.m4a", self.audio_dir / f"{name}.wav"
        src.write_bytes(recording)
        try:
            await asyncio.to_thread(audio.transcode_talk, src, dst)
        finally:
            src.unlink(missing_ok=True)
        try:
            await self.go2rtc.play(cam_id, self._audio_src(self.shares.add(dst)))
        except (RuntimeError, httpx.HTTPError):
            dst.unlink(missing_ok=True)
            raise

    async def siren(self, cam_id: int, on: bool, seconds: int = 30) -> None:
        cam = self.db.camera(cam_id)
        if not cam:
            return
        mode = capabilities(cam)["siren"]
        if not mode:
            raise RuntimeError("this camera has no siren or speaker")
        timer = self._siren_off.pop(cam_id, None)
        if timer:
            timer.cancel()
        if mode == "tapo":
            try:
                await asyncio.to_thread(self._tapo_client(cam).alarm, on)
            except httpx.HTTPError:
                raise RuntimeError("camera control port not reachable")
            except TapoError as exc:
                raise RuntimeError(str(exc))
        elif on:
            siren = self.audio_dir / "siren.wav"
            if not siren.exists():
                await asyncio.to_thread(audio.write_siren, siren)
            await self.go2rtc.play(cam_id, self._audio_src(self.shares.add(siren, delete_after=False)))
        else:
            await self.go2rtc.stop_play(cam_id)
        if on:  # never leave a siren howling: switch it off after the chosen time
            self._siren_off[cam_id] = asyncio.get_running_loop().call_later(
                seconds, lambda: asyncio.create_task(self._siren_quiet(cam_id)))

    async def _siren_quiet(self, cam_id: int) -> None:
        self._siren_off.pop(cam_id, None)
        try:
            await self.siren(cam_id, False)
        except Exception as exc:
            log.warning("could not stop siren on camera %s: %s", cam_id, exc)

    def _on_person(self, cam_id: int) -> None:
        """Called from a camera worker thread when a person event starts."""
        cam = self.db.camera(cam_id)
        if not cam or not self._loop:
            return
        cfg = camera_config(cam["config"])
        if not cfg["siren_on_person"] or not capabilities(cam)["siren"]:
            return

        async def run():
            try:
                await self.siren(cam_id, True, cfg["siren_seconds"])
            except Exception as exc:
                log.warning("automatic siren on camera %s failed: %s", cam_id, exc)

        asyncio.run_coroutine_threadsafe(run(), self._loop)

    async def keep_registered(self) -> None:
        """go2rtc may start later or restart; PUT is idempotent, so just repeat it."""
        while True:
            for cam in self.db.cameras():
                if cam["enabled"]:
                    try:
                        await self.go2rtc.register(cam["id"], *camera_urls(cam))
                    except Exception as exc:
                        log.warning("go2rtc not reachable: %s", exc)
                        break
            await asyncio.sleep(60)

    def new_pairing_code(self) -> str:
        return new_pairing_code(self.db)


def new_pairing_code(db: Database) -> str:
    """Store a fresh one-time code (hashed) and return it for display."""
    db.purge_expired_pairing()
    code = security.new_pairing_code()
    db.execute("INSERT INTO pairing(code_hash, expires_at) VALUES(?, ?)",
               (security.hash_secret(code), time.time() + security.PAIRING_TTL))
    return code
