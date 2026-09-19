"""ONVIF WS-Discovery: find cameras on the hub's LAN (Tapo C1xx/C2xx answer on port 2020)."""

import ipaddress
import re
import socket
import time
import uuid
from urllib.parse import urlsplit

PROBE = """<?xml version="1.0" encoding="UTF-8"?>
<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope"
 xmlns:w="http://schemas.xmlsoap.org/ws/2004/08/addressing"
 xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery"
 xmlns:dn="http://www.onvif.org/ver10/network/wsdl">
<e:Header><w:MessageID>uuid:{id}</w:MessageID>
<w:To e:mustUnderstand="true">urn:schemas-xmlsoap-org:ws:2005:04:discovery</w:To>
<w:Action e:mustUnderstand="true">http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</w:Action></e:Header>
<e:Body><d:Probe><d:Types>dn:NetworkVideoTransmitter</d:Types></d:Probe></e:Body></e:Envelope>"""

_XADDR_RE = re.compile(rb"<[^>]*XAddrs>([^<]+)</", re.I)
_SCOPE_RE = re.compile(rb"<[^>]*Scopes>([^<]+)</", re.I)


def _vendor(scopes: str) -> str:
    s = scopes.lower()
    for key in ("tapo", "tp-link", "hikvision", "dahua", "reolink", "amcrest", "imou", "axis"):
        if key in s:
            return "tapo" if key in ("tapo", "tp-link") else key
    return "generic"


def discover(timeout: float = 3.0) -> list[dict]:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
    sock.settimeout(0.5)
    found: dict[str, dict] = {}
    try:
        sock.sendto(PROBE.format(id=uuid.uuid4()).encode(), ("239.255.255.250", 3702))
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                data, (addr, _) = sock.recvfrom(65535)
            except socket.timeout:
                continue
            # Only report devices on private networks; ignore anything spoofing public addresses.
            try:
                if not ipaddress.ip_address(addr).is_private:
                    continue
            except ValueError:
                continue
            xaddrs = _XADDR_RE.search(data)
            scopes = _SCOPE_RE.search(data)
            onvif_port = None
            if xaddrs:
                first = xaddrs.group(1).decode(errors="ignore").split()[0]
                onvif_port = urlsplit(first).port
            vendor = _vendor(scopes.group(1).decode(errors="ignore") if scopes else "")
            found[addr] = {"host": addr, "onvif_port": onvif_port, "vendor": vendor}
    finally:
        sock.close()
    return sorted(found.values(), key=lambda d: tuple(int(p) for p in d["host"].split(".")))
