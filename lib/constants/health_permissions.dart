import 'package:health/health.dart';

/// Health permission data types and configurations for the PHR app
class HealthPermissions {
  /// List of all health data types that the app requests access to
  static const List<HealthDataType> requiredPermissions = [
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.STEPS,
  ];

  /// Access types for all required permissions (READ_WRITE for all)
  static List<HealthDataAccess> get accessTypes => 
      List.filled(requiredPermissions.length, HealthDataAccess.READ_WRITE);

  /// Permission categories for UI display
  static const List<HealthPermissionCategory> permissionCategories = [
    HealthPermissionCategory(
      icon: 'favorite',
      title: 'Heart Rate & Blood Pressure',
      description: 'Monitor cardiovascular health',
      color: 0xFFFF3B30,
      dataTypes: [
        HealthDataType.HEART_RATE,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      ],
    ),
    HealthPermissionCategory(
      icon: 'thermostat',
      title: 'Body Temperature',
      description: 'Track body temperature changes',
      color: 0xFFFF9500,
      dataTypes: [
        HealthDataType.BODY_TEMPERATURE,
      ],
    ),
    HealthPermissionCategory(
      icon: 'monitor_weight',
      title: 'Weight & Height',
      description: 'Monitor body composition',
      color: 0xFF34C759,
      dataTypes: [
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
      ],
    ),
    HealthPermissionCategory(
      icon: 'air',
      title: 'Oxygen Saturation',
      description: 'Track breathing and oxygen levels',
      color: 0xFF007AFF,
      dataTypes: [
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.RESPIRATORY_RATE,
        HealthDataType.STEPS,
      ],
    ),
  ];
}

/// Data class for health permission category information
class HealthPermissionCategory {
  const HealthPermissionCategory({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.dataTypes,
  });

  final String icon;
  final String title;
  final String description;
  final int color;
  final List<HealthDataType> dataTypes;
}