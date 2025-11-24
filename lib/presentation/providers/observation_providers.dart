import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/observation_entity.dart';
import '../../domain/usecases/observation_usecases.dart';
import '../../data/repositories/health_data_repository_impl.dart';
import '../../services/api_service.dart';

// Providers
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final healthDataRepositoryProvider = Provider<HealthDataRepositoryImpl>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return HealthDataRepositoryImpl(apiService);
});

final submitObservationUseCaseProvider = Provider<SubmitObservationUseCase>((ref) {
  final repository = ref.watch(healthDataRepositoryProvider);
  return SubmitObservationUseCase(repository);
});

final getObservationsUseCaseProvider = Provider<GetObservationsUseCase>((ref) {
  final repository = ref.watch(healthDataRepositoryProvider);
  return GetObservationsUseCase(repository);
});

// State providers
final observationsProvider = StateNotifierProvider<ObservationsNotifier, AsyncValue<List<ObservationEntity>>>((ref) {
  final getObservationsUseCase = ref.watch(getObservationsUseCaseProvider);
  return ObservationsNotifier(getObservationsUseCase);
});

final observationSubmissionProvider = StateNotifierProvider<ObservationSubmissionNotifier, AsyncValue<bool?>>((ref) {
  final submitObservationUseCase = ref.watch(submitObservationUseCaseProvider);
  final observationsNotifier = ref.watch(observationsProvider.notifier);
  return ObservationSubmissionNotifier(submitObservationUseCase, observationsNotifier);
});

class ObservationsNotifier extends StateNotifier<AsyncValue<List<ObservationEntity>>> {
  final GetObservationsUseCase _getObservationsUseCase;

  ObservationsNotifier(this._getObservationsUseCase) : super(const AsyncValue.loading()) {
    loadObservations();
  }

  Future<void> loadObservations() async {
    try {
      state = const AsyncValue.loading();
      final observations = await _getObservationsUseCase.execute();
      state = AsyncValue.data(observations);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void addObservation(ObservationEntity observation) {
    final currentObservations = state.value ?? [];
    state = AsyncValue.data([...currentObservations, observation]);
  }
}

class ObservationSubmissionNotifier extends StateNotifier<AsyncValue<bool?>> {
  final SubmitObservationUseCase _submitObservationUseCase;
  final ObservationsNotifier _observationsNotifier;

  ObservationSubmissionNotifier(this._submitObservationUseCase, this._observationsNotifier) 
      : super(const AsyncValue.data(null));

  Future<void> submitObservation(ObservationEntity observation) async {
    try {
      state = const AsyncValue.loading();
      final success = await _submitObservationUseCase.execute(observation);
      state = AsyncValue.data(success);
      
      if (success) {
        _observationsNotifier.addObservation(observation);
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void resetSubmissionState() {
    state = const AsyncValue.data(null);
  }
}