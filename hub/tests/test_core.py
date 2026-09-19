import base64
import json
import os
from datetime import datetime
from pathlib import Path

import numpy as np
import pytest
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from obscura import security
from obscura.detect import MotionDetector, zone_mask, zones_hit
from obscura.recorder import ffmpeg_segment_cmd, pick_segments
from obscura.worker import schedule_active

ZONE = {"id": "z", "name": "Porch", "points": [[0.0, 0.0], [0.5, 0.0], [0.5, 1.0], [0.0, 1.0]],
        "motion": True, "person": True}


def frames_with_square(x: int, y: int, n: int = 8):
    """A static dark frame with a bright square appearing at (x, y) after two frames."""
    out = []
    for i in range(n):
        f = np.zeros((360, 640, 3), np.uint8)
        if i >= 2:
            f[y:y + 80, x:x + 80] = 255
        out.append(f)
    return out


def run(detector, frames):
    return max(detector.update(f) for f in frames)


def test_motion_inside_zone_triggers():
    assert run(MotionDetector([ZONE], "medium"), frames_with_square(60, 100)) > 0


def test_motion_spots_mark_the_moving_area():
    det = MotionDetector([ZONE], "medium")
    run(det, frames_with_square(60, 100))
    assert det.spots and abs(det.spots[0][0] - 100 / 640) < 0.03 and abs(det.spots[0][1] - 140 / 360) < 0.03


def test_motion_outside_zone_ignored():
    assert run(MotionDetector([ZONE], "medium"), frames_with_square(480, 100)) == 0


def test_no_zones_means_whole_frame():
    assert run(MotionDetector([], "medium"), frames_with_square(480, 100)) > 0


def test_person_zone_hit_uses_polygon():
    assert zones_hit([ZONE], "person", 0.25, 0.9) == ["Porch"]
    assert zones_hit([ZONE], "person", 0.75, 0.9) == []
    assert zones_hit([ZONE], "motion", 0.25, 0.5) == ["Porch"]


def test_zone_mask_per_kind():
    only_person = [{**ZONE, "motion": False}]
    assert zone_mask(only_person, "motion", 10, 10).all()  # no motion zones -> everywhere
    assert zone_mask(only_person, "person", 10, 10)[:, 8].sum() == 0


@pytest.mark.parametrize("hhmm,expected", [("23:30", True), ("03:00", True), ("12:00", False)])
def test_schedule_wraps_midnight(hhmm, expected):
    h, m = map(int, hhmm.split(":"))
    now = datetime(2026, 9, 16, h, m)  # a Wednesday
    assert schedule_active({"mode": "window", "start": "22:00", "end": "07:00", "days": list(range(7))}, now) is expected


def test_schedule_days():
    now = datetime(2026, 9, 16, 23, 0)
    assert schedule_active({"mode": "window", "start": "22:00", "end": "07:00", "days": [0]}, now) is False
    assert schedule_active({"mode": "always"}, now) is True


def test_pick_segments(tmp_path):
    names = ["20260918-120000", "20260918-120002", "20260918-120004", "20260918-120006", "junk"]
    files = [tmp_path / f"{n}.ts" for n in names]
    start = datetime(2026, 9, 18, 12, 0, 3).timestamp()
    end = datetime(2026, 9, 18, 12, 0, 4).timestamp()
    picked = [p.stem for p in pick_segments(files, start, end, 2)]
    assert picked == ["20260918-120002", "20260918-120004"]


def test_ffmpeg_protocols_restricted(tmp_path):
    cmd = ffmpeg_segment_cmd("rtsp://127.0.0.1:8554/cam_1", tmp_path, 2)
    assert cmd[cmd.index("-protocol_whitelist") + 1] == "rtsp,rtp,udp,tcp"
    assert "-nostdin" in cmd


def test_ffmpeg_input_has_io_timeout(tmp_path):
    cmd = ffmpeg_segment_cmd("rtsp://127.0.0.1:8554/cam_1", tmp_path, 2)
    assert cmd.index("-timeout") < cmd.index("-i")
    assert int(cmd[cmd.index("-timeout") + 1]) > 0


def test_rtsp_url_ipv6_and_no_credentials():
    assert security.build_rtsp_url("fe80::1", 554, "", "", "/s") == "rtsp://[fe80::1]:554/s"
    assert security.build_rtsp_url("cam.lan", 8554, "u", "", "/s") == "rtsp://u@cam.lan:8554/s"


@pytest.mark.parametrize("host", ["", "-x", "a..b", "x" * 300, "a_b.lan", "evil.com#", "1.2.3.4:80"])
def test_bad_hosts(host):
    assert not security.valid_host(host)


def test_push_payload_roundtrip():
    key = os.urandom(32)
    key_b64 = base64.urlsafe_b64encode(key).decode().rstrip("=")
    assert security.valid_push_key(key_b64)
    blob = base64.b64decode(security.encrypt_push(key_b64, {"e": 7, "k": "person"}))
    plain = AESGCM(key).decrypt(blob[:12], blob[12:], None)
    assert json.loads(plain) == {"e": 7, "k": "person"}


def test_pairing_code_alphabet():
    code = security.new_pairing_code()
    assert len(code) == 10 and not set(code) & set("01OIL")
    assert security.normalize_code("abc-de fgh") == "ABCDEFGH"


def test_model_hash_pinned_in_dockerfile():
    dockerfile = (Path(__file__).parents[1] / "Dockerfile").read_text()
    assert "c789161ed43c8269fcd4e67c67eeeb4e80c622da2eb296a20bc6007bd18a0b7d" in dockerfile
