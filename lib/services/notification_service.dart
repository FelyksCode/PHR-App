import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phr_app/core/utils/timezone_initializer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/models/notification_reminder.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  /* -------------------------------------------------------------------------- */
  /* INIT                                                                       */
  /* -------------------------------------------------------------------------- */

  Future<void> init() async {
    await initTimezone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await plugin.initialize(initSettings);

    // If the master switch is OFF, ensure no reminder notifications remain.
    if (!await areHealthRemindersEnabled()) {
      await cancelAllHealthReminderNotifications();
    }
  }

  Future<void> requestNotificationPermission() async {
    final status = await Permission.notification.request();

    if (!status.isGranted) {
      debugPrint('[PERMISSION] Notification denied');
    }
  }

  /* -------------------------------------------------------------------------- */
  /* PUBLIC API                                                                  */
  /* -------------------------------------------------------------------------- */

  static const String healthRemindersEnabledKey = 'health_reminders_enabled';
  static const String _remindersPrefsKey = 'notification_reminders';

  Future<bool> areHealthRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(healthRemindersEnabledKey) ?? true;
  }

  Future<void> cancelAllHealthReminderNotifications() async {
    final reminders = await _loadStoredReminders();
    for (final r in reminders) {
      await cancelNotification(r.id);
    }
  }

  Future<void> rescheduleAllHealthReminderNotifications() async {
    final enabled = await areHealthRemindersEnabled();
    if (!enabled) return;

    final reminders = await _loadStoredReminders();
    for (final r in reminders) {
      if (!r.enabled) continue;
      await scheduleNotification(
        id: r.id,
        title: r.title,
        body: r.description,
        time: r.time,
        interval: _intervalFromString(r.interval),
        weekDay: r.weekDay,
        monthDay: r.monthDay,
      );
    }
  }

  Future<void> scheduleNotification({
    required String id,
    required String title,
    required String body,
    required TimeOfDay time,
    required NotificationInterval interval,
    int? weekDay, // 1 = Monday ... 7 = Sunday
    int? monthDay, // 1 - 31
  }) async {
    final enabled = await areHealthRemindersEnabled();
    if (!enabled) {
      debugPrint(
        '[NOTIFICATION] Skipping schedule (health reminders disabled): $id',
      );
      return;
    }

    final int notificationId = _idFromString(id);
    final now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime scheduled = _buildSchedule(
      now: now,
      time: time,
      interval: interval,
      weekDay: weekDay,
      monthDay: monthDay,
    );

    debugPrint('[NOTIFICATION]');
    debugPrint('now:        $now');
    debugPrint('scheduled:  $scheduled');

    await plugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduled,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: _matchComponents(interval),
    );
  }

  Future<void> cancelNotification(String id) async {
    final int notificationId = _idFromString(id);
    await plugin.cancel(notificationId);
  }

  /* -------------------------------------------------------------------------- */
  /* SCHEDULING LOGIC                                                            */
  /* -------------------------------------------------------------------------- */

  tz.TZDateTime _buildSchedule({
    required tz.TZDateTime now,
    required TimeOfDay time,
    required NotificationInterval interval,
    int? weekDay,
    int? monthDay,
  }) {
    switch (interval) {
      case NotificationInterval.daily:
        return _nextDaily(now, time);

      case NotificationInterval.weekly:
        if (weekDay == null) {
          throw ArgumentError('weekDay is required for weekly notifications');
        }
        return _nextWeekly(now, time, weekDay);

      case NotificationInterval.monthly:
        if (monthDay == null) {
          throw ArgumentError('monthDay is required for monthly notifications');
        }
        return _nextMonthly(now, time, monthDay);
    }
  }

  tz.TZDateTime _nextDaily(tz.TZDateTime now, TimeOfDay time) {
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    debugPrint("[NEXT DAILY]: ${tz.local}");
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  tz.TZDateTime _nextWeekly(
    tz.TZDateTime now,
    TimeOfDay time,
    int targetWeekday,
  ) {
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    while (scheduled.weekday != targetWeekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  tz.TZDateTime _nextMonthly(tz.TZDateTime now, TimeOfDay time, int targetDay) {
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      targetDay,
      time.hour,
      time.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month + 1,
        targetDay,
        time.hour,
        time.minute,
      );
    }

    return scheduled;
  }

  /* -------------------------------------------------------------------------- */
  /* HELPERS                                                                     */
  /* -------------------------------------------------------------------------- */

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'reminder_channel',
        'Reminders',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
  }

  DateTimeComponents? _matchComponents(NotificationInterval interval) {
    switch (interval) {
      case NotificationInterval.daily:
        return DateTimeComponents.time;
      case NotificationInterval.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      case NotificationInterval.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
    }
  }

  int _idFromString(String id) {
    // Stable mapping from String ID to positive int for notification IDs.
    return id.hashCode & 0x7fffffff;
  }

  Future<List<NotificationReminder>> _loadStoredReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_remindersPrefsKey);
      if (jsonString == null || jsonString.trim().isEmpty) {
        return const [];
      }

      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(NotificationReminder.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[NOTIFICATION] Failed to load stored reminders: $e');
      return const [];
    }
  }

  NotificationInterval _intervalFromString(String? interval) {
    switch (interval) {
      case 'Weekly':
        return NotificationInterval.weekly;
      case 'Monthly':
        return NotificationInterval.monthly;
      case 'Daily':
      default:
        return NotificationInterval.daily;
    }
  }
}

/* -------------------------------------------------------------------------- */
/* ENUMS                                                                       */
/* -------------------------------------------------------------------------- */

enum NotificationInterval { daily, weekly, monthly }
