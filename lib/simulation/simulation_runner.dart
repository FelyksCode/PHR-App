import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/observation_entity.dart';
import '../domain/usecases/observation_usecases.dart';
import 'simulation_profile.dart';
import 'simulation_service.dart';

class SimulationRunResult {
  final DateTime day;
  final int profilesProcessed;
  final int observationsGenerated;
  final int observationsSubmitted;
  final int profilesSkippedAlreadyRun;

  const SimulationRunResult({
    required this.day,
    required this.profilesProcessed,
    required this.observationsGenerated,
    required this.observationsSubmitted,
    required this.profilesSkippedAlreadyRun,
  });
}

class SimulationRunner {
  final SubmitObservationUseCase _submitObservationUseCase;
  final SimulationService _simulationService;

  SimulationRunner(this._submitObservationUseCase, {SimulationService? service})
    : _simulationService = service ?? const SimulationService();

  static const String _dedupPrefix = 'simulation_run_day_v1';

  Future<SimulationRunResult> runOneDayForProfile({
    required SimulationProfile profile,
    required DateTime day,
  }) async {
    return runOneDayForProfiles(day: day, profiles: [profile]);
  }

  Future<SimulationRunResult> runOneDayForProfiles({
    required DateTime day,
    required List<SimulationProfile> profiles,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    var profilesProcessed = 0;
    var generated = 0;
    var submitted = 0;
    var skipped = 0;

    for (final profile in profiles) {
      final key = _dedupKey(profile.profileId, day);
      final alreadyRun = prefs.getBool(key) == true;
      if (alreadyRun) {
        skipped++;
        continue;
      }

      profilesProcessed++;
      final obs = _simulationService.generateOneDay(profile: profile, day: day);
      generated += obs.length;

      final ok = await _submitObservations(obs);
      if (ok) {
        submitted += obs.length;
        await prefs.setBool(key, true);
      }
    }

    return SimulationRunResult(
      day: DateTime(day.year, day.month, day.day),
      profilesProcessed: profilesProcessed,
      observationsGenerated: generated,
      observationsSubmitted: submitted,
      profilesSkippedAlreadyRun: skipped,
    );
  }

  Future<SimulationRunResult> runOneDayForAllProfiles({
    required DateTime day,
  }) async {
    return runOneDayForProfiles(day: day, profiles: SimulationProfile.all);
  }

  Future<bool> _submitObservations(List<ObservationEntity> observations) async {
    // Uses existing submission flow (use case → repository → ApiService → FHIR mapping).
    var ok = true;
    for (final obs in observations) {
      final success = await _submitObservationUseCase.execute(obs);
      if (!success) ok = false;
    }
    return ok;
  }

  String _dedupKey(String profileId, DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$_dedupPrefix::$profileId::${d.year}-$mm-$dd';
  }
}
