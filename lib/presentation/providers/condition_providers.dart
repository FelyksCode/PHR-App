import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/condition_entity.dart';
import '../../domain/usecases/condition_usecases.dart';
import 'observation_providers.dart'; // Import for healthDataRepositoryProvider

final submitConditionUseCaseProvider = Provider<SubmitConditionUseCase>((ref) {
  final repository = ref.watch(healthDataRepositoryProvider);
  return SubmitConditionUseCase(repository);
});

final getConditionsUseCaseProvider = Provider<GetConditionsUseCase>((ref) {
  final repository = ref.watch(healthDataRepositoryProvider);
  return GetConditionsUseCase(repository);
});

// State providers
final conditionsProvider = StateNotifierProvider<ConditionsNotifier, AsyncValue<List<ConditionEntity>>>((ref) {
  final getConditionsUseCase = ref.watch(getConditionsUseCaseProvider);
  return ConditionsNotifier(getConditionsUseCase);
});

final conditionSubmissionProvider = StateNotifierProvider<ConditionSubmissionNotifier, AsyncValue<bool?>>((ref) {
  final submitConditionUseCase = ref.watch(submitConditionUseCaseProvider);
  final conditionsNotifier = ref.watch(conditionsProvider.notifier);
  return ConditionSubmissionNotifier(submitConditionUseCase, conditionsNotifier);
});

class ConditionsNotifier extends StateNotifier<AsyncValue<List<ConditionEntity>>> {
  final GetConditionsUseCase _getConditionsUseCase;

  ConditionsNotifier(this._getConditionsUseCase) : super(const AsyncValue.loading()) {
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

  ConditionSubmissionNotifier(this._submitConditionUseCase, this._conditionsNotifier) 
      : super(const AsyncValue.data(null));

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