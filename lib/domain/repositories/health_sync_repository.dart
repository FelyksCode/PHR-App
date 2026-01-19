import '../entities/health_sync_entity.dart';
import '../entities/observation_entity.dart';

abstract class HealthSyncRepository {
  /// Request permissions for health data access
  Future<bool> requestPermissions(List<HealthDataType> dataTypes);

  /// Check if permissions are granted for specific data types
  Future<bool> hasPermissions(List<HealthDataType> dataTypes);

  /// Get health data for specified types and date range
  Future<List<HealthDataPoint>> getHealthData({
    required List<HealthDataType> dataTypes,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Get latest health data since last sync
  Future<List<HealthDataPoint>> getDeltaHealthData({
    required List<HealthDataType> dataTypes,
    required DateTime since,
  });

  /// Get current sync status
  Future<HealthSyncEntity> getSyncStatus();

  /// Update sync status
  Future<void> updateSyncStatus(HealthSyncEntity status);

  /// Submit synced observations to backend
  Future<bool> submitSyncedObservations(List<ObservationEntity> observations);

  /// Convert health data points to observation entities
  List<ObservationEntity> convertToObservations(
    List<HealthDataPoint> healthData,
    DataSource source,
  );
}
