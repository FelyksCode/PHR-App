class ApiConstants {
  static const String baseUrl = 'http://10.0.2.2:8000';
  static const String observationEndpoint = '/health-data/observation';
  static const String conditionEndpoint = '/health-data/condition';
  static const String healthDataEndpoint = '/health-data';
  static const String vendorSelectEndpoint = '/integrations/vendors/select';
  static const String fitbitAuthorizeEndpoint = '/integrations/fitbit/authorize';
  static const String fitbitStatusEndpoint = '/integrations/fitbit/status';
  static const String syncImmediateEndpoint = '/health/sync/immediate';
  static const String healthObservationsEndpoint = '/health/observations';
  
  // Headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}