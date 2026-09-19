import 'package:flutter/material.dart';

import 'guide_model.dart';
import 'guides_ru.dart' show repoUrl;

const guidesEn = <Guide>[
  Guide(
    id: 'overview',
    icon: Icons.hub_outlined,
    title: 'How it works',
    summary: 'Camera → hub → phone. No vendor cloud.',
    steps: [
      GuideStep(
        'Three parts',
        '1. The camera (e.g. Tapo C110) streams video on your local network over RTSP.\n'
            '2. The hub is a small server at home (Raspberry Pi, mini PC, NAS or an old laptop). It holds the only '
            'connection to the camera, looks for motion and people inside your zones, records short clips and can '
            'copy them to cloud storage.\n'
            '3. The Obscura app talks only to the hub: live view, alerts and clip playback.',
      ),
      GuideStep(
        'Why a hub',
        'The hub is the bridge between your home network and your phone. The camera is never exposed to the internet; '
            'at most the hub is, ideally through an encrypted VPN (Tailscale). Camera passwords stay on the hub and never '
            'reach the phone.',
      ),
      GuideStep(
        'What gets saved',
        'Not 24/7 footage — only moments. When a trigger fires, the hub saves a clip with 4 seconds before the event '
            'and up to 40 seconds after. Clips live on the hub (old ones are deleted automatically) and can be copied to S3, '
            'WebDAV (Nextcloud, Yandex Disk) or anything rclone supports.',
      ),
      GuideStep(
        'Setup order',
        '1. Prepare a server ("Server requirements").\n'
            '2. Install the hub ("Install the hub").\n'
            '3. Enable RTSP on the camera ("Tapo camera").\n'
            '4. Pair the app using the code from the hub logs.\n'
            '5. Add the camera, draw zones, enable notifications.\n'
            '6. For access away from home, set up Tailscale ("Access from anywhere").',
      ),
    ],
  ),
  Guide(
    id: 'requirements',
    icon: Icons.memory,
    title: 'Server requirements',
    summary: 'Minimum: Raspberry Pi 4 with a 64-bit OS.',
    steps: [
      GuideStep(
        'How much power',
        'The hub never re-encodes video, so the load is light. Most CPU goes to person detection '
            '(YOLOX-nano runs about once per second, and only while something moves).',
        table: [
          ['Cameras', 'Minimum', 'Recommended'],
          ['1–2', 'Raspberry Pi 4, 2 GB RAM', 'Raspberry Pi 4/5, 4 GB'],
          ['3–4', 'Raspberry Pi 5, 4 GB', 'Intel N100 mini PC, 8 GB'],
          ['5–10', 'N100 mini PC, 8 GB', 'Intel i3/i5, 8–16 GB'],
        ],
      ),
      GuideStep(
        'Operating system',
        'Any 64-bit Linux with Docker: Raspberry Pi OS Lite (64-bit), Ubuntu Server, Debian. Synology/QNAP NAS with Docker '
            'and Windows/macOS with Docker Desktop also work (with caveats, see installation).',
        warning: '32-bit systems are not supported: the person detector needs a 64-bit OS.',
      ),
      GuideStep(
        'Disk',
        'A 10-second 2K clip from a Tapo C110 is about 2–3 MB. 100 events a day ≈ 250 MB. On a Raspberry Pi prefer a USB SSD '
            'or flash drive: SD cards wear out. The pre-record buffer lives in RAM, so it does not wear the card.',
      ),
      GuideStep(
        'Network',
        'Connect the hub to the router with a cable if you can. Give the camera and the hub fixed IP addresses '
            '(router setting usually called "DHCP reservation").',
      ),
    ],
  ),
  Guide(
    id: 'install',
    icon: Icons.terminal,
    title: 'Install the hub',
    summary: 'Docker, three commands and a code for your phone.',
    steps: [
      GuideStep(
        '1. Prepare a Raspberry Pi (if you use one)',
        'Download Raspberry Pi Imager and pick Raspberry Pi OS Lite (64-bit). In the image settings (gear icon) set a user, '
            'password, Wi-Fi (if no cable) and enable SSH. Flash the card, boot the Pi and connect from your computer:',
        code: 'ssh YOUR_USER@raspberrypi.local',
      ),
      GuideStep(
        '2. Install Docker',
        'Docker\'s official install script. Log out of SSH and back in afterwards so the docker group applies.',
        code: 'curl -fsSL https://get.docker.com | sh\nsudo usermod -aG docker \$USER',
      ),
      GuideStep(
        '3. Download Obscura and start it',
        'The hub and go2rtc run as two containers and start again automatically after a reboot.',
        code: 'git clone $repoUrl\ncd obscura/deploy\nmkdir -p data && sudo chown -R 1000:1000 data\ndocker compose up -d',
      ),
      GuideStep(
        '4. Get the pairing code',
        'On first start the hub prints a one-time code (valid for 10 minutes). The second command makes a new one.',
        code: 'docker compose logs hub | grep -i pairing\n# or a fresh code:\ndocker compose exec hub python -m obscura pair',
      ),
      GuideStep(
        '5. Pair your phone',
        'Find the hub\'s IP with the command below. In the app enter an address like 192.168.1.10:7878 and the code. '
            'The phone must be on the same Wi-Fi (or on Tailscale, see "Access from anywhere").',
        code: 'hostname -I',
      ),
      GuideStep(
        'Updating',
        'Settings, clips and paired phones live in deploy/data and survive updates.',
        code: 'cd ~/obscura && git pull\ncd deploy && docker compose pull && docker compose up -d',
      ),
      GuideStep(
        'Windows, macOS and NAS',
        'Windows/macOS: install Docker Desktop, enable Settings → Resources → Network → "Enable host networking", then run '
            'steps 3–5 in a terminal. Camera discovery may not work in this mode — type IPs manually.\n'
            'Synology: Container Manager → Project → Create → point it at the folder with docker-compose.yml from the repository.',
        warning: 'The hub machine must stay on, otherwise recording and alerts stop.',
      ),
    ],
  ),
  Guide(
    id: 'tapo',
    icon: Icons.videocam_outlined,
    title: 'Tapo camera (C110 etc.)',
    summary: 'Camera account for video, TP-Link password for talk and siren.',
    steps: [
      GuideStep(
        '1. Set the camera up as usual',
        'Connect the camera to Wi-Fi with the official Tapo app and update the firmware.',
      ),
      GuideStep(
        '2. Create a camera account',
        'In the Tapo app: open the camera → gear (Settings) → Advanced Settings → Camera Account. Choose a username and '
            'password (6–32 characters). This is not your TP-Link ID: it is a separate local login for the RTSP/ONVIF stream.',
        warning: 'Use a unique password: it will be stored on the hub.',
      ),
      GuideStep(
        '3. Third-party compatibility (newer firmware)',
        'If the camera settings have "Third-Party Compatibility" (sometimes under Tapo Lab), turn it on. '
            'Newer firmware may block RTSP without it.',
      ),
      GuideStep(
        '4. Find the camera IP',
        'Camera settings → Device Info → IP address. Reserve it in your router so it doesn\'t change, or tap '
            '"Find on network" when adding the camera in Obscura.',
      ),
      GuideStep(
        '5. Add it to Obscura',
        'Cameras → Add camera → brand TP-Link Tapo → IP → camera account username and password. Obscura records the main '
            '2K stream /stream1 and analyses the light /stream2.',
        code: 'rtsp://USER:PASSWORD@CAMERA_IP:554/stream1\nrtsp://USER:PASSWORD@CAMERA_IP:554/stream2',
      ),
      GuideStep(
        '6. Talk and siren (optional)',
        'Tapo\'s speaker and alarm are not reachable over RTSP but through the camera\'s own protocol, which only accepts '
            'your TP-Link account password (the one you sign in to the Tapo app with). Enter it in the camera connection '
            'settings under "TP-Link account password". Obscura checks it right away.\n\n'
            'The hub does not keep the password itself, only its hashes (MD5 and SHA-256), which is all the camera needs. '
            'The app never receives them either.\n\n'
            'The camera screen then shows:\n'
            '• "Hold to talk": hold, speak, release, and the message plays from the camera speaker '
            '(1–2 s delay, up to 30 s at a time);\n'
            '• "Siren": the camera\'s own alarm (sound and light); it switches off by itself after the set time.\n'
            'Under Triggers you can turn on "Siren when a person is detected".',
        warning: 'The hash still lets anyone on your LAN log in to the camera, so protect the hub like your phone. '
            'If the hub is ever stolen, change your TP-Link password.',
      ),
      GuideStep(
        'If talk or the siren fail',
        '• "Wrong TP-Link account password": check it in the Tapo app (sign out and back in).\n'
            '• "Camera locked after failed logins": wait the time shown; the camera blocks logins after a few mistakes.\n'
            '• The hub must reach the camera on ports 443 and 8800 (normally open on a home network).\n'
            '• TP-Link sometimes changes the login in new firmware. If it stops working after a camera update, '
            'update the hub: docker compose pull && docker compose up -d.',
      ),
      GuideStep(
        'If it won\'t connect',
        '• Make sure the hub and the camera are on the same network (ping the IP from the hub).\n'
            '• Double-check the camera account credentials.\n'
            '• Tapo allows few simultaneous connections: close live view in the Tapo app.\n'
            '• Tapo privacy mode turns the stream off — disable it.',
      ),
    ],
  ),
  Guide(
    id: 'cameras',
    icon: Icons.linked_camera_outlined,
    title: 'Other cameras',
    summary: 'Any camera with RTSP or ONVIF.',
    steps: [
      GuideStep(
        'Presets',
        'Obscura knows the stream paths of popular brands. Pick the brand and the paths are filled in.',
        table: [
          ['Brand', 'Main stream', 'Sub stream'],
          ['Tapo', '/stream1', '/stream2'],
          ['Hikvision', '/Streaming/Channels/101', '/Streaming/Channels/102'],
          ['Dahua / Imou', '/cam/realmonitor?channel=1&subtype=0', '…subtype=1'],
          ['Reolink', '/h264Preview_01_main', '/h264Preview_01_sub'],
        ],
      ),
      GuideStep(
        'Anything else',
        'Choose "Other RTSP / ONVIF camera" and enter the stream path under Advanced. Find it in the camera manual or at '
            'ispyconnect.com/cameras. A sub stream (low resolution) is optional but cuts hub load a lot.',
      ),
      GuideStep(
        'Talk and siren',
        'If the camera has a speaker and supports two-way audio over RTSP/ONVIF (Profile T; most Hikvision, Dahua and '
            'Reolink models with a speaker), turn on "Camera has a speaker" in the connection settings. "Hold to talk" '
            'and "Siren" appear; here the siren plays through the camera speaker.\n\n'
            'Audio is sent as G.711 A-law (PCMA). If the camera stays silent, check in its web interface that audio is '
            'enabled and the codec is G.711A.',
      ),
      GuideStep(
        'Limits',
        'H.264 and H.265 streams are supported. Cloud-only cameras without RTSP (some Xiaomi, Ring, Arlo) cannot be added directly.',
      ),
    ],
  ),
  Guide(
    id: 'remote',
    icon: Icons.public,
    title: 'Access from anywhere',
    summary: 'Tailscale: no open ports, encrypted.',
    steps: [
      GuideStep(
        'How the bridge works',
        'At home the camera and hub share a network. Away from home the phone needs a way to reach the hub. The simplest safe '
            'option is Tailscale, a private VPN: hub and phone see each other as if on the same network, traffic is encrypted '
            '(WireGuard) and no router ports are opened.',
      ),
      GuideStep(
        '1. Install Tailscale on the hub',
        'The command prints a login link — sign in with Google, GitHub, Microsoft or e-mail. Free for personal use.',
        code: 'curl -fsSL https://tailscale.com/install.sh | sh\nsudo tailscale up\ntailscale ip -4',
      ),
      GuideStep(
        '2. Install Tailscale on the phone',
        'Get Tailscale from Google Play / the App Store, sign in to the same account and turn the VPN on.',
      ),
      GuideStep(
        '3. Connect Obscura through Tailscale',
        'Use the hub\'s Tailscale address in the app (100.x.y.z:7878 from the command above) or a name like '
            'hub.your-tailnet.ts.net:7878. If you paired using the home IP, disconnect in Settings and pair again with a new code.',
      ),
      GuideStep(
        'Alternative: Cloudflare Tunnel',
        'If you have a domain on Cloudflare, install cloudflared on the hub and tunnel to http://localhost:7878. '
            'Use https://cam.your-domain.com in the app. Downside: Cloudflare terminates TLS.',
        code: 'cloudflared tunnel login\ncloudflared tunnel create obscura\ncloudflared tunnel route dns obscura cam.example.com\n'
            'cloudflared tunnel run --url http://localhost:7878 obscura',
      ),
      GuideStep(
        'Don\'t',
        'Don\'t forward port 7878 on your router without HTTPS. If you must forward, put Caddy in front of the hub '
            '(it gets a Let\'s Encrypt certificate itself) and open only 443.',
        code: '# /etc/caddy/Caddyfile\ncam.example.com {\n  reverse_proxy 127.0.0.1:7878\n}',
        warning: 'The app warns you when connecting to a public address over plain http.',
      ),
    ],
  ),
  Guide(
    id: 'cloud',
    icon: Icons.cloud_outlined,
    title: 'Cloud storage',
    summary: 'S3, Yandex Disk, Nextcloud, Google Drive…',
    steps: [
      GuideStep(
        'Why',
        'If the hub is stolen or breaks, copies of the clips stay in the cloud. The hub uploads every clip and thumbnail right '
            'after recording to a folder like obscura/camera-1/2026-09-18/. Set it up in Settings → Storage.',
      ),
      GuideStep(
        'Yandex Disk (WebDAV)',
        '1. Open id.yandex.ru → Security → App passwords → create one for "Files (WebDAV)".\n'
            '2. In Obscura: Storage → WebDAV.\n'
            '   URL: https://webdav.yandex.ru\n'
            '   Server type: other\n'
            '   User: your Yandex login\n'
            '   Password: the app password\n'
            '3. Save and tap "Test connection".',
      ),
      GuideStep(
        'Nextcloud / ownCloud (WebDAV)',
        'URL: https://your-server/remote.php/dav/files/USERNAME/\n'
            'Server type: nextcloud (or owncloud)\n'
            'Password: create an app password in Settings → Security.',
      ),
      GuideStep(
        'S3-compatible (AWS, Backblaze B2, MinIO, Cloudflare R2, Yandex Object Storage)',
        'Create a bucket and an access key in the provider console. In Obscura: Storage → S3.\n'
            '   Provider: Other (AWS for Amazon, Minio for MinIO)\n'
            '   Endpoint: e.g. https://s3.eu-central-003.backblazeb2.com\n'
            '   Region: e.g. eu-central-003\n'
            '   Folder: BUCKET_NAME/obscura — the first path part is the bucket.',
      ),
      GuideStep(
        'Google Drive, Dropbox, OneDrive, Mega and more',
        'For services with browser sign-in, configure rclone on the hub by hand, then pick the "rclone" type and enter the '
            'remote name you created (e.g. gdrive).',
        code: 'cd ~/obscura/deploy\ndocker compose exec -it hub rclone --config /data/rclone.conf config',
      ),
      GuideStep(
        'Encrypted cloud copies',
        'rclone can encrypt files before upload (the crypt type). Create a crypt remote on top of your cloud remote in '
            'rclone config and use its name in Obscura — the provider only sees encrypted files.',
      ),
    ],
  ),
  Guide(
    id: 'notifications',
    icon: Icons.notifications_active_outlined,
    title: 'Notifications',
    summary: 'Different sounds for motion and people.',
    steps: [
      GuideStep(
        'Two sounds',
        'Person: a loud alarm trill (three rising beeps, twice), vibration and red colour. Motion: a short soft chime. '
            'Hear both in Settings → Notifications → Sound check.',
      ),
      GuideStep(
        'Android: UnifiedPush via ntfy',
        'Obscura does not use Google Firebase. Background alerts are delivered by a distributor app, ntfy.\n'
            '1. Install ntfy from Google Play or F-Droid and open it once.\n'
            '2. In Obscura: Settings → Notifications → turn on "Push notifications".\n'
            '3. Allow notifications and disable battery optimisation for ntfy.\n'
            'Alert contents are encrypted with your phone\'s key: the ntfy server only sees ciphertext.',
      ),
      GuideStep(
        'Your own ntfy server (optional)',
        'ntfy.sh is used by default. To avoid depending on it, run your own ntfy (docker run binwiederhier/ntfy serve) and set '
            'its address in the ntfy app settings.',
      ),
      GuideStep(
        'iPhone',
        'iOS does not allow background alerts without Apple\'s servers. Use the ntfy iOS app:\n'
            '1. In Obscura: Settings → Notifications → "ntfy topic" → enable it and keep the generated topic name.\n'
            '2. Subscribe to the same topic in the ntfy app.\n'
            'Person alerts arrive with maximum priority. Tapping one opens Obscura.',
        warning: 'The camera name and event type are sent to the ntfy topic in plain text. '
            'Use a long random topic, an access token or your own ntfy server.',
      ),
      GuideStep(
        'While the app is open',
        'While Obscura is on screen, events come straight from the hub — even without push.',
      ),
    ],
  ),
  Guide(
    id: 'security',
    icon: Icons.verified_user_outlined,
    title: 'Security',
    summary: 'Keep your cameras from becoming a hole.',
    steps: [
      GuideStep(
        'Already in place',
        '• Every hub request needs a device token; the hub stores only a hash of it.\n'
            '• Pairing codes are single-use, expire in 10 minutes and guessing is rate-limited.\n'
            '• Camera and cloud passwords are never sent back to the app.\n'
            '• go2rtc is reachable only from inside the server.\n'
            '• Push payloads are encrypted with the phone\'s key.',
      ),
      GuideStep(
        'Your part',
        '• Use Tailscale for remote access; don\'t open ports.\n'
            '• Turn on the app lock (Settings → App lock).\n'
            '• Lost a phone? Revoke it in Settings → Devices from another phone.\n'
            '• Update the hub regularly.\n'
            '• If you can, block the cameras\' internet access in the router (or move them to a guest network/VLAN).',
      ),
      GuideStep(
        'Backup',
        'All hub state is in deploy/data. Copy the folder to move the hub to another machine.',
        code: 'cd ~/obscura/deploy && docker compose stop hub\ntar czf obscura-backup.tgz data\ndocker compose start hub',
      ),
    ],
  ),
];
