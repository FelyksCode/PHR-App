import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/observation_entity.dart';

part 'observation_model.g.dart';

@JsonSerializable()
class ObservationModel extends ObservationEntity {
  const ObservationModel({
    required super.id,
    required super.type,
    required super.value,
    required super.unit,
    required super.timestamp,
    super.category,
    super.source,
    super.patientId,
    super.deviceInfo,
    super.notes,
  });

  factory ObservationModel.fromJson(Map<String, dynamic> json) =>
      _$ObservationModelFromJson(json);


  factory ObservationModel.fromEntity(ObservationEntity entity) {
    return ObservationModel(
      id: entity.id,
      type: entity.type,
      value: entity.value,
      unit: entity.unit,
      timestamp: entity.timestamp,
      category: entity.category,
      source: entity.source,
      patientId: entity.patientId,
      deviceInfo: entity.deviceInfo,
      notes: entity.notes,
    );
  }

  static ObservationModel create({
    required ObservationType type,
    required double value,
    required String unit,
    ObservationCategory? category,
    DataSource source = DataSource.manual,
    DateTime? timestamp,
    String? patientId,
    String? deviceInfo,
    String? notes,
  }) {
    return ObservationModel(
      id: const Uuid().v4(),
      type: type,
      value: value,
      unit: unit,
      timestamp: timestamp ?? DateTime.now(),
      category: category ?? ObservationCategory.vitalSigns,
      source: source,
      patientId: patientId,
      deviceInfo: deviceInfo,
      notes: notes,
    );
  }

  /// Convert to FHIR Observation resource format for backend
  Map<String, dynamic> toFhirJson() {
    return {
      'resourceType': 'Observation',
      'id': id,
      'status': 'final',
      'category': [
        {
          'coding': [
            {
              'system': 'http://terminology.hl7.org/CodeSystem/observation-category',
              'code': category.code,
              'display': category.display
            }
          ]
        }
      ],
      'code': {
        'coding': [
          {
            'system': 'http://loinc.org',
            'code': type.loincCode,
            'display': type.displayName,
          }
        ]
      },
      'subject': {
        'reference': 'Patient/${patientId ?? 'unknown'}'
      },
      'effectiveDateTime': timestamp.toIso8601String(),
      'valueQuantity': {
        'value': value,
        'unit': unit,
        'system': 'http://unitsofmeasure.org',
        'code': type.standardUnit,
      },
      if (deviceInfo != null) 'device': {'display': deviceInfo},
      if (notes != null) 'note': [{'text': notes}],
      'meta': {
        'tag': [
          {
            'system': 'http://terminology.hl7.org/CodeSystem/v3-ObservationValue',
            'code': source.name,
            'display': source.displayName,
          }
        ]
      },
    };
  }

  /// Create a Blood Pressure Panel observation with systolic and diastolic components
  /// Returns a FHIR observation with the panel structure (code 35094-2)
  static Map<String, dynamic> createBloodPressurePanelFhir({
    required double systolic,
    required double diastolic,
    required String patientId,
    DateTime? timestamp,
    String? notes,
    DataSource source = DataSource.manual,
    ObservationCategory? category,
  }) {
    final effectiveTime = timestamp ?? DateTime.now();
    final categoryVal = category ?? ObservationCategory.vitalSigns;

    return {
      'resourceType': 'Observation',
      'id': const Uuid().v4(),
      'status': 'final',
      'category': [
        {
          'coding': [
            {
              'system': 'http://terminology.hl7.org/CodeSystem/observation-category',
              'code': categoryVal.code,
              'display': categoryVal.display
            }
          ]
        }
      ],
      'code': {
        'coding': [
          {
            'system': 'http://loinc.org',
            'code': '35094-2',
            'display': 'Blood Pressure Panel'
          }
        ],
        'text': 'Blood Pressure Panel'
      },
      'subject': {
        'reference': 'Patient/$patientId'
      },
      'effectiveDateTime': effectiveTime.toIso8601String(),
      'component': [
        {
          'code': {
            'coding': [
              {
                'system': 'http://loinc.org',
                'code': '8480-6',
                'display': 'Systolic Blood Pressure'
              }
            ]
          },
          'valueQuantity': {
            'value': systolic,
            'unit': 'mmHg',
            'system': 'http://unitsofmeasure.org',
            'code': 'mm[Hg]'
          }
        },
        {
          'code': {
            'coding': [
              {
                'system': 'http://loinc.org',
                'code': '8462-4',
                'display': 'Diastolic Blood Pressure'
              }
            ]
          },
          'valueQuantity': {
            'value': diastolic,
            'unit': 'mmHg',
            'system': 'http://unitsofmeasure.org',
            'code': 'mm[Hg]'
          }
        }
      ],
      if (notes != null)
        'note': [
          {'text': notes}
        ],
      'meta': {
        'tag': [
          {
            'system': 'http://terminology.hl7.org/CodeSystem/v3-ObservationValue',
            'code': source.name,
            'display': source.displayName,
          }
        ]
      },
    };
  }
}