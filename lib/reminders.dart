import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;
import 'birthday.dart';

class Reminders {
  final plugin = FlutterLocalNotificationsPlugin();
  bool ready = false;
  String status = 'Bildirimler henüz etkinleştirilmedi.';
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Future<void> init() async {
    if (!supported) {
      status = 'Bildirimler Android ve iOS uygulamasında çalışır.';
      return;
    }
    data.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    ready = true;
  }

  Future<bool> request({bool requestExactTime = true}) async {
    if (!supported) return false;
    if (!ready) await init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;
      final allowed = await android.requestNotificationsPermission() ?? false;
      if (allowed && requestExactTime)
        await android.requestExactAlarmsPermission();
      return allowed;
    }
    return await plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()!
            .requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  Future<void> _queue = Future.value();
  Future<void> sync(List<Birthday> people, bool enabled) {
    final operation = _queue.then((_) => _sync(people, enabled));
    _queue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _sync(List<Birthday> people, bool enabled) async {
    if (!supported) {
      status = 'Bildirimler Android ve iOS uygulamasında çalışır.';
      return;
    }
    if (!ready) await init();
    // Refresh the device's time zone when returning from settings or travelling.
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await plugin.cancelAll();
    if (!enabled) {
      status = 'Bildirimler kapalı.';
      return;
    }
    var exact = true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;
      if (await android.areNotificationsEnabled() != true) {
        status = 'Telefon ayarlarından bildirim izni verin.';
        return;
      }
      exact = await android.canScheduleExactNotifications() ?? false;
    } else {
      final permission = await plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()!
          .checkPermissions();
      if (permission?.isEnabled != true) {
        status = 'Telefon ayarlarından bildirim izni verin.';
        return;
      }
    }
    final events = upcomingEvents(people, DateTime.now()).take(60).toList();
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      await plugin.zonedSchedule(
        i,
        e.birthday.title,
        e.daysBefore == 0
            ? 'Bugün kutlama zamanı!'
            : '${e.daysBefore} gün kaldı.',
        tz.TZDateTime(
          tz.local,
          e.date.year,
          e.date.month,
          e.date.day,
          e.date.hour,
        ),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'birthdays',
            'Özel günler',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
    status =
        '${events.length} hatırlatma planlandı.${exact ? '' : ' Kesin saat izni kapalı; bildirimler gecikebilir.'}';
  }
}
