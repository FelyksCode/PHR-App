import 'package:flutter/material.dart';
import '../../domain/entities/condition_entity.dart';

/// Extensions for ConditionSeverity
extension ConditionSeverityUI on ConditionSeverity {
  /// Get color for severity level
  Color get color {
    switch (this) {
      case ConditionSeverity.mild:
        return Colors.amber;
      case ConditionSeverity.moderate:
        return Colors.orange;
      case ConditionSeverity.severe:
        return Colors.red;
    }
  }

  /// Get background color for severity level
  Color get backgroundColor {
    switch (this) {
      case ConditionSeverity.mild:
        return Colors.amber.withValues(alpha:0.1);
      case ConditionSeverity.moderate:
        return Colors.orange.withValues(alpha:0.1);
      case ConditionSeverity.severe:
        return Colors.red.withValues(alpha:0.1);
    }
  }

  /// Get icon for severity level
  IconData get icon {
    switch (this) {
      case ConditionSeverity.mild:
        return Icons.sentiment_satisfied;
      case ConditionSeverity.moderate:
        return Icons.sentiment_neutral;
      case ConditionSeverity.severe:
        return Icons.sentiment_very_dissatisfied;
    }
  }
}
