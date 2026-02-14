import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../core/config/app_mode.dart';
import '../core/errors/app_error.dart';
import '../core/errors/app_error_logger.dart';
import '../domain/repositories/health_sync_repository.dart';
import '../domain/entities/health_sync_entity.dart';
import '../domain/entities/observation_entity.dart';
import 'workmanager_service.dart';

/// Service for managing health data sync operations.
/// Uses WorkManagerService for all background task registration.
class HealthSyncService {
  final HealthSyncRepository _repository;

  static const String _periodicSyncKey = 'periodic_sync_enabled';

  HealthSyncService(this._repository);

  /// Schedule periodic sync using WorkManagerService
  Future<void> schedulePeriodicSync({
    Duration interval = const Duration(hours: 1),
  }) async {
    if (AppConfig.isSimulation) return;
    if (Platform.isAndroid) {
      await WorkManagerService.instance.registerPeriodicTask(
        uniqueName: BackgroundTaskIds.healthSyncPeriodic,
        taskName: BackgroundTaskNames.healthDataSync,
        frequency: interval,
      );

      // Store the enabled state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_periodicSyncKey, true);
    }
  }

  /// Cancel scheduled sync using WorkManagerService
  Future<void> cancelPeriodicSync() async {
    if (AppConfig.isSimulation) return;
    if (Platform.isAndroid) {
      await WorkManagerService.instance.cancelTask(
        BackgroundTaskIds.healthSyncPeriodic,
      );

      // Store the disabled state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_periodicSyncKey, false);
    }
  }

  /// Check if periodic sync is currently enabled
  Future<bool> isPeriodicSyncEnabled() async {
    if (AppConfig.isSimulation) return false;
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      return await WorkManagerService.instance.isTaskEnabled(
        BackgroundTaskIds.healthSyncPeriodic,
      );
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Error checking periodic sync status',
          code: 'HEALTH_SYNC_STATUS_ERROR',
          stackTrace: st,
          originalException: e,
        ),
        source: 'HealthSyncService.isPeriodicSyncEnabled',
        severity: ErrorSeverity.low,
      );
      return false;
    }
  }

  /// Perform manual sync
  Future<SyncResult> performSync({
    List<HealthDataType>? specificDataTypes,
    DateTime? since,
  }) async {
    if (AppConfig.isSimulation) {
      return SyncResult.failed('Simulation mode: Health Connect is disabled');
    }
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
      final startDate =
          since ??
          currentStatus.lastSyncTime ??
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
            totalSyncedObservations:
                currentStatus.totalSyncedObservations + observations.length,
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
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Error during health sync',
          code: 'HEALTH_SYNC_PERFORM_ERROR',
          stackTrace: st,
          originalException: e,
        ),
        source: 'HealthSyncService.performSync',
        severity: ErrorSeverity.medium,
      );

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
    if (AppConfig.isSimulation) return false;
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
    return !AppConfig.isSimulation && (Platform.isAndroid || Platform.isIOS);
  }

  /// Get platform-specific data source
  DataSource get platformDataSource {
    if (AppConfig.isSimulation) {
      return DataSource.manual;
    }
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

  factory SyncResult.success(int syncedCount) => SyncResult._(
    SyncResultType.success,
    'Successfully synced $syncedCount observations',
    syncedCount,
  );

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

enum SyncResultType { success, failed, permissionDenied, noData }
