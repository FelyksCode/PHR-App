import 'package:flutter/material.dart';

class ReminderHistoryRecord {
  final String id;
  final String? reminderId;
  final String title;
  final TimeOfDay time;
  final String dateKey; // yyyy-MM-dd

  const ReminderHistoryRecord({
    required this.id,
    this.reminderId,
    required this.title,
    required this.time,
    required this.dateKey,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'reminderId': reminderId,
        'title': title,
        'hour': time.hour,
        'minute': time.minute,
        'dateKey': dateKey,
      };

  factory ReminderHistoryRecord.fromJson(Map<String, dynamic> json) {
    return ReminderHistoryRecord(
      id: json['id'] as String,
      reminderId: json['reminderId'] as String?,
      title: json['title'] as String,
      time: TimeOfDay(hour: json['hour'] as int, minute: json['minute'] as int),
      dateKey: json['dateKey'] as String,
    );
  }
}
