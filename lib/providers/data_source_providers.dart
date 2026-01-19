import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/data_source_config.dart';
import '../services/data_source_selection_service.dart';
import '../services/data_ingestion_service.dart';
import '../services/api_service.dart';

// Provider for DataSourceSelectionService
final dataSourceSelectionServiceProvider = Provider<DataSourceSelectionService>(
  (ref) {
    return DataSourceSelectionService();
  },
);

// Provider for DataIngestionService
final dataIngestionServiceProvider = Provider<DataIngestionService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  final selectionService = ref.read(dataSourceSelectionServiceProvider);
  return DataIngestionService(apiService, selectionService);
});

// StateNotifier for managing data source configuration
class DataSourceConfigNotifier
    extends StateNotifier<AsyncValue<DataSourceConfig>> {
  final DataSourceSelectionService _service;

  DataSourceConfigNotifier(this._service) : super(const AsyncValue.loading()) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await _service.getSelectedDataSource();
      state = AsyncValue.data(config);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Select a new data source (single source enforcement)
  Future<bool> selectDataSource(DataSourceType type) async {
    try {
      await _service.setDataSource(type);
      await _loadConfig();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Deactivate current data source
  Future<void> deactivate() async {
    try {
      await _service.deactivateDataSource();
      await _loadConfig();
    } catch (e) {
      // Ignore errors on deactivation
    }
  }

  /// Refresh configuration
  Future<void> refresh() async {
    await _loadConfig();
  }
}

// Provider for data source configuration state
final dataSourceConfigProvider =
    StateNotifierProvider<
      DataSourceConfigNotifier,
      AsyncValue<DataSourceConfig>
    >((ref) {
      final service = ref.read(dataSourceSelectionServiceProvider);
      return DataSourceConfigNotifier(service);
    });

// Provider for checking if automatic ingestion is available
final automaticIngestionAvailableProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(dataIngestionServiceProvider);
  return await service.isAutomaticIngestionAvailable();
});

// Provider for current ingestion status message
final ingestionStatusProvider = FutureProvider<String>((ref) async {
  final service = ref.read(dataIngestionServiceProvider);
  return await service.getIngestionStatus();
});
