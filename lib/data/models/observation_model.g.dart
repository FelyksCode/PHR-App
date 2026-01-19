// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'observation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ObservationModel _$ObservationModelFromJson(Map<String, dynamic> json) =>
    ObservationModel(
      id: json['id'] as String,
      type: $enumDecode(_$ObservationTypeEnumMap, json['type']),
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      category: $enumDecodeNullable(
        _$ObservationCategoryEnumMap,
        json['category'],
      ),
      source:
          $enumDecodeNullable(_$DataSourceEnumMap, json['source']) ??
          DataSource.manual,
      patientId: json['patientId'] as String?,
      deviceInfo: json['deviceInfo'] as String?,
      notes: json['notes'] as String?,
    );

const _$ObservationTypeEnumMap = {
  ObservationType.bodyWeight: 'bodyWeight',
  ObservationType.bodyHeight: 'bodyHeight',
  ObservationType.bodyTemperature: 'bodyTemperature',
  ObservationType.bloodPressureSystolic: 'bloodPressureSystolic',
  ObservationType.bloodPressureDiastolic: 'bloodPressureDiastolic',
  ObservationType.oxygenSaturation: 'oxygenSaturation',
  ObservationType.heartRate: 'heartRate',
  ObservationType.respiratoryRate: 'respiratoryRate',
  ObservationType.steps: 'steps',
};

const _$ObservationCategoryEnumMap = {
  ObservationCategory.vitalSigns: 'vitalSigns',
  ObservationCategory.activity: 'activity',
  ObservationCategory.bodyMeasurements: 'bodyMeasurements',
  ObservationCategory.laboratory: 'laboratory',
};

const _$DataSourceEnumMap = {
  DataSource.manual: 'manual',
  DataSource.wearable: 'wearable',
  DataSource.healthKit: 'healthKit',
  DataSource.healthConnect: 'healthConnect',
  DataSource.vendor: 'vendor',
};
