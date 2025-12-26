import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/questionnaire_entity.dart';
import '../../domain/entities/questionnaire_definitions.dart';
import '../../domain/entities/condition_entity.dart';

/// Provider for all current symptom questions
final currentSymptomsQuestionsProvider = Provider<List<QuestionDefinition>>((ref) {
  return QuestionnaireDefinitions.currentSymptomsQuestions;
});

/// Provider for all side effects questions
final sideEffectsQuestionsProvider = Provider<List<QuestionDefinition>>((ref) {
  return QuestionnaireDefinitions.sideEffectsQuestions;
});

/// Provider for questionnaire submission state
final questionnaireSubmittingProvider = StateProvider<bool>((ref) => false);

/// Manages questionnaire responses state
class QuestionnaireResponseNotifier extends StateNotifier<QuestionnaireResponse> {
  QuestionnaireResponseNotifier()
      : super(
          QuestionnaireResponse(
            responses: [],
            timestamp: DateTime.now(),
          ),
        ) {
    _initializeQuestions();
  }

  void _initializeQuestions() {
    final allQuestions = [
      ...QuestionnaireDefinitions.currentSymptomsQuestions,
      ...QuestionnaireDefinitions.sideEffectsQuestions,
    ];

    final initialResponses = allQuestions.map((q) {
      return QuestionResponse(
        questionId: q.id,
        questionLabel: q.label,
        category: q.category,
        coding: q.coding,
        severity: null,
      );
    }).toList();

    state = QuestionnaireResponse(
      responses: initialResponses,
      timestamp: DateTime.now(),
      notes: state.notes,
      patientId: state.patientId,
      encounterId: state.encounterId,
    );
  }

  /// Update severity for a specific question
  void setSeverity(String questionId, ConditionSeverity? severity) {
    final updatedResponses = state.responses.map((r) {
      if (r.questionId == questionId) {
        return QuestionResponse(
          questionId: r.questionId,
          questionLabel: r.questionLabel,
          category: r.category,
          coding: r.coding,
          severity: severity,
        );
      }
      return r;
    }).toList();

    state = state.copyWith(responses: updatedResponses);
  }

  /// Update notes for the questionnaire
  void setNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  /// Set patient and encounter IDs
  void setMetadata(String patientId, String? encounterId) {
    state = state.copyWith(
      patientId: patientId,
      encounterId: encounterId,
    );
  }

  /// Reset all responses
  void reset() {
    _initializeQuestions();
  }

  /// Clear a specific question's response
  void clearQuestion(String questionId) {
    setSeverity(questionId, null);
  }

  /// Get count of answered questions in a category
  int getAnsweredCountByCategory(String category) {
    return state.getAnsweredByCategory(category).length;
  }

  /// Get total count of questions in a category
  int getTotalCountByCategory(String category) {
    return state.getResponsesByCategory(category).length;
  }
}

/// State provider for questionnaire responses
final questionnaireResponseProvider =
    StateNotifierProvider<QuestionnaireResponseNotifier, QuestionnaireResponse>(
  (ref) => QuestionnaireResponseNotifier(),
);

/// Computed provider: answered questions count by category
final answeredCountCurrentProvider = Provider<int>((ref) {
  final response = ref.watch(questionnaireResponseProvider);
  return response.getAnsweredByCategory('current_symptom').length;
});

final answeredCountSideEffectsProvider = Provider<int>((ref) {
  final response = ref.watch(questionnaireResponseProvider);
  return response.getAnsweredByCategory('side_effect').length;
});

/// Computed provider: total answered questions
final totalAnsweredProvider = Provider<int>((ref) {
  final response = ref.watch(questionnaireResponseProvider);
  return response.answeredQuestions.length;
});

/// Computed provider: validation - whether any question is answered
final hasAnswersProvider = Provider<bool>((ref) {
  final response = ref.watch(questionnaireResponseProvider);
  return response.answeredQuestions.isNotEmpty;
});

/// Computed provider: answered questions by category
final answeredCurrentProvider = Provider<List<QuestionResponse>>((ref) {
  final response = ref.watch(questionnaireResponseProvider);
  return response.getAnsweredByCategory('current_symptom');
});

final answeredSideEffectsProvider = Provider<List<QuestionResponse>>((ref) {
  final response = ref.watch(questionnaireResponseProvider);
  return response.getAnsweredByCategory('side_effect');
});
