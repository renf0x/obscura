import base64
import hashlib
import json
import shutil
import sqlite3
import subprocess
import wave

import httpx
import pytest
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from fastapi.testclient import TestClient

from obscura import audio, hub as hub_module, tapo
from obscura.api import create_app
from obscura.db import Database

TAPO = {"name": "Door", "vendor": "tapo", "host": "192.168.1.50", "username": "u", "password": "p"}
CLOUD = "My TP-Link pass"


def up(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest().upper()


class FakeTapoCamera:
    """Device side of the Tapo control handshake, as the camera implements it."""

    def __init__(self, password: str, algo: str = "sha256", secure: bool = True):
        raw = password.encode()
        self.hashed = (hashlib.sha256(raw) if algo == "sha256" else hashlib.md5(raw)).hexdigest().upper()
        self.md5 = hashlib.md5(raw).hexdigest().upper()
        self.secure, self.nonce, self.cnonce = secure, "ABCDEF0123456789", None
        self.seq, self.requests = 100, []

    def _keys(self):
        key = up(self.cnonce + self.hashed + self.nonce)
        mk = lambda kind: hashlib.sha256((kind + self.cnonce + self.nonce + key).encode()).digest()[:16]
        return mk("lsk"), mk("ivb")

    def handle(self, request: httpx.Request) -> httpx.Response:
        body = json.loads(request.content)
        if request.url.path == "/":
            params = body["params"]
            if not self.secure:
                ok = params.get("password") == self.md5
                return httpx.Response(200, json={"error_code": 0, "result": {"stok": "STOK"}} if ok
                                      else {"error_code": -40411})
            if "digest_passwd" not in params:
                self.cnonce = params["cnonce"]
                confirm = up(self.cnonce + self.hashed + self.nonce) + self.nonce + self.cnonce
                return httpx.Response(200, json={"error_code": -40413, "result": {"data": {
                    "nonce": self.nonce, "device_confirm": confirm, "encrypt_type": ["3"]}}})
            if params["digest_passwd"] != up(self.hashed + self.cnonce + self.nonce) + self.cnonce + self.nonce:
                return httpx.Response(200, json={"error_code": -40411})
            return httpx.Response(200, json={"error_code": 0, "result": {
                "stok": "STOK", "start_seq": self.seq, "user_group": "root"}})
        assert request.url.path == "/stok=STOK/ds"
        if not self.secure:
            self.requests.append(body)
            return httpx.Response(200, json={"error_code": 0})
        assert request.headers["Seq"] == str(self.seq)
        assert request.headers["Tapo_tag"] == up(up(self.hashed + self.cnonce) + request.content.decode() + str(self.seq))
        self.seq += 1
        lsk, ivb = self._keys()
        dec = Cipher(algorithms.AES(lsk), modes.CBC(ivb)).decryptor()
        unpad = padding.PKCS7(128).unpadder()
        raw = base64.b64decode(body["params"]["request"])
        self.requests.append(json.loads(unpad.update(dec.update(raw) + dec.finalize()) + unpad.finalize()))
        pad = padding.PKCS7(128).padder()
        enc = Cipher(algorithms.AES(lsk), modes.CBC(ivb)).encryptor()
        answer = enc.update(pad.update(b'{"error_code":0}') + pad.finalize()) + enc.finalize()
        return httpx.Response(200, json={"error_code": 0, "result": {"response": base64.b64encode(answer).decode()}})


def client_for(cam: FakeTapoCamera, password: str) -> tapo.TapoClient:
    md5, sha = tapo.password_hashes(password)
    return tapo.TapoClient("192.168.1.50", md5, sha, transport=httpx.MockTransport(cam.handle))


@pytest.mark.parametrize("algo", ["sha256", "md5"])
def test_tapo_secure_login_and_alarm(algo):
    cam = FakeTapoCamera(CLOUD, algo)
    client = client_for(cam, CLOUD)
    client.alarm(True)
    client.alarm(False)
    assert client.algo == algo
    assert cam.requests == [
        {"method": "do", "msg_alarm": {"manual_msg_alarm": {"action": "start"}}},
        {"method": "do", "msg_alarm": {"manual_msg_alarm": {"action": "stop"}}},
    ]


def test_tapo_legacy_login():
    cam = FakeTapoCamera(CLOUD, secure=False)
    client = client_for(cam, CLOUD)
    client.alarm(True)
    assert client.algo == "md5" and cam.requests[0]["msg_alarm"]["manual_msg_alarm"]["action"] == "start"


def test_tapo_wrong_password():
    with pytest.raises(tapo.TapoError, match="wrong TP-Link"):
        client_for(FakeTapoCamera(CLOUD), "nope").alarm(True)


# --- API ------------------------------------------------------------------------

def add_tapo(client, auth, **extra):
    r = client.post("/api/cameras", json=TAPO | extra, headers=auth)
    assert r.status_code == 201, r.text
    return r.json()


def test_cloud_password_stored_only_as_hash(client, hub, auth, settings):
    cam = add_tapo(client, auth, cloud_password=CLOUD)
    assert cam["has_cloud_password"] is True
    assert cam["capabilities"] == {"talk": True, "siren": "tapo"}
    assert CLOUD not in client.get("/api/cameras", headers=auth).text
    row = hub.db.camera(cam["id"])
    assert row["cloud_md5"] == hashlib.md5(CLOUD.encode()).hexdigest().upper()
    raw = b"".join(p.read_bytes() for p in settings.data_dir.glob("obscura.db*"))
    assert CLOUD.encode() not in raw
    # go2rtc gets the two-way audio source with the hash, never the password.
    assert hub.go2rtc.talk[cam["id"]] == f"tapo://admin:{row['cloud_md5']}@192.168.1.50"


def test_cloud_password_kept_cleared_and_capabilities(client, hub, auth):
    cam = add_tapo(client, auth, cloud_password=CLOUD)
    client.put(f"/api/cameras/{cam['id']}", json=TAPO, headers=auth)
    assert hub.db.camera(cam["id"])["cloud_md5"]
    r = client.put(f"/api/cameras/{cam['id']}", json=TAPO | {"cloud_password": ""}, headers=auth).json()
    assert r["has_cloud_password"] is False and r["capabilities"] == {"talk": False, "siren": None}
    other = client.post("/api/cameras", json=TAPO | {"vendor": "hikvision", "two_way": True}, headers=auth).json()
    assert other["capabilities"] == {"talk": True, "siren": "speaker"}


def test_talk_and_siren_need_setup_and_live_camera(client, auth):
    cam = add_tapo(client, auth)
    assert client.post(f"/api/cameras/{cam['id']}/talk", content=b"x" * 500, headers=auth).status_code == 409
    assert client.post(f"/api/cameras/{cam['id']}/siren", json={"on": True}, headers=auth).status_code == 409
    cam = add_tapo(client, auth, host="192.168.1.51", cloud_password=CLOUD)
    client.patch(f"/api/cameras/{cam['id']}", json={"enabled": False}, headers=auth)
    assert client.post(f"/api/cameras/{cam['id']}/siren", json={"on": True}, headers=auth).status_code == 409


@pytest.mark.parametrize("body", [{"on": True, "seconds": 0}, {"on": True, "seconds": 3600}, {}])
def test_siren_input_validated(client, auth, body):
    cam = add_tapo(client, auth, cloud_password=CLOUD)
    assert client.post(f"/api/cameras/{cam['id']}/siren", json=body, headers=auth).status_code == 422


def test_tapo_siren_uses_control_api(client, hub, auth, monkeypatch):
    calls = []
    monkeypatch.setattr(tapo.TapoClient, "alarm", lambda self, on: calls.append(on))
    cam = add_tapo(client, auth, cloud_password=CLOUD)
    assert client.post(f"/api/cameras/{cam['id']}/siren", json={"on": True, "seconds": 10}, headers=auth).json() \
        == {"on": True, "seconds": 10}
    client.post(f"/api/cameras/{cam['id']}/siren", json={"on": False}, headers=auth)
    assert calls == [True, False]


def test_speaker_siren_goes_through_go2rtc(client, hub, auth):
    cam = client.post("/api/cameras", json=TAPO | {"vendor": "generic", "two_way": True}, headers=auth).json()
    assert client.post(f"/api/cameras/{cam['id']}/siren", json={"on": True}, headers=auth).status_code == 200
    client.post(f"/api/cameras/{cam['id']}/siren", json={"on": False}, headers=auth)
    (cid, src), (_, stop) = hub.go2rtc.played
    assert cid == cam["id"] and stop == ""
    assert src.startswith("ffmpeg:http://127.0.0.1:") and src.endswith("#audio=pcma#input=file")


def test_talk_body_limit(client, auth, ffmpeg):
    cam = add_tapo(client, auth, cloud_password=CLOUD)
    r = client.post(f"/api/cameras/{cam['id']}/talk", content=b"x" * (2 * 1024 * 1024), headers=auth)
    assert r.status_code == 413
    # Garbage within the limit reaches ffmpeg and is rejected there, not by the size check.
    r = client.post(f"/api/cameras/{cam['id']}/talk", content=b"x" * 200_000, headers=auth)
    assert r.status_code == 422


@pytest.fixture
def ffmpeg(monkeypatch):
    exe = shutil.which("ffmpeg")
    if not exe:
        imageio_ffmpeg = pytest.importorskip("imageio_ffmpeg")
        exe = imageio_ffmpeg.get_ffmpeg_exe()
    monkeypatch.setattr(audio, "FFMPEG", exe)
    return exe


def test_talk_end_to_end(client, hub, auth, settings, ffmpeg, tmp_path):
    rec = tmp_path / "rec.m4a"
    subprocess.run([ffmpeg, "-f", "lavfi", "-i", "sine=frequency=440:duration=2", "-c:a", "aac", "-y", str(rec)],
                   check=True, capture_output=True)
    cam = add_tapo(client, auth, cloud_password=CLOUD)
    r = client.post(f"/api/cameras/{cam['id']}/talk", content=rec.read_bytes(), headers=auth)
    assert r.status_code == 204, r.text
    src = hub.go2rtc.played[-1][1]
    path = src.split("#")[0].split("127.0.0.1:")[1].split("/", 1)[1]
    # Only the local machine (go2rtc) may fetch the audio.
    assert client.get("/" + path).status_code == 404
    with TestClient(create_app(settings, hub), client=("127.0.0.1", 5000)) as local:
        r = local.get("/" + path)
        assert r.status_code == 200 and r.content[:4] == b"RIFF"
        assert local.get("/internal/audio/" + "A" * 43).status_code == 404
    with wave.open(str(next(hub.audio_dir.glob("*.wav")))) as w:
        assert (w.getframerate(), w.getnchannels()) == (8000, 1) and 1.5 < w.getnframes() / 8000 < 2.5


def test_person_triggers_automatic_siren(client, hub, auth, monkeypatch):
    fired = []

    async def fake_siren(cam_id, on, seconds=30):
        fired.append((cam_id, on, seconds))

    cam = add_tapo(client, auth, cloud_password=CLOUD)
    cfg = client.get(f"/api/cameras/{cam['id']}", headers=auth).json()["config"]
    client.patch(f"/api/cameras/{cam['id']}", json={"config": cfg | {"siren_on_person": True, "siren_seconds": 20}},
                 headers=auth)
    monkeypatch.setattr(hub, "siren", fake_siren)
    hub._on_person(cam["id"])
    client.get("/api/health")  # let the event loop run the scheduled coroutine
    assert fired == [(cam["id"], True, 20)]


def test_siren_wav(tmp_path):
    audio.write_siren(tmp_path / "s.wav", seconds=2)
    with wave.open(str(tmp_path / "s.wav")) as w:
        assert w.getframerate() == 8000 and w.getnframes() == 16000


def test_old_database_is_migrated(tmp_path):
    conn = sqlite3.connect(tmp_path / "obscura.db")
    conn.execute("CREATE TABLE cameras (id INTEGER PRIMARY KEY, name TEXT NOT NULL, vendor TEXT NOT NULL, "
                 "host TEXT NOT NULL, port INTEGER NOT NULL, username TEXT NOT NULL DEFAULT '', "
                 "password TEXT NOT NULL DEFAULT '', main_path TEXT NOT NULL, sub_path TEXT NOT NULL DEFAULT '', "
                 "enabled INTEGER NOT NULL DEFAULT 1, config TEXT NOT NULL DEFAULT '{}')")
    conn.execute("INSERT INTO cameras(name, vendor, host, port, main_path) VALUES('a', 'tapo', 'h', 554, '/s')")
    conn.commit()
    conn.close()
    cam = Database(tmp_path / "obscura.db").camera(1)
    assert cam["cloud_md5"] == "" and cam["two_way"] == 0
    assert hub_module.capabilities(cam) == {"talk": False, "siren": None}


def test_control_test_learns_hash_for_go2rtc(client, hub, auth, monkeypatch):
    cam = add_tapo(client, auth, cloud_password=CLOUD)
    monkeypatch.setattr(tapo.TapoClient, "check", lambda self: "sha256")
    assert client.post(f"/api/cameras/{cam['id']}/control/test", headers=auth).json() == {"ok": True, "message": "ok"}
    row = hub.db.camera(cam["id"])
    assert row["cloud_algo"] == "sha256"
    assert hub.go2rtc.talk[cam["id"]] == f"tapo://admin:{row['cloud_sha256']}@192.168.1.50"


def test_control_test_reports_wrong_password(client, auth, monkeypatch):
    def refuse(self):
        raise tapo.TapoError("wrong TP-Link account password")

    cam = add_tapo(client, auth, cloud_password=CLOUD)
    monkeypatch.setattr(tapo.TapoClient, "check", refuse)
    r = client.post(f"/api/cameras/{cam['id']}/control/test", headers=auth).json()
    assert r == {"ok": False, "message": "wrong TP-Link account password"}
    assert client.get(f"/api/cameras/{cam['id']}", headers=auth).json()["control_error"] == r["message"]
