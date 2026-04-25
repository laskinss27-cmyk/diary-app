import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPermissionResult {
  final bool notificationsGranted;
  final bool exactAlarmGranted;
  const NotificationPermissionResult({
    required this.notificationsGranted,
    required this.exactAlarmGranted,
  });

  bool get allGranted => notificationsGranted && exactAlarmGranted;
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'diary_reminder';
  static const _notifId = 100;
  static const _hourKey = 'reminder_hour';
  static const _minuteKey = 'reminder_minute';
  static const _enabledKey = 'reminder_enabled';

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);
    debugPrint('Notifications initialized');
  }

  /// Re-arm the daily schedule on app launch in case the OS killed it
  /// (e.g. MIUI background restrictions, reboot without RECEIVE_BOOT_COMPLETED
  /// hooks firing for the plugin).
  static Future<void> rescheduleIfEnabled() async {
    final s = await getSettings();
    if (!s.enabled) return;
    try {
      await scheduleDaily(s.hour, s.minute);
      debugPrint('Notification re-armed on app start');
    } catch (e) {
      debugPrint('Re-arm failed: $e');
    }
  }

  /// Requests POST_NOTIFICATIONS (Android 13+) and SCHEDULE_EXACT_ALARM.
  /// Must be called before scheduleDaily on Android 13+, otherwise the
  /// notification will be silently dropped.
  static Future<NotificationPermissionResult> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return const NotificationPermissionResult(
        notificationsGranted: true,
        exactAlarmGranted: true,
      );
    }
    final notif = await android.requestNotificationsPermission() ?? false;
    final exact = await android.requestExactAlarmsPermission() ?? false;
    debugPrint('Permissions: notif=$notif exact=$exact');
    return NotificationPermissionResult(
      notificationsGranted: notif,
      exactAlarmGranted: exact,
    );
  }

  static Future<bool> areNotificationsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.areNotificationsEnabled() ?? false;
  }

  static Future<void> scheduleDaily(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);
    await prefs.setBool(_enabledKey, true);

    await _plugin.cancel(_notifId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'Напоминания',
      channelDescription: 'Ежедневные напоминания о записи в дневник',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.reminder,
    );

    // Try exact first; if the user denied SCHEDULE_EXACT_ALARM we fall back
    // to inexact so the notification still fires (just with OS-decided drift).
    try {
      await _plugin.zonedSchedule(
        _notifId,
        'Время для записи в дневник',
        'Как прошёл твой день? Запиши свои мысли и чувства.',
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint(
          'Notification scheduled (exact) for $hour:${minute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('Exact schedule failed ($e), falling back to inexact');
      try {
        await _plugin.zonedSchedule(
          _notifId,
          'Время для записи в дневник',
          'Как прошёл твой день? Запиши свои мысли и чувства.',
          scheduled,
          const NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e2) {
        debugPrint('Inexact also failed: $e2');
      }
    }
  }

  static Future<void> cancel() async {
    await _plugin.cancel(_notifId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    debugPrint('Notifications cancelled');
  }

  static Future<({int hour, int minute, bool enabled})> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      hour: prefs.getInt(_hourKey) ?? 21,
      minute: prefs.getInt(_minuteKey) ?? 0,
      enabled: prefs.getBool(_enabledKey) ?? false,
    );
  }
}
