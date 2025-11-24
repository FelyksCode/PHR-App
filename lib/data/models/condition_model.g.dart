// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'condition_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConditionModel _$ConditionModelFromJson(Map<String, dynamic> json) =>
    ConditionModel(
      id: json['id'] as String,
      category: $enumDecode(_$ConditionCategoryEnumMap, json['category']),
      severity: $enumDecode(_$ConditionSeverityEnumMap, json['severity']),
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      notes: json['notes'] as String?,
      patientId: json['patientId'] as String?,
      onsetDate: json['onsetDate'] == null
          ? null
          : DateTime.parse(json['onsetDate'] as String),
      abatementDate: json['abatementDate'] == null
          ? null
          : DateTime.parse(json['abatementDate'] as String),
    );

Map<String, dynamic> _$ConditionModelToJson(ConditionModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'category': _$ConditionCategoryEnumMap[instance.category]!,
      'severity': _$ConditionSeverityEnumMap[instance.severity]!,
      'description': instance.description,
      'notes': instance.notes,
      'timestamp': instance.timestamp.toIso8601String(),
      'patientId': instance.patientId,
      'onsetDate': instance.onsetDate?.toIso8601String(),
      'abatementDate': instance.abatementDate?.toIso8601String(),
    };

const _$ConditionCategoryEnumMap = {
  ConditionCategory.currentSymptom: 'currentSymptom',
  ConditionCategory.sideEffect: 'sideEffect',
};

const _$ConditionSeverityEnumMap = {
  ConditionSeverity.mild: 'mild',
  ConditionSeverity.moderate: 'moderate',
  ConditionSeverity.severe: 'severe',
};
