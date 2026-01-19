import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/condition_entity.dart';
import '../../domain/usecases/condition_usecases.dart';
import '../../services/api_service.dart';
import 'observation_providers.dart'; // Import for healthDataRepositoryProvider
import 'cache_providers.dart';
import 'offline_mode_provider.dart';
import 'connectivity_provider.dart';

final submitConditionUseCaseProvider = Provider<SubmitConditionUseCase>((ref) {
  final repository = ref.watch(healthDataRepositoryProvider);
  return SubmitConditionUseCase(repository);
});

final getConditionsUseCaseProvider = Provider<GetConditionsUseCase>((ref) {
  final repository = ref.watch(healthDataRepositoryProvider);
  return GetConditionsUseCase(repository);
});

// State providers
final conditionsProvider =
    StateNotifierProvider<
      ConditionsNotifier,
      AsyncValue<List<ConditionEntity>>
    >((ref) {
      final getConditionsUseCase = ref.watch(getConditionsUseCaseProvider);
      return ConditionsNotifier(getConditionsUseCase);
    });

final conditionSubmissionProvider =
    StateNotifierProvider<ConditionSubmissionNotifier, AsyncValue<bool?>>((
      ref,
    ) {
      final submitConditionUseCase = ref.watch(submitConditionUseCaseProvider);
      final conditionsNotifier = ref.watch(conditionsProvider.notifier);
      return ConditionSubmissionNotifier(
        submitConditionUseCase,
        conditionsNotifier,
      );
    });

// Latest conditions from FHIR API provider
final latestConditionsProvider =
    StateNotifierProvider<
      LatestConditionsNotifier,
      AsyncValue<List<Map<String, dynamic>>>
    >((ref) {
      final apiService = ref.watch(apiServiceProvider);
      final cache = ref.watch(localCacheServiceProvider);
      return LatestConditionsNotifier(ref, apiService, cache);
    });

class LatestConditionsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref _ref;
  final dynamic _apiService; // ApiService type
  final dynamic _cache; // LocalCacheService

  LatestConditionsNotifier(this._ref, this._apiService, this._cache)
    : super(const AsyncValue.loading()) {
    _loadWithCache();
  }

  Future<void> _loadWithCache() async {
    try {
      // Load cached data first for instant display (especially offline)
      final cached = await _cache.getCachedConditions();
      if (!mounted) return;

      if (cached.isNotEmpty) {
        state = AsyncValue.data(cached);
      }

      final online = await _apiService.isOnline();
      if (!mounted) return;

      _ref.read(connectivityProvider.notifier).state = online;
      if (!online) {
        _ref.read(offlineModeProvider.notifier).state = true;
        return;
      } else {
        _ref.read(offlineModeProvider.notifier).state = false;
      }

      // Then try to fetch fresh data
      await loadLatestConditions();
    } catch (e, stack) {
      if (!mounted) return;
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadLatestConditions() async {
    if (_isOffline()) {
      // Offline mode: skip fetching conditions, use cache.
      final cached = await _cache.getCachedConditions();
      if (!mounted) return;
      state = AsyncValue.data(cached);
      return;
    }

    try {
      final conditions = await _apiService.getLatestConditions(count: 10);
      if (!mounted) return;

      await _cache.cacheConditions(conditions);
      if (!mounted) return;

      state = AsyncValue.data(conditions);
    } catch (error, stackTrace) {
      // Keep cached data if fetch fails and we already have it
      final currentData = state.value;
      if (currentData == null || currentData.isEmpty) {
        final cached = await _cache.getCachedConditions();
        if (!mounted) return;

        if (cached.isNotEmpty) {
          state = AsyncValue.data(cached);
        } else {
          state = AsyncValue.error(error, stackTrace);
        }
      } else {}
      // If we already have data showing, silently fail to keep current state
    }
  }

  Future<void> refresh() async {
    await loadLatestConditions();
  }

  bool _isOffline() {
    return !_ref.read(connectivityProvider) || _ref.read(offlineModeProvider);
  }
}

class ConditionsNotifier
    extends StateNotifier<AsyncValue<List<ConditionEntity>>> {
  final GetConditionsUseCase _getConditionsUseCase;

  ConditionsNotifier(this._getConditionsUseCase)
    : super(const AsyncValue.loading()) {
    loadConditions();
  }

  Future<void> loadConditions() async {
    try {
      state = const AsyncValue.loading();
      final conditions = await _getConditionsUseCase.execute();
      state = AsyncValue.data(conditions);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void addCondition(ConditionEntity condition) {
    final currentConditions = state.value ?? [];
    state = AsyncValue.data([...currentConditions, condition]);
  }
}

class ConditionSubmissionNotifier extends StateNotifier<AsyncValue<bool?>> {
  final SubmitConditionUseCase _submitConditionUseCase;
  final ConditionsNotifier _conditionsNotifier;

  ConditionSubmissionNotifier(
    this._submitConditionUseCase,
    this._conditionsNotifier,
  ) : super(const AsyncValue.data(null));

  Future<void> submitCondition(ConditionEntity condition) async {
    try {
      state = const AsyncValue.loading();
      final success = await _submitConditionUseCase.execute(condition);
      state = AsyncValue.data(success);

      if (success) {
        _conditionsNotifier.addCondition(condition);
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void resetSubmissionState() {
    state = const AsyncValue.data(null);
  }
}
