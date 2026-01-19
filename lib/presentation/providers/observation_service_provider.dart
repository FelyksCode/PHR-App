import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/observation_entity.dart';
import '../../domain/usecases/observation_usecases.dart';
import '../../data/repositories/health_data_repository_impl.dart';
import '../../services/api_service.dart';

class ObservationService extends ChangeNotifier {
  final ApiService _apiService;
  late final HealthDataRepositoryImpl _repository;
  late final SubmitObservationUseCase _submitUseCase;
  late final GetObservationsUseCase _getUseCase;

  // Callbacks to refresh Riverpod providers
  VoidCallback? _refreshObservationsCallback;
  VoidCallback? _refreshConditionsCallback;

  ObservationService(this._apiService) {
    _repository = HealthDataRepositoryImpl(_apiService);
    _submitUseCase = SubmitObservationUseCase(_repository);
    _getUseCase = GetObservationsUseCase(_repository);
  }

  // Set callback functions to refresh providers after successful submissions
  void setRefreshCallbacks({
    VoidCallback? refreshObservations,
    VoidCallback? refreshConditions,
  }) {
    _refreshObservationsCallback = refreshObservations;
    _refreshConditionsCallback = refreshConditions;
  }

  Future<bool> submitObservation(ObservationEntity observation) async {
    try {
      final success = await _submitUseCase.execute(observation);
      if (success) {
        // Refresh providers after successful submission
        _refreshObservationsCallback?.call();
        _refreshConditionsCallback?.call();
      }
      return success;
    } catch (e) {
      debugPrint('Error submitting observation: $e');
      return false;
    }
  }

  Future<bool> submitMultipleObservations(
    List<ObservationEntity> observations,
  ) async {
    try {
      bool allSuccess = true;
      for (final observation in observations) {
        final success = await _submitUseCase.execute(observation);
        if (!success) {
          allSuccess = false;
        }
      }
      if (allSuccess) {
        // Refresh providers after successful submission
        _refreshObservationsCallback?.call();
        _refreshConditionsCallback?.call();
      }
      return allSuccess;
    } catch (e) {
      debugPrint('Error submitting observations: $e');
      return false;
    }
  }

  /// Submit a blood pressure panel observation with systolic and diastolic components
  /// Uses FHIR component-based structure for better compliance
  Future<bool> submitBloodPressurePanelObservation({
    required double systolic,
    required double diastolic,
    String? notes,
    DataSource source = DataSource.manual,
  }) async {
    try {
      final success = await _apiService.submitBloodPressurePanelObservation(
        systolic: systolic,
        diastolic: diastolic,
        notes: notes,
        source: source,
      );
      if (success) {
        // Refresh providers after successful submission
        _refreshObservationsCallback?.call();
        _refreshConditionsCallback?.call();
      }
      return success;
    } catch (e) {
      debugPrint('Error submitting blood pressure panel: $e');
      return false;
    }
  }

  Future<List<ObservationEntity>> getObservations() async {
    try {
      return await _getUseCase.execute();
    } catch (e) {
      debugPrint('Error getting observations: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLatestObservations({
    int count = 10,
  }) async {
    try {
      return await _apiService.getLatestObservations(count: count);
    } catch (e) {
      debugPrint('Error getting latest observations: $e');
      return [];
    }
  }
}

// Riverpod provider for ObservationService
final observationServiceProvider = Provider<ObservationService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return ObservationService(apiService);
});
