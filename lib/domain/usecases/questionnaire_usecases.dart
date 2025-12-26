import '../entities/questionnaire_entity.dart';
import '../entities/questionnaire_definitions.dart';
import '../repositories/health_data_repository.dart';
import '../mappers/fhir_condition_mapper.dart';

/// Submit a questionnaire response as FHIR Condition resources
class SubmitQuestionnaireUseCase {
  final HealthDataRepository _repository;

  SubmitQuestionnaireUseCase(this._repository);

  /// Execute submission of questionnaire responses
  /// Returns true if all conditions were successfully submitted
  Future<bool> execute({
    required QuestionnaireResponse response,
    required String patientId,
  }) async {
    // Validate that there are answered questions
    final answeredQuestions = response.answeredQuestions;
    if (answeredQuestions.isEmpty) {
      throw ArgumentError('No answered questions to submit');
    }

    // Convert to FHIR Bundle
    final fhirBundle = FhirConditionMapper.questionnaireResponseToFhirBundle(
      response,
      patientId,
    );

    // Submit to backend
    return await _repository.submitFhirBundle(fhirBundle);
  }
}

/// Retrieve questionnaire definitions
class GetQuestionnaireDefinitionsUseCase {
  /// Get all questions for a specific category
  List<QuestionDefinition> executeByCategory(String category) {
    if (category == 'current_symptom') {
      return QuestionnaireDefinitions.currentSymptomsQuestions;
    } else if (category == 'side_effect') {
      return QuestionnaireDefinitions.sideEffectsQuestions;
    }
    return [];
  }

  /// Get all questions
  List<QuestionDefinition> executeAll() {
    return [
      ...QuestionnaireDefinitions.currentSymptomsQuestions,
      ...QuestionnaireDefinitions.sideEffectsQuestions,
    ];
  }
}
