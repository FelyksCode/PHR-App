import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../core/errors/app_error.dart';
import '../core/errors/app_error_logger.dart';
import '../services/api_service.dart';
import 'workmanager_service.dart';

/// Service for managing vendor (Fitbit) background sync operations.
/// Uses WorkManagerService for all background task registration.
class VendorBackgroundSyncService {
  final ApiService _apiService;

  static const String _periodicVendorSyncKey = 'periodic_vendor_sync_enabled';

  VendorBackgroundSyncService(this._apiService);

  /// Schedule periodic Fitbit sync using WorkManagerService.
  ///
  /// [frequency] controls how often the background task runs.
  /// If null, a default of 1 hour is used. The actual minimum
  /// interval is still enforced by WorkManager on Android.
  Future<void> schedulePeriodicVendorSync({Duration? frequency}) async {
    if (Platform.isAndroid) {
      final effectiveFrequency = frequency ?? const Duration(hours: 1);
      await WorkManagerService.instance.registerPeriodicTask(
        uniqueName: BackgroundTaskIds.vendorSyncPeriodic,
        taskName: BackgroundTaskNames.vendorFitbitSync,
        frequency: effectiveFrequency,
      );

      // Store the enabled state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_periodicVendorSyncKey, true);
    }
  }

  /// Cancel periodic vendor sync using WorkManagerService
  Future<void> cancelPeriodicVendorSync() async {
    if (Platform.isAndroid) {
      await WorkManagerService.instance.cancelTask(
        BackgroundTaskIds.vendorSyncPeriodic,
      );

      // Store the disabled state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_periodicVendorSyncKey, false);
    }
  }

  /// Check if periodic vendor sync is currently enabled
  Future<bool> isPeriodicVendorSyncEnabled() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      return await WorkManagerService.instance.isTaskEnabled(
        BackgroundTaskIds.vendorSyncPeriodic,
      );
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Error checking periodic vendor sync status',
          code: 'VENDOR_SYNC_STATUS_ERROR',
          stackTrace: st,
          originalException: e,
        ),
        source: 'VendorBackgroundSyncService.isPeriodicVendorSyncEnabled',
        severity: ErrorSeverity.low,
      );
      return false;
    }
  }

  /// Perform vendor sync (called from background task)
  Future<bool> performVendorSync() async {
    try {
      await _apiService.triggerVendorSync(vendor: 'fitbit');
      // Backend returns 202 Accepted; treat trigger as success.
      return true;
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Error during vendor background sync',
          code: 'VENDOR_SYNC_BG_ERROR',
          stackTrace: st,
          originalException: e,
        ),
        source: 'VendorBackgroundSyncService.performVendorSync',
        severity: ErrorSeverity.medium,
      );
      return false;
    }
  }
}
