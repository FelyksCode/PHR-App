import 'package:health/health.dart' as health_pkg;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

import '../../domain/repositories/health_sync_repository.dart';
import '../../domain/entities/health_sync_entity.dart';
import '../../domain/entities/observation_entity.dart';
import '../models/observation_model.dart';
import '../../services/api_service.dart';

class HealthSyncRepositoryImpl implements HealthSyncRepository {
  final ApiService _apiService;
  final health_pkg.Health _health = health_pkg.Health();
  
  // Sync status storage key
  static const String _syncStatusKey = 'health_sync_status';
  static const String _lastSyncKey = 'last_sync_timestamp';
  
  HealthSyncRepositoryImpl(this._apiService);

  @override
  Future<bool> requestPermissions(List<HealthDataType> dataTypes) async {
    try {
      // Convert to platform health types
      final healthTypes = _convertToHealthTypes(dataTypes);
      
      if (Platform.isAndroid) {
        // Request Health Connect permissions
        final hasPermissions = await _health.hasPermissions(
          healthTypes,
          permissions: healthTypes.map((type) => 
            health_pkg.HealthDataAccess.READ).toList(),
        ) ?? false;
        
        if (!hasPermissions) {
          return await _health.requestAuthorization(
            healthTypes,
            permissions: healthTypes.map((type) => 
              health_pkg.HealthDataAccess.READ).toList(),
          );
        }
        return true;
      } else if (Platform.isIOS) {
        // Request HealthKit permissions
        return await _health.requestAuthorization(
          healthTypes,
          permissions: healthTypes.map((type) => 
            health_pkg.HealthDataAccess.READ).toList(),
        );
      }
      
      return false;
    } catch (e) {
      print('Error requesting health permissions: $e');
      return false;
    }
  }

  @override
  Future<bool> hasPermissions(List<HealthDataType> dataTypes) async {
    try {
      final healthTypes = _convertToHealthTypes(dataTypes);
      return await _health.hasPermissions(
        healthTypes,
        permissions: healthTypes.map((type) => 
          health_pkg.HealthDataAccess.READ).toList(),
      ) ?? false;
    } catch (e) {
      print('Error checking health permissions: $e');
      return false;
    }
  }

  @override
  Future<List<HealthDataPoint>> getHealthData({
    required List<HealthDataType> dataTypes,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final healthTypes = _convertToHealthTypes(dataTypes);
      final healthData = await _health.getHealthDataFromTypes(
        types: healthTypes,
        startTime: startDate,
        endTime: endDate,
      );

      return _convertToHealthDataPoints(healthData);
    } catch (e) {
      print('Error getting health data: $e');
      return [];
    }
  }

  @override
  Future<List<HealthDataPoint>> getDeltaHealthData({
    required List<HealthDataType> dataTypes,
    required DateTime since,
  }) async {
    return await getHealthData(
      dataTypes: dataTypes,
      startDate: since,
      endDate: DateTime.now(),
    );
  }

  @override
  Future<HealthSyncEntity> getSyncStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statusJson = prefs.getString(_syncStatusKey);
      final lastSyncTimestamp = prefs.getInt(_lastSyncKey);
      
