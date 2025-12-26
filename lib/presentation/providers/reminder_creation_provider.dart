import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State class for notification reminder creation dialog
class ReminderCreationState {
  final String? selectedVitalSign;
  final String? selectedInterval;
  final String? selectedDay;
  final int? selectedDate;
  final TimeOfDay? selectedTime;

  const ReminderCreationState({
    this.selectedVitalSign,
    this.selectedInterval,
    this.selectedDay,
    this.selectedDate,
    this.selectedTime,
  });

  ReminderCreationState copyWith({
    String? selectedVitalSign,
    String? selectedInterval,
    String? selectedDay,
    int? selectedDate,
    TimeOfDay? selectedTime,
    bool clearDay = false,
    bool clearDate = false,
  }) {
    return ReminderCreationState(
      selectedVitalSign: selectedVitalSign ?? this.selectedVitalSign,
      selectedInterval: selectedInterval ?? this.selectedInterval,
      selectedDay: clearDay ? null : (selectedDay ?? this.selectedDay),
      selectedDate: clearDate ? null : (selectedDate ?? this.selectedDate),
      selectedTime: selectedTime ?? this.selectedTime,
    );
  }
}

/// State notifier for reminder creation
class ReminderCreationNotifier extends StateNotifier<ReminderCreationState> {
  ReminderCreationNotifier() : super(const ReminderCreationState());

  void setVitalSign(String vitalSign) {
    state = state.copyWith(selectedVitalSign: vitalSign);
  }

  void setInterval(String interval) {
    // Clear day/date when changing interval
    state = state.copyWith(
      selectedInterval: interval,
      clearDay: true,
      clearDate: true,
    );
  }

  void setDay(String day) {
    state = state.copyWith(selectedDay: day);
  }

  void setDate(int date) {
    state = state.copyWith(selectedDate: date);
  }

  void setTime(TimeOfDay time) {
    state = state.copyWith(selectedTime: time);
  }

  void reset() {
    state = const ReminderCreationState();
  }

  void initializeFromReminder({
    String? vitalSign,
    String? interval,
    String? day,
    int? date,
    TimeOfDay? time,
  }) {
    state = ReminderCreationState(
      selectedVitalSign: vitalSign,
      selectedInterval: interval,
      selectedDay: day,
      selectedDate: date,
      selectedTime: time,
    );
  }
}

/// Provider for reminder creation state
final reminderCreationProvider =
    StateNotifierProvider.autoDispose<ReminderCreationNotifier, ReminderCreationState>(
  (ref) => ReminderCreationNotifier(),
);
