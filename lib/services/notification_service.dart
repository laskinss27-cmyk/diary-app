import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

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

  static Future<void> scheduleDaily(int hour, int minute) async {
    // Save settings
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);
    await prefs.setBool(_enabledKey, true);

    // Cancel existing
    await _plugin.cancel(_notifId);

    // Schedule
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'Напоминания',
      channelDescription: 'Ежедневные напоминания о записи в дневник',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

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

    debugPrint('Notification scheduled for $hour:${minute.toString().padLeft(2, '0')}');
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
