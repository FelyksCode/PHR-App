import '../entities/observation_entity.dart';
import '../entities/condition_entity.dart';

abstract class HealthDataRepository {
  Future<bool> submitObservation(ObservationEntity observation);
  Future<bool> submitCondition(ConditionEntity condition);
  Future<bool> submitFhirBundle(Map<String, dynamic> bundle);
  Future<List<ObservationEntity>> getObservations();
  Future<List<ConditionEntity>> getConditions();
}
