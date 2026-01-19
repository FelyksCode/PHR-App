/// Data Source Configuration Entity
/// Defines the single automatic data ingestion source for the PHR app
library;

/// Enum representing supported automatic data sources
enum DataSourceType {
  /// Fitbit vendor cloud API (via Google OAuth)
  fitbit('fitbit', 'Fitbit'),

  /// Manual input only - no automatic sync
  manual('manual', 'Manual Entry');

  const DataSourceType(this.id, this.displayName);

  final String id;
  final String displayName;

  bool get isAutomatic => this == DataSourceType.fitbit;
  bool get isManual => this == DataSourceType.manual;
}

/// Configuration for the selected data source
class DataSourceConfig {
  final DataSourceType type;
  final DateTime? selectedAt;
  final bool isActive;

  const DataSourceConfig({
    required this.type,
    this.selectedAt,
    this.isActive = true,
  });

  DataSourceConfig copyWith({
    DataSourceType? type,
    DateTime? selectedAt,
    bool? isActive,
  }) {
    return DataSourceConfig(
      type: type ?? this.type,
      selectedAt: selectedAt ?? this.selectedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.id,
      'selectedAt': selectedAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory DataSourceConfig.fromJson(Map<String, dynamic> json) {
    final typeId = json['type'] as String?;
    final type = DataSourceType.values.firstWhere(
      (t) => t.id == typeId,
      orElse: () => DataSourceType.manual,
    );

    return DataSourceConfig(
      type: type,
      selectedAt: json['selectedAt'] != null
          ? DateTime.parse(json['selectedAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  static const DataSourceConfig defaultConfig = DataSourceConfig(
    type: DataSourceType.manual,
    isActive: true,
  );
}
