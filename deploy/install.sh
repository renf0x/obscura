#!/usr/bin/env bash
# Obscura hub on a plain Debian/Ubuntu server (VPS or home box), no Docker.
#
#   sudo ./install.sh [domain]
#
# - hub + go2rtc as systemd services, listening on localhost only;
# - Caddy in front with an automatic HTTPS certificate. Without a domain, <your-ip>.sslip.io is used
#   (a public DNS name that resolves to your IP), so the phone always gets a valid HTTPS address;
# - opens only 80/443 in ufw (if ufw is on); other firewall rules, VPN and SSH settings are untouched.
#
# Re-running updates the hub and keeps data (/opt/obscura/data).
set -euo pipefail

GO2RTC_VERSION=v1.9.14
MODEL_URL=https://github.com/Megvii-BaseDetection/YOLOX/releases/download/0.1.1rc0/yolox_nano.onnx
MODEL_SHA256=c789161ed43c8269fcd4e67c67eeeb4e80c622da2eb296a20bc6007bd18a0b7d
ROOT=/opt/obscura
SRC="$(cd "$(dirname "$0")/../hub" && pwd)"

[ "$(id -u)" = 0 ] || { echo "Run as root (sudo)."; exit 1; }
[ -d "$SRC/obscura" ] || { echo "Run from a checkout of the repository (hub/ not found)."; exit 1; }

DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then
  ip="$(curl -4fsS https://api.ipify.org)"
  DOMAIN="${ip//./-}.sslip.io"
fi
case "$DOMAIN" in *[!A-Za-z0-9.-]*|"") echo "Bad domain: $DOMAIN"; exit 1;; esac

echo "==> Packages"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ffmpeg python3-venv curl ca-certificates caddy qrencode >/dev/null

echo "==> User and folders"
id obscura >/dev/null 2>&1 || useradd --system --home "$ROOT" --shell /usr/sbin/nologin obscura
mkdir -p "$ROOT/bin" "$ROOT/data"

echo "==> go2rtc $GO2RTC_VERSION"
case "$(dpkg --print-architecture)" in
  amd64) arch=amd64 ;; arm64) arch=arm64 ;; armhf) arch=armv6 ;;
  *) echo "Unsupported architecture"; exit 1 ;;
esac
if ! "$ROOT/bin/go2rtc" -version 2>/dev/null | grep -q "${GO2RTC_VERSION#v}"; then
  curl -fsSLo "$ROOT/bin/go2rtc" \
    "https://github.com/AlexxIT/go2rtc/releases/download/$GO2RTC_VERSION/go2rtc_linux_$arch"
  chmod 755 "$ROOT/bin/go2rtc"
fi

echo "==> Person detector model"
if ! echo "$MODEL_SHA256  $ROOT/bin/yolox_nano.onnx" | sha256sum -c - >/dev/null 2>&1; then
  curl -fsSLo "$ROOT/bin/yolox_nano.onnx" "$MODEL_URL"
  echo "$MODEL_SHA256  $ROOT/bin/yolox_nano.onnx" | sha256sum -c -
fi

echo "==> Hub"
rm -rf "$ROOT/app" && mkdir -p "$ROOT/app"
cp -r "$SRC/obscura" "$SRC/requirements.txt" "$ROOT/app/"
[ -x "$ROOT/venv/bin/python" ] || python3 -m venv "$ROOT/venv"
"$ROOT/venv/bin/pip" install -q --upgrade pip
"$ROOT/venv/bin/pip" install -q -r "$ROOT/app/requirements.txt"
chown -R obscura: "$ROOT/data"

TZ_NAME="$(timedatectl show -p Timezone --value 2>/dev/null || echo UTC)"

cat > /etc/systemd/system/obscura-go2rtc.service <<EOF
[Unit]
Description=Obscura go2rtc (localhost only)
After=network-online.target
Wants=network-online.target

[Service]
User=obscura
# Inline config: camera passwords registered by the hub stay in memory only.
ExecStart=$ROOT/bin/go2rtc -config '{"api":{"listen":"127.0.0.1:1984","allow_paths":["/api/streams","/api/frame.jpeg","/api/stream.mp4"]},"rtsp":{"listen":"127.0.0.1:8554"},"webrtc":{"listen":""},"srtp":{"listen":""},"log":{"level":"warn"}}'
Restart=always
RestartSec=3
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/obscura-hub.service <<EOF
[Unit]
Description=Obscura hub
After=network-online.target obscura-go2rtc.service
Wants=network-online.target
Requires=obscura-go2rtc.service

[Service]
User=obscura
WorkingDirectory=$ROOT/app
Environment=OBSCURA_DATA=$ROOT/data OBSCURA_HOST=127.0.0.1 OBSCURA_PORT=7878
Environment=OBSCURA_MODEL=$ROOT/bin/yolox_nano.onnx PYTHONUNBUFFERED=1 TZ=$TZ_NAME
Environment=PATH=$ROOT/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$ROOT/venv/bin/python -m obscura
Restart=always
RestartSec=3
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=$ROOT/data

[Install]
WantedBy=multi-user.target
EOF

echo "==> HTTPS ($DOMAIN)"
CADDYFILE=/etc/caddy/Caddyfile
if [ -f "$CADDYFILE" ] && ! grep -q "obscura" "$CADDYFILE" && grep -qvE '^\s*(#|$)' "$CADDYFILE" \
   && ! grep -q "/usr/share/caddy" "$CADDYFILE"; then
  # Someone else's Caddy config: add ours as a separate file instead of overwriting it.
  mkdir -p /etc/caddy/conf.d
  grep -q "import conf.d/\*" "$CADDYFILE" || echo "import conf.d/*" >> "$CADDYFILE"
  CADDYFILE=/etc/caddy/conf.d/obscura
fi
cat > "$CADDYFILE" <<EOF
# obscura
$DOMAIN {
	reverse_proxy 127.0.0.1:7878
}
EOF

if ufw status 2>/dev/null | grep -q "Status: active"; then
  ufw allow 80/tcp comment "Obscura HTTPS certificate" >/dev/null
  ufw allow 443/tcp comment "Obscura" >/dev/null
fi

systemctl daemon-reload
systemctl enable -q obscura-go2rtc obscura-hub caddy
systemctl restart obscura-go2rtc obscura-hub caddy

echo "==> Waiting for the hub"
for _ in $(seq 30); do curl -fsS http://127.0.0.1:7878/api/health >/dev/null 2>&1 && break; sleep 2; done
# `obscura-pair`: a fresh single-use code shown as a QR; the app scans it and connects, no typing.
cat > /usr/local/bin/obscura-pair <<EOF
#!/bin/sh
set -e
code="\$(cd $ROOT/app && sudo -u obscura OBSCURA_DATA=$ROOT/data $ROOT/venv/bin/python -m obscura pair 2>/dev/null | sed -n 's/.*Pairing code: *//p')"
qrencode -t ansiutf8 "{\"url\":\"https://$DOMAIN\",\"code\":\"\$code\"}"
echo "Address: https://$DOMAIN   Code: \$code   (valid 10 minutes, single use)"
EOF
chmod 755 /usr/local/bin/obscura-pair

echo
echo "Obscura hub is running. In the app tap \"Scan QR\" and point the phone at this code:"
echo
/usr/local/bin/obscura-pair
cat <<EOF

  QR for another phone:  obscura-pair
  Logs:                  journalctl -u obscura-hub -f

Cameras must be reachable from this server (same LAN, or a port forward through your router's
VPN tunnel). Add them in the app with their LAN or tunnel address.
EOF
