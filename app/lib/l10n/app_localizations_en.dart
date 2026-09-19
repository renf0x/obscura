// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tagline => 'Observe · Detect · Prevent';

  @override
  String get connectTitle => 'Connect to your hub';

  @override
  String get connectSubtitle =>
      'Enter the hub address and the pairing code from its logs.';

  @override
  String get hubAddress => 'Hub address';

  @override
  String get hubAddressInvalid => 'Enter an address like 192.168.1.10:7878';

  @override
  String get pairingCode => 'Pairing code';

  @override
  String get pairingCodeInvalid => 'The code has 10 characters';

  @override
  String get deviceName => 'Name of this phone';

  @override
  String get deviceNameInvalid => 'Enter 1–40 characters';

  @override
  String get connect => 'Connect';

  @override
  String get scanQr => 'Scan QR Code';

  @override
  String get qrInvalid => 'This QR code is not an Obscura pairing code.';

  @override
  String get noHubYet => 'No hub yet?';

  @override
  String get noHubYetBody =>
      'Step-by-step setup: server, camera, remote access, cloud.';

  @override
  String get insecureTitle => 'Unencrypted connection';

  @override
  String get insecureBody =>
      'This is a public address over plain http: your access token would travel unencrypted. Use Tailscale or https instead.';

  @override
  String get connectAnyway => 'Connect Anyway';

  @override
  String get pairInvalidCode =>
      'Invalid or expired code. Get a new one: docker compose exec hub python -m obscura pair';

  @override
  String get pairTooMany => 'Too many attempts. Wait 10 minutes and try again.';

  @override
  String get hubUnreachable => 'Hub unreachable';

  @override
  String get hubUnreachableHint =>
      'Check that the hub is running and that your phone is on the same network or on Tailscale.';

  @override
  String get retry => 'Retry';

  @override
  String get error => 'Error';

  @override
  String get loading => 'Loading…';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get discard => 'Discard';

  @override
  String get close => 'Close';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get optional => 'Optional';

  @override
  String get generate => 'Generate';

  @override
  String get rename => 'Rename';

  @override
  String get unsavedTitle => 'Discard changes?';

  @override
  String get unsavedBody => 'You have unsaved changes.';

  @override
  String get fieldRequired => 'Required';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get tabHome => 'Home';

  @override
  String get tabCameras => 'Cameras';

  @override
  String get tabEvents => 'Events';

  @override
  String get tabSettings => 'Settings';

  @override
  String get tabNotifications => 'Notifications';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get goodNight => 'Good night';

  @override
  String get allSecure => 'All Systems Secure';

  @override
  String get attentionNeeded => 'Attention Needed';

  @override
  String get noCamerasYet => 'No cameras yet';

  @override
  String get noCamerasBody =>
      'Add your first camera: Tapo, Hikvision, Dahua, Reolink or any RTSP camera.';

  @override
  String get addFirstCamera => 'Add your first camera';

  @override
  String get statTotal => 'Total cameras';

  @override
  String get statOnline => 'Online';

  @override
  String get statOffline => 'Offline';

  @override
  String get statAlerts24h => 'Alerts (24h)';

  @override
  String get statPeople24h => 'People (24h)';

  @override
  String get personModelMissing =>
      'Person detection is unavailable on the hub (model not loaded). Motion detection still works.';

  @override
  String get liveOverview => 'Live overview';

  @override
  String get allCameras => 'All Cameras';

  @override
  String get recentAlerts => 'Recent alerts';

  @override
  String get seeAll => 'See All';

  @override
  String get noEventsYet => 'No events yet';

  @override
  String get noEventsBody =>
      'Motion and people inside your zones will appear here.';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get live => 'Live';

  @override
  String get connecting => 'Connecting…';

  @override
  String get uploaded => 'Copied to cloud';

  @override
  String get notUploaded => 'Not copied';

  @override
  String get kindPerson => 'Person detected';

  @override
  String get kindMotion => 'Motion detected';

  @override
  String get kindManual => 'Manual recording';

  @override
  String get camerasSubtitle => 'Manage and monitor your devices';

  @override
  String get addCamera => 'Add Camera';

  @override
  String get filterAllPlain => 'All';

  @override
  String get privacyOn => 'Privacy mode';

  @override
  String get privacyMode => 'Privacy Mode';

  @override
  String get privacyEnable => 'Turn On Privacy Mode';

  @override
  String get privacyDisable => 'Resume Camera';

  @override
  String get privacyBody =>
      'The hub stops live view, detection and recording for this camera until you resume it.';

  @override
  String get deleteCameraBody =>
      'Its settings and zones will be removed. Recorded clips stay until retention deletes them.';

  @override
  String get moreActions => 'More actions';

  @override
  String get triggers => 'Triggers';

  @override
  String get triggerZones => 'Trigger Zones';

  @override
  String get connectionSettings => 'Login, password, IP';

  @override
  String get findOnNetwork => 'Find cameras on the network';

  @override
  String get scan => 'Scan';

  @override
  String get nothingFound =>
      'Nothing found. Enter the IP manually — some cameras don\'t announce themselves.';

  @override
  String get alreadyAdded => 'Already added';

  @override
  String get cameraBrand => 'Brand';

  @override
  String get tapoHint =>
      'Tapo needs a “camera account” for RTSP. Tap for the 1-minute guide.';

  @override
  String get cameraName => 'Name';

  @override
  String get cameraNameHint => 'Front Door…';

  @override
  String get cameraIp => 'Camera IP';

  @override
  String get hostInvalid => 'Enter an IP or host name';

  @override
  String get port => 'Port';

  @override
  String get portInvalid => '1–65535';

  @override
  String get cameraUser => 'Camera account user';

  @override
  String get cameraPassword => 'Camera account password';

  @override
  String get passwordKeep => 'Leave empty to keep the current one';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get advanced => 'Advanced';

  @override
  String get advancedHint => 'Custom RTSP stream paths';

  @override
  String get mainStreamPath => 'Main stream path (recording)';

  @override
  String get subStreamPath => 'Sub stream path (analysis)';

  @override
  String get subStreamHint => 'Low resolution; empty = use main stream';

  @override
  String get pathInvalid => 'Must start with / and contain no spaces';

  @override
  String get unmute => 'Sound';

  @override
  String get mute => 'Mute';

  @override
  String get capture => 'Capture';

  @override
  String get record => 'Record';

  @override
  String get snapshotSaved => 'Snapshot saved';

  @override
  String get recordingStarted => 'Recording 30 seconds…';

  @override
  String get stopRecording => 'Stop';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get timeline => 'Timeline';

  @override
  String get fullscreen => 'Full screen';

  @override
  String get notificationsTriggers => 'Notifications & Triggers';

  @override
  String get schedule => 'Schedule';

  @override
  String get motionDetection => 'Motion Detection';

  @override
  String get motionDetectionHint => 'Any movement inside motion zones';

  @override
  String get personDetection => 'Person Detection';

  @override
  String get personDetectionHint => 'AI detects people inside person zones';

  @override
  String get alertSensitivity => 'Alert Sensitivity';

  @override
  String get sensLow => 'Low';

  @override
  String get sensMedium => 'Medium';

  @override
  String get sensHigh => 'High';

  @override
  String get sensitivityHint =>
      'Higher catches smaller movements but may react to rain, insects or light changes.';

  @override
  String get zonesNone => 'No zones: the whole frame is watched';

  @override
  String get editZones => 'Edit';

  @override
  String get notifyPerson => 'People';

  @override
  String get notifyPersonHint => 'Loud alarm sound';

  @override
  String get notifyMotion => 'Motion';

  @override
  String get notifyMotionHint => 'Soft chime';

  @override
  String get soundPreview => 'Sound check';

  @override
  String get soundPreviewHint =>
      'Each alert type has its own sound so you know what happened without looking.';

  @override
  String get soundTest => 'Sound test';

  @override
  String get alwaysOn => 'Always On';

  @override
  String get alwaysOnHint => 'Triggers work 24/7';

  @override
  String get onSchedule => 'On Schedule';

  @override
  String get onScheduleHint => 'Only at chosen times, e.g. at night';

  @override
  String get from => 'From';

  @override
  String get to => 'to';

  @override
  String get dayMon => 'Mon';

  @override
  String get dayTue => 'Tue';

  @override
  String get dayWed => 'Wed';

  @override
  String get dayThu => 'Thu';

  @override
  String get dayFri => 'Fri';

  @override
  String get daySat => 'Sat';

  @override
  String get daySun => 'Sun';

  @override
  String get zone => 'Zone';

  @override
  String get zoneName => 'Zone name';

  @override
  String get zonesHint =>
      'Add a zone, then drag its corners over the area to watch. Choose whether it reacts to motion, people or both. Zones for people check where the feet are.';

  @override
  String get legendBoth => 'Motion + people';

  @override
  String get legendMotion => 'Motion only';

  @override
  String get legendPerson => 'People only';

  @override
  String get addZone => 'Add Zone';

  @override
  String get addPoints => 'Add Points';

  @override
  String get doneAddingPoints => 'Done';

  @override
  String get undoPoint => 'Remove last point';

  @override
  String get deleteZoneBody => 'The zone will stop triggering alerts.';

  @override
  String get zoneInactive => 'Zone is off: pick motion and/or people.';

  @override
  String get deleteEventTitle => 'Delete event?';

  @override
  String get deleteEventBody =>
      'The clip and thumbnail are removed from the hub. Cloud copies stay.';

  @override
  String get clipProcessing => 'Saving clip…';

  @override
  String get clipUnavailable => 'Clip unavailable';

  @override
  String get type => 'Type';

  @override
  String get camera => 'Camera';

  @override
  String get time => 'Time';

  @override
  String get duration => 'Duration';

  @override
  String get zones => 'Zones';

  @override
  String get cloudCopy => 'Cloud copy';

  @override
  String get saveOrShare => 'Save or Share Clip';

  @override
  String get hubSection => 'Hub';

  @override
  String get appSection => 'App';

  @override
  String get pushActive => 'Push on';

  @override
  String get pushInactive => 'Push off — alerts only while the app is open';

  @override
  String get storage => 'Storage';

  @override
  String get storageSubtitle => 'Retention and cloud copies';

  @override
  String get devices => 'Paired Devices';

  @override
  String get devicesSubtitle => 'Phones with access, pair another';

  @override
  String get appLock => 'App Lock';

  @override
  String get appLockHint => 'Fingerprint, face or device PIN';

  @override
  String get lockUnsupported => 'Set up a screen lock on this phone first.';

  @override
  String get guides => 'Setup Guides';

  @override
  String get guidesSubtitle => 'Server, cameras, remote access, cloud';

  @override
  String get about => 'About & Licenses';

  @override
  String get aboutSubtitle => 'Open source, MIT License';

  @override
  String get disconnect => 'Disconnect From Hub';

  @override
  String get disconnectTitle => 'Disconnect?';

  @override
  String get disconnectBody =>
      'This phone forgets the hub. You’ll need a new pairing code to connect again.';

  @override
  String get deviceRevoked => 'This phone was removed from the hub.';

  @override
  String get locked => 'Obscura is locked';

  @override
  String get unlock => 'Unlock';

  @override
  String get unlockReason => 'Unlock Obscura';

  @override
  String get pairAnother => 'Pair Another Phone';

  @override
  String get pairAnotherHint =>
      'Scan with Obscura on the other phone (Connect → Scan QR Code).';

  @override
  String get qrCode => 'Pairing QR code';

  @override
  String get codeExpires => 'Single use, valid for 10 minutes';

  @override
  String get thisDevice => 'this phone';

  @override
  String get revoke => 'Revoke';

  @override
  String get revokeBody => 'That phone loses access immediately.';

  @override
  String get devicesHint =>
      'Lost a phone? Revoke it here from another paired phone.';

  @override
  String get onHub => 'On the hub';

  @override
  String get keepDays => 'Keep days';

  @override
  String get maxGb => 'Max GB';

  @override
  String get retentionHint =>
      'Oldest clips are deleted when either limit is reached.';

  @override
  String get retentionInvalid => 'Days: 1–365, size: at least 0.5 GB';

  @override
  String get howTo => 'How To';

  @override
  String get cloudEnabled => 'Copy clips to the cloud';

  @override
  String get cloudEnabledHint => 'Every clip is uploaded right after recording';

  @override
  String get rcloneCustom => 'rclone';

  @override
  String get s3Provider => 'Provider';

  @override
  String get s3Endpoint => 'Endpoint';

  @override
  String get s3Region => 'Region';

  @override
  String get s3AccessKey => 'Access key ID';

  @override
  String get s3SecretKey => 'Secret access key';

  @override
  String get webdavUrl => 'WebDAV URL';

  @override
  String get webdavVendor => 'Server type';

  @override
  String get webdavUser => 'User';

  @override
  String get webdavPassword => 'Password (app password)';

  @override
  String get secretWriteOnly => 'Stored on the hub only; never shown again';

  @override
  String get rcloneRemote => 'rclone remote name';

  @override
  String get rcloneRemoteHint =>
      'Created on the hub with: docker compose exec -it hub rclone --config /data/rclone.conf config';

  @override
  String get cloudFolder => 'Folder (for S3: bucket/folder)';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get storageTestOk => 'Connection works';

  @override
  String get storageTestFailed => 'Connection failed';

  @override
  String get pushTitle => 'Push notifications';

  @override
  String get pushActiveHint => 'Alerts arrive even when the app is closed';

  @override
  String get pushOffHint => 'Needs the ntfy app as a push distributor';

  @override
  String get pushError => 'Registration failed — open ntfy and try again';

  @override
  String get pushExplain =>
      'Uses UnifiedPush (no Google services). Alert contents are end-to-end encrypted between the hub and this phone.';

  @override
  String get noDistributorTitle => 'Install ntfy first';

  @override
  String get noDistributorBody =>
      'Background alerts need a UnifiedPush distributor. Install the free ntfy app from Google Play or F-Droid, open it once, then turn push on again.';

  @override
  String get openGuide => 'Open Guide';

  @override
  String get ntfyTitle => 'ntfy topic (iPhone)';

  @override
  String get ntfyExplain =>
      'For iPhone or as a backup: the hub also posts alerts to an ntfy topic you subscribe to in the ntfy app. Camera name and event type are sent in plain text.';

  @override
  String get ntfyEnable => 'Send alerts to an ntfy topic';

  @override
  String get ntfyServer => 'ntfy server';

  @override
  String get ntfyTopic => 'Topic';

  @override
  String get ntfyTopicHint =>
      'Anyone who knows the topic can read it — keep it long and random.';

  @override
  String get ntfyToken => 'Access token';

  @override
  String get voiceAndSiren => 'Voice & siren';

  @override
  String get holdToTalk => 'Hold to talk';

  @override
  String get talking => 'Speak now… release to send';

  @override
  String get talkSending => 'Sending to the camera…';

  @override
  String get talkSent => 'Played through the camera speaker';

  @override
  String get talkTooShort => 'Keep holding the button while you speak';

  @override
  String get micDenied =>
      'No microphone access. Allow it in the phone settings.';

  @override
  String get siren => 'Siren';

  @override
  String get sirenStop => 'Stop Siren';

  @override
  String get sirenConfirmTitle => 'Turn on the siren?';

  @override
  String get sirenConfirmBody =>
      'The camera will sound a loud alarm. It switches off by itself after the set time.';

  @override
  String get sirenTurnOn => 'Turn On';

  @override
  String get sirenOff => 'Siren off';

  @override
  String get talkSetupTitle => 'Talk and siren are not set up';

  @override
  String get talkSetupTapo =>
      'Enter your TP-Link account password in the camera connection settings.';

  @override
  String get talkSetupOther =>
      'Turn on “Camera has a speaker” in the camera connection settings.';

  @override
  String get setUp => 'Set Up';

  @override
  String get cloudPassword => 'TP-Link account password';

  @override
  String get cloudPasswordHint =>
      'For talk and siren: the password you sign in to the Tapo app with. No login needed — the camera always uses “admin”. The hub keeps only the password\'s hash.';

  @override
  String get cloudPasswordRemove => 'Remove the account password';

  @override
  String get twoWay => 'Camera has a speaker';

  @override
  String get twoWayHint =>
      'Enables talk and a siren through the speaker (RTSP/ONVIF two-way audio).';

  @override
  String get controlOk => 'TP-Link account password accepted';

  @override
  String get sirenOnPerson => 'Siren when a person is detected';

  @override
  String get sirenOnPersonHint =>
      'Scares off intruders. Uses the camera\'s own alarm (Tapo) or its speaker.';

  @override
  String get sirenDuration => 'Siren duration';

  @override
  String get sirenUnavailable =>
      'Needs the TP-Link account password (Tapo) or “Camera has a speaker” in the connection settings.';

  @override
  String controlFailed(String message) {
    return 'Talk and siren unavailable: $message';
  }

  @override
  String sirenOn(int seconds) {
    return 'Siren on for $seconds s';
  }

  @override
  String camerasOnline(int online, int total) {
    return '$online of $total cameras online';
  }

  @override
  String deleteCameraTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String deleteZoneTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String revokeTitle(String name) {
    return 'Revoke $name?';
  }

  @override
  String diskFree(String size) {
    return '$size free';
  }

  @override
  String storedClips(String size) {
    return 'clips $size';
  }

  @override
  String lastSeen(String time) {
    return 'Last seen $time';
  }

  @override
  String filterAll(int count) {
    return 'All ($count)';
  }

  @override
  String filterOnline(int count) {
    return 'Online ($count)';
  }

  @override
  String filterOffline(int count) {
    return 'Offline ($count)';
  }

  @override
  String seconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String zonesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zones',
      one: '1 zone',
    );
    return '$_temp0';
  }

  @override
  String storageUsage(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips',
      one: '1 clip',
    );
    return '$_temp0, $size';
  }

  @override
  String get change => 'Change';

  @override
  String get deleteAllEvents => 'Delete all events';

  @override
  String get deleteAllEventsBody =>
      'Every clip and thumbnail from all cameras is removed from the hub. This can\'t be undone.';

  @override
  String get deleteCameraEventsBody =>
      'Every clip and thumbnail from this camera is removed from the hub. This can\'t be undone.';

  @override
  String get showOverlay => 'Show zones and motion';

  @override
  String get hideOverlay => 'Hide zones and motion';

  @override
  String get download => 'Download';

  @override
  String get savedToGallery => 'Saved to gallery (Obscura album)';

  @override
  String get recordLow => 'Compact recording (720p)';

  @override
  String get recordLowHint =>
      'Clips are about 3x smaller and the hub pulls one stream from the camera instead of two. Live view stays full quality.';

  @override
  String get remoteHubManual =>
      'The hub runs on a remote server, so it can\'t search your home network. Enter the address the server reaches the camera at (e.g. your router\'s tunnel address).';
}
