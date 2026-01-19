import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

// Provider for tracking if notification permission request is in progress
final isRequestingNotificationPermissionsProvider = StateProvider<bool>(
  (ref) => false,
);

// Provider for the notification permission state
final notificationPermissionProvider =
    StateNotifierProvider<NotificationPermissionNotifier, PermissionStatus?>((
      ref,
    ) {
      return NotificationPermissionNotifier();
    });

class NotificationPermissionNotifier extends StateNotifier<PermissionStatus?> {
  NotificationPermissionNotifier() : super(null) {
    _checkInitialStatus();
  }

  // Check initial permission status
  Future<void> _checkInitialStatus() async {
    try {
      final status = await Permission.notification.status;
      state = status;
    } catch (e) {
      state = null;
    }
  }

  // Request notification permission
  Future<PermissionStatus> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      state = status;
      return status;
    } catch (e) {
      rethrow;
    }
  }

  // Check current permission status
  Future<PermissionStatus> checkPermissionStatus() async {
    try {
      final status = await Permission.notification.status;
      state = status;
      return status;
    } catch (e) {
      rethrow;
    }
  }

  // Open app settings
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
