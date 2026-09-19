import pytest
from fastapi.testclient import TestClient

from obscura import hub as hub_module, tapo
from obscura.api import create_app
from obscura.config import Settings
from obscura.worker import camera_config


class FakeGo2rtc:
    def __init__(self):
        self.registered: dict[int, tuple] = {}
        self.talk: dict[int, str | None] = {}
        self.played: list[tuple[int, str]] = []

    def rtsp_url(self, name):
        return f"rtsp://127.0.0.1:8554/{name}"

    async def register(self, cam_id, main, sub, talk=None):
        self.registered[cam_id] = (main, sub)
        self.talk[cam_id] = talk

    async def play(self, cam_id, src):
        self.played.append((cam_id, src))

    async def stop_play(self, cam_id):
        self.played.append((cam_id, ""))

    async def unregister(self, cam_id):
        self.registered.pop(cam_id, None)

    async def frame(self, cam_id):
        return b"\xff\xd8fake\xff\xd9"


class FakeWorker:
    def __init__(self, cam, *args, **kwargs):
        self.cam_id = cam["id"]
        self.online = True
        self.resolution = (640, 360)
        self.triggers = []
        self.cfg = camera_config(cam["config"])
        self.last_frame = 0.0
        self.reconfigured = 0

    def reconfigure(self, cam):
        self.cfg = camera_config(cam["config"])
        self.reconfigured += 1

    def start(self):
        pass

    def stop(self):
        pass

    def trigger(self, kind, score, zones, frame=None, box=None):
        self.triggers.append(kind)

    def stop_manual(self):
        self.triggers.append("stop")


@pytest.fixture
def settings(tmp_path):
    return Settings(data_dir=tmp_path, host="127.0.0.1", port=0,
                    go2rtc_api="http://127.0.0.1:1", go2rtc_rtsp="rtsp://127.0.0.1:1",
                    model_path=tmp_path / "missing.onnx")


@pytest.fixture
def hub(settings, monkeypatch):
    monkeypatch.setattr(hub_module, "CameraWorker", FakeWorker)
    # Tapo cameras get a background login check; keep tests off the real network.
    monkeypatch.setattr(tapo.TapoClient, "check", lambda self: "md5")
    h = hub_module.Hub(settings)
    h.go2rtc = FakeGo2rtc()

    async def idle():
        return None

    h.keep_registered = idle
    return h


@pytest.fixture
def client(settings, hub):
    with TestClient(create_app(settings, hub)) as c:
        yield c


@pytest.fixture
def auth(client, hub):
    code = hub.new_pairing_code()
    r = client.post("/api/pair", json={"code": code, "device_name": "test phone"})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['token']}"}
