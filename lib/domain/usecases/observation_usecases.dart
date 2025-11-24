import '../entities/observation_entity.dart';
import '../repositories/health_data_repository.dart';

class SubmitObservationUseCase {
  final HealthDataRepository _repository;

  SubmitObservationUseCase(this._repository);

  Future<bool> execute(ObservationEntity observation) async {
    return await _repository.submitObservation(observation);
  }
}

class GetObservationsUseCase {
  final HealthDataRepository _repository;

  GetObservationsUseCase(this._repository);

  Future<List<ObservationEntity>> execute() async {
    return await _repository.getObservations();
  }
}