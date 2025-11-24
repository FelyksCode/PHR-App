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
  Map<String, dynamic> toFhirJson() {
    final Map<String, Map<String, String>> categoryCodes = {
      'current_symptom': {
        'system': 'http://terminology.hl7.org/CodeSystem/condition-category',
        'code': 'problem-list-item',
        'display': 'Problem List Item'
      },
      'side_effect': {
        'system': 'http://snomed.info/sct',
        'code': '420134006',
        'display': 'Propensity to adverse reactions'
      }
    };

    final Map<String, Map<String, String>> severityCodes = {
      'mild': {
        'system': 'http://snomed.info/sct',
        'code': '255604002',
        'display': 'Mild'
      },
      'moderate': {
        'system': 'http://snomed.info/sct',
        'code': '6736007',
        'display': 'Moderate'
      },
      'severe': {
        'system': 'http://snomed.info/sct',
        'code': '24484000',
        'display': 'Severe'
      }
    };

    return {
      'resourceType': 'Condition',
      'id': id,
      'clinicalStatus': {
        'coding': [
          {
            'system': 'http://terminology.hl7.org/CodeSystem/condition-clinical',
            'code': 'active',
            'display': 'Active'
          }
        ]
      },
      'verificationStatus': {
        'coding': [
          {
            'system': 'http://terminology.hl7.org/CodeSystem/condition-ver-status',
            'code': 'confirmed',
            'display': 'Confirmed'
          }
        ]
      },
      'category': [
        {
          'coding': [categoryCodes[category.name] ?? {}]
        }
      ],
      'severity': {
        'coding': [severityCodes[severity.name] ?? {}]
      },
      'code': {
        'text': description
      },
      'subject': {
        'reference': 'Patient/${patientId ?? 'unknown'}'
      },
      'recordedDate': timestamp.toIso8601String(),
      if (onsetDate != null) 'onsetDateTime': onsetDate!.toIso8601String(),
      if (abatementDate != null) 'abatementDateTime': abatementDate!.toIso8601String(),
      if (notes != null) 'note': [{'text': notes}],
    };
  }
}