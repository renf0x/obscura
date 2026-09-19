# Security

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting ("Security" tab → "Report a vulnerability").
Do not open public issues for security problems.

## Threat model

Obscura handles home camera footage, so the defaults assume a hostile network outside the home.

| Asset | Protection |
|-------|-----------|
| Hub API | Every route except `/api/health` and `/api/pair` requires a per-device bearer token. Tokens are 256-bit random values; the hub stores only their SHA-256. Devices can be revoked individually. |
| Pairing | One-time 10-character codes, valid for 10 minutes, consumed atomically. Attempts are rate-limited per client and globally. |
| Camera credentials | Stored only on the hub (SQLite in the data volume). Never returned by the API. go2rtc runs without a config file, so it keeps them in memory only. |
| TP-Link account password (Tapo talk/siren) | Never stored: the hub keeps only the uppercase MD5 and SHA-256 hashes the camera's login needs. Write-only from the app. The login is a challenge-response, so the hash does not cross the network either. |
| Talk recordings | Accepted only from paired devices, max 1 MB. ffmpeg decodes them with the MP4 demuxer forced and `-protocol_whitelist file`. Converted audio lives in RAM and is served to go2rtc through random one-off links (`/internal/audio/…`) that answer only on localhost and expire after two minutes. |
| Cloud credentials | Written into rclone's config on the hub; secret fields are write-only from the app. |
| go2rtc | Bound to `127.0.0.1`; `allow_paths` blocks `/api/exec`, `/api/config` and the web UI. Stream names come from numeric IDs only. |
| ffmpeg / rclone | Invoked with argument lists (no shell). ffmpeg input is restricted with `-protocol_whitelist rtsp,rtp,udp,tcp`. Camera URLs are rebuilt from validated host/port/path parts. |
| Clip files | Served by event ID; paths come from the database and are checked to stay inside the clips directory. |
| Push payloads | AES-256-GCM with a key generated on the phone, so the UnifiedPush relay only sees ciphertext. Push endpoints cannot point at loopback, link-local or metadata addresses. |
| Phone | Token in the platform keystore (flutter_secure_storage), Android backups disabled, optional biometric app lock. The token is only ever sent in the `Authorization` header, never in URLs. |

## Known limitations

- **Transport.** The hub speaks plain HTTP. Use it on the LAN or through Tailscale (WireGuard), Cloudflare Tunnel or a
  TLS reverse proxy. The app warns before pairing over plain HTTP with a public address.
- **Paired device = admin.** Any paired phone can change settings and pair or revoke other phones.
- **Rate limiting behind proxies.** Behind a tunnel all clients share one source IP, so only the global pairing limit
  applies. `X-Forwarded-For` is deliberately ignored because clients can forge it.
- **ntfy topic (optional, for iPhone).** Topic messages contain the camera name and event type in plain text. Use a long
  random topic, an access token or a self-hosted ntfy server.
- **Tapo control uses the camera's self-signed certificate.** TLS to the camera is not verified (Tapo cameras
  have no trusted certificate). Someone who can impersonate the camera on your LAN could capture a login exchange
  and try to brute-force a weak TP-Link password offline. Use a strong, unique TP-Link password.
- **The password hash is a camera credential.** Anyone who copies the hub's database can log in to Tapo cameras on
  your LAN with it (not to your TP-Link cloud account). If the hub is stolen, change the TP-Link password.
- **Data at rest.** The hub's data volume is not encrypted. Protect the server physically and use full-disk encryption
  if that matters to you. Use rclone `crypt` remotes for encrypted cloud copies.
