"""Sound to the camera's speaker: push-to-talk messages and the speaker siren.

go2rtc plays audio into a camera ("two-way audio" / RTSP backchannel / Tapo) from a source URL.
It fetches that URL itself, so the hub hands out short-lived one-off links on localhost.
"""

import secrets
import subprocess
import threading
import time
import wave
from pathlib import Path

import numpy as np

FFMPEG = "ffmpeg"
RATE = 8000  # G.711, the codec cameras accept on the backchannel
MAX_TALK_SECONDS = 30
SIREN_SECONDS = 60
SHARE_TTL = 120


def transcode_talk(src: Path, dst: Path) -> None:
    """Phone recording (AAC in MP4/M4A) -> mono 8 kHz WAV.

    The input comes from a paired phone, but is still treated as untrusted: the container is
    forced to MP4 (no playlist/concat demuxers) and only local file access is allowed.
    """
    cmd = [
        FFMPEG, "-nostdin", "-hide_banner", "-loglevel", "error",
        "-protocol_whitelist", "file", "-f", "mov", "-i", str(src),
        "-vn", "-t", str(MAX_TALK_SECONDS), "-ac", "1", "-ar", str(RATE),
        # Phones record quietly and cameras have tiny speakers: even out and lift the level.
        "-af", "highpass=f=200,dynaudnorm", "-c:a", "pcm_s16le", "-y", str(dst),
    ]
    try:
        r = subprocess.run(cmd, capture_output=True, timeout=30)
    except subprocess.TimeoutExpired:
        raise ValueError("audio conversion timed out")
    except OSError:
        raise RuntimeError("ffmpeg is not installed on the hub")
    if r.returncode != 0 or not dst.exists() or dst.stat().st_size < 1000:
        raise ValueError("unsupported or empty recording")


def write_siren(path: Path, seconds: int = SIREN_SECONDS) -> None:
    """Police-style wail: 700-1600 Hz sweep, clipped a little so it sounds harsh on small speakers."""
    t = np.arange(int(RATE * seconds)) / RATE
    freq = 1150 + 450 * np.sin(2 * np.pi * t / 1.6)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    wave_ = np.clip(1.6 * np.sin(phase), -1, 1) * 0.95
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((wave_ * 32767).astype("<i2").tobytes())


class Shares:
    """One-off download links for go2rtc: random 256-bit names that expire after two minutes."""

    def __init__(self) -> None:
        self._items: dict[str, tuple[Path, float, bool]] = {}
        self._lock = threading.Lock()

    def add(self, path: Path, delete_after: bool = True) -> str:
        token = secrets.token_urlsafe(32)
        with self._lock:
            self._purge()
            self._items[token] = (path, time.monotonic() + SHARE_TTL, delete_after)
        return token

    def get(self, token: str) -> Path | None:
        with self._lock:
            self._purge()
            item = self._items.get(token)
        return item[0] if item and item[0].exists() else None

    def _purge(self) -> None:
        now = time.monotonic()
        for token, (path, expires, delete_after) in list(self._items.items()):
            if expires < now:
                del self._items[token]
                if delete_after:
                    path.unlink(missing_ok=True)
