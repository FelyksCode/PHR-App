import '../entities/condition_entity.dart';
import '../repositories/health_data_repository.dart';

class SubmitConditionUseCase {
  final HealthDataRepository _repository;

  SubmitConditionUseCase(this._repository);

  Future<bool> execute(ConditionEntity condition) async {
    return await _repository.submitCondition(condition);
  }
}

class GetConditionsUseCase {
  final HealthDataRepository _repository;

  GetConditionsUseCase(this._repository);

  Future<List<ConditionEntity>> execute() async {
    return await _repository.getConditions();
  }
}