import 'condition_entity.dart';

/// Represents a single question in a clinical questionnaire
class QuestionDefinition {
  final String id;
  final String label;
  final String category; // 'current_symptom' or 'side_effect'
  final FhirCoding coding;

  const QuestionDefinition({
    required this.id,
    required this.label,
    required this.category,
    required this.coding,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuestionDefinition && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// FHIR coding system and code for a condition
class FhirCoding {
  final String system;
  final String code;
  final String display;

  const FhirCoding({
    required this.system,
    required this.code,
    required this.display,
  });

  Map<String, dynamic> toJson() {
    return {
      'system': system,
      'code': code,
      'display': display,
    };
  }
}

/// User's response to a single questionnaire question
class QuestionResponse {
  final String questionId;
  final ConditionSeverity? severity;
  final String questionLabel;
  final String category;
  final FhirCoding coding;

  const QuestionResponse({
    required this.questionId,
    required this.questionLabel,
    required this.category,
    required this.coding,
    this.severity,
  });

  bool get isAnswered => severity != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuestionResponse && other.questionId == questionId;
  }

  @override
  int get hashCode => questionId.hashCode;

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'questionLabel': questionLabel,
      'category': category,
      'severity': severity?.name,
      'coding': coding.toJson(),
    };
  }
}

/// Container for all questionnaire responses
class QuestionnaireResponse {
  final List<QuestionResponse> responses;
  final String? notes; // Optional notes for the entire questionnaire
  final DateTime timestamp;
  final String? patientId;
  final String? encounterId;

  const QuestionnaireResponse({
    required this.responses,
    required this.timestamp,
    this.notes,
    this.patientId,
    this.encounterId,
  });

  /// Get only answered questions (severity was selected)
  List<QuestionResponse> get answeredQuestions =>
      responses.where((r) => r.isAnswered).toList();

  /// Filter responses by category
  List<QuestionResponse> getResponsesByCategory(String category) =>
      responses.where((r) => r.category == category).toList();

  /// Get answered questions by category
  List<QuestionResponse> getAnsweredByCategory(String category) =>
      answeredQuestions.where((r) => r.category == category).toList();

  Map<String, dynamic> toJson() {
    return {
      'responses': responses.map((r) => r.toJson()).toList(),
      'notes': notes,
      'timestamp': timestamp.toIso8601String(),
      'patientId': patientId,
      'encounterId': encounterId,
    };
  }

  /// Create a copy with modified fields
  QuestionnaireResponse copyWith({
    List<QuestionResponse>? responses,
    String? notes,
    DateTime? timestamp,
    String? patientId,
    String? encounterId,
  }) {
    return QuestionnaireResponse(
      responses: responses ?? this.responses,
      notes: notes ?? this.notes,
      timestamp: timestamp ?? this.timestamp,
      patientId: patientId ?? this.patientId,
      encounterId: encounterId ?? this.encounterId,
    );
  }
}
