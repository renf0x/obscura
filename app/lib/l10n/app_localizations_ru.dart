// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get tagline => 'Наблюдать · Замечать · Предотвращать';

  @override
  String get connectTitle => 'Подключение к хабу';

  @override
  String get connectSubtitle =>
      'Введите адрес хаба и код сопряжения из его логов.';

  @override
  String get hubAddress => 'Адрес хаба';

  @override
  String get hubAddressInvalid => 'Введите адрес вида 192.168.1.10:7878';

  @override
  String get pairingCode => 'Код сопряжения';

  @override
  String get pairingCodeInvalid => 'Код состоит из 10 символов';

  @override
  String get deviceName => 'Имя этого телефона';

  @override
  String get deviceNameInvalid => 'Введите от 1 до 40 символов';

  @override
  String get connect => 'Подключить';

  @override
  String get scanQr => 'Сканировать QR-код';

  @override
  String get qrInvalid => 'Этот QR-код не является кодом сопряжения Obscura.';

  @override
  String get noHubYet => 'Ещё нет хаба?';

  @override
  String get noHubYetBody =>
      'Пошаговая настройка: сервер, камера, удалённый доступ, облако.';

  @override
  String get insecureTitle => 'Незашифрованное подключение';

  @override
  String get insecureBody =>
      'Это публичный адрес по обычному http: токен доступа будет передаваться без шифрования. Используйте Tailscale или https.';

  @override
  String get connectAnyway => 'Всё равно подключить';

  @override
  String get pairInvalidCode =>
      'Неверный или просроченный код. Получите новый: docker compose exec hub python -m obscura pair';

  @override
  String get pairTooMany =>
      'Слишком много попыток. Подождите 10 минут и попробуйте снова.';

  @override
  String get hubUnreachable => 'Хаб недоступен';

  @override
  String get hubUnreachableHint =>
      'Проверьте, что хаб запущен, а телефон в той же сети или в Tailscale.';

  @override
  String get retry => 'Повторить';

  @override
  String get error => 'Ошибка';

  @override
  String get loading => 'Загрузка…';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get save => 'Сохранить';

  @override
  String get saved => 'Сохранено';

  @override
  String get saveChanges => 'Сохранить изменения';

  @override
  String get discard => 'Не сохранять';

  @override
  String get close => 'Закрыть';

  @override
  String get copy => 'Копировать';

  @override
  String get copied => 'Скопировано';

  @override
  String get optional => 'Необязательно';

  @override
  String get generate => 'Сгенерировать';

  @override
  String get rename => 'Переименовать';

  @override
  String get unsavedTitle => 'Не сохранять изменения?';

  @override
  String get unsavedBody => 'Есть несохранённые изменения.';

  @override
  String get fieldRequired => 'Обязательное поле';

  @override
  String get yesterday => 'Вчера';

  @override
  String get tabHome => 'Главная';

  @override
  String get tabCameras => 'Камеры';

  @override
  String get tabEvents => 'События';

  @override
  String get tabSettings => 'Настройки';

  @override
  String get tabNotifications => 'Уведомления';

  @override
  String get goodMorning => 'Доброе утро';

  @override
  String get goodAfternoon => 'Добрый день';

  @override
  String get goodEvening => 'Добрый вечер';

  @override
  String get goodNight => 'Доброй ночи';

  @override
  String get allSecure => 'Все системы в норме';

  @override
  String get attentionNeeded => 'Требуется внимание';

  @override
  String get noCamerasYet => 'Камер пока нет';

  @override
  String get noCamerasBody =>
      'Добавьте первую камеру: Tapo, Hikvision, Dahua, Reolink или любую RTSP-камеру.';

  @override
  String get addFirstCamera => 'Добавьте первую камеру';

  @override
  String get statTotal => 'Всего камер';

  @override
  String get statOnline => 'В сети';

  @override
  String get statOffline => 'Не в сети';

  @override
  String get statAlerts24h => 'Тревоги (24 ч)';

  @override
  String get statPeople24h => 'Люди (24 ч)';

  @override
  String get personModelMissing =>
      'Распознавание людей на хабе недоступно (модель не загружена). Детекция движения работает.';

  @override
  String get liveOverview => 'Обзор';

  @override
  String get allCameras => 'Все камеры';

  @override
  String get recentAlerts => 'Последние тревоги';

  @override
  String get seeAll => 'Все';

  @override
  String get noEventsYet => 'Событий пока нет';

  @override
  String get noEventsBody => 'Здесь появятся движение и люди в ваших зонах.';

  @override
  String get online => 'В сети';

  @override
  String get offline => 'Не в сети';

  @override
  String get live => 'Эфир';

  @override
  String get connecting => 'Подключение…';

  @override
  String get uploaded => 'Скопировано в облако';

  @override
  String get notUploaded => 'Не скопировано';

  @override
  String get kindPerson => 'Обнаружен человек';

  @override
  String get kindMotion => 'Движение';

  @override
  String get kindManual => 'Запись вручную';

  @override
  String get camerasSubtitle => 'Управление и наблюдение';

  @override
  String get addCamera => 'Добавить камеру';

  @override
  String get filterAllPlain => 'Все';

  @override
  String get privacyOn => 'Режим приватности';

  @override
  String get privacyMode => 'Приватность';

  @override
  String get privacyEnable => 'Включить приватность';

  @override
  String get privacyDisable => 'Включить камеру';

  @override
  String get privacyBody =>
      'Хаб остановит просмотр, детекцию и запись с этой камеры, пока вы её снова не включите.';

  @override
  String get deleteCameraBody =>
      'Настройки и зоны будут удалены. Записанные ролики останутся до автоматической очистки.';

  @override
  String get moreActions => 'Другие действия';

  @override
  String get triggers => 'Триггеры';

  @override
  String get triggerZones => 'Зоны триггеров';

  @override
  String get connectionSettings => 'Логин, пароль, IP';

  @override
  String get findOnNetwork => 'Найти камеры в сети';

  @override
  String get scan => 'Искать';

  @override
  String get nothingFound =>
      'Ничего не найдено. Введите IP вручную — не все камеры отвечают на поиск.';

  @override
  String get alreadyAdded => 'Уже добавлена';

  @override
  String get cameraBrand => 'Бренд';

  @override
  String get tapoHint =>
      'Для RTSP в Tapo нужен «аккаунт камеры». Нажмите — инструкция на минуту.';

  @override
  String get cameraName => 'Название';

  @override
  String get cameraNameHint => 'Входная дверь…';

  @override
  String get cameraIp => 'IP камеры';

  @override
  String get hostInvalid => 'Введите IP или имя хоста';

  @override
  String get port => 'Порт';

  @override
  String get portInvalid => '1–65535';

  @override
  String get cameraUser => 'Логин аккаунта камеры';

  @override
  String get cameraPassword => 'Пароль аккаунта камеры';

  @override
  String get passwordKeep => 'Оставьте пустым, чтобы не менять';

  @override
  String get showPassword => 'Показать пароль';

  @override
  String get hidePassword => 'Скрыть пароль';

  @override
  String get advanced => 'Расширенные';

  @override
  String get advancedHint => 'Свои пути RTSP-потоков';

  @override
  String get mainStreamPath => 'Путь основного потока (запись)';

  @override
  String get subStreamPath => 'Путь доп. потока (анализ)';

  @override
  String get subStreamHint => 'Низкое разрешение; пусто = основной поток';

  @override
  String get pathInvalid => 'Должен начинаться с / и не содержать пробелов';

  @override
  String get unmute => 'Звук';

  @override
  String get mute => 'Без звука';

  @override
  String get capture => 'Снимок';

  @override
  String get record => 'Запись';

  @override
  String get snapshotSaved => 'Снимок сохранён';

  @override
  String get recordingStarted => 'Запись 30 секунд…';

  @override
  String get stopRecording => 'Стоп';

  @override
  String get quickActions => 'Быстрые действия';

  @override
  String get timeline => 'Хронология';

  @override
  String get fullscreen => 'Во весь экран';

  @override
  String get notificationsTriggers => 'Уведомления и триггеры';

  @override
  String get schedule => 'Расписание';

  @override
  String get motionDetection => 'Детекция движения';

  @override
  String get motionDetectionHint => 'Любое движение в зонах движения';

  @override
  String get personDetection => 'Распознавание людей';

  @override
  String get personDetectionHint => 'ИИ находит людей в зонах людей';

  @override
  String get alertSensitivity => 'Чувствительность';

  @override
  String get sensLow => 'Низкая';

  @override
  String get sensMedium => 'Средняя';

  @override
  String get sensHigh => 'Высокая';

  @override
  String get sensitivityHint =>
      'Высокая ловит мелкие движения, но может реагировать на дождь, насекомых и смену освещения.';

  @override
  String get zonesNone => 'Зон нет: отслеживается весь кадр';

  @override
  String get editZones => 'Изменить';

  @override
  String get notifyPerson => 'Люди';

  @override
  String get notifyPersonHint => 'Громкий тревожный сигнал';

  @override
  String get notifyMotion => 'Движение';

  @override
  String get notifyMotionHint => 'Мягкий сигнал';

  @override
  String get soundPreview => 'Проверка звуков';

  @override
  String get soundPreviewHint =>
      'У каждого типа тревоги свой звук — понятно, что случилось, не глядя на экран.';

  @override
  String get soundTest => 'Проверка звука';

  @override
  String get alwaysOn => 'Всегда';

  @override
  String get alwaysOnHint => 'Триггеры работают круглосуточно';

  @override
  String get onSchedule => 'По расписанию';

  @override
  String get onScheduleHint => 'Только в выбранное время, например ночью';

  @override
  String get from => 'С';

  @override
  String get to => 'до';

  @override
  String get dayMon => 'Пн';

  @override
  String get dayTue => 'Вт';

  @override
  String get dayWed => 'Ср';

  @override
  String get dayThu => 'Чт';

  @override
  String get dayFri => 'Пт';

  @override
  String get daySat => 'Сб';

  @override
  String get daySun => 'Вс';

  @override
  String get zone => 'Зона';

  @override
  String get zoneName => 'Название зоны';

  @override
  String get zonesHint =>
      'Добавьте зону и перетащите её углы на нужную область. Выберите, реагирует ли она на движение, людей или на всё. Для людей учитывается положение ног.';

  @override
  String get legendBoth => 'Движение + люди';

  @override
  String get legendMotion => 'Только движение';

  @override
  String get legendPerson => 'Только люди';

  @override
  String get addZone => 'Добавить зону';

  @override
  String get addPoints => 'Добавить точки';

  @override
  String get doneAddingPoints => 'Готово';

  @override
  String get undoPoint => 'Удалить последнюю точку';

  @override
  String get deleteZoneBody => 'Зона перестанет вызывать тревоги.';

  @override
  String get zoneInactive => 'Зона выключена: выберите движение и/или людей.';

  @override
  String get deleteEventTitle => 'Удалить событие?';

  @override
  String get deleteEventBody =>
      'Ролик и превью удалятся с хаба. Копии в облаке останутся.';

  @override
  String get clipProcessing => 'Сохранение ролика…';

  @override
  String get clipUnavailable => 'Ролик недоступен';

  @override
  String get type => 'Тип';

  @override
  String get camera => 'Камера';

  @override
  String get time => 'Время';

  @override
  String get duration => 'Длительность';

  @override
  String get zones => 'Зоны';

  @override
  String get cloudCopy => 'Копия в облаке';

  @override
  String get saveOrShare => 'Сохранить или отправить';

  @override
  String get hubSection => 'Хаб';

  @override
  String get appSection => 'Приложение';

  @override
  String get pushActive => 'Push включены';

  @override
  String get pushInactive =>
      'Push выключены — тревоги только при открытом приложении';

  @override
  String get storage => 'Хранилище';

  @override
  String get storageSubtitle => 'Хранение и копии в облаке';

  @override
  String get devices => 'Устройства';

  @override
  String get devicesSubtitle => 'Телефоны с доступом, добавить ещё';

  @override
  String get appLock => 'Блокировка приложения';

  @override
  String get appLockHint => 'Отпечаток, лицо или PIN устройства';

  @override
  String get lockUnsupported =>
      'Сначала настройте блокировку экрана на телефоне.';

  @override
  String get guides => 'Инструкции';

  @override
  String get guidesSubtitle => 'Сервер, камеры, удалённый доступ, облако';

  @override
  String get about => 'О приложении и лицензии';

  @override
  String get aboutSubtitle => 'Открытый код, лицензия MIT';

  @override
  String get disconnect => 'Отключиться от хаба';

  @override
  String get disconnectTitle => 'Отключиться?';

  @override
  String get disconnectBody =>
      'Телефон забудет хаб. Для повторного подключения понадобится новый код.';

  @override
  String get deviceRevoked => 'Этот телефон удалён из хаба.';

  @override
  String get locked => 'Obscura заблокирован';

  @override
  String get unlock => 'Разблокировать';

  @override
  String get unlockReason => 'Разблокируйте Obscura';

  @override
  String get pairAnother => 'Подключить ещё телефон';

  @override
  String get pairAnotherHint =>
      'Отсканируйте в Obscura на другом телефоне (Подключение → Сканировать QR-код).';

  @override
  String get qrCode => 'QR-код сопряжения';

  @override
  String get codeExpires => 'Одноразовый, действует 10 минут';

  @override
  String get thisDevice => 'этот телефон';

  @override
  String get revoke => 'Отозвать';

  @override
  String get revokeBody => 'Телефон сразу потеряет доступ.';

  @override
  String get devicesHint =>
      'Потеряли телефон? Отзовите его здесь с другого телефона.';

  @override
  String get onHub => 'На хабе';

  @override
  String get keepDays => 'Хранить дней';

  @override
  String get maxGb => 'Макс. ГБ';

  @override
  String get retentionHint =>
      'Старые ролики удаляются, когда достигнут любой из лимитов.';

  @override
  String get retentionInvalid => 'Дни: 1–365, объём: не меньше 0,5 ГБ';

  @override
  String get howTo => 'Как настроить';

  @override
  String get cloudEnabled => 'Копировать ролики в облако';

  @override
  String get cloudEnabledHint => 'Каждый ролик выгружается сразу после записи';

  @override
  String get rcloneCustom => 'rclone';

  @override
  String get s3Provider => 'Провайдер';

  @override
  String get s3Endpoint => 'Endpoint';

  @override
  String get s3Region => 'Регион';

  @override
  String get s3AccessKey => 'Access key ID';

  @override
  String get s3SecretKey => 'Secret access key';

  @override
  String get webdavUrl => 'Адрес WebDAV';

  @override
  String get webdavVendor => 'Тип сервера';

  @override
  String get webdavUser => 'Логин';

  @override
  String get webdavPassword => 'Пароль (пароль приложения)';

  @override
  String get secretWriteOnly =>
      'Хранится только на хабе и больше не показывается';

  @override
  String get rcloneRemote => 'Имя подключения rclone';

  @override
  String get rcloneRemoteHint =>
      'Создаётся на хабе командой: docker compose exec -it hub rclone --config /data/rclone.conf config';

  @override
  String get cloudFolder => 'Папка (для S3: бакет/папка)';

  @override
  String get testConnection => 'Проверить подключение';

  @override
  String get storageTestOk => 'Подключение работает';

  @override
  String get storageTestFailed => 'Ошибка подключения';

  @override
  String get pushTitle => 'Push-уведомления';

  @override
  String get pushActiveHint => 'Тревоги приходят даже при закрытом приложении';

  @override
  String get pushOffHint => 'Нужно приложение ntfy как посредник';

  @override
  String get pushError =>
      'Ошибка регистрации — откройте ntfy и попробуйте снова';

  @override
  String get pushExplain =>
      'Используется UnifiedPush (без сервисов Google). Содержимое тревог зашифровано между хабом и этим телефоном.';

  @override
  String get noDistributorTitle => 'Сначала установите ntfy';

  @override
  String get noDistributorBody =>
      'Для фоновых тревог нужен посредник UnifiedPush. Установите бесплатное приложение ntfy из Google Play или F-Droid, откройте его один раз и снова включите push.';

  @override
  String get openGuide => 'Открыть инструкцию';

  @override
  String get ntfyTitle => 'Топик ntfy (iPhone)';

  @override
  String get ntfyExplain =>
      'Для iPhone или как запасной канал: хаб дублирует тревоги в топик ntfy, на который вы подписываетесь в приложении ntfy. Название камеры и тип события передаются открытым текстом.';

  @override
  String get ntfyEnable => 'Отправлять тревоги в топик ntfy';

  @override
  String get ntfyServer => 'Сервер ntfy';

  @override
  String get ntfyTopic => 'Топик';

  @override
  String get ntfyTopicHint =>
      'Любой, кто знает имя топика, может его читать — оставьте длинное случайное имя.';

  @override
  String get ntfyToken => 'Токен доступа';

  @override
  String get voiceAndSiren => 'Голос и сирена';

  @override
  String get holdToTalk => 'Удерживайте, чтобы говорить';

  @override
  String get talking => 'Говорите… отпустите, чтобы отправить';

  @override
  String get talkSending => 'Отправка на камеру…';

  @override
  String get talkSent => 'Воспроизведено в динамике камеры';

  @override
  String get talkTooShort => 'Держите кнопку, пока говорите';

  @override
  String get micDenied =>
      'Нет доступа к микрофону. Разрешите его в настройках телефона.';

  @override
  String get siren => 'Сирена';

  @override
  String get sirenStop => 'Выключить сирену';

  @override
  String get sirenConfirmTitle => 'Включить сирену?';

  @override
  String get sirenConfirmBody =>
      'Камера включит громкую тревогу. Она выключится сама через заданное время.';

  @override
  String get sirenTurnOn => 'Включить';

  @override
  String get sirenOff => 'Сирена выключена';

  @override
  String get talkSetupTitle => 'Разговор и сирена не настроены';

  @override
  String get talkSetupTapo =>
      'Укажите пароль аккаунта TP-Link в настройках подключения камеры.';

  @override
  String get talkSetupOther =>
      'Включите «У камеры есть динамик» в настройках подключения камеры.';

  @override
  String get setUp => 'Настроить';

  @override
  String get cloudPassword => 'Пароль аккаунта TP-Link';

  @override
  String get cloudPasswordHint =>
      'Для разговора и сирены: пароль, с которым вы входите в приложение Tapo. Логин не нужен — камера всегда использует «admin». Хаб хранит только хэш пароля.';

  @override
  String get cloudPasswordRemove => 'Удалить пароль аккаунта';

  @override
  String get twoWay => 'У камеры есть динамик';

  @override
  String get twoWayHint =>
      'Включает разговор и сирену через динамик (двусторонний звук RTSP/ONVIF).';

  @override
  String get controlOk => 'Пароль аккаунта TP-Link принят';

  @override
  String get sirenOnPerson => 'Сирена при обнаружении человека';

  @override
  String get sirenOnPersonHint =>
      'Отпугивает непрошеных гостей. Работает через тревогу камеры (Tapo) или её динамик.';

  @override
  String get sirenDuration => 'Длительность сирены';

  @override
  String get sirenUnavailable =>
      'Нужен пароль аккаунта TP-Link (Tapo) или «У камеры есть динамик» в настройках подключения.';

  @override
  String controlFailed(String message) {
    return 'Разговор и сирена недоступны: $message';
  }

  @override
  String sirenOn(int seconds) {
    return 'Сирена включена на $seconds с';
  }

  @override
  String camerasOnline(int online, int total) {
    return '$online из $total камер в сети';
  }

  @override
  String deleteCameraTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String deleteZoneTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String revokeTitle(String name) {
    return 'Отозвать «$name»?';
  }

  @override
  String diskFree(String size) {
    return 'свободно $size';
  }

  @override
  String storedClips(String size) {
    return 'ролики $size';
  }

  @override
  String lastSeen(String time) {
    return 'Был в сети: $time';
  }

  @override
  String filterAll(int count) {
    return 'Все ($count)';
  }

  @override
  String filterOnline(int count) {
    return 'В сети ($count)';
  }

  @override
  String filterOffline(int count) {
    return 'Не в сети ($count)';
  }

  @override
  String seconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count секунды',
      many: '$count секунд',
      few: '$count секунды',
      one: '$count секунда',
    );
    return '$_temp0';
  }

  @override
  String zonesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count зоны',
      many: '$count зон',
      few: '$count зоны',
      one: '$count зона',
    );
    return '$_temp0';
  }

  @override
  String storageUsage(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ролика',
      many: '$count роликов',
      few: '$count ролика',
      one: '$count ролик',
    );
    return '$_temp0, $size';
  }

  @override
  String get change => 'Изменить';

  @override
  String get deleteAllEvents => 'Удалить все события';

  @override
  String get deleteAllEventsBody =>
      'Все ролики и превью со всех камер удалятся с хаба. Отменить нельзя.';

  @override
  String get deleteCameraEventsBody =>
      'Все ролики и превью этой камеры удалятся с хаба. Отменить нельзя.';

  @override
  String get showOverlay => 'Показать зоны и движение';

  @override
  String get hideOverlay => 'Скрыть зоны и движение';

  @override
  String get download => 'Скачать';

  @override
  String get savedToGallery => 'Сохранено в галерею (альбом Obscura)';

  @override
  String get recordLow => 'Экономная запись (720p)';

  @override
  String get recordLowHint =>
      'Ролики втрое меньше, хаб тянет с камеры один поток вместо двух. Живое видео остаётся в полном качестве.';

  @override
  String get remoteHubManual =>
      'Хаб работает на сервере, поэтому искать камеры в домашней сети он не может. Введите адрес камеры, по которому её видит сервер (например, адрес роутера в туннеле).';
}
