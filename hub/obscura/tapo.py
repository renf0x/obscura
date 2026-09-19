"""Minimal client for the Tapo camera's local control API (HTTPS, port 443).

Only what Obscura needs: log in and switch the camera's own alarm (siren + light) on and off.
Protocol as implemented by pytapo (MIT, https://github.com/JurajNyiri/pytapo), rewritten against
`cryptography` + `httpx` so the hub does not pull in pytapo's dependency tree.

The camera authenticates the owner's TP-Link *cloud* password, but only ever by its hash
(uppercase MD5 on older firmware, uppercase SHA-256 on newer). The hub therefore stores just
those two hashes, never the password itself.
"""

import base64
import hashlib
import json
import logging
import os
import threading

import httpx
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

log = logging.getLogger(__name__)

USER = "admin"  # the local API account is always "admin" + the cloud password
_HEADERS = {
    "Accept": "application/json",
    "User-Agent": "Tapo CameraClient Android",
    "requestByApp": "true",
    "Content-Type": "application/json; charset=UTF-8",
}
_SESSION_ERRORS = {-40401, -40413, -1, 9999}


class TapoError(Exception):
    pass


def password_hashes(password: str) -> tuple[str, str]:
    """(md5, sha256) of the cloud password, uppercase hex, as the camera expects them."""
    raw = password.encode()
    return hashlib.md5(raw).hexdigest().upper(), hashlib.sha256(raw).hexdigest().upper()


def _sha256_upper(*parts: str) -> str:
    return hashlib.sha256("".join(parts).encode()).hexdigest().upper()


def _token(kind: str, cnonce: str, nonce: str, hashed: str) -> bytes:
    key = _sha256_upper(cnonce, hashed, nonce)
    return hashlib.sha256((kind + cnonce + nonce + key).encode()).digest()[:16]


