import 'package:flutter/material.dart';

class NotificationReminder {
  final String id;
  final String title;
  final String description;
  final TimeOfDay time;
  final bool enabled;
  final bool isComplete;

  NotificationReminder({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    this.enabled = true,
    this.isComplete = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'hour': time.hour,
        'minute': time.minute,
        'enabled': enabled,
        'isComplete': isComplete,
      };

  factory NotificationReminder.fromJson(Map<String, dynamic> json) {
    return NotificationReminder(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      time: TimeOfDay(hour: json['hour'] as int, minute: json['minute'] as int),
      enabled: json['enabled'] as bool? ?? true,
      isComplete: json['isComplete'] as bool? ?? false,
    );
  }

  NotificationReminder copyWith({
    String? id,
    String? title,
    String? description,
    TimeOfDay? time,
    bool? enabled,
    bool? isComplete,
  }) {
    return NotificationReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      time: time ?? this.time,
      enabled: enabled ?? this.enabled,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}