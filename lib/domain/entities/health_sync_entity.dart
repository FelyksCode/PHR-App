import 'observation_entity.dart';

enum HealthDataType {
  heartRate,
  bodyTemperature,
  oxygenSaturation,
  bloodPressureSystolic,
  bloodPressureDiastolic,
  bodyWeight,
  bodyHeight,
  respiratoryRate,
  steps;

  String get displayName {
    switch (this) {
      case HealthDataType.heartRate:
        return 'Heart Rate';
      case HealthDataType.bodyTemperature:
        return 'Body Temperature';
      case HealthDataType.oxygenSaturation:
        return 'Oxygen Saturation';
      case HealthDataType.bloodPressureSystolic:
        return 'Blood Pressure (Systolic)';
      case HealthDataType.bloodPressureDiastolic:
        return 'Blood Pressure (Diastolic)';
      case HealthDataType.bodyWeight:
        return 'Body Weight';
      case HealthDataType.bodyHeight:
        return 'Body Height';
      case HealthDataType.respiratoryRate:
        return 'Respiratory Rate';
      case HealthDataType.steps:
        return 'Steps';
    }
  }

  ObservationType get observationType {
    switch (this) {
      case HealthDataType.heartRate:
        return ObservationType.heartRate;
      case HealthDataType.bodyTemperature:
        return ObservationType.bodyTemperature;
      case HealthDataType.oxygenSaturation:
        return ObservationType.oxygenSaturation;
      case HealthDataType.bloodPressureSystolic:
        return ObservationType.bloodPressureSystolic;
      case HealthDataType.bloodPressureDiastolic:
        return ObservationType.bloodPressureDiastolic;
      case HealthDataType.bodyWeight:
        return ObservationType.bodyWeight;
      case HealthDataType.bodyHeight:
        return ObservationType.bodyHeight;
      case HealthDataType.respiratoryRate:
        return ObservationType.respiratoryRate;
      case HealthDataType.steps:
        return ObservationType.steps;
    }
  }
}

enum SyncStatus {
  idle,
  syncing,
  success,
  failed,
  permissionDenied,
  noData;

  String get displayName {
    switch (this) {
      case SyncStatus.idle:
        return 'Ready to Sync';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.success:
        return 'Sync Successful';
      case SyncStatus.failed:
        return 'Sync Failed';
      case SyncStatus.permissionDenied:
        return 'Permission Denied';
      case SyncStatus.noData:
        return 'No New Data';
    }
  }
}

class HealthSyncEntity {
  final DateTime? lastSyncTime;
  final SyncStatus status;
  final int totalSyncedObservations;
  final String? errorMessage;
  final List<HealthDataType> permittedDataTypes;

  const HealthSyncEntity({
    this.lastSyncTime,
    this.status = SyncStatus.idle,
    this.totalSyncedObservations = 0,
    this.errorMessage,
    this.permittedDataTypes = const [],
  });

  HealthSyncEntity copyWith({
    DateTime? lastSyncTime,
    SyncStatus? status,
    int? totalSyncedObservations,
    String? errorMessage,
    List<HealthDataType>? permittedDataTypes,
  }) {
    return HealthSyncEntity(
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      status: status ?? this.status,
      totalSyncedObservations: totalSyncedObservations ?? this.totalSyncedObservations,
      errorMessage: errorMessage ?? this.errorMessage,
      permittedDataTypes: permittedDataTypes ?? this.permittedDataTypes,
    );
  }
}

class HealthDataPoint {
  final HealthDataType type;
  final double value;
  final String unit;
  final DateTime timestamp;
  final String? deviceInfo;

  const HealthDataPoint({
    required this.type,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.deviceInfo,
  });
}