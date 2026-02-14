import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';

import '../core/errors/app_error.dart';
import '../core/errors/app_error_logger.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../core/config/app_mode.dart';
import '../data/repositories/health_sync_repository_impl.dart';
import '../domain/entities/health_sync_entity.dart';
import '../domain/entities/observation_entity.dart';
import '../services/api_service.dart';
import '../core/utils/timezone_initializer.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('[BG] Task started: $taskName at ${DateTime.now()}');
    if (inputData != null) {
      debugPrint('[BG] Input data: $inputData');
    }

    try {
      // STEP 1: Initialize timezone for deterministic background behavior.
      await initTimezone();

      debugPrint('[TIME CHECK][BG]');
      debugPrint('DateTime.now(): ${DateTime.now()}');
      debugPrint('tz.local: ${tz.local}');
      debugPrint('tz.now(tz.local): ${tz.TZDateTime.now(tz.local)}');

      // STEP 2: Initialize notification service (required for scheduled notifications)
      await _initializeNotifications();

      // STEP 3: Initialize API client (required for network calls)
      _initializeApiClient();

      // STEP 4: Route to appropriate task handler
      final handler = TaskRegistry.getHandler(taskName);

      if (handler == null) {
        debugPrint('[BG] Unknown task: $taskName');
        return Future.value(false);
      }

      final result = await handler(inputData);

      if (result) {
        debugPrint('[BG] Task completed: $taskName');
      } else {
        debugPrint('[BG] Task failed: $taskName');
      }

      return Future.value(result);
    } catch (e, st) {
      debugPrint('[BG] Task error: $taskName - $e');
      debugPrint('Stack trace: $st');

      // Log error but don't crash the background isolate
      AppErrorLogger.logError(
        UnknownError(
          'Background task failed: $taskName',
          code: 'WORKMANAGER_TASK_ERROR',
          stackTrace: st,
          originalException: e,
        ),
        source: 'workmanagerCallbackDispatcher',
        severity: ErrorSeverity.medium,
      );

      return Future.value(false);
    }
  });
}

/// Initialize notification service in background isolate.
/// Required for tasks that schedule notifications.
Future<void> _initializeNotifications() async {
  try {
    await NotificationService.instance.init();
    debugPrint('[BG] Notifications initialized');
  } catch (e) {
    // Non-fatal: some tasks may not need notifications
    debugPrint('[BG] Failed to initialize notifications: $e (continuing)');
  }
}

/// Initialize API client in background isolate.
/// Required for tasks that make network requests.
void _initializeApiClient() {
  try {
    ApiClient.initialize(baseUrl: ApiConstants.baseUrl);
    debugPrint('[BG] API client initialized');
  } catch (e) {
    debugPrint('[BG] Failed to initialize API client: $e');
    throw Exception('API client initialization failed in background');
  }
}

/// Task registry that maps task names to handlers
/// Handlers must be self-contained and work in background isolates
class TaskRegistry {
  static final Map<String, TaskHandler> _handlers = {
    'health_data_sync': _handleHealthDataSync,
    'vendor_fitbit_sync': _handleVendorFitbitSync,
  };

  /// Get handler for a task name
  static TaskHandler? getHandler(String taskName) {
    return _handlers[taskName];
  }

  /// Register a custom handler (for extensibility)
  static void registerHandler(String taskName, TaskHandler handler) {
    _handlers[taskName] = handler;
  }

  // Prevent instantiation
  TaskRegistry._();
}

/// Type definition for task handlers
/// Handlers receive optional input data and return a success boolean
typedef TaskHandler = Future<bool> Function(Map<String, dynamic>? inputData);

