import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../domain/repositories/health_sync_repository.dart';
import '../domain/entities/health_sync_entity.dart';
import '../domain/entities/observation_entity.dart';

class HealthSyncService {
  final HealthSyncRepository _repository;
  
  // WorkManager task identifiers
  static const String syncTaskName = 'health_data_sync';
  static const String syncTaskId = 'health_sync_task';
  static const String _periodicSyncKey = 'periodic_sync_enabled';
  
  HealthSyncService(this._repository);
  
  /// Initialize background sync (Android only)
  Future<void> initializeBackgroundSync() async {
    if (Platform.isAndroid) {
      await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
    }
  }
  
  /// Schedule periodic sync
  Future<void> schedulePeriodicSync({Duration interval = const Duration(hours: 1)}) async {
    if (Platform.isAndroid) {
      await Workmanager().registerPeriodicTask(
        syncTaskId,
        syncTaskName,
        frequency: interval,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
      );
      
      // Store the enabled state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_periodicSyncKey, true);
    }
  }
  
  /// Cancel scheduled sync
  Future<void> cancelPeriodicSync() async {
    if (Platform.isAndroid) {
      await Workmanager().cancelByUniqueName(syncTaskId);
      
      // Store the disabled state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_periodicSyncKey, false);
    }
  }
  
  /// Check if periodic sync is currently enabled
  Future<bool> isPeriodicSyncEnabled() async {
    if (!Platform.isAndroid) {
      return false;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_periodicSyncKey) ?? false;
    } catch (e) {
      print('Error checking periodic sync status: $e');
      return false;
    }
  }
  
  /// Perform manual sync
  Future<SyncResult> performSync({
    List<HealthDataType>? specificDataTypes,
    DateTime? since,
  }) async {
    try {
      // Get current sync status
      final currentStatus = await _repository.getSyncStatus();
      
      // Update status to syncing
      await _repository.updateSyncStatus(
        currentStatus.copyWith(status: SyncStatus.syncing),
      );
      
      // Use permitted data types or specific types
      final dataTypes = specificDataTypes ?? currentStatus.permittedDataTypes;
      
      if (dataTypes.isEmpty) {
        await _repository.updateSyncStatus(
          currentStatus.copyWith(
            status: SyncStatus.permissionDenied,
            errorMessage: 'No data types permitted for sync',
          ),
        );
        return SyncResult.permissionDenied('No data types permitted');
      }
      
      // Check permissions
      final hasPermissions = await _repository.hasPermissions(dataTypes);
      if (!hasPermissions) {
        await _repository.updateSyncStatus(
          currentStatus.copyWith(
            status: SyncStatus.permissionDenied,
            errorMessage: 'Health data permissions not granted',
          ),
        );
        return SyncResult.permissionDenied('Permissions not granted');
      }
      
      // Get health data since last sync or specified time
      final startDate = since ?? currentStatus.lastSyncTime ?? 
        DateTime.now().subtract(const Duration(days: 7));
      
      final healthData = await _repository.getHealthData(
        dataTypes: dataTypes,
        startDate: startDate,
        endDate: DateTime.now(),
      );
      
      if (healthData.isEmpty) {
        await _repository.updateSyncStatus(
          currentStatus.copyWith(
            status: SyncStatus.noData,
            lastSyncTime: DateTime.now(),
          ),
        );
        return SyncResult.noData('No new health data available');
      }
      
      // Convert to observations
      final observations = _repository.convertToObservations(
        healthData,
        Platform.isIOS ? DataSource.healthKit : DataSource.healthConnect,
      );
      
      // Submit to backend
      final success = await _repository.submitSyncedObservations(observations);
      
      if (success) {
        await _repository.updateSyncStatus(
          currentStatus.copyWith(
            status: SyncStatus.success,
            lastSyncTime: DateTime.now(),
            totalSyncedObservations: currentStatus.totalSyncedObservations + observations.length,
            errorMessage: null,
          ),
        );
        return SyncResult.success(observations.length);
      } else {
        await _repository.updateSyncStatus(
          currentStatus.copyWith(
            status: SyncStatus.failed,
            errorMessage: 'Failed to submit synced observations to backend',
          ),
        );
        return SyncResult.failed('Failed to submit data to backend');
      }
      
    } catch (e) {
      print('Error during health sync: $e');
      
      // Update status to failed
      final currentStatus = await _repository.getSyncStatus();
      await _repository.updateSyncStatus(
        currentStatus.copyWith(
          status: SyncStatus.failed,
          errorMessage: 'Sync error: $e',
        ),
      );
      
      return SyncResult.failed('Sync error: $e');
    }
  }
  
  /// Request permissions for health data types
  Future<bool> requestPermissions(List<HealthDataType> dataTypes) async {
    final granted = await _repository.requestPermissions(dataTypes);
    
    if (granted) {
      // Update permitted data types in sync status
      final currentStatus = await _repository.getSyncStatus();
      await _repository.updateSyncStatus(
        currentStatus.copyWith(permittedDataTypes: dataTypes),
      );
    }
    
    return granted;
  }
  
  /// Check if health sync is supported on current platform
  bool get isSupported {
    return Platform.isAndroid || Platform.isIOS;
  }
  
  /// Get platform-specific data source
  DataSource get platformDataSource {
    if (Platform.isIOS) {
      return DataSource.healthKit;
    } else if (Platform.isAndroid) {
      return DataSource.healthConnect;
    } else {
      return DataSource.manual;
    }
  }
}

/// Result of a sync operation
class SyncResult {
  final SyncResultType type;
  final String message;
  final int? syncedCount;
  
  const SyncResult._(this.type, this.message, this.syncedCount);
  
  factory SyncResult.success(int syncedCount) =>
    SyncResult._(SyncResultType.success, 'Successfully synced $syncedCount observations', syncedCount);
    
  factory SyncResult.failed(String error) =>
    SyncResult._(SyncResultType.failed, error, null);
    
  factory SyncResult.permissionDenied(String message) =>
    SyncResult._(SyncResultType.permissionDenied, message, null);
    
  factory SyncResult.noData(String message) =>
    SyncResult._(SyncResultType.noData, message, 0);
  
  bool get isSuccess => type == SyncResultType.success;
  bool get isFailed => type == SyncResultType.failed;
  bool get isPermissionDenied => type == SyncResultType.permissionDenied;
  bool get isNoData => type == SyncResultType.noData;
}

enum SyncResultType {
  success,
  failed,
  permissionDenied,
  noData,
}

/// WorkManager callback dispatcher (Android background processing)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Background sync task executed: $task");
    
    try {
      // This would need to be set up with dependency injection
      // For now, just return success
      // In a real implementation, you would:
      // 1. Initialize your DI container
      // 2. Get the HealthSyncService instance
      // 3. Perform the sync operation
      // 4. Return the appropriate result
      
      return Future.value(true);
    } catch (e) {
      print("Background sync failed: $e");
      return Future.value(false);
    }
  });
}