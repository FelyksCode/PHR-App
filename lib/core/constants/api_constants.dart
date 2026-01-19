class ApiConstants {
  static const String baseUrl = 'http://10.0.2.2:8000';
  // static const String baseUrl = 'http://192.168.1.81:8000';
  static const String observationEndpoint = '/health-data/observation';
  static const String conditionEndpoint = '/health-data/condition';
  static const String healthDataEndpoint = '/health-data';
  static const String vendorsEndpoint = '/integrations/vendors';
  static const String vendorSelectEndpoint = '/integrations/vendors/select';
  static const String vendorDisconnectEndpoint =
      '/integrations/vendors/disconnect';
  static const String fitbitAuthorizeEndpoint =
      '/integrations/fitbit/authorize';
  static const String fitbitStatusEndpoint = '/integrations/fitbit/status';
  static const String healthObservationsEndpoint = '/health/observations';

  /// Backend-managed vendor sync trigger (returns 202 Accepted).
  static String vendorSyncEndpoint(String vendor) => '/vendors/$vendor/sync';

  /// Backend-managed sync job status.
  static const String syncStatusEndpoint = '/sync/status';

  /// Standardized Observation feed (single source of truth).
  static const String observationsEndpoint = '/observations';

  // Headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
