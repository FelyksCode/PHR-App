enum ObservationType {
  bodyWeight('body_weight', 'Body Weight'),
  bodyHeight('body_height', 'Body Height'),
  bodyTemperature('body_temperature', 'Body Temperature'),
  bloodPressureSystolic('blood_pressure_systolic', 'Blood Pressure Systolic'),
  bloodPressureDiastolic('blood_pressure_diastolic', 'Blood Pressure Diastolic'),
  oxygenSaturation('oxygen_saturation', 'Oxygen Saturation'),
  heartRate('heart_rate', 'Heart Rate'),
  respiratoryRate('respiratory_rate', 'Respiratory Rate'),
  steps('steps', 'Steps');

  const ObservationType(this.name, this.displayName);
  
  final String name;
  final String displayName;

  /// LOINC codes for FHIR mapping
  String get loincCode {
    switch (this) {
      case ObservationType.bodyWeight:
        return '29463-7';
      case ObservationType.bodyHeight:
        return '8302-2';
      case ObservationType.bodyTemperature:
        return '8310-5';
      case ObservationType.bloodPressureSystolic:
        return '8480-6';
      case ObservationType.bloodPressureDiastolic:
        return '8462-4';
      case ObservationType.oxygenSaturation:
        return '59408-5';
      case ObservationType.heartRate:
        return '8867-4';
      case ObservationType.respiratoryRate:
        return '9279-1';
      case ObservationType.steps:
        return '55423-8';
    }
  }

  /// Standard units for each observation type
  String get standardUnit {
    switch (this) {
      case ObservationType.bodyWeight:
        return 'kg';
      case ObservationType.bodyHeight:
        return 'cm';
      case ObservationType.bodyTemperature:
        return 'Cel';
      case ObservationType.bloodPressureSystolic:
      case ObservationType.bloodPressureDiastolic:
        return 'mm[Hg]';
      case ObservationType.oxygenSaturation:
        return '%';
      case ObservationType.heartRate:
        return '/min';
      case ObservationType.respiratoryRate:
        return '/min';
      case ObservationType.steps:
        return '1';
    }
  }
}

enum DataSource {
  manual('manual', 'Manual Entry'),
  healthKit('health_kit', 'HealthKit'),
  healthConnect('health_connect', 'Health Connect');

  const DataSource(this.name, this.displayName);
  
  final String name;
  final String displayName;
}

class ObservationEntity {
  final String id;
  final ObservationType type;
  final double value;
  final String unit;
  final DateTime timestamp;
  final String? patientId;
  final String? deviceInfo;
  final String? notes;
  final DataSource source;

  const ObservationEntity({
    required this.id,
    required this.type,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.patientId,
    this.deviceInfo,
    this.notes,
    this.source = DataSource.manual,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ObservationEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ObservationEntity(id: $id, type: $type, value: $value, unit: $unit, timestamp: $timestamp)';
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'value': value,
      'unit': unit,
      'timestamp': timestamp.toIso8601String(),
      'patientId': patientId,
      'deviceInfo': deviceInfo,
      'notes': notes,
      'source': source.name,
    };
  }

  factory ObservationEntity.fromJson(Map<String, dynamic> json) {
    return ObservationEntity(
      id: json['id'] as String,
      type: ObservationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ObservationType.bodyWeight,
      ),
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      patientId: json['patientId'] as String?,
      deviceInfo: json['deviceInfo'] as String?,
      notes: json['notes'] as String?,
      source: DataSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => DataSource.manual,
      ),
    );
  }
}