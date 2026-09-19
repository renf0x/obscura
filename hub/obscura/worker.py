"""Per-camera worker: reads the low-res substream, detects, and turns triggers into events."""

import json
import logging
import os
import threading
import time
from datetime import datetime
from pathlib import Path

import cv2

from .config import Settings
from .db import Database
from .detect import PERSON_SCORE, MotionDetector, PersonDetector, zones_hit
from .notify import Notifier
from .recorder import SegmentRecorder
from .storage import Storage

log = logging.getLogger(__name__)
os.environ.setdefault("OPENCV_FFMPEG_CAPTURE_OPTIONS", "rtsp_transport;tcp")

ANALYZE_FPS = 5
PERSON_INTERVAL = 1.0
TRACK_MAX = 3000  # motion/person marks kept per event (5 per second over the longest clip)
MANUAL_SECONDS = 30

DEFAULT_CONFIG = {
    "motion": True,
    "person": True,
    "sensitivity": "medium",
    "zones": [],
    "schedule": {"mode": "always", "start": "22:00", "end": "07:00", "days": [0, 1, 2, 3, 4, 5, 6]},
    "notify_motion": True,
    "notify_person": True,
    "siren_on_person": False,
    "siren_seconds": 30,
    "record_quality": "high",
}


def camera_config(raw: dict) -> dict:
    return {**DEFAULT_CONFIG, **raw}


def schedule_active(schedule: dict, now: datetime) -> bool:
    if schedule.get("mode") != "window":
        return True
    if now.weekday() not in schedule.get("days", range(7)):
        return False
    start, end = schedule.get("start", "00:00"), schedule.get("end", "23:59")
    cur = now.strftime("%H:%M")
    # A window like 22:00-07:00 wraps past midnight.
    return start <= cur < end if start <= end else (cur >= start or cur < end)


