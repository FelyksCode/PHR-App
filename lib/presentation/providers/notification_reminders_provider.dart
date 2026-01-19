import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../data/models/notification_reminder.dart';

final notificationRemindersProvider =
    StateNotifierProvider<
      NotificationRemindersNotifier,
      List<NotificationReminder>
    >((ref) => NotificationRemindersNotifier());

class NotificationRemindersNotifier
    extends StateNotifier<List<NotificationReminder>> {
  static const _prefsKey = 'notification_reminders';

  NotificationRemindersNotifier() : super([]) {
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      state = jsonList.map((e) => NotificationReminder.fromJson(e)).toList();
    }
  }

  Future<void> _saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, jsonString);
  }

  void addReminder(NotificationReminder reminder) {
    state = [...state, reminder];
    _saveReminders();
  }

  void removeReminder(String id) {
    state = state.where((r) => r.id != id).toList();
    _saveReminders();
  }

  void updateReminder(NotificationReminder reminder) {
    state = [
      for (final r in state)
        if (r.id == reminder.id) reminder else r,
    ];
    _saveReminders();
  }
}
