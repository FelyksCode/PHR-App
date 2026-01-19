import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'dart:io';
import '../constants/health_permissions.dart';

/// Service for managing Health Connect client and feature availability
class HealthConnectService {
  static HealthConnectService? _instance;
  static HealthConnectService get instance =>
      _instance ??= HealthConnectService._();

  HealthConnectService._();

  Health? _healthClient;
  bool _isInitialized = false;

  /// Initialize the Health Connect service
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (Platform.isAndroid) {
      _healthClient = Health();

      // Check if Health Connect is available on the device
      try {
        final status = await _healthClient!.getHealthConnectSdkStatus();
        final isAvailable = status == HealthConnectSdkStatus.sdkAvailable;

        if (!isAvailable) {
          if (kDebugMode) {
            print(
              'Health Connect SDK is not available on this device. Status: $status',
            );
          }
          // In debug mode, we can still use the service for testing
          if (!kDebugMode) {
            throw Exception('Health Connect is not available on this device');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error checking Health Connect SDK status: $e');
        }
        // In debug mode, continue anyway for testing
        if (!kDebugMode) {
          throw Exception('Failed to check Health Connect availability: $e');
        }
      }

      _isInitialized = true;
    } else if (Platform.isIOS) {
      _healthClient = Health();
      _isInitialized = true;
    }
  }

  /// Get Health client instance (uses FakeHealthConnectClient in debug mode if needed)
  Health get healthClient {
    if (!_isInitialized) {
      throw Exception('HealthConnectService must be initialized first');
    }
    return _healthClient!;
  }

  /// Check if Health Connect features are available
  Future<bool> isFeatureAvailable() async {
    if (!Platform.isAndroid) {
      // iOS HealthKit is always available if the device supports it
      return true;
    }

    try {
      // For Android Health Connect
      if (_healthClient != null) {
        // Check if Health Connect SDK is available
        final status = await _healthClient!.getHealthConnectSdkStatus();
        final isAvailable = status == HealthConnectSdkStatus.sdkAvailable;

        if (kDebugMode) {
          print('Health Connect SDK available: $isAvailable (status: $status)');
          // In debug mode, always return true to enable testing

          return true;
        }

        return isAvailable;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking Health Connect availability: $e');
        // In debug mode, return true to enable testing
        return true;
      }
      return false;
    }
  }

