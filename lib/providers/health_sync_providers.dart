import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/health_sync_repository.dart';
import '../domain/entities/health_sync_entity.dart';
import '../domain/entities/observation_entity.dart';
import '../data/repositories/health_sync_repository_impl.dart';
import '../services/health_sync_service.dart';
import '../services/api_service.dart';

// Provider for ApiService
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

// Provider for HealthSyncRepository
final healthSyncRepositoryProvider = Provider<HealthSyncRepository>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return HealthSyncRepositoryImpl(apiService);
});

// Provider for HealthSyncService
final healthSyncServiceProvider = Provider<HealthSyncService>((ref) {
  final repository = ref.read(healthSyncRepositoryProvider);
  return HealthSyncService(repository);
});

// StateNotifier for managing health sync state
class HealthSyncNotifier extends StateNotifier<AsyncValue<HealthSyncEntity>> {
  final HealthSyncRepository _repository;
  final HealthSyncService _service;
  
  HealthSyncNotifier(this._repository, this._service) 
    : super(const AsyncValue.loading()) {
    _loadSyncStatus();
  }
  
  Future<void> _loadSyncStatus() async {
    try {
      final status = await _repository.getSyncStatus();
      state = AsyncValue.data(status);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  /// Request permissions for health data access
  Future<bool> requestPermissions(List<HealthDataType> dataTypes) async {
    try {
      final granted = await _service.requestPermissions(dataTypes);
      if (granted) {
        // Reload status to reflect updated permissions
        await _loadSyncStatus();
      }
      return granted;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }
  
  /// Perform manual sync
  Future<SyncResult> performSync({
    List<HealthDataType>? dataTypes,
    DateTime? since,
  }) async {
    // Update state to show syncing status
    state.whenData((currentStatus) {
      state = AsyncValue.data(currentStatus.copyWith(status: SyncStatus.syncing));
    });
    
    try {
      final result = await _service.performSync(
        specificDataTypes: dataTypes,
        since: since,
      );
      
      // Reload status to reflect sync results
      await _loadSyncStatus();
      
      return result;
    } catch (e) {
      // Reload status to reflect error state
      await _loadSyncStatus();
      rethrow;
    }
  }
  
  /// Initialize background sync (Android only)
  Future<void> initializeBackgroundSync() async {
    try {
      await _service.initializeBackgroundSync();
    } catch (e) {
      print('Error initializing background sync: $e');
    }
  }
  
  /// Schedule periodic sync
  Future<void> schedulePeriodicSync({Duration interval = const Duration(hours: 1)}) async {
    try {
      await _service.schedulePeriodicSync(interval: interval);
    } catch (e) {
      print('Error scheduling periodic sync: $e');
    }
  }
  
  /// Cancel periodic sync
  Future<void> cancelPeriodicSync() async {
    try {
      await _service.cancelPeriodicSync();
    } catch (e) {
      print('Error canceling periodic sync: $e');
    }
  }
  
  /// Check if periodic sync is currently enabled
  Future<bool> isPeriodicSyncEnabled() async {
    try {
      return await _service.isPeriodicSyncEnabled();
    } catch (e) {
      print('Error checking periodic sync status: $e');
      return false;
    }
  }
  
  /// Refresh sync status
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadSyncStatus();
  }
  
  /// Check if health sync is supported
  bool get isSupported => _service.isSupported;
  
  /// Get platform data source
  DataSource get platformDataSource => _service.platformDataSource;
}

// Provider for HealthSyncNotifier
final healthSyncNotifierProvider = 
  StateNotifierProvider<HealthSyncNotifier, AsyncValue<HealthSyncEntity>>((ref) {
  final repository = ref.read(healthSyncRepositoryProvider);
  final service = ref.read(healthSyncServiceProvider);
  return HealthSyncNotifier(repository, service);
});

// Convenience provider for getting sync status
final syncStatusProvider = Provider<AsyncValue<SyncStatus>>((ref) {
  return ref.watch(healthSyncNotifierProvider).whenData((entity) => entity.status);
});

// Provider for checking if permissions are granted
final hasHealthPermissionsProvider = FutureProvider.family<bool, List<HealthDataType>>((ref, dataTypes) async {
  final repository = ref.read(healthSyncRepositoryProvider);
  return await repository.hasPermissions(dataTypes);
});

// Provider for supported health data types
final supportedHealthDataTypesProvider = Provider<List<HealthDataType>>((ref) {
  return [
    HealthDataType.heartRate,
    HealthDataType.bloodPressureSystolic,
    HealthDataType.bloodPressureDiastolic,
    HealthDataType.bodyTemperature,
    HealthDataType.oxygenSaturation,
    HealthDataType.respiratoryRate,
    HealthDataType.steps,
    HealthDataType.bodyWeight,
    HealthDataType.bodyHeight,
  ];
});