import 'dart:math';

import 'condition_entity.dart';
import 'questionnaire_entity.dart';

/// UI-level input model for submitting a single FHIR Condition.
///
/// One instance maps to exactly one FHIR Condition resource.
class ConditionInput {
  /// Local identifier for the entry (used to keep failed items for retry).
  ///
  /// For questionnaire-driven conditions, this is the questionId.
  final String localId;

  /// Stable idempotency key for this condition entry.
  ///
  /// Included as Condition.identifier[0] with system `urn:app:condition-request`.
  /// Keep stable across retries for the same entry.
  final String clientRequestId;

  final FhirCoding coding;
  final ConditionSeverity severity;

  final String patientId;
  final String? encounterId;
  final DateTime recordedDate;

  /// Optional note to attach to the Condition.
  final String? note;

  const ConditionInput({
    required this.localId,
    required this.clientRequestId,
    required this.coding,
    required this.severity,
    required this.patientId,
    required this.recordedDate,
    this.encounterId,
    this.note,
  });

  /// Creates a ConditionInput from a questionnaire answer.
  static ConditionInput fromQuestionResponse({
    required QuestionResponse response,
    required String patientId,
    required DateTime recordedDate,
    required String clientRequestId,
    String? encounterId,
    String? note,
  }) {
    final severity = response.severity;
    if (severity == null) {
      throw ArgumentError(
        'Cannot create ConditionInput from unanswered question',
      );
    }

    return ConditionInput(
      localId: response.questionId,
      clientRequestId: clientRequestId,
      coding: response.coding,
      severity: severity,
      patientId: patientId,
      encounterId: encounterId,
      recordedDate: recordedDate,
      note: note,
    );
  }

  /// FHIR Condition JSON payload (single resource).
  ///
  /// NOTE: Do NOT put multiple conditions into one Condition resource.
  Map<String, dynamic> toFhirConditionJson() {
    return {
      'resourceType': 'Condition',
      'identifier': [
        {'system': 'urn:app:condition-request', 'value': clientRequestId},
      ],
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
          'text': 'Problem List Item',
        },
      ],
      'code': {
        'coding': [coding.toJson()],
        'text': coding.display,
      },
      'subject': {'reference': 'Patient/$patientId'},
      'recordedDate': recordedDate.toIso8601String(),
      'severity': {
        'coding': [
          {
            'system': 'http://snomed.info/sct',
            'code': _mapSeverityToSnomedCode(severity),
            'display': severity.displayName,
          },
        ],
      },
      if (encounterId != null)
        'encounter': {'reference': 'Encounter/$encounterId'},
      if (note != null && note!.trim().isNotEmpty)
        'note': [
          {'text': note!.trim()},
        ],
    };
  }

  static String _mapSeverityToSnomedCode(ConditionSeverity severity) {
    switch (severity) {
      case ConditionSeverity.mild:
        return '255604002';
      case ConditionSeverity.moderate:
        return '6736007';
      case ConditionSeverity.severe:
        return '24484000';
    }
  }

  /// Generates a stable-enough request id for UI entries.
  ///
  /// Callers should persist the returned value for retries.
  static String generateClientRequestId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rnd = Random().nextInt(1 << 32);
    return '$now-$rnd';
  }
}
