"""Tokens, pairing codes, rate limiting and input validation helpers."""

import base64
import hashlib
import ipaddress
import json
import os
import re
import secrets
import socket
import threading
import time
from collections import deque
from urllib.parse import quote, urlsplit

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

PAIRING_TTL = 600
# No 0/O/1/I/L to keep codes easy to type from a screen.
_CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"


def new_token() -> str:
    return secrets.token_urlsafe(32)


def hash_secret(value: str) -> str:
    # Tokens and codes are high-entropy random values, so a fast hash is enough;
    # the point is that a leaked database does not leak usable credentials.
    return hashlib.sha256(value.encode()).hexdigest()


def new_pairing_code() -> str:
    return "".join(secrets.choice(_CODE_ALPHABET) for _ in range(10))


def normalize_code(code: str) -> str:
    return re.sub(r"[\s-]", "", code).upper()


class RateLimiter:
    """Sliding-window limiter keyed by client address, plus a global cap."""

    def __init__(self, per_key: int, global_limit: int, window: float):
        self.per_key, self.global_limit, self.window = per_key, global_limit, window
        self._hits: dict[str, deque] = {}
        self._all: deque = deque()
        self._lock = threading.Lock()

    def _trim(self, q: deque, now: float) -> None:
        while q and q[0] < now - self.window:
            q.popleft()

    def allow(self, key: str) -> bool:
        now = time.monotonic()
        with self._lock:
            q = self._hits.setdefault(key, deque())
            self._trim(q, now)
            self._trim(self._all, now)
            if len(q) >= self.per_key or len(self._all) >= self.global_limit:
                return False
            q.append(now)
            self._all.append(now)
            return True


# --- camera addresses ---------------------------------------------------------

_HOST_RE = re.compile(r"^(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)*[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$")
# Path + query as used by camera vendors; no spaces, '#', '@' or control characters.
_PATH_RE = re.compile(r"^/[A-Za-z0-9._~/?=&%+:,;-]{0,200}$")


def valid_host(host: str) -> bool:
    try:
        ipaddress.ip_address(host)
        return True
    except ValueError:
        return len(host) <= 253 and bool(_HOST_RE.match(host))


def valid_path(path: str) -> bool:
    return bool(_PATH_RE.match(path))


def build_rtsp_url(host: str, port: int, username: str, password: str, path: str) -> str:
    """Build an rtsp:// URL. Inputs must already be validated; credentials are percent-encoded."""
    if not valid_host(host) or not valid_path(path) or not 0 < port < 65536:
        raise ValueError("invalid camera address")
    netloc = f"[{host}]" if ":" in host else host
    auth = ""
    if username:
        auth = quote(username, safe="") + (":" + quote(password, safe="") if password else "") + "@"
    url = f"rtsp://{auth}{netloc}:{port}{path}"
    # Final guard: whatever reaches go2rtc/ffmpeg must be a plain rtsp URL.
    parts = urlsplit(url)
    if parts.scheme != "rtsp" or parts.fragment or any(c in url for c in " \t\r\n#"):
        raise ValueError("invalid camera address")
    return url


def is_private_host(host: str) -> bool:
    try:
        ip = ipaddress.ip_address(host)
    except ValueError:
        return False
    return ip.is_private or ip.is_loopback or ip.is_link_local


def _blocked_ip(ip: ipaddress._BaseAddress) -> bool:
    return ip.is_loopback or ip.is_link_local or ip.is_multicast or ip.is_unspecified or ip.is_reserved


def resolves_safely(host: str) -> bool:
    """True if every address the host resolves to is allowed. Catches 127.1, 0x7f000001 and DNS names
    pointing at loopback, which a literal-IP check would miss."""
    try:
        infos = socket.getaddrinfo(host, None)
    except (OSError, UnicodeError):
        return False
    return bool(infos) and not any(_blocked_ip(ipaddress.ip_address(i[4][0].split("%")[0])) for i in infos)


def valid_push_endpoint(url: str, resolve: bool = True) -> bool:
    """UnifiedPush endpoints / ntfy servers: plain http(s) URLs that must not reach hub-local services
    (go2rtc on 127.0.0.1) or cloud metadata addresses."""
    if len(url) > 1000 or any(c in url for c in " \t\r\n"):
        return False
    parts = urlsplit(url)
    if parts.scheme not in ("https", "http") or not parts.hostname or parts.username or parts.password:
        return False
    host = parts.hostname
    if host == "localhost" or host.endswith(".localhost"):
        return False
    try:
        if _blocked_ip(ipaddress.ip_address(host)):
            return False
    except ValueError:
        pass
    return resolves_safely(host) if resolve else True


def encrypt_push(key_b64: str, payload: dict) -> str:
    """AES-256-GCM with the device's own key, so the push relay only sees ciphertext."""
    key = base64.urlsafe_b64decode(key_b64 + "=" * (-len(key_b64) % 4))
    nonce = os.urandom(12)
    ct = AESGCM(key).encrypt(nonce, json.dumps(payload, separators=(",", ":")).encode(), None)
    return base64.b64encode(nonce + ct).decode()


def valid_push_key(key_b64: str) -> bool:
    try:
        return len(base64.urlsafe_b64decode(key_b64 + "=" * (-len(key_b64) % 4))) == 32
    except (ValueError, TypeError):
        return False
