import 'package:dio/dio.dart';
import '../data/models/observation_model.dart';
import '../data/models/condition_model.dart';
import '../core/constants/api_constants.dart';

class ApiService {
  final Dio _dio;

  ApiService() : _dio = Dio() {
    _dio.options.baseUrl = ApiConstants.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add interceptors for logging in debug mode
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print(obj),
      ),
    );
  }

  Future<bool> submitObservation(ObservationModel observation) async {
    try {
      final response = await _dio.post(
        ApiConstants.observationEndpoint,
        data: observation.toFhirJson(),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      print('Error submitting observation: ${e.message}');
      return false;
    } catch (e) {
      print('Unexpected error submitting observation: $e');
      return false;
    }
  }

  Future<bool> submitCondition(ConditionModel condition) async {
    try {
      final response = await _dio.post(
        ApiConstants.conditionEndpoint,
        data: condition.toFhirJson(),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      print('Error submitting condition: ${e.message}');
      return false;
    } catch (e) {
      print('Unexpected error submitting condition: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getHealthData() async {
    try {
      final response = await _dio.get(ApiConstants.healthDataEndpoint);
      
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      print('Error fetching health data: ${e.message}');
      return null;
    } catch (e) {
      print('Unexpected error fetching health data: $e');
      return null;
    }
  }
}