class ApiConstants {
  static const String baseUrl = 'http://localhost:8080/api';
  static const String observationEndpoint = '/health-data/observation';
  static const String conditionEndpoint = '/health-data/condition';
  static const String healthDataEndpoint = '/health-data';
  
  // Headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}