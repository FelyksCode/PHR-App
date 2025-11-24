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
    super.patientId,
    super.deviceInfo,
    super.notes,
  });

  factory ObservationModel.fromJson(Map<String, dynamic> json) =>
      _$ObservationModelFromJson(json);

  Map<String, dynamic> toJson() => _$ObservationModelToJson(this);

  factory ObservationModel.fromEntity(ObservationEntity entity) {
    return ObservationModel(
      id: entity.id,
      type: entity.type,
      value: entity.value,
      unit: entity.unit,
      timestamp: entity.timestamp,
      patientId: entity.patientId,
      deviceInfo: entity.deviceInfo,
      notes: entity.notes,
    );
  }

  static ObservationModel create({
    required ObservationType type,
    required double value,
    required String unit,
    String? patientId,
    String? deviceInfo,
    String? notes,
  }) {
    return ObservationModel(
      id: const Uuid().v4(),
      type: type,
      value: value,
      unit: unit,
      timestamp: DateTime.now(),
      patientId: patientId,
      deviceInfo: deviceInfo,
      notes: notes,
    );
  }

  /// Convert to FHIR Observation resource format for backend
  Map<String, dynamic> toFhirJson() {
    final Map<String, String> loincCodes = {
      'body_weight': '29463-7',
      'body_height': '8302-2', 
      'body_temperature': '8310-5',
      'blood_pressure_systolic': '8480-6',
      'blood_pressure_diastolic': '8462-4',
      'oxygen_saturation': '2708-6',
    };

    final Map<String, String> units = {
      'body_weight': 'kg',
      'body_height': 'cm',
      'body_temperature': 'Cel',
      'blood_pressure_systolic': 'mm[Hg]',
      'blood_pressure_diastolic': 'mm[Hg]',
      'oxygen_saturation': '%',
    };

    return {
      'resourceType': 'Observation',
      'id': id,
      'status': 'final',
      'category': [
        {
          'coding': [
            {
              'system': 'http://terminology.hl7.org/CodeSystem/observation-category',
              'code': 'vital-signs',
              'display': 'Vital Signs'
            }
          ]
        }
      ],
      'code': {
        'coding': [
          {
            'system': 'http://loinc.org',
            'code': loincCodes[type.name] ?? '',
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
        'unit': units[type.name] ?? unit,
        'system': 'http://unitsofmeasure.org',
        'code': units[type.name] ?? unit,
      },
      if (deviceInfo != null) 'device': {'display': deviceInfo},
      if (notes != null) 'note': [{'text': notes}],
    };
  }
}