class CameraWorker:
    def __init__(self, cam: dict, settings: Settings, db: Database, notifier: Notifier,
                 storage: Storage, person: PersonDetector | None, sub_url: str, main_url: str,
                 on_person=None):
        self.cam_id, self.name = cam["id"], cam["name"]
        self.cfg = camera_config(cam["config"])
        self.s, self.db, self.notifier, self.storage, self.person = settings, db, notifier, storage, person
        self.sub_url = sub_url
        self.on_person = on_person
        self.recorder = SegmentRecorder(self.cam_id, main_url, settings.buffer_dir, settings.segment_seconds)
        self.last_frame = 0.0
        self.resolution: tuple[int, int] | None = None
        self._active: dict | None = None
        self._frame = None  # newest decoded frame, for thumbnails of manual recordings
        self._lock = threading.Lock()
        self._stop = threading.Event()
        self._reconfigured = threading.Event()
        self._thread = threading.Thread(target=self._run, name=f"cam-{self.cam_id}", daemon=True)

    @property
    def online(self) -> bool:
        return time.time() - self.last_frame < 15

    def start(self) -> None:
        self.recorder.start()
        self._thread.start()

    def reconfigure(self, cam: dict) -> None:
        """New zones/sensitivity/schedule take effect on the next frame, keeping the stream and the buffer."""
        self.name, self.cfg = cam["name"], camera_config(cam["config"])
        self._reconfigured.set()

    def stop(self) -> None:
        self._stop.set()
        self._thread.join(timeout=10)
        self._finish(force=True)
        self.recorder.stop()

    # --- main loop --------------------------------------------------------
    def _run(self) -> None:
        backoff = 2
        while not self._stop.is_set():
            cap = cv2.VideoCapture(self.sub_url, cv2.CAP_FFMPEG)
            if not cap.isOpened():
                self._stop.wait(backoff)
                backoff = min(backoff * 2, 60)
                continue
            backoff = 2
            try:
                self._loop(cap)
            except Exception:
                log.exception("camera %s worker crashed", self.cam_id)
            finally:
                cap.release()
            self._stop.wait(2)

    def _loop(self, cap: cv2.VideoCapture) -> None:
        self._reconfigured.set()
        next_analyze = next_person = 0.0
        while not self._stop.is_set():
            if self._reconfigured.is_set():
                self._reconfigured.clear()
                zones = self.cfg["zones"]
                motion = MotionDetector(zones, self.cfg["sensitivity"])
                anywhere = MotionDetector([], self.cfg["sensitivity"])  # gates the heavier person model
            ok, frame = cap.read()
            now = time.time()
            if not ok:
                return
            self.last_frame, self._frame = now, frame
            self.resolution = (frame.shape[1], frame.shape[0])
            self._finish()
            if now < next_analyze:
                continue
            next_analyze = now + 1 / ANALYZE_FPS
            if not schedule_active(self.cfg["schedule"], datetime.now()):
                continue

            fraction = motion.update(frame)
            moving = anywhere.update(frame) > 0
            if self.cfg["motion"] and fraction > 0:
                self.trigger("motion", fraction, [z.get("name", "zone") for z in zones if z.get("motion")], frame)
            self._mark(now, motion.spots, None)

            if self.cfg["person"] and self.person and moving and now >= next_person:
                next_person = now + PERSON_INTERVAL
                min_score = PERSON_SCORE.get(self.cfg["sensitivity"], 0.5)
                has_zones = any(z.get("person") for z in zones)
                people = self.person.detect(frame, min_score)
                for p in people:
                    # Feet position decides which zone a person stands in, like commercial NVRs.
                    fx, fy = (p.box[0] + p.box[2]) / 2, p.box[3]
                    hit = zones_hit(zones, "person", fx, fy)
                    if hit or not has_zones:
                        self.trigger("person", p.score, hit, frame, p.box)
                        break
                for p in people:
                    self._mark(now, [], [round(v, 3) for v in p.box])

    def _mark(self, now: float, spots: list, box: list | None) -> None:
        """Remember where things moved during an event, so the app can draw it over the clip."""
        ev = self._active
        if ev is not None and (spots or box) and len(ev["track"]) < TRACK_MAX:
            ev["track"].append([round(now, 2), spots, box])

    # --- events -----------------------------------------------------------
    def trigger(self, kind: str, score: float, zone_names: list[str], frame=None, box=None) -> None:
        now = time.time()
        with self._lock:
            ev = self._active
            if ev is None:
                ev_id = self.db.execute(
                    "INSERT INTO events(camera_id, kind, started_at, score, zones) VALUES(?, ?, ?, ?, ?)",
                    (self.cam_id, kind, now, score, json.dumps(sorted(set(zone_names)))),
                )
                ev = self._active = {"id": ev_id, "kind": kind, "start": now, "last": now, "zones": set(zone_names),
                                     "until": now + MANUAL_SECONDS if kind == "manual" else None,
                                     "track": [], "zone_shapes": self.cfg["zones"]}
                self._thumb(ev, frame if frame is not None else self._frame, box)
                self._announce(ev, "start")
                if kind == "person":
                    self._person_alert()
                return
            ev["last"] = now
            ev["zones"].update(zone_names)
            if kind == "manual":
                ev["until"] = now + MANUAL_SECONDS
            if kind == "person" and ev["kind"] == "motion":
                # Upgrade: a person is more important than the motion that preceded it.
                ev["kind"] = "person"
                self.db.execute("UPDATE events SET kind = 'person', score = ? WHERE id = ?", (score, ev["id"]))
                self._thumb(ev, frame, box)
                self._announce(ev, "start")
                self._person_alert()

    def stop_manual(self) -> None:
        """End a manual recording now; the clip is cut on the next frame."""
        with self._lock:
            ev = self._active
            if ev is not None and ev["until"]:
                ev["until"] = time.time()

    def _person_alert(self) -> None:
        if self.on_person:
            try:
                self.on_person(self.cam_id)
            except Exception:
                log.exception("person alert hook failed")

    def _announce(self, ev: dict, phase: str) -> None:
        row = self.db.one("SELECT * FROM events WHERE id = ?", (ev["id"],))
        if not row:
            return
        want = {"motion": self.cfg["notify_motion"], "person": self.cfg["notify_person"]}.get(ev["kind"], False)
        self.notifier.event(row, self.name, phase if (want or phase != "start") else "silent")

    def _thumb(self, ev: dict, frame, box) -> None:
        if frame is None:
            return
        img = frame.copy()
        if box:
            h, w = img.shape[:2]
            cv2.rectangle(img, (int(box[0] * w), int(box[1] * h)), (int(box[2] * w), int(box[3] * h)), (120, 220, 60), 2)
        rel = self._rel_path(ev, ".jpg")
        path = self.s.clips_dir / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        cv2.imwrite(str(path), img, [cv2.IMWRITE_JPEG_QUALITY, 80])
        self.db.execute("UPDATE events SET thumb = ? WHERE id = ?", (rel, ev["id"]))

    def _rel_path(self, ev: dict, suffix: str) -> str:
        day = datetime.fromtimestamp(ev["start"]).strftime("%Y%m%d")
        return f"{self.cam_id}/{day}/{ev['id']}{suffix}"

    def _finish(self, force: bool = False) -> None:
        now = time.time()
        with self._lock:
            ev = self._active
            if ev is None:
                return
            if ev["until"]:
                done = now >= ev["until"]
            else:
                done = now - ev["last"] > self.s.post_seconds or now - ev["start"] > self.s.max_clip_seconds
            if not (done or force):
                return
            self._active = None
        end = min(now, ev["until"] or now)
        self.db.execute("UPDATE events SET ended_at = ?, zones = ? WHERE id = ?",
                        (end, json.dumps(sorted(ev["zones"])), ev["id"]))
        threading.Thread(target=self._build_clip, args=(ev, end), daemon=True).start()

    def _build_clip(self, ev: dict, end: float) -> None:
        rel = self._rel_path(ev, ".mp4")
        out = self.s.clips_dir / rel
        clip_start = self.recorder.build_clip(ev["start"] - self.s.pre_seconds, end, out)
        if clip_start is None:
            return
        thumb = self.s.clips_dir / self._rel_path(ev, ".jpg")
        size = out.stat().st_size + (thumb.stat().st_size if thumb.exists() else 0)
        # Times relative to the clip's first frame, zones as they were when the event fired.
        track = {"zones": ev["zone_shapes"],
                 "marks": [[round(t - clip_start, 2), spots, box] for t, spots, box in ev["track"]]}
        self.db.execute("UPDATE events SET clip = ?, size = ?, track = ? WHERE id = ?",
                        (rel, size, json.dumps(track, separators=(",", ":")), ev["id"]))
        self._announce(ev, "update")
        self.storage.enqueue(ev["id"])


def clip_path(clips_dir: Path, rel: str | None) -> Path | None:
    """Resolve a DB-stored relative path, refusing anything outside the clips directory."""
    if not rel:
        return None
    path = (clips_dir / rel).resolve()
    return path if path.is_relative_to(clips_dir.resolve()) and path.is_file() else None
