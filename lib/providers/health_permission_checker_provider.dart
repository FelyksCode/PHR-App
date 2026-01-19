import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/health_connect_service.dart';
import '../constants/health_permissions.dart';

/// Permission check result with timestamp for caching
class PermissionCheckResult {
  final bool allPermissionsGranted;
  final DateTime timestamp;

  const PermissionCheckResult({
    required this.allPermissionsGranted,
    required this.timestamp,
  });

  /// Check if cached result is still valid (within 5 minutes)
  bool get isValid {
    final age = DateTime.now().difference(timestamp);
    return age.inMinutes < 5;
  }
}

/// Cached Health Connect permission checker.
/// Prevents repeated async permission calls on widget rebuild.
///
/// Cache invalidation:
/// - Automatically expires after 5 minutes
/// - Can be manually invalidated via ref.invalidate()
/// - Invalidates on permission screen navigation
class HealthPermissionChecker
    extends StateNotifier<AsyncValue<PermissionCheckResult>> {
  HealthPermissionChecker() : super(const AsyncValue.loading());

  /// Check permissions with caching
  Future<void> checkPermissions() async {
    // If we have a valid cached result, use it
    final currentState = state;
    if (currentState is AsyncData<PermissionCheckResult>) {
      final result = currentState.value;
      if (result.isValid) {
        debugPrint(
          '[PermissionChecker] Using cached result: ${result.allPermissionsGranted}',
        );
        return;
      }
    }

    // Otherwise, perform fresh check
    state = const AsyncValue.loading();

    try {
      final healthService = HealthConnectService.instance;
      await healthService.initialize();

      // Check if Health Connect is available
      final isAvailable = await healthService.isFeatureAvailable();
      if (!isAvailable) {
        debugPrint('[PermissionChecker] Health Connect not available');
        state = AsyncValue.data(
          PermissionCheckResult(
            allPermissionsGranted: false,
            timestamp: DateTime.now(),
          ),
        );
        return;
      }

      // Check if all required permissions are granted
      final permissions = HealthPermissions.requiredPermissions;
      final hasAllPermissions = await healthService.hasAllPermissions(
        permissions: permissions,
      );

      debugPrint('[PermissionChecker] Fresh check: $hasAllPermissions');
      state = AsyncValue.data(
        PermissionCheckResult(
          allPermissionsGranted: hasAllPermissions,
          timestamp: DateTime.now(),
        ),
      );
    } catch (e, st) {
      debugPrint('[PermissionChecker] Error checking permissions: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Force refresh (invalidate cache)
  Future<void> refresh() async {
    debugPrint('[PermissionChecker] Forcing refresh...');
    state = const AsyncValue.loading();
    await checkPermissions();
  }
}

/// Provider for cached permission checking
final healthPermissionCheckerProvider =
    StateNotifierProvider<
      HealthPermissionChecker,
      AsyncValue<PermissionCheckResult>
    >((ref) => HealthPermissionChecker());
