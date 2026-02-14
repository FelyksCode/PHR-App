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

Map<String, dynamic> _$ObservationModelToJson(ObservationModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$ObservationTypeEnumMap[instance.type]!,
      'value': instance.value,
      'unit': instance.unit,
      'timestamp': instance.timestamp.toIso8601String(),
      'category': _$ObservationCategoryEnumMap[instance.category]!,
      'source': _$DataSourceEnumMap[instance.source]!,
      'patientId': instance.patientId,
      'deviceInfo': instance.deviceInfo,
      'notes': instance.notes,
    };

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
  ObservationType.caloriesBurned: 'caloriesBurned',
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
  DataSource.vendor: 'vendor',
};
