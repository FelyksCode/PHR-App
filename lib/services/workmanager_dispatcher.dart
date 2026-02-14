import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';

import '../core/errors/app_error.dart';
import '../core/errors/app_error_logger.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
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

/// Handler for vendor (Fitbit) sync task
/// This is self-contained and does not depend on any UI state or providers
Future<bool> _handleVendorFitbitSync(Map<String, dynamic>? inputData) async {
  try {
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