  /// Check if background health data reading is supported
  Future<bool> isBackgroundReadingSupported() async {
    if (!Platform.isAndroid) {
      // iOS HealthKit supports background reading
      return true;
    }

    try {
      // For Android Health Connect, check if available
      final isAvailable = await isFeatureAvailable();

      if (kDebugMode) {
        print('Background health data reading available: $isAvailable');
      }

      return isAvailable;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking background reading support: $e');
        return true; // Allow in debug mode
      }
      return false;
    }
  }

  /// Check which health permissions are already granted
  Future<List<HealthDataType>> getGrantedPermissions({
    required List<HealthDataType> permissions,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (kDebugMode) {
        print(
          'Checking granted permissions for ${permissions.length} permissions...',
        );
      }

      // Use batch permission check - the package handles this efficiently
      final hasPermissions = await _healthClient!.hasPermissions(permissions);

      final grantedPermissions = <HealthDataType>[];
      if (hasPermissions == true) {
        // All permissions are granted
        grantedPermissions.addAll(permissions);
      }

      if (kDebugMode) {
        print('Batch permission check result: $hasPermissions');
        print(
          'Granted permissions: ${grantedPermissions.length}/${permissions.length}',
        );
      }

      return grantedPermissions;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking granted permissions: $e');
        // In debug mode, assume no permissions granted
        return [];
      }
      rethrow;
    }
  }

  /// Check if all required permissions are already granted
  Future<bool> hasAllPermissions({
    required List<HealthDataType> permissions,
  }) async {
    try {
      final grantedPermissions = await getGrantedPermissions(
        permissions: permissions,
      );
      final hasAll = grantedPermissions.length == permissions.length;

      if (kDebugMode) {
        print(
          'Has all required permissions: $hasAll (${grantedPermissions.length}/${permissions.length})',
        );
      }

      return hasAll;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking all permissions: $e');
        return false;
      }
      return false;
    }
  }

  /// Request health permissions with feature checks
  /// Similar to Android's checkPermissionsAndRun pattern
  Future<bool> requestHealthPermissions({
    required List<HealthDataType> permissions,
    List<HealthDataAccess>? accessTypes,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (Platform.isAndroid) {
        if (kDebugMode) {
          print('Requesting Health Connect permissions...');
          print('Permissions to request: ${permissions.length}');
        }

        // Always request permissions - let the Health Connect dialog handle the UI
        // Use requestAuthorization with proper parameter format
        final result = await _healthClient!.requestAuthorization(
          permissions,
          permissions:
              accessTypes ??
              permissions.map((_) => HealthDataAccess.READ_WRITE).toList(),
        );

        if (kDebugMode) {
          print('Health Connect permission request result: $result');
        }

        return result;
      } else if (Platform.isIOS) {
        // For iOS HealthKit - directly request permissions
        if (kDebugMode) {
          print('Requesting HealthKit permissions...');
        }

        final result = await _healthClient!.requestAuthorization(permissions);

        if (kDebugMode) {
          print('HealthKit permissions granted: $result');
        }

        return result;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting health permissions: $e');
        print('Error type: ${e.runtimeType}');
      }

      // Re-throw the error so the UI can handle it appropriately
      rethrow;
    }
  }

  /// Get health data with error handling
  Future<List<HealthDataPoint>> getHealthData({
    required List<HealthDataType> types,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final data = await _healthClient!.getHealthDataFromTypes(
        types: types,
        startTime: startTime,
        endTime: endTime,
      );

      if (kDebugMode) {
        print('Retrieved ${data.length} health data points');
      }

      return data;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting health data: $e');
        // In debug mode, return empty list instead of throwing
        return [];
      }
      rethrow;
    }
  }

  /// Check Health Connect installation status
  Future<HealthConnectSdkStatus> getHealthConnectStatus() async {
    if (!Platform.isAndroid) {
      return HealthConnectSdkStatus.sdkAvailable;
    }

    try {
      final status = await _healthClient!.getHealthConnectSdkStatus();
      return status ?? HealthConnectSdkStatus.sdkUnavailable;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking Health Connect status: $e');
        return HealthConnectSdkStatus.sdkAvailable; // Assume available in debug
      }
      return HealthConnectSdkStatus.sdkUnavailable;
    }
  }

  /// Install Health Connect if not available
  Future<void> installHealthConnect() async {
    if (!Platform.isAndroid) return;

    try {
      if (kDebugMode) {
        print('Attempting to install/open Health Connect...');
      }

      // Use the correct method to open Health Connect in Play Store
      await _healthClient!.installHealthConnect();

      if (kDebugMode) {
        print('Health Connect installation request sent');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error installing Health Connect: $e');
        print('Please manually install Health Connect from Google Play Store');
      }
      rethrow;
    }
  }

  /// Check if Health Connect app is actually installed on the device
  Future<bool> isHealthConnectInstalled() async {
    if (!Platform.isAndroid) return true; // iOS doesn't need separate app

    try {
      final status = await getHealthConnectStatus();
      final isInstalled = status == HealthConnectSdkStatus.sdkAvailable;

      if (kDebugMode) {
        print(
          'Health Connect installation check: $isInstalled (status: $status)',
        );
      }

      return isInstalled;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking Health Connect installation: $e');
      }
      return false;
    }
  }

  /// Test permissions individually to prove they work
  /// This method demonstrates requesting each permission type one by one
  Future<void> testPermissionsIndividually() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (kDebugMode) {
      print('Testing permissions individually...');
    }

    for (final type in HealthPermissions.requiredPermissions) {
      try {
        final result = await Health().requestAuthorization([type]);
        if (kDebugMode) {
          print("$type => $result");
        }
      } catch (e) {
        if (kDebugMode) {
          print("$type => ERROR: $e");
        }
      }
    }

    if (kDebugMode) {
      print('Individual permission testing completed.');
    }
  }
}