/// Handler for health data sync task
/// This is self-contained and does not depend on any UI state or providers
Future<bool> _handleHealthDataSync(Map<String, dynamic>? inputData) async {
  try {
    if (AppConfig.isSimulation) {
      debugPrint('[BG] Simulation mode: skipping health data sync');
      return true;
    }
    debugPrint('[BG] Starting health data sync...');

    // Create instances needed for sync
    final apiService = ApiService();
    final repository = HealthSyncRepositoryImpl(apiService);

    // Get sync status
    final syncStatus = await repository.getSyncStatus();

    // Check if we have permitted data types
    if (syncStatus.permittedDataTypes.isEmpty) {
      debugPrint('[BG] No permitted data types for sync');
      return true; // Return true as this is not an error condition
    }

    // Update to syncing status
    await repository.updateSyncStatus(
      syncStatus.copyWith(status: SyncStatus.syncing),
    );

    // Check permissions
    final hasPermissions = await repository.hasPermissions(
      syncStatus.permittedDataTypes,
    );

    if (!hasPermissions) {
      debugPrint('[BG] Missing health data permissions');
      await repository.updateSyncStatus(
        syncStatus.copyWith(
          status: SyncStatus.permissionDenied,
          errorMessage: 'Health data permissions not granted',
        ),
      );
      return true; // Return true as this is not an error, just a state
    }

    // Get health data since last sync
    final startDate =
        syncStatus.lastSyncTime ??
        DateTime.now().subtract(const Duration(days: 7));

    final healthData = await repository.getHealthData(
      dataTypes: syncStatus.permittedDataTypes,
      startDate: startDate,
      endDate: DateTime.now(),
    );

    if (healthData.isEmpty) {
      debugPrint('[BG] No new health data to sync');
      await repository.updateSyncStatus(
        syncStatus.copyWith(
          status: SyncStatus.noData,
          lastSyncTime: DateTime.now(),
        ),
      );
      return true;
    }

    // Convert to observations and submit
    final observations = repository.convertToObservations(
      healthData,
      DataSource.healthConnect,
    );

    final success = await repository.submitSyncedObservations(observations);

    if (success) {
      await repository.updateSyncStatus(
        syncStatus.copyWith(
          status: SyncStatus.success,
          lastSyncTime: DateTime.now(),
          totalSyncedObservations:
              syncStatus.totalSyncedObservations + observations.length,
          errorMessage: null,
        ),
      );
      debugPrint('[BG] Synced ${observations.length} observations');
      return true;
    } else {
      await repository.updateSyncStatus(
        syncStatus.copyWith(
          status: SyncStatus.failed,
          errorMessage: 'Failed to submit observations to backend',
        ),
      );
      return false;
    }
  } catch (e, st) {
    debugPrint('[BG] Health sync error: $e');
    AppErrorLogger.logError(
      UnknownError(
        'Health data sync failed in background',
        code: 'BG_HEALTH_SYNC_ERROR',
        stackTrace: st,
        originalException: e,
      ),
      source: '_handleHealthDataSync',
      severity: ErrorSeverity.medium,
    );
    return false;
  }
}

/// Handler for vendor (Fitbit) sync task
/// This is self-contained and does not depend on any UI state or providers
Future<bool> _handleVendorFitbitSync(Map<String, dynamic>? inputData) async {
  try {
    if (AppConfig.isSimulation) {
      debugPrint('[BG] Simulation mode: skipping vendor Fitbit sync');
      return true;
    }
    debugPrint('[BG] Starting vendor Fitbit sync...');

    // Create API service instance
    final apiService = ApiService();

    // Trigger backend-managed vendor sync (202 Accepted)
    await apiService.triggerVendorSync(vendor: 'fitbit');
    debugPrint('[BG] Vendor sync accepted by backend');
    return true;
  } catch (e, st) {
    debugPrint('[BG] Vendor sync error: $e');
    AppErrorLogger.logError(
      UnknownError(
        'Vendor sync failed in background',
        code: 'BG_VENDOR_SYNC_ERROR',
        stackTrace: st,
        originalException: e,
      ),
      source: '_handleVendorFitbitSync',
      severity: ErrorSeverity.medium,
    );
    return false;
  }
}
