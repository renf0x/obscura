import time

import pytest

from obscura import security

PROTECTED = [
    ("get", "/api/overview"), ("get", "/api/cameras"), ("post", "/api/cameras"),
    ("get", "/api/cameras/1"), ("get", "/api/cameras/1/live"), ("get", "/api/cameras/1/snapshot"),
    ("get", "/api/events"), ("delete", "/api/events"), ("get", "/api/events/1/clip"), ("get", "/api/events/stream"),
    ("get", "/api/devices"), ("post", "/api/pairing-code"), ("get", "/api/settings/storage"),
    ("put", "/api/settings/ntfy"), ("get", "/api/discover"),
    ("post", "/api/cameras/1/talk"), ("post", "/api/cameras/1/siren"), ("post", "/api/cameras/1/control/test"),
]

TAPO = {"name": "Front door", "vendor": "tapo", "host": "192.168.1.50",
        "username": "cam user", "password": "p@ss:w/rd#1"}


def test_health_is_public(client):
    assert client.get("/api/health").json()["ok"] is True


@pytest.mark.parametrize("method,path", PROTECTED)
def test_every_route_requires_token(client, method, path):
    assert getattr(client, method)(path).status_code == 401
    r = getattr(client, method)(path, headers={"Authorization": "Bearer nope"})
    assert r.status_code == 401


def test_docs_are_disabled(client):
    for path in ("/docs", "/redoc", "/openapi.json"):
        assert client.get(path).status_code == 404


def test_pairing_code_is_single_use(client, hub):
    code = hub.new_pairing_code()
    body = {"code": code, "device_name": "a"}
    assert client.post("/api/pair", json=body).status_code == 200
    assert client.post("/api/pair", json=body).status_code == 403


def test_pairing_code_expires(client, hub):
    code = hub.new_pairing_code()
    hub.db.execute("UPDATE pairing SET expires_at = ?", (time.time() - 1,))
    assert client.post("/api/pair", json={"code": code, "device_name": "a"}).status_code == 403


def test_pairing_is_rate_limited(client):
    codes = [client.post("/api/pair", json={"code": "WRONGCODE1", "device_name": "x"}).status_code
             for _ in range(7)]
    assert codes[:5] == [403] * 5
    assert codes[5:] == [429, 429]


def test_token_is_stored_hashed(client, hub, auth):
    token = auth["Authorization"].split()[1]
    row = hub.db.one("SELECT token_hash FROM devices")
    assert row["token_hash"] == security.hash_secret(token) != token


def test_revoked_device_loses_access(client, auth):
    me = [d for d in client.get("/api/devices", headers=auth).json() if d["current"]][0]
    assert client.delete(f"/api/devices/{me['id']}", headers=auth).status_code == 204
    assert client.get("/api/cameras", headers=auth).status_code == 401


def test_camera_password_never_returned(client, hub, auth):
    r = client.post("/api/cameras", json=TAPO, headers=auth)
    assert r.status_code == 201, r.text
    cam = r.json()
    assert "password" not in cam and cam["has_password"] is True
    assert TAPO["password"] not in client.get("/api/cameras", headers=auth).text
    # Credentials are percent-encoded into the RTSP URL handed to go2rtc.
    main, sub = hub.go2rtc.registered[cam["id"]]
    assert main == "rtsp://cam%20user:p%40ss%3Aw%2Frd%231@192.168.1.50:554/stream1"
    assert sub.endswith("/stream2")


def test_update_keeps_password_when_omitted(client, hub, auth):
    cam = client.post("/api/cameras", json=TAPO, headers=auth).json()
    body = {k: v for k, v in TAPO.items() if k != "password"} | {"name": "Door"}
    assert client.put(f"/api/cameras/{cam['id']}", json=body, headers=auth).status_code == 200
    assert hub.db.camera(cam["id"])["password"] == TAPO["password"]


