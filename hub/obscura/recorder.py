"""Continuous short-segment ring buffer per camera, cut into clips on events.

ffmpeg copies the camera's H.264/H.265 without re-encoding (cheap on a Raspberry Pi);
only audio is converted to AAC because MP4 cannot hold the G.711 audio most cameras send.
"""

import logging
import shutil
import subprocess
import threading
import time
from datetime import datetime
from pathlib import Path

log = logging.getLogger(__name__)

BUFFER_KEEP_SECONDS = 90
_STAMP = "%Y%m%d-%H%M%S"


def ffmpeg_segment_cmd(source: str, out_dir: Path, seconds: int) -> list[str]:
    return [
        "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error",
        # Only network protocols; blocks file:, concat: and friends even if a URL were crafted.
        "-protocol_whitelist", "rtsp,rtp,udp,tcp",
        # A stalled source (e.g. go2rtc restarted and the stream isn't re-registered yet) must make
        # ffmpeg exit so the restart loop takes over; without it ffmpeg waits forever.
        "-rtsp_transport", "tcp", "-timeout", "10000000", "-i", source,
        "-map", "0:v:0", "-map", "0:a:0?",
        "-c:v", "copy", "-c:a", "aac", "-b:a", "64k",
        "-f", "segment", "-segment_time", str(seconds), "-segment_format", "mpegts",
        "-reset_timestamps", "1", "-strftime", "1",
        str(out_dir / f"{_STAMP}.ts"),
    ]


def segment_time(path: Path) -> float:
    return datetime.strptime(path.stem, _STAMP).timestamp()


def pick_segments(files: list[Path], start: float, end: float, seg_len: float) -> list[Path]:
    """Segments overlapping [start, end]; a segment named T covers roughly [T, T + seg_len]."""
    picked = []
    for f in sorted(files):
        try:
            t = segment_time(f)
        except ValueError:
            continue
        if t + seg_len >= start and t <= end:
            picked.append(f)
    return picked


class SegmentRecorder:
    def __init__(self, cam_id: int, source: str, buffer_dir: Path, seconds: int):
        self.cam_id, self.source, self.seconds = cam_id, source, seconds
        self.dir = buffer_dir / str(cam_id)
        self._proc: subprocess.Popen | None = None
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, name=f"rec-{cam_id}", daemon=True)

    def start(self) -> None:
        shutil.rmtree(self.dir, ignore_errors=True)
        self.dir.mkdir(parents=True, exist_ok=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._proc and self._proc.poll() is None:
            self._proc.terminate()
        self._thread.join(timeout=5)
        shutil.rmtree(self.dir, ignore_errors=True)

    def _run(self) -> None:
        backoff = 2
        while not self._stop.is_set():
            self._proc = subprocess.Popen(
                ffmpeg_segment_cmd(self.source, self.dir, self.seconds),
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
            )
            while self._proc.poll() is None and not self._stop.is_set():
                self._cleanup()
                self._stop.wait(5)
            if self._stop.is_set():
                break
            err = (self._proc.stderr.read() or b"")[-300:].decode(errors="replace") if self._proc.stderr else ""
            log.warning("camera %s recorder exited: %s", self.cam_id, err.strip())
            self._stop.wait(backoff)
            backoff = min(backoff * 2, 60)

    def _cleanup(self) -> None:
        cutoff = time.time() - BUFFER_KEEP_SECONDS
        for f in self.dir.glob("*.ts"):
            try:
                if segment_time(f) < cutoff:
                    f.unlink(missing_ok=True)
            except ValueError:
                f.unlink(missing_ok=True)

    def build_clip(self, start: float, end: float, out: Path) -> float | None:
        """Concatenate buffered segments covering [start, end] into an MP4. Call after `end` has passed.
        Returns the wall-clock time the clip starts at, or None."""
        # The segment containing `end` is only closed after it finishes.
        deadline = time.time() + self.seconds * 3
        while time.time() < deadline:
            newest = max((segment_time(f) for f in self.dir.glob("*.ts")), default=0)
            if newest >= end:
                break
            time.sleep(0.5)
        segments = pick_segments(list(self.dir.glob("*.ts")), start, end, self.seconds)
        # The last file is still being written by ffmpeg; leave it out unless it's all we have.
        done = [s for s in segments if segment_time(s) + self.seconds <= time.time()] or segments
        if not done:
            return None
        out.parent.mkdir(parents=True, exist_ok=True)
        listing = out.with_suffix(".txt")
        listing.write_text("".join(f"file '{s.as_posix()}'\n" for s in done))
        cmd = [
            "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
            "-f", "concat", "-safe", "0", "-i", str(listing),
            "-c", "copy", "-bsf:a", "aac_adtstoasc", "-movflags", "+faststart", str(out),
        ]
        try:
            res = subprocess.run(cmd, capture_output=True, timeout=60)
        finally:
            listing.unlink(missing_ok=True)
        if res.returncode != 0:
            log.warning("clip build failed: %s", res.stderr[-300:].decode(errors="replace"))
            return None
        return segment_time(done[0])