class TapoClient:
    def __init__(self, host: str, md5: str, sha256: str, port: int = 443,
                 transport: httpx.BaseTransport | None = None):
        self.base = f"https://{host}:{port}" if ":" not in host else f"https://[{host}]:{port}"
        self.md5, self.sha256 = md5, sha256
        # The camera only has a self-signed certificate. The login is a challenge-response, so the
        # password hash itself never crosses the wire.
        self.http = httpx.Client(verify=False, timeout=8, transport=transport, headers=_HEADERS)
        self.algo: str | None = None  # "md5" or "sha256", learned from the camera's confirmation
        self._stok: str | None = None
        self._secure = False
        self._cnonce = ""
        self._lsk = self._ivb = b""
        self._seq = 0
        self._lock = threading.Lock()

    # --- login ------------------------------------------------------------
    def _hashed(self) -> str:
        return self.sha256 if self.algo == "sha256" else self.md5

    def _post(self, url: str, body: dict, headers: dict | None = None) -> dict:
        r = self.http.post(url, content=json.dumps(body), headers=headers)
        try:
            return r.json()
        except ValueError:
            raise TapoError(f"unexpected answer from camera (HTTP {r.status_code})")

    def _login(self) -> None:
        self._cnonce = os.urandom(8).hex().upper()
        first = self._post(self.base, {"method": "login", "params": {
            "cnonce": self._cnonce, "encrypt_type": "3", "username": USER}})
        data = (first.get("result") or {}).get("data") or {}
        if "nonce" in data and "device_confirm" in data:
            self._secure = True
            nonce = data["nonce"]
            for algo, hashed in (("sha256", self.sha256), ("md5", self.md5)):
                if data["device_confirm"] == _sha256_upper(self._cnonce, hashed, nonce) + nonce + self._cnonce:
                    self.algo = algo
                    break
            else:
                raise TapoError("wrong TP-Link account password")
            digest = _sha256_upper(self._hashed(), self._cnonce, nonce)
            res = self._post(self.base, {"method": "login", "params": {
                "cnonce": self._cnonce, "encrypt_type": "3", "username": USER,
                "digest_passwd": digest + self._cnonce + nonce}})
            result = res.get("result") or {}
            if "start_seq" not in result or "stok" not in result:
                raise TapoError(_login_error(res))
            if result.get("user_group", "root") != "root":
                raise TapoError("the camera only accepts the owner's TP-Link account")
            self._lsk = _token("lsk", self._cnonce, nonce, self._hashed())
            self._ivb = _token("ivb", self._cnonce, nonce, self._hashed())
            self._seq = int(result["start_seq"])
            self._stok = result["stok"]
            return
        # Older firmware: plain login with the MD5 hash over TLS.
        self._secure, self.algo = False, "md5"
        res = self._post(self.base, {"method": "login", "params": {
            "hashed": True, "password": self.md5, "username": USER}})
        stok = (res.get("result") or {}).get("stok")
        if res.get("error_code", 0) != 0 or not stok:
            raise TapoError(_login_error(res))
        self._stok = stok

    # --- requests ---------------------------------------------------------
    def _encrypt(self, raw: bytes) -> bytes:
        padder = padding.PKCS7(128).padder()
        enc = Cipher(algorithms.AES(self._lsk), modes.CBC(self._ivb)).encryptor()
        return enc.update(padder.update(raw) + padder.finalize()) + enc.finalize()

    def _decrypt(self, raw: bytes) -> bytes:
        dec = Cipher(algorithms.AES(self._lsk), modes.CBC(self._ivb)).decryptor()
        unpadder = padding.PKCS7(128).unpadder()
        return unpadder.update(dec.update(raw) + dec.finalize()) + unpadder.finalize()

    def _send(self, request: dict) -> dict:
        if not self._stok:
            self._login()
        url = f"{self.base}/stok={self._stok}/ds"
        if not self._secure:
            return self._post(url, request)
        body = {"method": "securePassthrough", "params": {
            "request": base64.b64encode(self._encrypt(json.dumps(request).encode())).decode()}}
        tag = _sha256_upper(_sha256_upper(self._hashed(), self._cnonce), json.dumps(body), str(self._seq))
        headers = {"Seq": str(self._seq), "Tapo_tag": tag}
        self._seq += 1
        res = self._post(url, body, headers)
        inner = (res.get("result") or {}).get("response")
        if inner is None:
            return res
        try:
            return json.loads(self._decrypt(base64.b64decode(inner)))
        except ValueError:
            raise TapoError("could not decrypt the camera's answer")

    def request(self, request: dict) -> dict:
        """Send one request, logging in again once if the session expired."""
        with self._lock:
            for attempt in range(2):
                res = self._send(request)
                code = res.get("error_code", 0)
                if code == 0:
                    return res
                if code in _SESSION_ERRORS and attempt == 0:
                    self._stok = None
                    continue
                raise TapoError(f"camera refused the command (error {code})")
        raise TapoError("camera session could not be established")

    # --- features ---------------------------------------------------------
    def alarm(self, on: bool) -> None:
        self.request({"method": "do", "msg_alarm": {"manual_msg_alarm": {"action": "start" if on else "stop"}}})

    def check(self) -> str:
        """Log in and return the hash algorithm the camera uses."""
        with self._lock:
            self._stok = None
            self._login()
        return self.algo or "md5"

    def close(self) -> None:
        self.http.close()


def _login_error(res: dict) -> str:
    data = (res.get("result") or {}).get("data") or res.get("data") or {}
    if data.get("sec_left"):
        return f"camera locked after failed logins, retry in {data['sec_left']} s"
    if data.get("code") == -40411 or res.get("error_code") == -40411:
        return "wrong TP-Link account password"
    if res.get("error_code") == -40211:
        # Firmware from mid-2026 changed the local login handshake; not a password problem.
        return "camera firmware blocks local control (error -40211); video still works"
    return f"camera login failed (error {res.get('error_code')})"