@pytest.mark.parametrize("patch", [
    {"host": "file:///etc/passwd"},
    {"host": "192.168.1.5/../x"},
    {"host": "a b"},
    {"main_path": "stream1"},
    {"main_path": "/x#backchannel=1"},
    {"main_path": "/a b"},
    {"vendor": "exec"},
    {"port": 0},
    {"username": "a\nb"},
])
def test_camera_input_is_validated(client, auth, patch):
    assert client.post("/api/cameras", json=TAPO | patch, headers=auth).status_code == 422


def test_zone_config_validation(client, auth):
    cam = client.post("/api/cameras", json=TAPO, headers=auth).json()
    good = {"zones": [{"id": "z1", "name": "Porch", "points": [[0.1, 0.1], [0.5, 0.1], [0.3, 0.6]],
                       "motion": False, "person": True}], "sensitivity": "high"}
    r = client.patch(f"/api/cameras/{cam['id']}", json={"config": good}, headers=auth)
    assert r.status_code == 200
    assert r.json()["config"]["zones"][0]["person"] is True
    bad = {"zones": [{"id": "z1", "points": [[0.1, 0.1], [1.5, 0.1], [0.3, 0.6]]}]}
    assert client.patch(f"/api/cameras/{cam['id']}", json={"config": bad}, headers=auth).status_code == 422


def test_privacy_mode_blocks_live(client, hub, auth):
    cam = client.post("/api/cameras", json=TAPO, headers=auth).json()
    client.patch(f"/api/cameras/{cam['id']}", json={"enabled": False}, headers=auth)
    assert cam["id"] not in hub.go2rtc.registered
    assert client.get(f"/api/cameras/{cam['id']}/live", headers=auth).status_code == 409


def test_clip_path_traversal_blocked(client, hub, auth, settings):
    secret = settings.data_dir / "obscura.db"
    ev = hub.db.execute("INSERT INTO events(camera_id, kind, started_at, clip, thumb) VALUES(1, 'motion', ?, ?, ?)",
                        (time.time(), "../obscura.db", str(secret)))
    assert client.get(f"/api/events/{ev}/clip", headers=auth).status_code == 404
    assert client.get(f"/api/events/{ev}/thumb", headers=auth).status_code == 404


def test_clip_is_served(client, hub, auth, settings):
    (settings.clips_dir / "1").mkdir(parents=True)
    (settings.clips_dir / "1" / "5.mp4").write_bytes(b"0123456789")
    ev = hub.db.execute("INSERT INTO events(camera_id, kind, started_at, clip) VALUES(1, 'person', ?, '1/5.mp4')",
                        (time.time(),))
    r = client.get(f"/api/events/{ev}/clip", headers=auth | {"Range": "bytes=2-4"})
    assert r.status_code == 206 and r.content == b"234"


def test_track_needs_auth_and_is_served(client, hub, auth):
    track = '{"zones":[],"marks":[[1.2,[[0.5,0.5,0.1]],null]]}'
    ev = hub.db.execute("INSERT INTO events(camera_id, kind, started_at, track) VALUES(1, 'motion', ?, ?)",
                        (time.time(), track))
    assert client.get(f"/api/events/{ev}/track").status_code == 401
    r = client.get(f"/api/events/{ev}/track", headers=auth)
    assert r.status_code == 200 and r.json()["marks"][0][0] == 1.2
    assert client.get(f"/api/events/{ev}", headers=auth).json()["has_track"] is True


def test_delete_all_events(client, hub, auth, settings):
    (settings.clips_dir / "1").mkdir(parents=True)
    clip = settings.clips_dir / "1" / "9.mp4"
    clip.write_bytes(b"x")
    for cam, name in ((1, "1/9.mp4"), (1, None), (2, None)):
        hub.db.execute("INSERT INTO events(camera_id, kind, started_at, clip) VALUES(?, 'motion', ?, ?)",
                       (cam, time.time(), name))
    assert client.delete("/api/events?camera_id=2", headers=auth).json() == {"deleted": 1}
    assert client.delete("/api/events", headers=auth).json() == {"deleted": 2}
    assert client.get("/api/events", headers=auth).json() == [] and not clip.exists()


