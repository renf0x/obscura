import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications with a distinct sound per trigger type.
/// Android notification channels fix their sound at creation, so each kind gets its own channel.
abstract final class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final tapped = ValueNotifier<int?>(null); // event id from a tapped notification
  static bool _ready = false;

  static bool get _ru => PlatformDispatcher.instance.locale.languageCode == 'ru';

  static Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_obscura'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) => tapped.value = int.tryParse(r.payload ?? ''),
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      tapped.value = int.tryParse(launch!.notificationResponse?.payload ?? '');
    }
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(AndroidNotificationChannel(
      'person',
      _ru ? 'Обнаружен человек' : 'Person detected',
      description: _ru ? 'Громкий тревожный сигнал' : 'Loud alarm sound',
      importance: Importance.max,
      sound: const RawResourceAndroidNotificationSound('obscura_person'),
      vibrationPattern: Int64List.fromList([0, 400, 150, 400, 150, 800]),
      enableLights: true,
      ledColor: const Color(0xFFFF5A5A),
    ));
    await android?.createNotificationChannel(AndroidNotificationChannel(
      'motion',
      _ru ? 'Движение' : 'Motion',
      description: _ru ? 'Мягкий сигнал' : 'Soft chime',
      importance: Importance.high,
      sound: const RawResourceAndroidNotificationSound('obscura_motion'),
      vibrationPattern: Int64List.fromList([0, 200]),
    ));
    _ready = true;
  }

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ??
        await ios?.requestPermissions(alert: true, sound: true, badge: true);
    return granted ?? false;
  }

  static Future<void> showEvent({required int eventId, required String kind, required String camera}) async {
    await init();
    final person = kind == 'person';
    final title = person
        ? (_ru ? 'Обнаружен человек' : 'Person detected')
        : kind == 'manual'
            ? (_ru ? 'Запись вручную' : 'Manual recording')
            : (_ru ? 'Движение' : 'Motion detected');
    await _plugin.show(
      id: eventId,
      title: title,
      body: camera,
      payload: '$eventId',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          person ? 'person' : 'motion',
          person ? (_ru ? 'Обнаружен человек' : 'Person detected') : (_ru ? 'Движение' : 'Motion'),
          importance: person ? Importance.max : Importance.high,
          priority: person ? Priority.max : Priority.high,
          category: person ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.event,
          color: person ? const Color(0xFFFF5A5A) : const Color(0xFF34E3A4),
          visibility: NotificationVisibility.private, // hide details on the lock screen
          ticker: title,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          interruptionLevel: person ? InterruptionLevel.timeSensitive : InterruptionLevel.active,
        ),
      ),
    );
  }
}
