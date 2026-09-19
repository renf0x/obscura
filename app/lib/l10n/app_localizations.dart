import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Observe · Detect · Prevent'**
  String get tagline;

  /// No description provided for @connectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to your hub'**
  String get connectTitle;

  /// No description provided for @connectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the hub address and the pairing code from its logs.'**
  String get connectSubtitle;

  /// No description provided for @hubAddress.
  ///
  /// In en, this message translates to:
  /// **'Hub address'**
  String get hubAddress;

  /// No description provided for @hubAddressInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an address like 192.168.1.10:7878'**
  String get hubAddressInvalid;

  /// No description provided for @pairingCode.
  ///
  /// In en, this message translates to:
  /// **'Pairing code'**
  String get pairingCode;

  /// No description provided for @pairingCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The code has 10 characters'**
  String get pairingCodeInvalid;

  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Name of this phone'**
  String get deviceName;

  /// No description provided for @deviceNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter 1–40 characters'**
  String get deviceNameInvalid;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQr;

  /// No description provided for @qrInvalid.
  ///
  /// In en, this message translates to:
  /// **'This QR code is not an Obscura pairing code.'**
  String get qrInvalid;

  /// No description provided for @noHubYet.
  ///
  /// In en, this message translates to:
  /// **'No hub yet?'**
  String get noHubYet;

  /// No description provided for @noHubYetBody.
  ///
  /// In en, this message translates to:
  /// **'Step-by-step setup: server, camera, remote access, cloud.'**
  String get noHubYetBody;

  /// No description provided for @insecureTitle.
  ///
  /// In en, this message translates to:
  /// **'Unencrypted connection'**
  String get insecureTitle;

  /// No description provided for @insecureBody.
  ///
  /// In en, this message translates to:
  /// **'This is a public address over plain http: your access token would travel unencrypted. Use Tailscale or https instead.'**
  String get insecureBody;

  /// No description provided for @connectAnyway.
  ///
  /// In en, this message translates to:
  /// **'Connect Anyway'**
  String get connectAnyway;

  /// No description provided for @pairInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired code. Get a new one: docker compose exec hub python -m obscura pair'**
  String get pairInvalidCode;

  /// No description provided for @pairTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait 10 minutes and try again.'**
  String get pairTooMany;

  /// No description provided for @hubUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Hub unreachable'**
  String get hubUnreachable;

  /// No description provided for @hubUnreachableHint.
  ///
  /// In en, this message translates to:
  /// **'Check that the hub is running and that your phone is on the same network or on Tailscale.'**
  String get hubUnreachableHint;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @unsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get unsavedTitle;

  /// No description provided for @unsavedBody.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes.'**
  String get unsavedBody;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabCameras.
  ///
  /// In en, this message translates to:
  /// **'Cameras'**
  String get tabCameras;

  /// No description provided for @tabEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get tabEvents;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @tabNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get tabNotifications;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @goodNight.
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get goodNight;

  /// No description provided for @allSecure.
  ///
  /// In en, this message translates to:
  /// **'All Systems Secure'**
  String get allSecure;

  /// No description provided for @attentionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Attention Needed'**
  String get attentionNeeded;

  /// No description provided for @noCamerasYet.
  ///
  /// In en, this message translates to:
  /// **'No cameras yet'**
  String get noCamerasYet;

  /// No description provided for @noCamerasBody.
  ///
  /// In en, this message translates to:
  /// **'Add your first camera: Tapo, Hikvision, Dahua, Reolink or any RTSP camera.'**
  String get noCamerasBody;

  /// No description provided for @addFirstCamera.
  ///
  /// In en, this message translates to:
  /// **'Add your first camera'**
  String get addFirstCamera;

  /// No description provided for @statTotal.
  ///
  /// In en, this message translates to:
  /// **'Total cameras'**
  String get statTotal;

  /// No description provided for @statOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get statOnline;

  /// No description provided for @statOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get statOffline;

  /// No description provided for @statAlerts24h.
  ///
  /// In en, this message translates to:
  /// **'Alerts (24h)'**
  String get statAlerts24h;

  /// No description provided for @statPeople24h.
  ///
  /// In en, this message translates to:
  /// **'People (24h)'**
  String get statPeople24h;

  /// No description provided for @personModelMissing.
  ///
  /// In en, this message translates to:
  /// **'Person detection is unavailable on the hub (model not loaded). Motion detection still works.'**
  String get personModelMissing;

  /// No description provided for @liveOverview.
  ///
  /// In en, this message translates to:
  /// **'Live overview'**
  String get liveOverview;

  /// No description provided for @allCameras.
  ///
  /// In en, this message translates to:
  /// **'All Cameras'**
  String get allCameras;

  /// No description provided for @recentAlerts.
  ///
  /// In en, this message translates to:
  /// **'Recent alerts'**
  String get recentAlerts;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @noEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No events yet'**
  String get noEventsYet;

  /// No description provided for @noEventsBody.
  ///
  /// In en, this message translates to:
  /// **'Motion and people inside your zones will appear here.'**
  String get noEventsBody;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @uploaded.
  ///
  /// In en, this message translates to:
  /// **'Copied to cloud'**
  String get uploaded;

  /// No description provided for @notUploaded.
  ///
  /// In en, this message translates to:
  /// **'Not copied'**
  String get notUploaded;

  /// No description provided for @kindPerson.
  ///
  /// In en, this message translates to:
  /// **'Person detected'**
  String get kindPerson;

  /// No description provided for @kindMotion.
  ///
  /// In en, this message translates to:
  /// **'Motion detected'**
  String get kindMotion;

  /// No description provided for @kindManual.
  ///
  /// In en, this message translates to:
  /// **'Manual recording'**
  String get kindManual;

  /// No description provided for @camerasSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage and monitor your devices'**
  String get camerasSubtitle;

  /// No description provided for @addCamera.
  ///
  /// In en, this message translates to:
  /// **'Add Camera'**
  String get addCamera;

  /// No description provided for @filterAllPlain.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAllPlain;

  /// No description provided for @privacyOn.
  ///
  /// In en, this message translates to:
  /// **'Privacy mode'**
  String get privacyOn;

  /// No description provided for @privacyMode.
  ///
  /// In en, this message translates to:
  /// **'Privacy Mode'**
  String get privacyMode;

  /// No description provided for @privacyEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn On Privacy Mode'**
  String get privacyEnable;

  /// No description provided for @privacyDisable.
  ///
  /// In en, this message translates to:
  /// **'Resume Camera'**
  String get privacyDisable;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'The hub stops live view, detection and recording for this camera until you resume it.'**
  String get privacyBody;

  /// No description provided for @deleteCameraBody.
  ///
  /// In en, this message translates to:
  /// **'Its settings and zones will be removed. Recorded clips stay until retention deletes them.'**
  String get deleteCameraBody;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @triggers.
  ///
  /// In en, this message translates to:
  /// **'Triggers'**
  String get triggers;

  /// No description provided for @triggerZones.
  ///
  /// In en, this message translates to:
  /// **'Trigger Zones'**
  String get triggerZones;

  /// No description provided for @connectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Login, password, IP'**
  String get connectionSettings;

  /// No description provided for @findOnNetwork.
  ///
  /// In en, this message translates to:
  /// **'Find cameras on the network'**
  String get findOnNetwork;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found. Enter the IP manually — some cameras don\'t announce themselves.'**
  String get nothingFound;

  /// No description provided for @alreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Already added'**
  String get alreadyAdded;

  /// No description provided for @cameraBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get cameraBrand;

  /// No description provided for @tapoHint.
  ///
  /// In en, this message translates to:
  /// **'Tapo needs a “camera account” for RTSP. Tap for the 1-minute guide.'**
  String get tapoHint;

  /// No description provided for @cameraName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get cameraName;

  /// No description provided for @cameraNameHint.
  ///
  /// In en, this message translates to:
  /// **'Front Door…'**
  String get cameraNameHint;

  /// No description provided for @cameraIp.
  ///
  /// In en, this message translates to:
  /// **'Camera IP'**
  String get cameraIp;

  /// No description provided for @hostInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an IP or host name'**
  String get hostInvalid;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @portInvalid.
  ///
  /// In en, this message translates to:
  /// **'1–65535'**
  String get portInvalid;

  /// No description provided for @cameraUser.
  ///
  /// In en, this message translates to:
  /// **'Camera account user'**
  String get cameraUser;

  /// No description provided for @cameraPassword.
  ///
  /// In en, this message translates to:
  /// **'Camera account password'**
  String get cameraPassword;

  /// No description provided for @passwordKeep.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to keep the current one'**
  String get passwordKeep;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @advancedHint.
  ///
  /// In en, this message translates to:
  /// **'Custom RTSP stream paths'**
  String get advancedHint;

  /// No description provided for @mainStreamPath.
  ///
  /// In en, this message translates to:
  /// **'Main stream path (recording)'**
  String get mainStreamPath;

  /// No description provided for @subStreamPath.
  ///
  /// In en, this message translates to:
  /// **'Sub stream path (analysis)'**
  String get subStreamPath;

  /// No description provided for @subStreamHint.
  ///
  /// In en, this message translates to:
  /// **'Low resolution; empty = use main stream'**
  String get subStreamHint;

  /// No description provided for @pathInvalid.
  ///
  /// In en, this message translates to:
  /// **'Must start with / and contain no spaces'**
  String get pathInvalid;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get unmute;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @capture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get capture;

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// No description provided for @snapshotSaved.
  ///
  /// In en, this message translates to:
  /// **'Snapshot saved'**
  String get snapshotSaved;

  /// No description provided for @recordingStarted.
  ///
  /// In en, this message translates to:
  /// **'Recording 30 seconds…'**
  String get recordingStarted;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopRecording;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get fullscreen;

  /// No description provided for @notificationsTriggers.
  ///
  /// In en, this message translates to:
  /// **'Notifications & Triggers'**
  String get notificationsTriggers;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @motionDetection.
  ///
  /// In en, this message translates to:
  /// **'Motion Detection'**
  String get motionDetection;

  /// No description provided for @motionDetectionHint.
  ///
  /// In en, this message translates to:
  /// **'Any movement inside motion zones'**
  String get motionDetectionHint;

  /// No description provided for @personDetection.
  ///
  /// In en, this message translates to:
  /// **'Person Detection'**
  String get personDetection;

  /// No description provided for @personDetectionHint.
  ///
  /// In en, this message translates to:
  /// **'AI detects people inside person zones'**
  String get personDetectionHint;

  /// No description provided for @alertSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Alert Sensitivity'**
  String get alertSensitivity;

  /// No description provided for @sensLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get sensLow;

  /// No description provided for @sensMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get sensMedium;

  /// No description provided for @sensHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get sensHigh;

  /// No description provided for @sensitivityHint.
  ///
  /// In en, this message translates to:
  /// **'Higher catches smaller movements but may react to rain, insects or light changes.'**
  String get sensitivityHint;

  /// No description provided for @zonesNone.
  ///
  /// In en, this message translates to:
  /// **'No zones: the whole frame is watched'**
  String get zonesNone;

  /// No description provided for @editZones.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editZones;

  /// No description provided for @notifyPerson.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get notifyPerson;

  /// No description provided for @notifyPersonHint.
  ///
  /// In en, this message translates to:
  /// **'Loud alarm sound'**
  String get notifyPersonHint;

  /// No description provided for @notifyMotion.
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get notifyMotion;

  /// No description provided for @notifyMotionHint.
  ///
  /// In en, this message translates to:
  /// **'Soft chime'**
  String get notifyMotionHint;

  /// No description provided for @soundPreview.
  ///
  /// In en, this message translates to:
  /// **'Sound check'**
  String get soundPreview;

  /// No description provided for @soundPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Each alert type has its own sound so you know what happened without looking.'**
  String get soundPreviewHint;

  /// No description provided for @soundTest.
  ///
  /// In en, this message translates to:
  /// **'Sound test'**
  String get soundTest;

  /// No description provided for @alwaysOn.
  ///
  /// In en, this message translates to:
  /// **'Always On'**
  String get alwaysOn;

  /// No description provided for @alwaysOnHint.
  ///
  /// In en, this message translates to:
  /// **'Triggers work 24/7'**
  String get alwaysOnHint;

  /// No description provided for @onSchedule.
  ///
  /// In en, this message translates to:
  /// **'On Schedule'**
  String get onSchedule;

  /// No description provided for @onScheduleHint.
  ///
  /// In en, this message translates to:
  /// **'Only at chosen times, e.g. at night'**
  String get onScheduleHint;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get to;

  /// No description provided for @dayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get dayMon;

  /// No description provided for @dayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get dayTue;

  /// No description provided for @dayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get dayWed;

  /// No description provided for @dayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get dayThu;

  /// No description provided for @dayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get dayFri;

  /// No description provided for @daySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get daySat;

  /// No description provided for @daySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get daySun;

  /// No description provided for @zone.
  ///
  /// In en, this message translates to:
  /// **'Zone'**
  String get zone;

  /// No description provided for @zoneName.
  ///
  /// In en, this message translates to:
  /// **'Zone name'**
  String get zoneName;

  /// No description provided for @zonesHint.
  ///
  /// In en, this message translates to:
  /// **'Add a zone, then drag its corners over the area to watch. Choose whether it reacts to motion, people or both. Zones for people check where the feet are.'**
  String get zonesHint;

  /// No description provided for @legendBoth.
  ///
  /// In en, this message translates to:
  /// **'Motion + people'**
  String get legendBoth;

  /// No description provided for @legendMotion.
  ///
  /// In en, this message translates to:
  /// **'Motion only'**
  String get legendMotion;

  /// No description provided for @legendPerson.
  ///
  /// In en, this message translates to:
  /// **'People only'**
  String get legendPerson;

  /// No description provided for @addZone.
  ///
  /// In en, this message translates to:
  /// **'Add Zone'**
  String get addZone;

  /// No description provided for @addPoints.
  ///
  /// In en, this message translates to:
  /// **'Add Points'**
  String get addPoints;

  /// No description provided for @doneAddingPoints.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneAddingPoints;

  /// No description provided for @undoPoint.
  ///
  /// In en, this message translates to:
  /// **'Remove last point'**
  String get undoPoint;

  /// No description provided for @deleteZoneBody.
  ///
  /// In en, this message translates to:
  /// **'The zone will stop triggering alerts.'**
  String get deleteZoneBody;

  /// No description provided for @zoneInactive.
  ///
  /// In en, this message translates to:
  /// **'Zone is off: pick motion and/or people.'**
  String get zoneInactive;

  /// No description provided for @deleteEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete event?'**
  String get deleteEventTitle;

  /// No description provided for @deleteEventBody.
  ///
  /// In en, this message translates to:
  /// **'The clip and thumbnail are removed from the hub. Cloud copies stay.'**
  String get deleteEventBody;

  /// No description provided for @clipProcessing.
  ///
  /// In en, this message translates to:
  /// **'Saving clip…'**
  String get clipProcessing;

  /// No description provided for @clipUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Clip unavailable'**
  String get clipUnavailable;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @zones.
  ///
  /// In en, this message translates to:
  /// **'Zones'**
  String get zones;

  /// No description provided for @cloudCopy.
  ///
  /// In en, this message translates to:
  /// **'Cloud copy'**
  String get cloudCopy;

  /// No description provided for @saveOrShare.
  ///
  /// In en, this message translates to:
  /// **'Save or Share Clip'**
  String get saveOrShare;

  /// No description provided for @hubSection.
  ///
  /// In en, this message translates to:
  /// **'Hub'**
  String get hubSection;

  /// No description provided for @appSection.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get appSection;

  /// No description provided for @pushActive.
  ///
  /// In en, this message translates to:
  /// **'Push on'**
  String get pushActive;

  /// No description provided for @pushInactive.
  ///
  /// In en, this message translates to:
  /// **'Push off — alerts only while the app is open'**
  String get pushInactive;

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @storageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Retention and cloud copies'**
  String get storageSubtitle;

  /// No description provided for @devices.
  ///
  /// In en, this message translates to:
  /// **'Paired Devices'**
  String get devices;

  /// No description provided for @devicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Phones with access, pair another'**
  String get devicesSubtitle;

  /// No description provided for @appLock.
  ///
  /// In en, this message translates to:
  /// **'App Lock'**
  String get appLock;

  /// No description provided for @appLockHint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint, face or device PIN'**
  String get appLockHint;

  /// No description provided for @lockUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Set up a screen lock on this phone first.'**
  String get lockUnsupported;

  /// No description provided for @guides.
  ///
  /// In en, this message translates to:
  /// **'Setup Guides'**
  String get guides;

  /// No description provided for @guidesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Server, cameras, remote access, cloud'**
  String get guidesSubtitle;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About & Licenses'**
  String get about;

  /// No description provided for @aboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open source, MIT License'**
  String get aboutSubtitle;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect From Hub'**
  String get disconnect;

  /// No description provided for @disconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect?'**
  String get disconnectTitle;

  /// No description provided for @disconnectBody.
  ///
  /// In en, this message translates to:
  /// **'This phone forgets the hub. You’ll need a new pairing code to connect again.'**
  String get disconnectBody;

  /// No description provided for @deviceRevoked.
  ///
  /// In en, this message translates to:
  /// **'This phone was removed from the hub.'**
  String get deviceRevoked;

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Obscura is locked'**
  String get locked;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Obscura'**
  String get unlockReason;

  /// No description provided for @pairAnother.
  ///
  /// In en, this message translates to:
  /// **'Pair Another Phone'**
  String get pairAnother;

  /// No description provided for @pairAnotherHint.
  ///
  /// In en, this message translates to:
  /// **'Scan with Obscura on the other phone (Connect → Scan QR Code).'**
  String get pairAnotherHint;

  /// No description provided for @qrCode.
  ///
  /// In en, this message translates to:
  /// **'Pairing QR code'**
  String get qrCode;

  /// No description provided for @codeExpires.
  ///
  /// In en, this message translates to:
  /// **'Single use, valid for 10 minutes'**
  String get codeExpires;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'this phone'**
  String get thisDevice;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @revokeBody.
  ///
  /// In en, this message translates to:
  /// **'That phone loses access immediately.'**
  String get revokeBody;

  /// No description provided for @devicesHint.
  ///
  /// In en, this message translates to:
  /// **'Lost a phone? Revoke it here from another paired phone.'**
  String get devicesHint;

  /// No description provided for @onHub.
  ///
  /// In en, this message translates to:
  /// **'On the hub'**
  String get onHub;

  /// No description provided for @keepDays.
  ///
  /// In en, this message translates to:
  /// **'Keep days'**
  String get keepDays;

  /// No description provided for @maxGb.
  ///
  /// In en, this message translates to:
  /// **'Max GB'**
  String get maxGb;

  /// No description provided for @retentionHint.
  ///
  /// In en, this message translates to:
  /// **'Oldest clips are deleted when either limit is reached.'**
  String get retentionHint;

  /// No description provided for @retentionInvalid.
  ///
  /// In en, this message translates to:
  /// **'Days: 1–365, size: at least 0.5 GB'**
  String get retentionInvalid;

  /// No description provided for @howTo.
  ///
  /// In en, this message translates to:
  /// **'How To'**
  String get howTo;

  /// No description provided for @cloudEnabled.
  ///
  /// In en, this message translates to:
  /// **'Copy clips to the cloud'**
  String get cloudEnabled;

  /// No description provided for @cloudEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'Every clip is uploaded right after recording'**
  String get cloudEnabledHint;

  /// No description provided for @rcloneCustom.
  ///
  /// In en, this message translates to:
  /// **'rclone'**
  String get rcloneCustom;

  /// No description provided for @s3Provider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get s3Provider;

  /// No description provided for @s3Endpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get s3Endpoint;

  /// No description provided for @s3Region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get s3Region;

  /// No description provided for @s3AccessKey.
  ///
  /// In en, this message translates to:
  /// **'Access key ID'**
  String get s3AccessKey;

  /// No description provided for @s3SecretKey.
  ///
  /// In en, this message translates to:
  /// **'Secret access key'**
  String get s3SecretKey;

  /// No description provided for @webdavUrl.
  ///
  /// In en, this message translates to:
  /// **'WebDAV URL'**
  String get webdavUrl;

  /// No description provided for @webdavVendor.
  ///
  /// In en, this message translates to:
  /// **'Server type'**
  String get webdavVendor;

  /// No description provided for @webdavUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get webdavUser;

  /// No description provided for @webdavPassword.
  ///
  /// In en, this message translates to:
  /// **'Password (app password)'**
  String get webdavPassword;

  /// No description provided for @secretWriteOnly.
  ///
  /// In en, this message translates to:
  /// **'Stored on the hub only; never shown again'**
  String get secretWriteOnly;

  /// No description provided for @rcloneRemote.
  ///
  /// In en, this message translates to:
  /// **'rclone remote name'**
  String get rcloneRemote;

  /// No description provided for @rcloneRemoteHint.
  ///
  /// In en, this message translates to:
  /// **'Created on the hub with: docker compose exec -it hub rclone --config /data/rclone.conf config'**
  String get rcloneRemoteHint;

  /// No description provided for @cloudFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder (for S3: bucket/folder)'**
  String get cloudFolder;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// No description provided for @storageTestOk.
  ///
  /// In en, this message translates to:
  /// **'Connection works'**
  String get storageTestOk;

  /// No description provided for @storageTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get storageTestFailed;

  /// No description provided for @pushTitle.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get pushTitle;

  /// No description provided for @pushActiveHint.
  ///
  /// In en, this message translates to:
  /// **'Alerts arrive even when the app is closed'**
  String get pushActiveHint;

  /// No description provided for @pushOffHint.
  ///
  /// In en, this message translates to:
  /// **'Needs the ntfy app as a push distributor'**
  String get pushOffHint;

  /// No description provided for @pushError.
  ///
  /// In en, this message translates to:
  /// **'Registration failed — open ntfy and try again'**
  String get pushError;

  /// No description provided for @pushExplain.
  ///
  /// In en, this message translates to:
  /// **'Uses UnifiedPush (no Google services). Alert contents are end-to-end encrypted between the hub and this phone.'**
  String get pushExplain;

  /// No description provided for @noDistributorTitle.
  ///
  /// In en, this message translates to:
  /// **'Install ntfy first'**
  String get noDistributorTitle;

  /// No description provided for @noDistributorBody.
  ///
  /// In en, this message translates to:
  /// **'Background alerts need a UnifiedPush distributor. Install the free ntfy app from Google Play or F-Droid, open it once, then turn push on again.'**
  String get noDistributorBody;

  /// No description provided for @openGuide.
  ///
  /// In en, this message translates to:
  /// **'Open Guide'**
  String get openGuide;

  /// No description provided for @ntfyTitle.
  ///
  /// In en, this message translates to:
  /// **'ntfy topic (iPhone)'**
  String get ntfyTitle;

  /// No description provided for @ntfyExplain.
  ///
  /// In en, this message translates to:
  /// **'For iPhone or as a backup: the hub also posts alerts to an ntfy topic you subscribe to in the ntfy app. Camera name and event type are sent in plain text.'**
  String get ntfyExplain;

  /// No description provided for @ntfyEnable.
  ///
  /// In en, this message translates to:
  /// **'Send alerts to an ntfy topic'**
  String get ntfyEnable;

  /// No description provided for @ntfyServer.
  ///
  /// In en, this message translates to:
  /// **'ntfy server'**
  String get ntfyServer;

  /// No description provided for @ntfyTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get ntfyTopic;

  /// No description provided for @ntfyTopicHint.
  ///
  /// In en, this message translates to:
  /// **'Anyone who knows the topic can read it — keep it long and random.'**
  String get ntfyTopicHint;

  /// No description provided for @ntfyToken.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get ntfyToken;

  /// No description provided for @voiceAndSiren.
  ///
  /// In en, this message translates to:
  /// **'Voice & siren'**
  String get voiceAndSiren;

  /// No description provided for @holdToTalk.
  ///
  /// In en, this message translates to:
  /// **'Hold to talk'**
  String get holdToTalk;

  /// No description provided for @talking.
  ///
  /// In en, this message translates to:
  /// **'Speak now… release to send'**
  String get talking;

  /// No description provided for @talkSending.
  ///
  /// In en, this message translates to:
  /// **'Sending to the camera…'**
  String get talkSending;

  /// No description provided for @talkSent.
  ///
  /// In en, this message translates to:
  /// **'Played through the camera speaker'**
  String get talkSent;

  /// No description provided for @talkTooShort.
  ///
  /// In en, this message translates to:
  /// **'Keep holding the button while you speak'**
  String get talkTooShort;

  /// No description provided for @micDenied.
  ///
  /// In en, this message translates to:
  /// **'No microphone access. Allow it in the phone settings.'**
  String get micDenied;

  /// No description provided for @siren.
  ///
  /// In en, this message translates to:
  /// **'Siren'**
  String get siren;

  /// No description provided for @sirenStop.
  ///
  /// In en, this message translates to:
  /// **'Stop Siren'**
  String get sirenStop;

  /// No description provided for @sirenConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on the siren?'**
  String get sirenConfirmTitle;

  /// No description provided for @sirenConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The camera will sound a loud alarm. It switches off by itself after the set time.'**
  String get sirenConfirmBody;

  /// No description provided for @sirenTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn On'**
  String get sirenTurnOn;

  /// No description provided for @sirenOff.
  ///
  /// In en, this message translates to:
  /// **'Siren off'**
  String get sirenOff;

  /// No description provided for @talkSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Talk and siren are not set up'**
  String get talkSetupTitle;

  /// No description provided for @talkSetupTapo.
  ///
  /// In en, this message translates to:
  /// **'Enter your TP-Link account password in the camera connection settings.'**
  String get talkSetupTapo;

  /// No description provided for @talkSetupOther.
  ///
  /// In en, this message translates to:
  /// **'Turn on “Camera has a speaker” in the camera connection settings.'**
  String get talkSetupOther;

  /// No description provided for @setUp.
  ///
  /// In en, this message translates to:
  /// **'Set Up'**
  String get setUp;

  /// No description provided for @cloudPassword.
  ///
  /// In en, this message translates to:
  /// **'TP-Link account password'**
  String get cloudPassword;

  /// No description provided for @cloudPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'For talk and siren: the password you sign in to the Tapo app with. No login needed — the camera always uses “admin”. The hub keeps only the password\'s hash.'**
  String get cloudPasswordHint;

  /// No description provided for @cloudPasswordRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove the account password'**
  String get cloudPasswordRemove;

  /// No description provided for @twoWay.
  ///
  /// In en, this message translates to:
  /// **'Camera has a speaker'**
  String get twoWay;

  /// No description provided for @twoWayHint.
  ///
  /// In en, this message translates to:
  /// **'Enables talk and a siren through the speaker (RTSP/ONVIF two-way audio).'**
  String get twoWayHint;

  /// No description provided for @controlOk.
  ///
  /// In en, this message translates to:
  /// **'TP-Link account password accepted'**
  String get controlOk;

  /// No description provided for @sirenOnPerson.
  ///
  /// In en, this message translates to:
  /// **'Siren when a person is detected'**
  String get sirenOnPerson;

  /// No description provided for @sirenOnPersonHint.
  ///
  /// In en, this message translates to:
  /// **'Scares off intruders. Uses the camera\'s own alarm (Tapo) or its speaker.'**
  String get sirenOnPersonHint;

  /// No description provided for @sirenDuration.
  ///
  /// In en, this message translates to:
  /// **'Siren duration'**
  String get sirenDuration;

  /// No description provided for @sirenUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Needs the TP-Link account password (Tapo) or “Camera has a speaker” in the connection settings.'**
  String get sirenUnavailable;

  /// No description provided for @controlFailed.
  ///
  /// In en, this message translates to:
  /// **'Talk and siren unavailable: {message}'**
  String controlFailed(String message);

  /// No description provided for @sirenOn.
  ///
  /// In en, this message translates to:
  /// **'Siren on for {seconds} s'**
  String sirenOn(int seconds);

  /// No description provided for @camerasOnline.
  ///
  /// In en, this message translates to:
  /// **'{online} of {total} cameras online'**
  String camerasOnline(int online, int total);

  /// No description provided for @deleteCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteCameraTitle(String name);

  /// No description provided for @deleteZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteZoneTitle(String name);

  /// No description provided for @revokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke {name}?'**
  String revokeTitle(String name);

  /// No description provided for @diskFree.
  ///
  /// In en, this message translates to:
  /// **'{size} free'**
  String diskFree(String size);

  /// No description provided for @storedClips.
  ///
  /// In en, this message translates to:
  /// **'clips {size}'**
  String storedClips(String size);

  /// No description provided for @lastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen {time}'**
  String lastSeen(String time);

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String filterAll(int count);

  /// No description provided for @filterOnline.
  ///
  /// In en, this message translates to:
  /// **'Online ({count})'**
  String filterOnline(int count);

  /// No description provided for @filterOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline ({count})'**
  String filterOffline(int count);

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 second} other{{count} seconds}}'**
  String seconds(int count);

  /// No description provided for @zonesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 zone} other{{count} zones}}'**
  String zonesCount(int count);

  /// No description provided for @storageUsage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 clip} other{{count} clips}}, {size}'**
  String storageUsage(int count, String size);

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @deleteAllEvents.
  ///
  /// In en, this message translates to:
  /// **'Delete all events'**
  String get deleteAllEvents;

  /// No description provided for @deleteAllEventsBody.
  ///
  /// In en, this message translates to:
  /// **'Every clip and thumbnail from all cameras is removed from the hub. This can\'t be undone.'**
  String get deleteAllEventsBody;

  /// No description provided for @deleteCameraEventsBody.
  ///
  /// In en, this message translates to:
  /// **'Every clip and thumbnail from this camera is removed from the hub. This can\'t be undone.'**
  String get deleteCameraEventsBody;

  /// No description provided for @showOverlay.
  ///
  /// In en, this message translates to:
  /// **'Show zones and motion'**
  String get showOverlay;

  /// No description provided for @hideOverlay.
  ///
  /// In en, this message translates to:
  /// **'Hide zones and motion'**
  String get hideOverlay;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @savedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery (Obscura album)'**
  String get savedToGallery;

  /// No description provided for @recordLow.
  ///
  /// In en, this message translates to:
  /// **'Compact recording (720p)'**
  String get recordLow;

  /// No description provided for @recordLowHint.
  ///
  /// In en, this message translates to:
  /// **'Clips are about 3x smaller and the hub pulls one stream from the camera instead of two. Live view stays full quality.'**
  String get recordLowHint;

  /// No description provided for @remoteHubManual.
  ///
  /// In en, this message translates to:
  /// **'The hub runs on a remote server, so it can\'t search your home network. Enter the address the server reaches the camera at (e.g. your router\'s tunnel address).'**
  String get remoteHubManual;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
