import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../domain/entities/data_source_config.dart';

/// Service for managing persistent data source selection
/// Ensures only one automatic ingestion path is active at any time
class DataSourceSelectionService {
  static const String _configKey = 'data_source_config';

  /// Get currently selected data source configuration
  Future<DataSourceConfig> getSelectedDataSource() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(_configKey);

      if (configJson != null) {
        final map = json.decode(configJson) as Map<String, dynamic>;
        return DataSourceConfig.fromJson(map);
      }

      return DataSourceConfig.defaultConfig;
    } catch (e) {
      // If error reading config, return default
      return DataSourceConfig.defaultConfig;
    }
  }

  /// Set the active data source
  /// This is the single point for configuring data ingestion
  Future<void> setDataSource(DataSourceType type) async {
    final config = DataSourceConfig(
      type: type,
      selectedAt: DateTime.now(),
      isActive: true,
    );

    await _saveConfig(config);
  }

  /// Deactivate current data source (switch to manual mode)
  Future<void> deactivateDataSource() async {
    final currentConfig = await getSelectedDataSource();
    final updatedConfig = currentConfig.copyWith(
      type: DataSourceType.manual,
      selectedAt: DateTime.now(),
      isActive: false,
    );

    await _saveConfig(updatedConfig);
  }

  /// Check if an automatic data source is currently active
  Future<bool> hasActiveAutomaticSource() async {
    final config = await getSelectedDataSource();
    return config.isActive && config.type.isAutomatic;
  }

  /// Get the type of currently active data source
  Future<DataSourceType> getActiveSourceType() async {
    final config = await getSelectedDataSource();
    return config.type;
  }

  /// Save configuration to persistent storage
  Future<void> _saveConfig(DataSourceConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = json.encode(config.toJson());
    await prefs.setString(_configKey, configJson);
  }

  /// Clear all data source configuration (reset to default)
  Future<void> clearConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
  }
}
