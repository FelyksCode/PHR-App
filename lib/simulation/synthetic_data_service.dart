import '../domain/entities/condition_entity.dart';
import '../domain/entities/questionnaire_definitions.dart';
import '../domain/entities/questionnaire_entity.dart';
import 'simulation_profile.dart';

/// Generates synthetic (research/testing-only) symptom + side-effect data.
///
/// This service is pure: it does not perform any persistence or networking.
class SyntheticDataService {
  const SyntheticDataService();

  /// Synthetic "conditions" for this app map to questionnaire side effects.
  List<QuestionResponse> generateSyntheticConditions({
    required SimulationProfile profile,
  }) {
    final questions = QuestionnaireDefinitions.sideEffectsQuestions;

    final count = switch (profile.profileId) {
      'stable_outpatient' => 1,
      'treatment_side_effect' => 3,
      'high_risk_outpatient' => 4,
      _ => 2,
    };

    final severity = switch (profile.profileId) {
      'stable_outpatient' => ConditionSeverity.mild,
      'treatment_side_effect' => ConditionSeverity.moderate,
      'high_risk_outpatient' => ConditionSeverity.severe,
      _ => ConditionSeverity.moderate,
    };

    return _pickQuestions(questions, profile.profileId, count)
        .map((q) => _answered(q, severity))
        .toList();
  }

  /// Synthetic "symptoms" map to questionnaire current symptoms.
  List<QuestionResponse> generateSyntheticSymptoms({
    required SimulationProfile profile,
  }) {
    final questions = QuestionnaireDefinitions.currentSymptomsQuestions;

    final count = switch (profile.profileId) {
      'stable_outpatient' => 2,
      'treatment_side_effect' => 3,
      'high_risk_outpatient' => 5,
      _ => 3,
    };

    // Use profile baseline as the default symptom severity.
    final severity = profile.symptomSeverityBaseline;

    return _pickQuestions(questions, profile.profileId, count)
        .map((q) => _answered(q, severity))
        .toList();
  }

  QuestionnaireResponse buildCombinedResponse({
    required SimulationProfile profile,
    required DateTime timestamp,
    required String patientId,
    String? note,
  }) {
    final conditions = generateSyntheticConditions(profile: profile);
    final symptoms = generateSyntheticSymptoms(profile: profile);

    return QuestionnaireResponse(
      responses: [...conditions, ...symptoms],
      timestamp: timestamp,
      notes: note,
      patientId: patientId,
    );
  }

  List<QuestionDefinition> _pickQuestions(
    List<QuestionDefinition> pool,
    String seed,
    int count,
  ) {
    if (pool.isEmpty || count <= 0) return const [];

    // Deterministic selection based on the profile id.
    final seedValue = seed.codeUnits.fold<int>(0, (acc, c) => acc + c);
    final start = seedValue % pool.length;

    final picked = <QuestionDefinition>[];
    for (var i = 0; i < count; i++) {
      picked.add(pool[(start + i) % pool.length]);
    }
    return picked;
  }

  QuestionResponse _answered(QuestionDefinition q, ConditionSeverity severity) {
    return QuestionResponse(
      questionId: q.id,
      questionLabel: q.label,
      category: q.category,
      coding: q.coding,
      severity: severity,
    );
  }
}
