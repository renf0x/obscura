<p align="center">
  <img src="docs/header.svg" alt="Obscura" width="100%">
</p>

<p align="center">
  <a href="README.md">English</a> · <b>Русский</b>
</p>

<p align="center">
  <a href="https://github.com/renf0x/obscura/actions/workflows/hub.yml"><img src="https://github.com/renf0x/obscura/actions/workflows/hub.yml/badge.svg" alt="hub"></a>
  <a href="https://github.com/renf0x/obscura/actions/workflows/app.yml"><img src="https://github.com/renf0x/obscura/actions/workflows/app.yml/badge.svg" alt="app"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-34E3A4?labelColor=060A09" alt="MIT"></a>
</p>

```text
ОБЪЕКТ ......... Obscura
ТИП ............ домашний хаб для камер + приложение для Android/iOS
КАМЕРЫ ......... TP-Link Tapo (C100/C110/C200/C210…), любые RTSP/ONVIF
ОБЛАКО TP-LINK . не используется
ПОДПИСКА ....... не нужна
```

## Вводная

Obscura следит за камерами с небольшого сервера, который принадлежит вам. Камеры остаются в домашней сети и
в интернет не ходят. Когда в зоне что-то двигается или появляется человек, хаб пишет короткий ролик, присылает
уведомление на телефон и складывает запись туда, куда вы скажете: на сам хаб, в S3, на WebDAV или в любое
облако, которое понимает rclone.

## Снаряжение

- **Живое видео** откуда угодно, через хаб.
- **Детекция движения и людей** в зонах, которые вы рисуете поверх кадра, как в приложении Tapo.
  Каждая зона реагирует на движение, на людей или на то и другое.
- **Разговор и сирена.** Зажмите кнопку и говорите через динамик камеры. Сирена включает встроенную тревогу
  Tapo, а на других камерах играет громкий сигнал через динамик. Может срабатывать сама, если в кадре человек.
- **Ролики, а не круглосуточная запись**: 4 секунды до срабатывания и до 40 после.
- **Своё хранилище.** Ролики лежат на хабе, копии уходят в S3, WebDAV (Яндекс Диск, Nextcloud) или в любое
  хранилище [rclone](https://rclone.org): Google Drive, Dropbox, OneDrive, зашифрованные хранилища.
- **Два звука уведомлений**: громкая трель, если это человек, мягкий сигнал, если просто движение. На Android
  они приходят через [UnifiedPush](https://unifiedpush.org), без сервисов Google, и содержимое зашифровано.
- **Инструкции в приложении**, на русском и английском: сервер, камера, удалённый доступ, облако, уведомления.

## Как устроено

```text
 Камера ──RTSP──▶ Хаб (ваш сервер) ──HTTPS / Tailscale──▶ Телефон
                   │  go2rtc: одно подключение к камере
                   │  движение + люди (YOLOX-nano) в зонах
                   │  кольцевой буфер ffmpeg → ролики
                   └─ rclone ──▶ S3 / WebDAV / Google Drive …
```

| Часть | Стек |
|-------|------|
| `hub/` | Python 3.12, FastAPI, OpenCV, onnxruntime (YOLOX-nano), ffmpeg, rclone, SQLite |
| `deploy/` | Docker Compose (хаб + [go2rtc](https://github.com/AlexxIT/go2rtc)) или скрипт установки через systemd |
| `app/` | Flutter (Android, iOS), плеер media_kit |

## Развёртывание

Есть два пути. Оба заканчиваются кодом сопряжения, который вводится в приложении один раз на каждый телефон.

### Путь А: компьютер дома, с Docker

Подойдёт любая 64-битная машина с Linux. Raspberry Pi 4 (2 ГБ) тянет одну-две камеры, мини-ПК на Intel N100 —
до десяти.

```sh
curl -fsSL https://get.docker.com | sh        # если Docker ещё не стоит
git clone https://github.com/renf0x/obscura
cd obscura/deploy
mkdir -p data && sudo chown -R 1000:1000 data
docker compose up -d --build
docker compose logs hub | grep -i pairing      # одноразовый код сопряжения
```

Перед запуском проверьте часовой пояс в `deploy/docker-compose.yml` (`TZ`): по нему считаются расписания и даты
роликов. Новый код для второго телефона: `docker compose exec hub python -m obscura pair`.

### Путь Б: сервер на Debian/Ubuntu, без Docker

Для VPS или домашнего сервера, к которому нужно ходить по HTTPS.

```sh
git clone https://github.com/renf0x/obscura
cd obscura/deploy
sudo ./install.sh                  # или: sudo ./install.sh cam.example.com
```

Скрипт ставит хаб и go2rtc как службы systemd, которые слушают только localhost, а перед ними ставит Caddy с
автоматическим сертификатом. Если домена нет, используется `<ваш-ip>.sslip.io`. В ufw открываются только
порты 80 и 443, остальные правила файрвола, VPN и SSH скрипт не трогает. В конце он печатает QR-код: откройте
приложение, нажмите **Сканировать QR-код**, и телефон подключится. Для следующего телефона есть команда
`obscura-pair`.

Камеры должны быть доступны с этого сервера: из той же сети или через туннель в домашнюю сеть. Повторный
запуск скрипта обновляет хаб, данные в `/opt/obscura/data` остаются.

### Телефон

Установите APK из [Releases](https://github.com/renf0x/obscura/releases) или соберите сами
(`cd app && flutter build apk --release`). Введите адрес хаба (`IP_ХАБА:7878` для пути А) и код, либо
отсканируйте QR с пути Б.

### Камера (Tapo)

В приложении Tapo откройте камеру → Настройки → «Расширенные настройки» → «Учётная запись камеры». Создайте
там логин и пароль и добавьте камеру в Obscura с ними. Другим камерам нужен их логин RTSP или ONVIF.

### Вне дома

Для пути А поставьте [Tailscale](https://tailscale.com) на хаб и на телефон и подключайтесь к адресу хаба в
Tailscale. Порты открывать не нужно. На пути Б хаб и так доступен по HTTPS.

Подробная версия каждого шага есть в приложении: *Настройки → Инструкции*.

## Разработка

```sh
# хаб
cd hub && python -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt && pytest

# приложение
cd app && flutter pub get && flutter analyze && flutter test
flutter run
```

Для живых камер нужен `ffmpeg` в PATH и запущенный go2rtc. Тестам не нужно ни то ни другое, они работают на
заглушках.

## Безопасность

Модель угроз и порядок сообщения об уязвимостях описаны в [SECURITY.md](SECURITY.md). Пишите о них закрыто,
не в публичных issues.

## Лицензия

[MIT](LICENSE). У компонентов свои лицензии: YOLOX (Apache-2.0), go2rtc (MIT), rclone (MIT), ffmpeg
(LGPL/GPL, запускается отдельным бинарником).