      if (statusJson != null) {
        final statusMap = json.decode(statusJson) as Map<String, dynamic>;
        return HealthSyncEntity(
          status: SyncStatus.values.firstWhere(
            (e) => e.toString() == statusMap['status'],
            orElse: () => SyncStatus.idle,
          ),
          lastSyncTime: lastSyncTimestamp != null 
            ? DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp)
            : null,
          permittedDataTypes: (statusMap['permittedDataTypes'] as List<dynamic>?)
            ?.map((e) => HealthDataType.values.firstWhere(
              (type) => type.toString() == e,
              orElse: () => HealthDataType.heartRate,
            ))
            .toList() ?? [],
          totalSyncedObservations: statusMap['totalSyncedObservations'] ?? 0,
          errorMessage: statusMap['errorMessage'],
        );
      }
      
      // Return default status if none exists
      return const HealthSyncEntity(
        status: SyncStatus.idle,
        lastSyncTime: null,
        permittedDataTypes: [
          HealthDataType.heartRate,
          HealthDataType.bloodPressureSystolic,
          HealthDataType.steps,
        ],
        totalSyncedObservations: 0,
        errorMessage: null,
      );
    } catch (e) {
      print('Error getting sync status: $e');
      throw Exception('Failed to get sync status: $e');
    }
  }

  @override
  Future<void> updateSyncStatus(HealthSyncEntity status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statusMap = {
        'status': status.status.toString(),
        'permittedDataTypes': status.permittedDataTypes.map((e) => e.toString()).toList(),
        'totalSyncedObservations': status.totalSyncedObservations,
        'errorMessage': status.errorMessage,
      };
      
      await prefs.setString(_syncStatusKey, json.encode(statusMap));
      
      if (status.lastSyncTime != null) {
        await prefs.setInt(_lastSyncKey, status.lastSyncTime!.millisecondsSinceEpoch);
      }
    } catch (e) {
      print('Error updating sync status: $e');
      throw Exception('Failed to update sync status: $e');
    }
  }

  @override
  Future<bool> submitSyncedObservations(List<ObservationEntity> observations) async {
    try {
      for (final observation in observations) {
        final model = ObservationModel.fromEntity(observation);
        final success = await _apiService.submitObservation(model);
        if (!success) return false;
      }
      return true;
    } catch (e) {
      print('Error submitting synced observations: $e');
      return false;
    }
  }

  @override
  List<ObservationEntity> convertToObservations(
    List<HealthDataPoint> healthData,
    DataSource source,
  ) {
    return healthData.map((dataPoint) => 
      ObservationEntity(
        id: 'sync_${DateTime.now().millisecondsSinceEpoch}',
        type: dataPoint.type.observationType,
        value: dataPoint.value,
        unit: dataPoint.unit,
        timestamp: dataPoint.timestamp,
        patientId: 'patient-1',
        deviceInfo: dataPoint.deviceInfo,
        notes: 'Synced from ${source.displayName}',
        source: source,
      )
    ).toList();
  }

  // Helper methods
  List<health_pkg.HealthDataType> _convertToHealthTypes(List<HealthDataType> dataTypes) {
    return dataTypes.map((type) {
      switch (type) {
        case HealthDataType.heartRate:
          return health_pkg.HealthDataType.HEART_RATE;
        case HealthDataType.bloodPressureSystolic:
          return health_pkg.HealthDataType.BLOOD_PRESSURE_SYSTOLIC;
        case HealthDataType.bloodPressureDiastolic:
          return health_pkg.HealthDataType.BLOOD_PRESSURE_DIASTOLIC;
        case HealthDataType.bodyTemperature:
          return health_pkg.HealthDataType.BODY_TEMPERATURE;
        case HealthDataType.respiratoryRate:
          return health_pkg.HealthDataType.RESPIRATORY_RATE;
        case HealthDataType.oxygenSaturation:
          return health_pkg.HealthDataType.BLOOD_OXYGEN;
        case HealthDataType.steps:
          return health_pkg.HealthDataType.STEPS;
        case HealthDataType.bodyWeight:
          return health_pkg.HealthDataType.WEIGHT;
        case HealthDataType.bodyHeight:
          return health_pkg.HealthDataType.HEIGHT;
      }
    }).toList();
  }

  List<HealthDataPoint> _convertToHealthDataPoints(List<health_pkg.HealthDataPoint> healthData) {
    return healthData.map((point) => 
      HealthDataPoint(
        type: _convertFromHealthType(point.type),
        value: double.tryParse(point.value.toString()) ?? 0.0,
        unit: _getUnitForType(_convertFromHealthType(point.type)),
        timestamp: point.dateFrom,
        deviceInfo: point.sourceId,
      )
    ).toList();
  }

  HealthDataType _convertFromHealthType(health_pkg.HealthDataType healthType) {
    switch (healthType) {
      case health_pkg.HealthDataType.HEART_RATE:
        return HealthDataType.heartRate;
      case health_pkg.HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
        return HealthDataType.bloodPressureSystolic;
      case health_pkg.HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
        return HealthDataType.bloodPressureDiastolic;
      case health_pkg.HealthDataType.BODY_TEMPERATURE:
        return HealthDataType.bodyTemperature;
      case health_pkg.HealthDataType.RESPIRATORY_RATE:
        return HealthDataType.respiratoryRate;
      case health_pkg.HealthDataType.BLOOD_OXYGEN:
        return HealthDataType.oxygenSaturation;
      case health_pkg.HealthDataType.STEPS:
        return HealthDataType.steps;
      case health_pkg.HealthDataType.WEIGHT:
        return HealthDataType.bodyWeight;
      case health_pkg.HealthDataType.HEIGHT:
        return HealthDataType.bodyHeight;
      default:
        return HealthDataType.heartRate;
    }
  }

  String _getUnitForType(HealthDataType type) {
    switch (type) {
      case HealthDataType.heartRate:
        return 'bpm';
      case HealthDataType.bloodPressureSystolic:
      case HealthDataType.bloodPressureDiastolic:
        return 'mmHg';
      case HealthDataType.bodyTemperature:
        return '°C';
      case HealthDataType.respiratoryRate:
        return 'bpm';
      case HealthDataType.oxygenSaturation:
        return '%';
      case HealthDataType.steps:
        return 'count';
      case HealthDataType.bodyWeight:
        return 'kg';
      case HealthDataType.bodyHeight:
        return 'cm';
    }
  }
}