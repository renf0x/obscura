<p align="center">
  <img src="docs/header.svg" alt="Obscura" width="100%">
</p>

<p align="center">
  <b>English</b> · <a href="README.ru.md">Русский</a>
</p>

<p align="center">
  <a href="https://github.com/renf0x/obscura/actions/workflows/hub.yml"><img src="https://github.com/renf0x/obscura/actions/workflows/hub.yml/badge.svg" alt="hub"></a>
  <a href="https://github.com/renf0x/obscura/actions/workflows/app.yml"><img src="https://github.com/renf0x/obscura/actions/workflows/app.yml/badge.svg" alt="app"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-34E3A4?labelColor=060A09" alt="MIT"></a>
</p>

```text
SUBJECT ........ Obscura
TYPE ........... home camera hub + Android/iOS app
CAMERAS ........ TP-Link Tapo (C100/C110/C200/C210…), any RTSP/ONVIF camera
VENDOR CLOUD ... not used
SUBSCRIPTION ... none
```

## Briefing

Obscura watches your cameras from a small server you own. The cameras stay on the home network and never
talk to the internet. The hub records short clips when something moves or a person walks into a zone, sends
an alert to your phone, and keeps the footage wherever you tell it to: on the hub, in S3, on a WebDAV share,
or in any cloud rclone supports.

## Equipment

- **Live view** from anywhere, through the hub.
- **Motion and person detection** in zones you draw over the camera image, the way the Tapo app does it.
  Each zone reacts to motion, to people, or to both.
- **Talk and siren.** Hold to talk through the camera speaker. The siren uses Tapo's built-in alarm, or plays a
  loud tone through the speaker on other cameras. It can go off by itself when a person is detected.
- **Clips, not 24/7 footage**: 4 seconds before the trigger and up to 40 after.
- **Your storage.** Clips stay on the hub and can be copied to S3, WebDAV (Nextcloud, Yandex Disk) or any
  [rclone](https://rclone.org) backend: Google Drive, Dropbox, OneDrive, encrypted remotes.
- **Two alert sounds**: a loud trill for a person, a soft chime for motion. Android gets them through
  [UnifiedPush](https://unifiedpush.org), without Google services, and the payload is end-to-end encrypted.
- **Field manual in the app**, in English and Russian: server, camera, remote access, cloud, notifications.

## How it works

```text
 Camera ──RTSP──▶ Hub (your server) ──HTTPS / Tailscale──▶ Phone
                   │  go2rtc: one connection per camera
                   │  motion + person (YOLOX-nano) inside zones
                   │  ffmpeg ring buffer → clips
                   └─ rclone ──▶ S3 / WebDAV / Google Drive …
```

| Part | Stack |
|------|-------|
| `hub/` | Python 3.12, FastAPI, OpenCV, onnxruntime (YOLOX-nano), ffmpeg, rclone, SQLite |
| `deploy/` | Docker Compose (hub + [go2rtc](https://github.com/AlexxIT/go2rtc)) or a plain systemd install script |
| `app/` | Flutter (Android, iOS), media_kit player |

## Deployment

Pick one of two routes. Both end with a pairing code that you enter in the app, once per phone.

### Route A: a box at home, with Docker

Any 64-bit Linux machine will do. A Raspberry Pi 4 (2 GB) handles one or two cameras; an Intel N100 mini PC
handles up to ten.

```sh
curl -fsSL https://get.docker.com | sh        # skip if Docker is already installed
git clone https://github.com/renf0x/obscura
cd obscura/deploy
mkdir -p data && sudo chown -R 1000:1000 data
docker compose up -d --build
docker compose logs hub | grep -i pairing      # one-time pairing code
```

Set your time zone in `deploy/docker-compose.yml` (`TZ`) first: schedules and clip dates use it.
A new code, for a second phone: `docker compose exec hub python -m obscura pair`.

### Route B: a Debian/Ubuntu server, no Docker

For a VPS or a home server that should be reachable over HTTPS.

```sh
git clone https://github.com/renf0x/obscura
cd obscura/deploy
sudo ./install.sh                  # or: sudo ./install.sh cam.example.com
```

The script installs the hub and go2rtc as systemd services bound to localhost and puts Caddy in front with
an automatic certificate. Without a domain it uses `<your-ip>.sslip.io`. In ufw it opens only ports 80 and 443
and leaves the rest of the firewall, VPN and SSH settings alone. At the end it prints a QR code: open the
app, tap **Scan QR Code**, and the phone connects. For another phone, run `obscura-pair`.

The cameras have to be reachable from this server: the same LAN, or a tunnel back to your home network.
Running the script again updates the hub and keeps the data in `/opt/obscura/data`.

### The phone

Install the APK from [Releases](https://github.com/renf0x/obscura/releases), or build it yourself
(`cd app && flutter build apk --release`). Enter the hub address (`HUB_IP:7878` for route A) and the code,
or scan the QR from route B.

### The camera (Tapo)

In the Tapo app open the camera → Settings → Advanced Settings → Camera Account. Create a username and
password there, then add the camera in Obscura with them. Other cameras need their RTSP or ONVIF login.

### Away from home

With route A, install [Tailscale](https://tailscale.com) on the hub and on the phone and connect to the hub's
Tailscale address. No ports to open. Route B is already reachable over HTTPS.

Every step above has a longer version in the app: *Settings → Setup Guides*.

## Development

```sh
# hub
cd hub && python -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt && pytest

# app
cd app && flutter pub get && flutter analyze && flutter test
flutter run
```

Real cameras need `ffmpeg` on PATH and a running go2rtc. The tests use fakes and need neither.

## Security

The threat model and how to report a vulnerability are in [SECURITY.md](SECURITY.md). Please report
privately, not in public issues.

## License

[MIT](LICENSE). Components keep their own licenses: YOLOX (Apache-2.0), go2rtc (MIT), rclone (MIT),
ffmpeg (LGPL/GPL, run as a separate binary).
