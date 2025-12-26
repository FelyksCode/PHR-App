import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/reminder_history_record.dart';

final reminderHistoryProvider = StateNotifierProvider<ReminderHistoryNotifier, List<ReminderHistoryRecord>>(
  (ref) => ReminderHistoryNotifier(),
);

class ReminderHistoryNotifier extends StateNotifier<List<ReminderHistoryRecord>> {
  static const _prefsKey = 'reminder_history';

  ReminderHistoryNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString != null) {
      final List<dynamic> list = json.decode(jsonString);
      state = list.map((e) => ReminderHistoryRecord.fromJson(e)).toList();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, jsonString);
  }

  void add(ReminderHistoryRecord record) {
    state = [...state, record];
    _save();
  }

  void remove(String id) {
    state = state.where((r) => r.id != id).toList();
    _save();
  }

  void clearAll() {
    state = const [];
    _save();
  }
}
