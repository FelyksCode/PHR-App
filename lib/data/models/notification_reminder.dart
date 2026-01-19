import 'package:flutter/material.dart';

/// Represents a user-configured health reminder with recurrence.
class NotificationReminder {
  final String id;
  final String title;
  final String description;
  final TimeOfDay time;
  final bool enabled;

  /// Recurrence: 'Daily' | 'Weekly' | 'Monthly'. Defaults to 'Daily' when null.
  final String? interval;

  /// For weekly reminders: 1..7 (Mon..Sun per Dart's DateTime.weekday).
  final int? weekDay;

  /// For monthly reminders: 1..31.
  final int? monthDay;

  /// Per-day completion keys: yyyy-MM-dd strings.
  final List<String> completedDates;

  /// Legacy field kept for backward compatibility (global completion).
  final bool isComplete;

  /// Creation timestamp used to avoid showing past-due before creation.
  final DateTime createdAt;

  NotificationReminder({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    this.enabled = true,
    this.interval,
    this.weekDay,
    this.monthDay,
    List<String>? completedDates,
    this.isComplete = false,
    DateTime? createdAt,
  }) : completedDates = completedDates ?? const [],
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'hour': time.hour,
    'minute': time.minute,
    'enabled': enabled,
    // Recurrence fields
    'interval': interval,
    'weekDay': weekDay,
    'monthDay': monthDay,
    'completedDates': completedDates,
    // Legacy
    'isComplete': isComplete,
    'createdAt': createdAt.toIso8601String(),
  };

  factory NotificationReminder.fromJson(Map<String, dynamic> json) {
    // Fallback for older saved reminders where interval fields are absent.
    final String? interval = json['interval'] as String?;
    int? weekDay = json['weekDay'] as int?;
    int? monthDay = json['monthDay'] as int?;

    // Try to parse from description like: "Vital - Weekly - Monday" or "Vital - Monthly - 15".
    if (interval == null) {
      final desc = (json['description'] as String?) ?? '';
      final parts = desc.split(' - ');
      if (parts.length >= 2) {
        final maybeInterval = parts[1];
        if (maybeInterval == 'Daily' ||
            maybeInterval == 'Weekly' ||
            maybeInterval == 'Monthly') {
          if (maybeInterval == 'Weekly' && parts.length >= 3) {
            final dayName = parts[2];
            const mapping = {
              'Monday': 1,
              'Tuesday': 2,
              'Wednesday': 3,
              'Thursday': 4,
              'Friday': 5,
              'Saturday': 6,
              'Sunday': 7,
            };
            weekDay = mapping[dayName];
          } else if (maybeInterval == 'Monthly' && parts.length >= 3) {
            monthDay = int.tryParse(parts[2]);
          }
        }
      }
    }

    final List<String> completedDates =
        (json['completedDates'] as List?)?.whereType<String>().toList() ??
        const [];

    return NotificationReminder(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      time: TimeOfDay(hour: json['hour'] as int, minute: json['minute'] as int),
      enabled: json['enabled'] as bool? ?? true,
      interval:
          interval ??
          (weekDay != null || monthDay != null
              ? (weekDay != null ? 'Weekly' : 'Monthly')
              : 'Daily'),
      weekDay: weekDay,
      monthDay: monthDay,
      completedDates: completedDates,
      isComplete: json['isComplete'] as bool? ?? false,
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  NotificationReminder copyWith({
    String? id,
    String? title,
    String? description,
    TimeOfDay? time,
    bool? enabled,
    String? interval,
    int? weekDay,
    int? monthDay,
    List<String>? completedDates,
    bool? isComplete,
    DateTime? createdAt,
  }) {
    return NotificationReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      time: time ?? this.time,
      enabled: enabled ?? this.enabled,
      interval: interval ?? this.interval,
      weekDay: weekDay ?? this.weekDay,
      monthDay: monthDay ?? this.monthDay,
      completedDates: completedDates ?? this.completedDates,
      isComplete: isComplete ?? this.isComplete,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Returns true if this reminder is due on the given date per its recurrence.
  bool isDueOn(DateTime date) {
    final String recur = (interval ?? 'Daily');
    if (recur == 'Daily') return true;
    if (recur == 'Weekly') {
      if (weekDay == null) return true; // fallback
      return date.weekday == weekDay;
    }
    if (recur == 'Monthly') {
      if (monthDay == null) return true; // fallback
      return date.day == monthDay;
    }
    return true;
  }

  /// Returns true if marked completed on the given calendar date.
  bool isCompletedOn(DateTime date) {
    final key = _dateKey(date);
    return completedDates.contains(key);
  }

  /// Mark this reminder completed for the given date.
  NotificationReminder completeOn(DateTime date) {
    final key = _dateKey(date);
    if (completedDates.contains(key)) return this;
    return copyWith(completedDates: [...completedDates, key]);
  }

  static String _dateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
