import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Daily practice reminders and "you have a task waiting" alerts
/// (SRS FR_15 / US_19, and the task alert asked for with FR_23).
///
/// Everything happens on the tablet — no server is needed.
class ReminderService {
  static const _dailyId = 1001;
  static const _taskId = 1002;

  static const _onKey = 'reminder_on';
  static const _hourKey = 'reminder_hour';
  static const _minKey = 'reminder_minute';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Must run once before any reminder is used.
  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );
    _ready = true;
  }

  /// Android 13 and newer must ask the user first.
  static Future<bool> askPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  // ---------------- settings ----------------

  static Future<bool> isOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onKey) ?? false;
  }

  /// The time the parent chose, as (hour, minute). Default 6 PM.
  static Future<(int, int)> time() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_hourKey) ?? 18, prefs.getInt(_minKey) ?? 0);
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'kidscribe_reminders',
      'Practice reminders',
      channelDescription: 'Daily practice and homework reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// Turns the daily reminder on at [hour]:[minute], or off.
  static Future<void> setDaily({
    required bool on,
    int hour = 18,
    int minute = 0,
  }) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onKey, on);
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minKey, minute);

    // Off means off: nothing is sent (SRS T_46).
    await _plugin.cancel(_dailyId);
    if (!on) return;

    await _plugin.zonedSchedule(
      _dailyId,
      'Time to write!',
      'Do your KidScribe practice today and keep your streak.',
      _nextTime(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // every day
    );
  }

  /// Tells the child (and the grown-up) that work is waiting.
  static Future<void> showTaskWaiting(int count) async {
    if (count <= 0) return;
    await init();
    await _plugin.show(
      _taskId,
      'You have homework!',
      count == 1
          ? 'One task is waiting for you in KidScribe.'
          : '$count tasks are waiting for you in KidScribe.',
      _details,
    );
  }

  /// A test message, so the parent can see it really works.
  static Future<void> showNow() async {
    await init();
    await _plugin.show(_taskId, 'KidScribe reminder',
        'This is how your reminder will look.', _details);
  }

  static Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// The next time today or tomorrow that matches [hour]:[minute].
  static tz.TZDateTime _nextTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var when =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    return when;
  }
}
