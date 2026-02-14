import 'dart:math';

import 'package:uuid/uuid.dart';

import '../domain/entities/observation_entity.dart';
import 'simulation_profile.dart';

class SimulationService {
  const SimulationService();

  /// Generate one full day of synthetic observations for a profile.
  ///
  /// - Uses existing `ObservationEntity` + `ObservationType` LOINC mapping.
  /// - Sets `source` to `DataSource.simulation`.
  /// - Uses deterministic UUID v5 based on profileId + type + timestamp.
  List<ObservationEntity> generateOneDay({
    required SimulationProfile profile,
    required DateTime day,
  }) {
    final dayStart = DateTime(day.year, day.month, day.day);

    final observations = <ObservationEntity>[];

    // Heart rate: every 3 hours.
    for (final hour in const [0, 3, 6, 9, 12, 15, 18, 21]) {
      final ts = dayStart.add(Duration(hours: hour, minutes: 10));
      final value = _valueInRange(
        seed: '${profile.profileId}|hr|${_tsKey(ts)}',
        range: profile.heartRateBpm,
      );
      observations.add(
        _obs(
          profileId: profile.profileId,
          type: ObservationType.heartRate,
          value: value.roundToDouble(),
          unit: ObservationType.heartRate.standardUnit,
          timestamp: ts,
          category: ObservationCategory.vitalSigns,
          deviceInfo: 'simulation:${profile.profileId}',
        ),
      );
    }

    // SpO2: every 6 hours.
    for (final hour in const [0, 6, 12, 18]) {
      final ts = dayStart.add(Duration(hours: hour, minutes: 20));
      final value = _valueInRange(
        seed: '${profile.profileId}|spo2|${_tsKey(ts)}',
        range: profile.spo2Percent,
      );
      observations.add(
        _obs(
          profileId: profile.profileId,
          type: ObservationType.oxygenSaturation,
          value: value,
          unit: ObservationType.oxygenSaturation.standardUnit,
          timestamp: ts,
          category: ObservationCategory.vitalSigns,
          deviceInfo: 'simulation:${profile.profileId}',
        ),
      );
    }

    // Body temperature: every 6 hours.
    for (final hour in const [2, 8, 14, 20]) {
      final ts = dayStart.add(Duration(hours: hour, minutes: 30));
      final value = _valueInRange(
        seed: '${profile.profileId}|temp|${_tsKey(ts)}',
        range: profile.bodyTempC,
      );
      observations.add(
        _obs(
          profileId: profile.profileId,
          type: ObservationType.bodyTemperature,
          value: _round(value, 1),
          unit: ObservationType.bodyTemperature.standardUnit,
          timestamp: ts,
          category: ObservationCategory.vitalSigns,
          deviceInfo: 'simulation:${profile.profileId}',
        ),
      );
    }

    // Blood pressure: morning + evening, as two separate observations.
    for (final hour in const [9, 19]) {
      final ts = dayStart.add(Duration(hours: hour, minutes: 5));
      final sys = _valueInRange(
        seed: '${profile.profileId}|bps|${_tsKey(ts)}',
        range: profile.systolicMmHg,
      );
      final dia = _valueInRange(
        seed: '${profile.profileId}|bpd|${_tsKey(ts)}',
        range: profile.diastolicMmHg,
      );

      observations.add(
        _obs(
          profileId: profile.profileId,
          type: ObservationType.bloodPressureSystolic,
          value: sys.roundToDouble(),
          unit: ObservationType.bloodPressureSystolic.standardUnit,
          timestamp: ts,
          category: ObservationCategory.vitalSigns,
          deviceInfo: 'simulation:${profile.profileId}',
        ),
      );
      observations.add(
        _obs(
          profileId: profile.profileId,
          type: ObservationType.bloodPressureDiastolic,
          value: dia.roundToDouble(),
          unit: ObservationType.bloodPressureDiastolic.standardUnit,
          timestamp: ts,
          category: ObservationCategory.vitalSigns,
          deviceInfo: 'simulation:${profile.profileId}',
        ),
      );
    }

    // Stable ordering helps predictability and simplifies debugging.
    observations.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return observations;
  }

  ObservationEntity _obs({
    required String profileId,
    required ObservationType type,
    required double value,
    required String unit,
    required DateTime timestamp,
    required ObservationCategory category,
    required String deviceInfo,
  }) {
    final id = deterministicObservationId(
      profileId: profileId,
      type: type,
      timestamp: timestamp,
    );

    return ObservationEntity(
      id: id,
      type: type,
      value: value,
      unit: unit,
      timestamp: timestamp,
      category: category,
      source: DataSource.simulation,
      patientId: profileId,
      deviceInfo: deviceInfo,
    );
  }

  /// Deterministic UUID v5 based on profileId + type + timestamp.
  static String deterministicObservationId({
    required String profileId,
    required ObservationType type,
    required DateTime timestamp,
  }) {
    // Use UTC ISO string for stability across time zones.
    final ts = timestamp.toUtc().toIso8601String();
    final name = '$profileId|${type.name}|$ts';
    // `Uuid.NAMESPACE_URL` is deprecated in uuid >=4, but still provides
    // a stable String namespace value (required by the current v5 signature).
    // Keeping it avoids adding new dependencies or copying constants.
    return const Uuid().v5(Uuid.NAMESPACE_URL, name);
  }

  double _valueInRange({required String seed, required SimulationRange range}) {
    final t = _fnv1a32(seed);
    final unit = (t % 10000) / 10000.0;
    final value = range.min + unit * (range.max - range.min);
    return max(range.min, min(range.max, value));
  }

  // Stable, fast hash (no dependency on String.hashCode randomness).
  int _fnv1a32(String input) {
    const int fnvPrime = 0x01000193;
    const int offsetBasis = 0x811C9DC5;

    var hash = offsetBasis;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash;
  }

  String _tsKey(DateTime ts) {
    // Minute-level key is enough for our fixed schedule.
    final u = ts.toUtc();
    final mm = u.month.toString().padLeft(2, '0');
    final dd = u.day.toString().padLeft(2, '0');
    final hh = u.hour.toString().padLeft(2, '0');
    final mi = u.minute.toString().padLeft(2, '0');
    return '${u.year}-$mm-${dd}T$hh:$mi';
  }

  double _round(double v, int decimals) {
    final p = pow(10, decimals).toDouble();
    return (v * p).roundToDouble() / p;
  }
}
