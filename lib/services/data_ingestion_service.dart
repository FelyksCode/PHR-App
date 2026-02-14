import '../domain/entities/data_source_config.dart';
import '../core/errors/app_error.dart';
import '../core/errors/app_error_logger.dart';
import '../core/config/app_mode.dart';
import 'api_service.dart';
import 'data_source_selection_service.dart';

/// Result of data ingestion operation
class IngestionResult {
  final bool success;
  final String message;
  final int createdCount;
  final int failedCount;
  final String? errorDetails;

  const IngestionResult({
    required this.success,
    required this.message,
    this.createdCount = 0,
    this.failedCount = 0,
    this.errorDetails,
  });

  factory IngestionResult.success(int created, int failed) {
    return IngestionResult(
      success: true,
      message: 'Sync completed: $created created, $failed failed',
      createdCount: created,
      failedCount: failed,
    );
  }

  factory IngestionResult.error(String error, {String? details}) {
    return IngestionResult(
      success: false,
      message: error,
      errorDetails: details,
    );
  }

  factory IngestionResult.noActiveSource() {
    return const IngestionResult(
      success: false,
      message:
          'No automatic data source configured. Please select a data source.',
    );
  }
}

/// Centralized service for health data ingestion
/// Enforces single automatic ingestion path based on selected data source
class DataIngestionService {
  final ApiService _apiService;
  final DataSourceSelectionService _selectionService;

  DataIngestionService(this._apiService, this._selectionService);

  /// Single entry point for automatic health data ingestion
  /// Routes to appropriate vendor based on selected data source
  Future<IngestionResult> ingestHealthData() async {
    try {
      if (AppConfig.isSimulation) {
        return IngestionResult.error(
          'Simulation mode: Fitbit sync is disabled',
        );
      }

      // Get active data source
      final config = await _selectionService.getSelectedDataSource();

      if (!config.isActive || config.type.isManual) {
        return IngestionResult.noActiveSource();
      }

      // Route to appropriate vendor
      switch (config.type) {
        case DataSourceType.fitbit:
          return await _ingestFromFitbit();

        case DataSourceType.manual:
          return IngestionResult.noActiveSource();
      }
    } catch (e, stackTrace) {
      AppErrorLogger.logError(
        UnknownError(
          'Error during data ingestion',
          code: 'INGESTION_ERROR',
          stackTrace: stackTrace,
          originalException: e,
        ),
        source: 'DataIngestionService.ingestHealthData',
        severity: ErrorSeverity.high,
      );

      return IngestionResult.error(
        'Failed to ingest health data',
        details: e.toString(),
      );
    }
  }

  /// Ingest data from Fitbit vendor cloud API
  Future<IngestionResult> _ingestFromFitbit() async {
    try {
      // Check if Fitbit is connected
      final status = await _apiService.getFitbitStatus();

      if (!status.isConnected) {
        return IngestionResult.error(
          'Fitbit is not connected',
          details: 'Please connect Fitbit in Data Sources settings',
        );
      }

      // Trigger backend-managed sync job (202 Accepted).
      // Backend handles: Vendor API call → normalization → Observation creation.
      await _apiService.triggerVendorSync(vendor: 'fitbit');
      return const IngestionResult(
        success: true,
        message: 'Sync request accepted. Check sync status for progress.',
      );
    } catch (e, stackTrace) {
      AppErrorLogger.logError(
        UnknownError(
          'Error ingesting Fitbit data',
          code: 'FITBIT_INGESTION_ERROR',
          stackTrace: stackTrace,
          originalException: e,
        ),
        source: 'DataIngestionService._ingestFromFitbit',
        severity: ErrorSeverity.high,
      );

      return IngestionResult.error(
        'Failed to sync Fitbit data',
        details: e.toString(),
      );
    }
  }

  /// Get the currently active data source
  Future<DataSourceConfig> getActiveDataSource() async {
    return await _selectionService.getSelectedDataSource();
  }

  /// Check if automatic ingestion is available
  Future<bool> isAutomaticIngestionAvailable() async {
    return await _selectionService.hasActiveAutomaticSource();
  }

  /// Get friendly status message for current configuration
  Future<String> getIngestionStatus() async {
    final config = await _selectionService.getSelectedDataSource();

    if (!config.isActive || config.type.isManual) {
      return 'Manual entry mode - no automatic sync';
    }

    switch (config.type) {
      case DataSourceType.fitbit:
        try {
          final status = await _apiService.getFitbitStatus();
          if (status.isConnected) {
            return 'Fitbit connected - automatic sync enabled';
          } else {
            return 'Fitbit selected but not connected';
          }
        } catch (e) {
          return 'Fitbit selected - connection status unknown';
        }

      case DataSourceType.manual:
        return 'Manual entry mode';
    }
  }
}