def test_large_body_rejected(client, auth):
    r = client.post("/api/cameras", content=b"x" * 70000, headers=auth | {"Content-Type": "application/json"})
    assert r.status_code == 413


def test_security_headers(client):
    h = client.get("/api/health").headers
    assert h["x-content-type-options"] == "nosniff"
    assert h["cache-control"] == "no-store"
    assert "server" not in h or "uvicorn" not in h["server"].lower()


@pytest.mark.parametrize("endpoint", [
    "http://127.0.0.1:8080/x", "http://169.254.169.254/latest", "file:///etc/passwd",
    "http://localhost/x", "https://user:pw@ntfy.sh/up", "gopher://x",
    "http://127.1:1984/api/streams", "http://0x7f000001/x", "http://[::1]/x",
])
def test_push_endpoint_ssrf_guard(client, auth, endpoint):
    key = "A" * 43
    assert client.put("/api/devices/me/push", json={"endpoint": endpoint, "key": key}, headers=auth).status_code == 422


def test_push_endpoint_accepts_unifiedpush(client, auth, monkeypatch):
    monkeypatch.setattr(security.socket, "getaddrinfo", lambda *a, **k: [(2, 1, 6, "", ("159.203.148.75", 0))])
    body = {"endpoint": "https://ntfy.sh/upAbc123?up=1", "key": "A" * 43}
    assert client.put("/api/devices/me/push", json=body, headers=auth).status_code == 204


def test_ntfy_token_is_write_only(client, auth, monkeypatch):
    monkeypatch.setattr(security.socket, "getaddrinfo", lambda *a, **k: [(2, 1, 6, "", ("159.203.148.75", 0))])
    body = {"enabled": True, "server": "https://ntfy.sh", "topic": "obscura_x1", "token": "tk_secret"}
    r = client.put("/api/settings/ntfy", json=body, headers=auth)
    assert r.status_code == 200 and "tk_secret" not in r.text and r.json()["has_token"] is True


def test_storage_rejects_unknown_backend_options(client, auth):
    body = {"type": "webdav", "options": {"url": "https://dav.example", "exec": "rm -rf /"}}
    assert client.post("/api/settings/storage/backend", json=body, headers=auth).status_code == 422


@pytest.mark.parametrize("path", ["../etc", "-flag", "/abs", "a/../../b"])
def test_storage_path_validation(client, auth, path):
    body = {"retention_days": 7, "max_gb": 5, "cloud_enabled": True, "cloud_type": "s3", "cloud_path": path}
    assert client.put("/api/settings/storage", json=body, headers=auth).status_code == 422


def test_manual_record(client, hub, auth):
    cam = client.post("/api/cameras", json=TAPO, headers=auth).json()
    assert client.post(f"/api/cameras/{cam['id']}/record", headers=auth).status_code == 202
    assert hub.workers[cam["id"]].triggers == ["manual"]
    assert client.delete(f"/api/cameras/{cam['id']}/record", headers=auth).status_code == 204
    assert hub.workers[cam["id"]].triggers == ["manual", "stop"]


def test_zone_change_keeps_camera_running(client, hub, auth):
    """Saving zones must not restart the camera: that dropped the pre-event buffer and showed it offline."""
    cam = client.post("/api/cameras", json=TAPO, headers=auth).json()
    worker = hub.workers[cam["id"]]
    zones = {"zones": [{"id": "z1", "name": "Porch", "points": [[0.1, 0.1], [0.5, 0.1], [0.3, 0.6]]}]}
    assert client.patch(f"/api/cameras/{cam['id']}", json={"config": zones}, headers=auth).status_code == 200
    assert hub.workers[cam["id"]] is worker and worker.reconfigured == 1
    assert worker.cfg["zones"][0]["name"] == "Porch"
    # Switching the recorded stream does need a restart.
    low = {**zones, "record_quality": "low"}
    assert client.patch(f"/api/cameras/{cam['id']}", json={"config": low}, headers=auth).status_code == 200
    assert hub.workers[cam["id"]] is not worker
