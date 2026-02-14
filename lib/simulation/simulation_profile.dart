import '../domain/entities/condition_entity.dart';

class SimulationRange {
  final double min;
  final double max;

  const SimulationRange({required this.min, required this.max})
    : assert(min <= max);
}

/// Exactly 3 simulated outpatient profiles.
class SimulationProfile {
  final String profileId;
  final String displayName;

  // Expected vital sign ranges
  final SimulationRange heartRateBpm;
  final SimulationRange systolicMmHg;
  final SimulationRange diastolicMmHg;
  final SimulationRange spo2Percent;
  final SimulationRange bodyTempC;

  // Symptom severity baseline (for future symptom generation).
  final ConditionSeverity symptomSeverityBaseline;

  const SimulationProfile({
    required this.profileId,
    required this.displayName,
    required this.heartRateBpm,
    required this.systolicMmHg,
    required this.diastolicMmHg,
    required this.spo2Percent,
    required this.bodyTempC,
    required this.symptomSeverityBaseline,
  });

  static const SimulationProfile stableOutpatient = SimulationProfile(
    profileId: 'stable_outpatient',
    displayName: 'Stable Outpatient',
    heartRateBpm: SimulationRange(min: 60, max: 85),
    systolicMmHg: SimulationRange(min: 110, max: 130),
    diastolicMmHg: SimulationRange(min: 70, max: 85),
    spo2Percent: SimulationRange(min: 96, max: 99),
    bodyTempC: SimulationRange(min: 36.4, max: 37.2),
    symptomSeverityBaseline: ConditionSeverity.mild,
  );

  static const SimulationProfile treatmentSideEffectPatient = SimulationProfile(
    profileId: 'treatment_side_effect',
    displayName: 'Treatment Side-Effect Patient',
    heartRateBpm: SimulationRange(min: 78, max: 108),
    systolicMmHg: SimulationRange(min: 95, max: 125),
    diastolicMmHg: SimulationRange(min: 60, max: 82),
    spo2Percent: SimulationRange(min: 93, max: 97),
    bodyTempC: SimulationRange(min: 37.2, max: 38.2),
    symptomSeverityBaseline: ConditionSeverity.moderate,
  );

  static const SimulationProfile highRiskOutpatient = SimulationProfile(
    profileId: 'high_risk_outpatient',
    displayName: 'High-Risk Outpatient',
    heartRateBpm: SimulationRange(min: 92, max: 130),
    systolicMmHg: SimulationRange(min: 135, max: 175),
    diastolicMmHg: SimulationRange(min: 85, max: 110),
    spo2Percent: SimulationRange(min: 88, max: 94),
    bodyTempC: SimulationRange(min: 36.8, max: 38.8),
    symptomSeverityBaseline: ConditionSeverity.severe,
  );

  static const List<SimulationProfile> all = [
    stableOutpatient,
    treatmentSideEffectPatient,
    highRiskOutpatient,
  ];
}
