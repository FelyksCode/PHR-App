import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/condition_entity.dart';

part 'condition_model.g.dart';

@JsonSerializable()
class ConditionModel extends ConditionEntity {
  const ConditionModel({
    required super.id,
    required super.category,
    required super.severity,
    required super.description,
    required super.timestamp,
    super.notes,
    super.patientId,
    super.onsetDate,
    super.abatementDate,
  });

  factory ConditionModel.fromJson(Map<String, dynamic> json) =>
      _$ConditionModelFromJson(json);

  Map<String, dynamic> toJson() => _$ConditionModelToJson(this);

  factory ConditionModel.fromEntity(ConditionEntity entity) {
    return ConditionModel(
      id: entity.id,
      category: entity.category,
      severity: entity.severity,
      description: entity.description,
      timestamp: entity.timestamp,
      notes: entity.notes,
      patientId: entity.patientId,
      onsetDate: entity.onsetDate,
      abatementDate: entity.abatementDate,
    );
  }

  static ConditionModel create({
    required ConditionCategory category,
    required ConditionSeverity severity,
    required String description,
    String? notes,
    String? patientId,
    DateTime? onsetDate,
    DateTime? abatementDate,
  }) {
    return ConditionModel(
      id: const Uuid().v4(),
      category: category,
      severity: severity,
      description: description,
      timestamp: DateTime.now(),
      notes: notes,
      patientId: patientId,
      onsetDate: onsetDate,
      abatementDate: abatementDate,
    );
  }

  /// Convert to FHIR Condition resource format for backend
  /// Optimized to work with backend defaults - only sends required fields
  Map<String, dynamic> toFhirJson() {
    // Map common conditions to SNOMED codes
    final Map<String, Map<String, String>> conditionCodes = {
      'fatigue': {
        'system': 'http://snomed.info/sct',
        'code': '84229001',
        'display': 'Fatigue',
      },
      'headache': {
        'system': 'http://snomed.info/sct',
        'code': '25064002',
        'display': 'Headache',
      },
      'nausea': {
        'system': 'http://snomed.info/sct',
        'code': '422587007',
        'display': 'Nausea',
      },
      'dizziness': {
        'system': 'http://snomed.info/sct',
        'code': '404684003',
        'display': 'Dizziness',
      },
      'fever': {
        'system': 'http://snomed.info/sct',
        'code': '386661006',
        'display': 'Fever',
      },
      'cough': {
        'system': 'http://snomed.info/sct',
        'code': '49727002',
        'display': 'Cough',
      },
      'pain': {
        'system': 'http://snomed.info/sct',
        'code': '22253000',
        'display': 'Pain',
      },
      'shortness of breath': {
        'system': 'http://snomed.info/sct',
        'code': '267036007',
        'display': 'Dyspnea',
      },
      'chest pain': {
        'system': 'http://snomed.info/sct',
        'code': '29857009',
        'display': 'Chest pain',
      },
      'abdominal pain': {
        'system': 'http://snomed.info/sct',
        'code': '21522001',
        'display': 'Abdominal pain',
      },
    };

    // Map severity to SNOMED codes as per specification
    final Map<String, Map<String, String>> severityCodes = {
      'mild': {
        'system': 'http://snomed.info/sct',
        'code': '255604002',
        'display': 'Mild',
      },
      'moderate': {
        'system': 'http://snomed.info/sct',
        'code': '6736007',
        'display': 'Moderate',
      },
      'severe': {
        'system': 'http://snomed.info/sct',
        'code': '24484000',
        'display': 'Severe',
      },
    };

    // Try to find SNOMED code for the condition description
    final descriptionLower = description.toLowerCase();
    final conditionCode = conditionCodes[descriptionLower];

    // Build the complete FHIR resource matching backend specification
    final Map<String, dynamic> fhirResource = {
      'resourceType': 'Condition',

      // Core condition identification with proper FHIR coding structure
      'code': conditionCode != null
          ? {
              'coding': [conditionCode],
              'text': conditionCode['display'] ?? description,
            }
          : {'text': description},

      // Clinical status - always active for new conditions
      'clinicalStatus': {
        'coding': [
          {
            'system':
                'http://terminology.hl7.org/CodeSystem/condition-clinical',
            'code': 'active',
            'display': 'Active',
          },
        ],
      },

      // Category - problem list item for symptoms/conditions
      'category': [
        {
          'coding': [
            {
              'system':
                  'http://terminology.hl7.org/CodeSystem/condition-category',
              'code': 'problem-list-item',
              'display': 'Problem List Item',
            },
          ],
        },
      ],

      // Severity with SNOMED coding
      'severity': {
        'coding': [severityCodes[severity.name] ?? severityCodes['mild']!],
      },

      // Timing information with ISO 8601 format
      'onsetDateTime':
          onsetDate?.toIso8601String() ?? timestamp.toIso8601String(),
      'recordedDate': timestamp.toIso8601String(),
    };

    // Only include subject if we have a specific patient ID
    // Backend will automatically set subject from current user if not provided
    if (patientId != null && patientId!.isNotEmpty && patientId != 'unknown') {
      fhirResource['subject'] = {'reference': 'Patient/$patientId'};
    }

    // Only include notes if present
    if (notes != null && notes!.isNotEmpty) {
      fhirResource['note'] = [
        {'text': notes},
      ];
    }

    // Let backend handle default clinicalStatus and category
    // This reduces payload size and avoids potential conflicts
    // Backend will set:
    // - clinicalStatus: active (default)
    // - category: problem-list-item (default)

    return fhirResource;
  }
}
