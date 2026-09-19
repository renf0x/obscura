"""Local clip retention and optional off-site copy through rclone.

rclone covers S3-compatible storage (AWS, Backblaze B2, MinIO, Yandex Object Storage...),
WebDAV (Nextcloud, Yandex Disk, ownCloud...) and 40+ other backends with one code path.
"""

import logging
import queue
import re
import shutil
import subprocess
import threading
import time
from datetime import datetime
from pathlib import Path

from .config import Settings
from .db import Database

log = logging.getLogger(__name__)

REMOTE = "obscura"
DEFAULTS = {"retention_days": 14, "max_gb": 20.0, "cloud": {"enabled": False, "type": "none", "path": "obscura"}}
_REMOTE_PATH_RE = re.compile(r"^[A-Za-z0-9._][A-Za-z0-9._/-]{0,199}$")
_REMOTE_NAME_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_-]{0,63}$")
# rclone option values we accept from the app, per backend. Anything else is rejected.
BACKEND_FIELDS = {
    "s3": {"provider", "endpoint", "region", "access_key_id", "secret_access_key"},
    "webdav": {"url", "vendor", "user", "pass"},
}
SECRET_FIELDS = {"secret_access_key", "pass"}


def valid_remote_path(path: str) -> bool:
    return bool(_REMOTE_PATH_RE.match(path)) and ".." not in path.split("/")


def valid_remote_name(name: str) -> bool:
    return bool(_REMOTE_NAME_RE.match(name))


def safe_value(value: str) -> bool:
    return len(value) <= 500 and not any(c in value for c in "\r\n\x00")


class Storage:
    def __init__(self, settings: Settings, db: Database):
        self.s, self.db = settings, db
        self._queue: queue.Queue[int] = queue.Queue()
        self._stop = threading.Event()

    def config(self) -> dict:
        cfg = {**DEFAULTS, **(self.db.get_kv("storage") or {})}
        cfg["cloud"] = {**DEFAULTS["cloud"], **cfg.get("cloud", {})}
        return cfg

    def start(self) -> None:
        threading.Thread(target=self._upload_loop, name="upload", daemon=True).start()
        threading.Thread(target=self._retention_loop, name="retention", daemon=True).start()

    def stop(self) -> None:
        self._stop.set()

    # --- rclone -----------------------------------------------------------
    def _rclone(self, *args: str, timeout: int = 120) -> subprocess.CompletedProcess:
        cmd = ["rclone", "--config", str(self.s.rclone_conf), *args]
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, stdin=subprocess.DEVNULL)

    def configure_backend(self, backend: str, options: dict[str, str]) -> None:
        """Create/replace the 'obscura' rclone remote. Values arrive as separate argv items, never via a shell."""
        allowed = BACKEND_FIELDS[backend]
        args = []
        for key, value in options.items():
            if key not in allowed or not safe_value(value):
                raise ValueError(f"invalid option {key}")
            args.append(f"{key}={value}")
        self._rclone("config", "delete", REMOTE, timeout=30)
        res = self._rclone("config", "create", REMOTE, backend, *args, "--obscure", "--non-interactive", timeout=30)
        if res.returncode != 0:
            raise ValueError(res.stderr.strip()[-300:] or "rclone config failed")
        self.s.rclone_conf.chmod(0o600)

    def remote_root(self) -> str | None:
        cloud = self.config()["cloud"]
        if not cloud.get("enabled") or cloud.get("type") == "none":
            return None
        remote = cloud.get("remote") if cloud.get("type") == "custom" else REMOTE
        return f"{remote}:{cloud.get('path', 'obscura')}"

    def test(self) -> tuple[bool, str]:
        root = self.remote_root()
        if not root:
            return False, "cloud storage is disabled"
        try:
            res = self._rclone("mkdir", root, timeout=45)
            if res.returncode == 0:
                res = self._rclone("lsf", "--max-depth", "1", root, timeout=45)
        except subprocess.TimeoutExpired:
            return False, "timeout"
        return res.returncode == 0, (res.stderr.strip()[-300:] if res.returncode else "ok")

    def enqueue(self, event_id: int) -> None:
        self._queue.put(event_id)

    def _upload_loop(self) -> None:
        # Retry anything left from earlier runs or failed uploads.
        for row in self.db.query("SELECT id FROM events WHERE uploaded = 0 AND clip IS NOT NULL"):
            self._queue.put(row["id"])
        while not self._stop.is_set():
            try:
                event_id = self._queue.get(timeout=5)
            except queue.Empty:
                continue
            root = self.remote_root()
            if not root:
                continue
            ev = self.db.one(
                "SELECT e.*, c.id AS cam FROM events e JOIN cameras c ON c.id = e.camera_id WHERE e.id = ?",
                (event_id,),
            )
            if not ev or not ev["clip"] or ev["uploaded"]:
                continue
            day = datetime.fromtimestamp(ev["started_at"]).strftime("%Y-%m-%d")
            ok = True
            for name in (ev["clip"], ev["thumb"]):
                if not name:
                    continue
                local = self.s.clips_dir / name
                if local.exists():
                    res = self._rclone("copyto", str(local), f"{root}/camera-{ev['cam']}/{day}/{local.name}", timeout=600)
                    ok = ok and res.returncode == 0
                    if res.returncode:
                        log.warning("upload failed for event %s: %s", event_id, res.stderr.strip()[-300:])
            if ok:
                self.db.execute("UPDATE events SET uploaded = 1 WHERE id = ?", (event_id,))
            else:
                threading.Timer(300, self._queue.put, args=(event_id,)).start()

    # --- retention --------------------------------------------------------
    def _retention_loop(self) -> None:
        while True:
            try:
                self.apply_retention()
            except Exception:
                log.exception("retention failed")
            if self._stop.wait(3600):
                break

    def apply_retention(self) -> int:
        cfg = self.config()
        removed = 0
        cutoff = time.time() - float(cfg["retention_days"]) * 86400
        for ev in self.db.query("SELECT * FROM events WHERE started_at < ?", (cutoff,)):
            self.delete_event(ev)
            removed += 1
        limit = float(cfg["max_gb"]) * 1024**3
        total = self.db.one("SELECT COALESCE(SUM(size), 0) AS s FROM events")["s"]
        if total > limit:
            for ev in self.db.query("SELECT * FROM events ORDER BY started_at ASC"):
                if total <= limit:
                    break
                total -= ev["size"]
                self.delete_event(ev)
                removed += 1
        return removed

    def delete_event(self, ev: dict) -> None:
        for name in (ev.get("clip"), ev.get("thumb")):
            if name:
                path = (self.s.clips_dir / name).resolve()
                if path.is_relative_to(self.s.clips_dir.resolve()):
                    path.unlink(missing_ok=True)
        self.db.execute("DELETE FROM events WHERE id = ?", (ev["id"],))

    def usage(self) -> dict:
        row = self.db.one("SELECT COUNT(*) AS n, COALESCE(SUM(size), 0) AS s FROM events")
        disk = None
        try:
            du = shutil.disk_usage(self.s.data_dir)
            disk = {"total": du.total, "free": du.free}
        except OSError:
            pass
        return {"events": row["n"], "bytes": row["s"], "disk": disk}
