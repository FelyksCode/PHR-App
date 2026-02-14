enum ObservationType {
  bodyWeight('body_weight', 'Body Weight', 'Berat badan', '体重'),
  bodyHeight('body_height', 'Body Height', 'Tinggi badan', '身高'),
  bodyTemperature('body_temperature', 'Body Temperature', 'Suhu tubuh', '体温'),
  bloodPressureSystolic(
    'blood_pressure_systolic',
    'Blood Pressure - Systolic',
    'Tekanan Darah - Sistolik',
    '血压 - 收缩压',
  ),
  bloodPressureDiastolic(
    'blood_pressure_diastolic',
    'Blood Pressure - Diastolic',
    'Tekanan Darah - Diastolik',
    '血压 - 舒张压',
  ),
  oxygenSaturation(
    'oxygen_saturation',
    'Oxygen Saturation',
    'Saturasi Oksigen',
    '血氧',
  ),
  heartRate('heart_rate', 'Heart Rate', 'Detak jantung', '心率'),
  respiratoryRate(
    'respiratory_rate',
    'Respiratory Rate',
    'Laju Pernapasan',
    '呼吸频率',
  ),
  steps('steps', 'Steps', 'Langkah', '步数'),
  caloriesBurned(
    'calories_burned',
    'Calories Burned',
    'Kalori Terbakar',
    '燃烧卡路里',
  );

  const ObservationType(
    this.name,
    this.displayName,
    this.displayNameId,
    this.displayNameZh,
  );

  final String name;
  final String displayName;
  final String displayNameId;
  final String displayNameZh;

  /// Get display name based on locale
  String getDisplayName({String locale = 'en'}) {
    switch (locale) {
      case 'id':
        return displayNameId;
      case 'zh':
        return displayNameZh;
      default:
        return displayName;
    }
  }

  /// LOINC codes for FHIR mapping (component-specific codes)
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
      case ObservationType.caloriesBurned:
        return '41670-5';
    }
  }

  /// FHIR panel code for component-based observations
  /// Blood Pressure uses a panel structure with systolic/diastolic as components
  String? get fhirPanelCode {
    switch (this) {
      case ObservationType.bloodPressureSystolic:
      case ObservationType.bloodPressureDiastolic:
        return '35094-2'; // Blood Pressure Panel
      default:
        return null;
    }
  }

  /// Indicates if this observation is part of a component-based panel
  bool get isComponentBased {
    switch (this) {
      case ObservationType.bloodPressureSystolic:
      case ObservationType.bloodPressureDiastolic:
        return true;
      default:
        return false;
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
      case ObservationType.caloriesBurned:
        return 'kcal';
    }
  }
}

enum ObservationCategory {
  vitalSigns('vital-signs', 'Vital Signs'),
  activity('activity', 'Activity'),
  bodyMeasurements('body-measurements', 'Body Measurements'),
  laboratory('laboratory', 'Laboratory');

  const ObservationCategory(this.code, this.display);

  final String code;
  final String display;
}

enum DataSource {
  manual('manual', 'Manual Entry'),
  wearable('wearable', 'Wearable Device'),
  healthKit('health_kit', 'HealthKit'),
  healthConnect('health_connect', 'Health Connect'),
  vendor('vendor', 'Vendor Integration'),
  simulation('simulation', 'Simulation');

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
  final ObservationCategory category;
  final DataSource source;
  final String? patientId;
  final String? deviceInfo;
  final String? notes;

  const ObservationEntity({
    required this.id,
    required this.type,
    required this.value,
    required this.unit,
    required this.timestamp,
    ObservationCategory? category,
    this.source = DataSource.manual,
    this.patientId,
    this.deviceInfo,
    this.notes,
  }) : category = category ?? ObservationCategory.vitalSigns;

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
      'category': category.code,
      'source': source.name,
      'patientId': patientId,
      'deviceInfo': deviceInfo,
      'notes': notes,
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
      category: ObservationCategory.values.firstWhere(
        (e) => e.code == json['category'],
        orElse: () => ObservationCategory.vitalSigns,
      ),
      source: DataSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => DataSource.manual,
      ),
      patientId: json['patientId'] as String?,
      deviceInfo: json['deviceInfo'] as String?,
      notes: json['notes'] as String?,
    );
  }
}
