"""Event fan-out: in-app live stream (SSE), UnifiedPush to phones, optional ntfy topic."""

import asyncio
import logging
import threading
import time

import httpx

from . import security
from .db import Database

log = logging.getLogger(__name__)

TITLES = {
    "person": "Person detected",
    "motion": "Motion detected",
    "manual": "Manual recording",
}


class EventBus:
    """Thread-safe publish from camera workers to asyncio subscribers (SSE clients)."""

    def __init__(self) -> None:
        self._subs: set[asyncio.Queue] = set()
        self._loop: asyncio.AbstractEventLoop | None = None
        self._lock = threading.Lock()

    def bind(self, loop: asyncio.AbstractEventLoop) -> None:
        self._loop = loop

    def subscribe(self) -> asyncio.Queue:
        q: asyncio.Queue = asyncio.Queue(maxsize=100)
        with self._lock:
            self._subs.add(q)
        return q

    def unsubscribe(self, q: asyncio.Queue) -> None:
        with self._lock:
            self._subs.discard(q)

    def publish(self, message: dict) -> None:
        if not self._loop:
            return
        with self._lock:
            subs = list(self._subs)
        for q in subs:
            self._loop.call_soon_threadsafe(_put_nowait, q, message)


def _put_nowait(q: asyncio.Queue, message: dict) -> None:
    if not q.full():
        q.put_nowait(message)


class Notifier:
    def __init__(self, db: Database, bus: EventBus):
        self.db, self.bus = db, bus
        self._client = httpx.Client(timeout=10, follow_redirects=False)

    def event(self, event: dict, camera_name: str, phase: str) -> None:
        """phase: 'start' (also pushed to phones), 'silent' (start, notifications off) or 'update' (clip ready)."""
        msg = {"type": "event", "phase": phase, "event": event}
        self.bus.publish(msg)
        if phase == "start":
            threading.Thread(target=self._push, args=(event, camera_name), daemon=True).start()

    def _push(self, event: dict, camera_name: str) -> None:
        payload = {"e": event["id"], "k": event["kind"], "c": camera_name, "t": int(event["started_at"])}
        for dev in self.db.query("SELECT id, push_endpoint, push_key FROM devices WHERE push_endpoint IS NOT NULL"):
            try:
                # Re-check at send time: DNS may have changed since the endpoint was registered.
                sent = time.time()
                if not security.valid_push_endpoint(dev["push_endpoint"]):
                    log.warning("push to device %s skipped: endpoint no longer valid", dev["id"])
                    continue
                body = security.encrypt_push(dev["push_key"], payload)
                r = self._client.post(dev["push_endpoint"], content=body.encode(),
                                      headers={"Content-Type": "text/plain", "Priority": "high"})
                # Timing only, never the endpoint URL: it is the device's push capability.
                log.info("push event %s (%s) to device %s: HTTP %s, %.1fs after event start, took %.2fs",
                         event["id"], event["kind"], dev["id"], r.status_code,
                         sent - event["started_at"], time.time() - sent)
                if r.status_code in (404, 410):  # distributor unregistered the app
                    self.db.execute("UPDATE devices SET push_endpoint = NULL WHERE id = ?", (dev["id"],))
            except Exception as exc:
                log.warning("push to device %s failed: %s", dev["id"], exc)
        self._ntfy(event, camera_name)

    def _ntfy(self, event: dict, camera_name: str) -> None:
        cfg = self.db.get_kv("ntfy") or {}
        if not cfg.get("enabled") or not cfg.get("server") or not cfg.get("topic"):
            return
        person = event["kind"] == "person"
        # JSON publishing keeps non-ASCII camera names intact (headers are latin-1 only).
        body = {
            "topic": cfg["topic"],
            "title": TITLES.get(event["kind"], "Event"),
            "message": camera_name,
            "priority": 5 if person else 3,
            "tags": ["rotating_light"] if person else ["eyes"],
            "click": f"obscura://event/{event['id']}",
        }
        if not security.valid_push_endpoint(cfg["server"]):
            return
        headers = {"Authorization": f"Bearer {cfg['token']}"} if cfg.get("token") else {}
        try:
            sent = time.time()
            r = self._client.post(cfg["server"].rstrip("/"), json=body, headers=headers)
            log.info("ntfy event %s: HTTP %s, took %.2fs", event["id"], r.status_code, time.time() - sent)
        except Exception as exc:
            log.warning("ntfy publish failed: %s", exc)
