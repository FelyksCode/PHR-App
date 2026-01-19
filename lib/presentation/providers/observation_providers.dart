import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/observation_entity.dart';
import '../../domain/usecases/observation_usecases.dart';
import '../../data/repositories/health_data_repository_impl.dart';
import '../../services/api_service.dart';
import 'cache_providers.dart';
import 'offline_mode_provider.dart';
import 'connectivity_provider.dart';

final healthDataRepositoryProvider = Provider<HealthDataRepositoryImpl>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return HealthDataRepositoryImpl(apiService);
});

final submitObservationUseCaseProvider = Provider<SubmitObservationUseCase>((
  ref,
) {
  final repository = ref.watch(healthDataRepositoryProvider);
  return SubmitObservationUseCase(repository);
});

final getObservationsUseCaseProvider = Provider<GetObservationsUseCase>((ref) {
  final repository = ref.watch(healthDataRepositoryProvider);
  return GetObservationsUseCase(repository);
});

// State providers
final observationsProvider =
    StateNotifierProvider<
      ObservationsNotifier,
      AsyncValue<List<ObservationEntity>>
    >((ref) {
      final getObservationsUseCase = ref.watch(getObservationsUseCaseProvider);
      return ObservationsNotifier(getObservationsUseCase);
    });

final observationSubmissionProvider =
    StateNotifierProvider<ObservationSubmissionNotifier, AsyncValue<bool?>>((
      ref,
    ) {
      final submitObservationUseCase = ref.watch(
        submitObservationUseCaseProvider,
      );
      final observationsNotifier = ref.watch(observationsProvider.notifier);
      return ObservationSubmissionNotifier(
        submitObservationUseCase,
        observationsNotifier,
      );
    });

// Latest observations from FHIR API provider
final latestObservationsProvider =
    StateNotifierProvider<
      LatestObservationsNotifier,
      AsyncValue<List<Map<String, dynamic>>>
    >((ref) {
      final apiService = ref.watch(apiServiceProvider);
      final cache = ref.watch(localCacheServiceProvider);
      return LatestObservationsNotifier(ref, apiService, cache);
    });

class LatestObservationsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref _ref;
  final ApiService _apiService;
  final dynamic _cache; // LocalCacheService
  bool _initialized = false;

  LatestObservationsNotifier(this._ref, this._apiService, this._cache)
    : super(const AsyncValue.loading()) {
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    // Prevent multiple initializations
    if (_initialized) return;
    _initialized = true;

    try {
      // Load cached data first for instant display (especially offline)
      final cached = await _cache.getCachedObservations();
      if (cached.isNotEmpty) {
        state = AsyncValue.data(cached);
      }

      final online = await _apiService.isOnline();
      _ref.read(connectivityProvider.notifier).state = online;
      if (!online) {
        _ref.read(offlineModeProvider.notifier).state = true;
        return;
      } else {
        _ref.read(offlineModeProvider.notifier).state = false;
      }

      // Then try to fetch fresh data
      await loadLatestObservations();
    } catch (e, stack) {
      // Only update state if we haven't been disposed
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> loadLatestObservations() async {
    if (_isOffline()) {
      // Offline mode: skip fetching observations, use cache.
      final cached = await _cache.getCachedObservations();
      if (mounted) {
        state = AsyncValue.data(cached);
      }
      return;
    }

    try {
      final observations = await _apiService.getLatestObservations();
      if (mounted) {
        await _cache.cacheObservations(observations);
        state = AsyncValue.data(observations);
      }
    } catch (error, stackTrace) {
      if (!mounted) return;

      // Keep cached data if fetch fails and we already have it
      final currentData = state.value;
      if (currentData == null || currentData.isEmpty) {
        final cached = await _cache.getCachedObservations();
        if (mounted) {
          if (cached.isNotEmpty) {
            state = AsyncValue.data(cached);
          } else {
            state = AsyncValue.error(error, stackTrace);
          }
        }
      }
      // If we already have data showing, silently fail to keep current state
    }
  }

  Future<void> refresh() async {
    await loadLatestObservations();
  }

  bool _isOffline() {
    return !_ref.read(connectivityProvider) || _ref.read(offlineModeProvider);
  }
}

class ObservationsNotifier
    extends StateNotifier<AsyncValue<List<ObservationEntity>>> {
  final GetObservationsUseCase _getObservationsUseCase;

  ObservationsNotifier(this._getObservationsUseCase)
    : super(const AsyncValue.loading()) {
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

  ObservationSubmissionNotifier(
    this._submitObservationUseCase,
    this._observationsNotifier,
  ) : super(const AsyncValue.data(null));

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
