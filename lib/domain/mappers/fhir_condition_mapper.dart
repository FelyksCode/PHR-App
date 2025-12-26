import '../entities/questionnaire_entity.dart';
import '../entities/condition_entity.dart';

/// Converts questionnaire responses to FHIR Condition resources
class FhirConditionMapper {
  /// Map FHIR severity to ConditionSeverity
  static ConditionSeverity mapSeverity(String severity) {
    return ConditionSeverity.values.firstWhere(
      (s) => s.name == severity,
      orElse: () => ConditionSeverity.mild,
    );
  }

  /// Convert a single question response to a FHIR Condition resource JSON
  static Map<String, dynamic> questionResponseToFhirCondition(
    QuestionResponse response,
    String? patientId,
    DateTime recordedDate,
    String? encounterId,
  ) {
    if (response.severity == null) {
      throw ArgumentError(
        'Cannot map unanswered question to FHIR Condition: ${response.questionId}',
      );
    }

    return {
      'resourceType': 'Condition',
      'clinicalStatus': {
        'coding': [
          {
            'system':
                'http://terminology.hl7.org/CodeSystem/condition-clinical',
            'code': 'active',
            'display': 'Active',
          },
        ],
        'text': 'Active',
      },
      'verificationStatus': {
        'coding': [
          {
            'system':
                'http://terminology.hl7.org/CodeSystem/condition-ver-status',
            'code': 'unconfirmed',
            'display': 'Unconfirmed',
          },
        ],
      },
      'category': [
        {
          'coding': [
            {
              'system': 'http://hl7.org/fhir/condition-category',
              'code': 'problem-list-item',
              'display': 'Problem List Item',
            },
          ],
          "text": "Problem List Item",
        },
      ],
      'code': {
        'coding': [response.coding.toJson()],
        'text': response.coding.display,
      },
      'subject': {'reference': 'Patient/$patientId'},
      'recordedDate': recordedDate.toIso8601String(),
      'severity': {
        'coding': [
          {
            'system': 'http://snomed.info/sct',
            'code': _mapSeverityToSnomedCode(response.severity!),
            'display': response.severity!.displayName,
          },
        ],
      },
      if (encounterId != null)
        'encounter': {'reference': 'Encounter/$encounterId'},
    };
  }

  /// Map ConditionSeverity to SNOMED code for severity
  static String _mapSeverityToSnomedCode(ConditionSeverity severity) {
    switch (severity) {
      case ConditionSeverity.mild:
        return '255604002'; // SNOMED code for mild
      case ConditionSeverity.moderate:
        return '6736007'; // SNOMED code for moderate
      case ConditionSeverity.severe:
        return '24484000'; // SNOMED code for severe
    }
  }

  /// Convert entire questionnaire response to FHIR Bundle with multiple Condition resources
  static Map<String, dynamic> questionnaireResponseToFhirBundle(
    QuestionnaireResponse response,
    String patientId,
  ) {
    final answeredQuestions = response.answeredQuestions;

    if (answeredQuestions.isEmpty) {
      throw ArgumentError('No answered questions to submit');
    }

    final conditions = answeredQuestions.map((q) {
      return {
        'fullUrl': 'urn:uuid:condition-${q.questionId}',
        'resource': questionResponseToFhirCondition(
          q,
          patientId,
          response.timestamp,
          response.encounterId,
        ),
        'request': {'method': 'POST', 'url': 'Condition'},
      };
    }).toList();

    return {
      'resourceType': 'Bundle',
      'type': 'transaction',
      'entry': conditions,
    };
  }
}
