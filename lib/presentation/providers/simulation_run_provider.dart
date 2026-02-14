import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../simulation/simulation_runner.dart';
import '../../simulation/simulation_profile.dart';
import 'observation_providers.dart';

final simulationRunnerProvider = Provider<SimulationRunner>((ref) {
  final submitUseCase = ref.read(submitObservationUseCaseProvider);
  return SimulationRunner(submitUseCase);
});

class SimulationRunNotifier
    extends StateNotifier<AsyncValue<SimulationRunResult?>> {
  final SimulationRunner _runner;

  SimulationRunNotifier(this._runner) : super(const AsyncValue.data(null));

  Future<SimulationRunResult> runTodayAllProfiles() async {
    state = const AsyncValue.loading();
    try {
      final now = DateTime.now();
      final result = await _runner.runOneDayForAllProfiles(day: now);
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<SimulationRunResult> runTodayForProfile(SimulationProfile profile) async {
    state = const AsyncValue.loading();
    try {
      final now = DateTime.now();
      final result = await _runner.runOneDayForProfile(profile: profile, day: now);
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final simulationRunProvider =
    StateNotifierProvider<SimulationRunNotifier, AsyncValue<SimulationRunResult?>>(
      (ref) {
        final runner = ref.read(simulationRunnerProvider);
        return SimulationRunNotifier(runner);
      },
    );
