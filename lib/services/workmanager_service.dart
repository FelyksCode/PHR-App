import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workmanager_dispatcher.dart';

/// Centralized WorkManager service for task registration and management.
/// Enforces single-responsibility principle by consolidating all task
/// registration logic in one place.
///
/// Key responsibilities:
/// - Register one-off and periodic background tasks
/// - Cancel tasks when no longer needed
/// - Track task state in SharedPreferences
/// - Provide type-safe task configuration
class WorkManagerService {
  static WorkManagerService? _instance;

  /// Singleton accessor
  static WorkManagerService get instance {
    _instance ??= WorkManagerService._();
    return _instance!;
  }

  WorkManagerService._();

  bool _initialized = false;

  /// Initialize WorkManager (Android only).
  /// MUST be called once in main() before registering any tasks.
  Future<void> initialize({bool isInDebugMode = false}) async {
    if (_initialized) {
      debugPrint('[WorkManagerService] Already initialized, skipping...');
      return;
    }

    if (!Platform.isAndroid) {
      debugPrint('[WorkManagerService] Not Android, skipping initialization');
      return;
    }

    try {
      await Workmanager().initialize(workmanagerCallbackDispatcher);
      _initialized = true;
      debugPrint('[WorkManagerService] Initialized successfully');
    } catch (e, st) {
      debugPrint('[WorkManagerService] Initialization failed: $e\n$st');
      rethrow;
    }
  }

  /// Register a one-off task to run once in the background.
  ///
  /// [uniqueName] - Unique identifier for the task
  /// [taskName] - Task name from BackgroundTaskNames
  /// [inputData] - Optional data to pass to the task
  /// [initialDelay] - Delay before first execution
  /// [constraints] - Battery, network, etc. constraints
  Future<void> registerOneOffTask({
    required String uniqueName,
    required String taskName,
    Map<String, dynamic>? inputData,
    Duration initialDelay = Duration.zero,
    Constraints? constraints,
  }) async {
    if (!Platform.isAndroid) return;

    _ensureInitialized();

    try {
      await Workmanager().registerOneOffTask(
        uniqueName,
        taskName,
        inputData: inputData,
        initialDelay: initialDelay,
        constraints: constraints ?? _defaultConstraints,
      );
      debugPrint(
        '[WorkManagerService] One-off task registered: $taskName ($uniqueName)',
      );
    } catch (e, st) {
      debugPrint(
        '[WorkManagerService] Failed to register one-off task: $e\n$st',
      );
      rethrow;
    }
  }

  /// Register a periodic task to run repeatedly at specified intervals.
  ///
  /// [uniqueName] - Unique identifier for the task
  /// [taskName] - Task name from BackgroundTaskNames
  /// [frequency] - Interval between executions (min 15 minutes on Android)
  /// [inputData] - Optional data to pass to the task
  /// [constraints] - Battery, network, etc. constraints
  /// [existingWorkPolicy] - How to handle conflicts with existing tasks
  Future<void> registerPeriodicTask({
    required String uniqueName,
    required String taskName,
    Duration frequency = const Duration(hours: 1),
    Map<String, dynamic>? inputData,
    Constraints? constraints,
    ExistingWorkPolicy existingWorkPolicy = ExistingWorkPolicy.keep,
  }) async {
    if (!Platform.isAndroid) return;

    _ensureInitialized();

    // Android WorkManager enforces minimum 15-minute intervals
    if (frequency.inMinutes < 15) {
      debugPrint(
        '[WorkManagerService] WARNING: Frequency adjusted from ${frequency.inMinutes}min to 15min (Android minimum)',
      );
      frequency = const Duration(minutes: 15);
    }

    try {
      await Workmanager().registerPeriodicTask(
        uniqueName,
        taskName,
        frequency: frequency,
        inputData: inputData,
        constraints: constraints ?? _defaultConstraints,
      );

      // Track task state
      await _setTaskEnabled(uniqueName, true);

      debugPrint(
        '[WorkManagerService] Periodic task registered: $taskName ($uniqueName) every ${frequency.inMinutes}min',
      );
    } catch (e, st) {
      debugPrint(
        '[WorkManagerService] Failed to register periodic task: $e\n$st',
      );
      rethrow;
    }
  }

  /// Cancel a specific task by its unique name.
  Future<void> cancelTask(String uniqueName) async {
    if (!Platform.isAndroid) return;

    try {
      await Workmanager().cancelByUniqueName(uniqueName);
      await _setTaskEnabled(uniqueName, false);
      debugPrint('[WorkManagerService] Task cancelled: $uniqueName');
    } catch (e, st) {
      debugPrint('[WorkManagerService] Failed to cancel task: $e\n$st');
      rethrow;
    }
  }

  /// Cancel all registered tasks.
  Future<void> cancelAllTasks() async {
    if (!Platform.isAndroid) return;

    try {
      await Workmanager().cancelAll();

      // Clear all task state
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_taskKeyPrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }

      debugPrint('[WorkManagerService] All tasks cancelled');
    } catch (e, st) {
      debugPrint('[WorkManagerService] Failed to cancel all tasks: $e\n$st');
      rethrow;
    }
  }

  /// Check if a specific task is currently enabled/registered.
  Future<bool> isTaskEnabled(String uniqueName) async {
    if (!Platform.isAndroid) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_taskKeyPrefix$uniqueName') ?? false;
    } catch (e) {
      debugPrint('[WorkManagerService] Failed to check task state: $e');
      return false;
    }
  }

  // Private helpers

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'WorkManagerService not initialized. Call initialize() in main() first.',
      );
    }
  }

  Future<void> _setTaskEnabled(String uniqueName, bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_taskKeyPrefix$uniqueName', enabled);
    } catch (e) {
      debugPrint('[WorkManagerService] Failed to save task state: $e');
    }
  }

  static const String _taskKeyPrefix = 'workmanager_task_';

  static final Constraints _defaultConstraints = Constraints(
    networkType: NetworkType.connected,
    requiresBatteryNotLow: true,
  );
}

/// Task name constants - centralized registry of all background tasks
class BackgroundTaskNames {
  /// Health data sync from Health Connect
  static const String healthDataSync = 'health_data_sync';

  /// Vendor (Fitbit) data sync
  static const String vendorFitbitSync = 'vendor_fitbit_sync';

  // Prevent instantiation
  BackgroundTaskNames._();
}

/// Unique task identifiers - used to cancel/update specific tasks
class BackgroundTaskIds {
  /// Periodic health sync task
  static const String healthSyncPeriodic = 'health_sync_periodic_task';

  /// Periodic vendor sync task
  static const String vendorSyncPeriodic = 'vendor_sync_periodic_task';

  // Prevent instantiation
  BackgroundTaskIds._();
}
