enum ConditionCategory {
  currentSymptom('current_symptom', 'Current Symptom'),
  sideEffect('side_effect', 'Side Effect');

  const ConditionCategory(this.name, this.displayName);

  final String name;
  final String displayName;
}

enum ConditionSeverity {
  mild('mild', 'Mild', 'Minimal Impact on Daily Life'),
  moderate('moderate', 'Moderate', 'Causing Problems in Daily Life'),
  severe('severe', 'Severe', 'Life-Threatening');

  const ConditionSeverity(this.name, this.displayName, this.description);

  final String name;
  final String displayName;
  final String description;
}

class ConditionEntity {
  final String id;
  final ConditionCategory category;
  final ConditionSeverity severity;
  final String description;
  final String? notes;
  final DateTime timestamp;
  final String? patientId;
  final DateTime? onsetDate;
  final DateTime? abatementDate;

  const ConditionEntity({
    required this.id,
    required this.category,
    required this.severity,
    required this.description,
    required this.timestamp,
    this.notes,
    this.patientId,
    this.onsetDate,
    this.abatementDate,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConditionEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ConditionEntity(id: $id, category: $category, severity: $severity, description: $description)';
  }
}
