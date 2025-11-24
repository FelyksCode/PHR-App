import '../../domain/entities/observation_entity.dart';
import '../../domain/entities/condition_entity.dart';
import '../../domain/repositories/health_data_repository.dart';
import '../models/observation_model.dart';
import '../models/condition_model.dart';
import '../../services/api_service.dart';

class HealthDataRepositoryImpl implements HealthDataRepository {
  final ApiService _apiService;
  final List<ObservationEntity> _observationsCache = [];
  final List<ConditionEntity> _conditionsCache = [];

  HealthDataRepositoryImpl(this._apiService);

  @override
  Future<bool> submitObservation(ObservationEntity observation) async {
    try {
      final observationModel = ObservationModel.fromEntity(observation);
      final success = await _apiService.submitObservation(observationModel);
      
      if (success) {
        _observationsCache.add(observation);
      }
      
      return success;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> submitCondition(ConditionEntity condition) async {
    try {
      final conditionModel = ConditionModel.fromEntity(condition);
      final success = await _apiService.submitCondition(conditionModel);
      
      if (success) {
        _conditionsCache.add(condition);
      }
      
      return success;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<ObservationEntity>> getObservations() async {
    return List.from(_observationsCache);
  }

  @override
  Future<List<ConditionEntity>> getConditions() async {
    return List.from(_conditionsCache);
  }
}