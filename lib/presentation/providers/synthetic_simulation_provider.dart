import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_mode.dart';
import '../../domain/usecases/questionnaire_usecases.dart';
import '../../services/api_service.dart';
import '../../simulation/simulation_profile.dart';
import '../../simulation/synthetic_data_service.dart';
import 'observation_providers.dart';

enum SyntheticSimulationStatus { idle, running, success, error }

enum SyntheticSimulationStep {
  initializing,
  generatingConditions,
  generatingSymptoms,
  savingLocalState,
  syncingBackend,
}

extension SyntheticSimulationStepText on SyntheticSimulationStep {
  String get label {
    switch (this) {
      case SyntheticSimulationStep.initializing:
        return 'Initializing simulation…';
      case SyntheticSimulationStep.generatingConditions:
        return 'Generating synthetic conditions…';
      case SyntheticSimulationStep.generatingSymptoms:
        return 'Generating synthetic symptoms…';
      case SyntheticSimulationStep.savingLocalState:
        return 'Saving data to local state…';
      case SyntheticSimulationStep.syncingBackend:
        return 'Syncing data to backend…';
    }
  }
}

class SyntheticSimulationState {
  final SyntheticSimulationStatus status;
  final SyntheticSimulationStep? step;
  final SimulationProfile? profile;
  final String? errorMessage;

  const SyntheticSimulationState._({
    required this.status,
    this.step,
    this.profile,
    this.errorMessage,
  });

  const SyntheticSimulationState.idle() : this._(status: SyntheticSimulationStatus.idle);

  const SyntheticSimulationState.running({
    required SimulationProfile profile,
    required SyntheticSimulationStep step,
  }) : this._(status: SyntheticSimulationStatus.running, profile: profile, step: step);

  const SyntheticSimulationState.success({required SimulationProfile profile})
    : this._(status: SyntheticSimulationStatus.success, profile: profile);

  const SyntheticSimulationState.error({
    required SimulationProfile profile,
    required String message,
  }) : this._(status: SyntheticSimulationStatus.error, profile: profile, errorMessage: message);
}

final syntheticDataServiceProvider = Provider<SyntheticDataService>((ref) {
  return const SyntheticDataService();
});

final submitQuestionnaireUseCaseProvider = Provider<SubmitQuestionnaireUseCase>((ref) {
  final repository = ref.watch(healthDataRepositoryProvider);
  return SubmitQuestionnaireUseCase(repository);
});

class SyntheticSimulationNotifier extends StateNotifier<SyntheticSimulationState> {
  final ApiService _api;
  final SubmitQuestionnaireUseCase _submitQuestionnaireUseCase;
  final SyntheticDataService _syntheticDataService;

  SyntheticSimulationNotifier(
    this._api,
    this._submitQuestionnaireUseCase,
    this._syntheticDataService,
  ) : super(const SyntheticSimulationState.idle());

  Future<void> run({required SimulationProfile profile}) async {
    if (!AppConfig.isSimulation) {
      state = SyntheticSimulationState.error(
        profile: profile,
        message: 'Simulation is disabled in production mode.',
      );
      return;
    }

    try {
      state = SyntheticSimulationState.running(
        profile: profile,
        step: SyntheticSimulationStep.initializing,
      );
      await Future<void>.delayed(const Duration(milliseconds: 350));

      final patientId = await _api.getFhirPatientId();
      if (patientId == null || patientId.trim().isEmpty) {
        throw StateError('Unable to resolve FHIR patient id');
      }

      state = SyntheticSimulationState.running(
        profile: profile,
        step: SyntheticSimulationStep.generatingConditions,
      );
      final conditions = _syntheticDataService.generateSyntheticConditions(
        profile: profile,
      );
      await Future<void>.delayed(const Duration(milliseconds: 450));

      state = SyntheticSimulationState.running(
        profile: profile,
        step: SyntheticSimulationStep.generatingSymptoms,
      );
      final symptoms = _syntheticDataService.generateSyntheticSymptoms(
        profile: profile,
      );
      await Future<void>.delayed(const Duration(milliseconds: 450));

      state = SyntheticSimulationState.running(
        profile: profile,
        step: SyntheticSimulationStep.savingLocalState,
      );

      // Build the transaction bundle in memory (no partial local commits).
      final now = DateTime.now();
      final response = _syntheticDataService.buildCombinedResponse(
        profile: profile,
        timestamp: now,
        patientId: patientId,
        note:
            'Synthetic simulation run (${profile.displayName}) — conditions=${conditions.length}, symptoms=${symptoms.length}',
      );

      await Future<void>.delayed(const Duration(milliseconds: 350));

      state = SyntheticSimulationState.running(
        profile: profile,
        step: SyntheticSimulationStep.syncingBackend,
      );

      final ok = await _submitQuestionnaireUseCase.execute(
        response: response,
        patientId: patientId,
      );

      if (!ok) {
        throw StateError('Backend sync failed');
      }

      state = SyntheticSimulationState.success(profile: profile);
    } catch (e) {
      state = SyntheticSimulationState.error(
        profile: profile,
        message: e.toString(),
      );
    }
  }

  void reset() {
    state = const SyntheticSimulationState.idle();
  }
}

final syntheticSimulationProvider =
    StateNotifierProvider<SyntheticSimulationNotifier, SyntheticSimulationState>((ref) {
      final api = ref.watch(apiServiceProvider);
      final submit = ref.watch(submitQuestionnaireUseCaseProvider);
      final synth = ref.watch(syntheticDataServiceProvider);
      return SyntheticSimulationNotifier(api, submit, synth);
    });
