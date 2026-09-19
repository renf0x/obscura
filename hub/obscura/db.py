"""SQLite persistence. One connection guarded by a lock; the hub is low-traffic."""

import json
import sqlite3
import threading
import time
from pathlib import Path
from typing import Any

SCHEMA = """
CREATE TABLE IF NOT EXISTS cameras (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    vendor TEXT NOT NULL,
    host TEXT NOT NULL,
    port INTEGER NOT NULL,
    username TEXT NOT NULL DEFAULT '',
    password TEXT NOT NULL DEFAULT '',
    main_path TEXT NOT NULL,
    sub_path TEXT NOT NULL DEFAULT '',
    enabled INTEGER NOT NULL DEFAULT 1,
    config TEXT NOT NULL DEFAULT '{}',
    cloud_md5 TEXT NOT NULL DEFAULT '',
    cloud_sha256 TEXT NOT NULL DEFAULT '',
    cloud_algo TEXT NOT NULL DEFAULT '',
    two_way INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY,
    camera_id INTEGER NOT NULL,
    kind TEXT NOT NULL,
    started_at REAL NOT NULL,
    ended_at REAL,
    score REAL NOT NULL DEFAULT 0,
    zones TEXT NOT NULL DEFAULT '[]',
    clip TEXT,
    thumb TEXT,
    size INTEGER NOT NULL DEFAULT 0,
    uploaded INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS events_started ON events(started_at DESC);
CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    created_at REAL NOT NULL,
    last_seen REAL NOT NULL,
    push_endpoint TEXT,
    push_key TEXT
);
CREATE TABLE IF NOT EXISTS pairing (
    code_hash TEXT PRIMARY KEY,
    expires_at REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS kv (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
"""

# Columns added after the first release: (table, column, definition).
MIGRATIONS = [
    ("cameras", "cloud_md5", "TEXT NOT NULL DEFAULT ''"),
    ("cameras", "cloud_sha256", "TEXT NOT NULL DEFAULT ''"),
    ("cameras", "cloud_algo", "TEXT NOT NULL DEFAULT ''"),
    ("cameras", "two_way", "INTEGER NOT NULL DEFAULT 0"),
    ("events", "track", "TEXT"),
]


class Database:
    def __init__(self, path: Path):
        path.parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
        self._conn.row_factory = sqlite3.Row
        self._lock = threading.Lock()
        with self._lock:
            self._conn.execute("PRAGMA journal_mode=WAL")
            self._conn.executescript(SCHEMA)
            for table, column, definition in MIGRATIONS:
                have = {r["name"] for r in self._conn.execute(f"PRAGMA table_info({table})")}
                if column not in have:
                    self._conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")

    def query(self, sql: str, args: tuple = ()) -> list[dict]:
        with self._lock:
            return [dict(r) for r in self._conn.execute(sql, args).fetchall()]

    def one(self, sql: str, args: tuple = ()) -> dict | None:
        rows = self.query(sql, args)
        return rows[0] if rows else None

    def execute(self, sql: str, args: tuple = ()) -> int:
        """Run a write; returns lastrowid (inserts) or rowcount (updates/deletes)."""
        with self._lock:
            cur = self._conn.execute(sql, args)
            return cur.lastrowid if sql.lstrip().upper().startswith("INSERT") else cur.rowcount

    # --- key/value settings -------------------------------------------------
    def get_kv(self, key: str, default: Any = None) -> Any:
        row = self.one("SELECT value FROM kv WHERE key = ?", (key,))
        return json.loads(row["value"]) if row else default

    def set_kv(self, key: str, value: Any) -> None:
        self.execute(
            "INSERT INTO kv(key, value) VALUES(?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            (key, json.dumps(value)),
        )

    # --- cameras ------------------------------------------------------------
    def camera(self, cam_id: int) -> dict | None:
        row = self.one("SELECT * FROM cameras WHERE id = ?", (cam_id,))
        if row:
            row["config"] = json.loads(row["config"])
        return row

    def cameras(self) -> list[dict]:
        rows = self.query("SELECT * FROM cameras ORDER BY id")
        for row in rows:
            row["config"] = json.loads(row["config"])
        return rows

    def purge_expired_pairing(self) -> None:
        self.execute("DELETE FROM pairing WHERE expires_at < ?", (time.time(),))
