import 'dart:io';

import 'package:dio/dio.dart';
import '../data/models/observation_model.dart';
import '../data/models/condition_model.dart';
import '../domain/entities/observation_entity.dart';
import '../core/constants/api_constants.dart';
import '../core/secure_storage/secure_storage_service.dart';

class ApiService {
  final Dio _dio;
  String? _cachedFhirPatientId;
  DateTime? _lastUserInfoFetch;
  static const Duration _cacheExpiry = Duration(hours: 1);

  ApiService() : _dio = Dio() {
    // Use base URL without /api suffix for FHIR endpoints
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

  Future<String?> _getAccessToken() async {
    return await SecureStorageService.getAccessToken();
  }

  Future<Map<String, dynamic>?> getCurrentUserInfo() async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        print('No access token found in storage');
        return null;
      }

      final response = await _dio.get(
        '/auth/me',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        final userInfo = response.data;
        // Cache the FHIR patient ID
        _cachedFhirPatientId = userInfo['fhir_patient_id']?.toString();
        _lastUserInfoFetch = DateTime.now();
        return userInfo;
      }
      return null;
    } on DioException catch (e) {
      print('Error fetching current user info: ${e.message}');
      print('Response status: ${e.response?.statusCode}');
      print('Response data: ${e.response?.data}');
      return null;
    } catch (e) {
      print('Unexpected error fetching current user info: $e');
      return null;
    }
  }

  Future<String?> getFhirPatientId() async {
    // Check if cached value is still valid
    if (_cachedFhirPatientId != null && 
        _lastUserInfoFetch != null &&
        DateTime.now().difference(_lastUserInfoFetch!) < _cacheExpiry) {
      return _cachedFhirPatientId;
    }
    
    // Fetch fresh user info
    final userInfo = await getCurrentUserInfo();
    return userInfo?['fhir_patient_id']?.toString();
  }

  Future<Map<String, dynamic>> getHealthStatus() async {
    try {
      final response = await _dio.get('/health');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data as Map);
      }

      return {
        'status': 'degraded',
        'fhir': {'status': 'unknown'},
        'error': 'Unexpected response ${response.statusCode}',
      };
    } on DioException catch (e) {
      final isOffline = e.type == DioExceptionType.connectionError || e.error is SocketException;
      final isTimeout = e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout;

      return {
        'status': 'degraded',
        'fhir': {'status': 'unknown'},
        'error': isOffline
            ? 'offline'
            : isTimeout
                ? 'timeout'
                : (e.message ?? 'error'),
      };
    } catch (e) {
      return {
        'status': 'degraded',
        'fhir': {'status': 'unknown'},
        'error': e.toString(),
      };
    }
  }

  /// Lightweight connectivity check to avoid expensive API calls when offline.
  Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> submitObservation(ObservationModel observation) async {
    try {
      // Get the stored access token
      final token = await _getAccessToken();
      if (token == null) {
        print('Error: No access token found in storage');
        return false;
      }

      // Get the current user's FHIR patient ID
      final fhirPatientId = await getFhirPatientId();
      if (fhirPatientId == null) {
        print('Error: Could not retrieve FHIR patient ID');
        return false;
      }
      
      // Create FHIR-compliant observation payload
      final fhirPayload = _createFhirObservation(observation, fhirPatientId);
      
      print('Submitting FHIR Observation:');
      print('Endpoint: /fhir/Observation');
      print('Patient ID: $fhirPatientId');
      print('Payload: $fhirPayload');
      
      final response = await _dio.post(
        '/fhir/Observation',
        data: fhirPayload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');
      
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      print('Error submitting observation: ${e.message}');
      print('Response status: ${e.response?.statusCode}');
      print('Response data: ${e.response?.data}');
      return false;
    } catch (e) {
      print('Unexpected error submitting observation: $e');
      return false;
    }
  }

  Map<String, dynamic> _createFhirObservation(ObservationModel observation, String fhirPatientId) {
    return {
      "resourceType": "Observation",
      "status": "final",
      "category": [
        {
          "coding": [
            {
              "system": "http://terminology.hl7.org/CodeSystem/observation-category",
              "code": "vital-signs",
              "display": "Vital Signs"
            }
          ]
        }
      ],
      "code": {
        "coding": [
          {
            "system": "http://loinc.org",
            "code": observation.type.loincCode,
            "display": observation.type.displayName
          }
        ]
      },
      "subject": {
        "reference": "Patient/$fhirPatientId"
      },
      "effectiveDateTime": observation.timestamp.toIso8601String(),
      "valueQuantity": {
        "value": observation.value,
        "unit": _getDisplayUnit(observation.type),
        "system": "http://unitsofmeasure.org",
        "code": observation.type.standardUnit
      },
      if (observation.notes != null) "note": [
        {
          "text": observation.notes
        }
      ]
    };
  }

  String _getDisplayUnit(ObservationType type) {
    switch (type) {
      case ObservationType.bodyWeight:
        return 'kg';
      case ObservationType.bodyHeight:
        return 'cm';
      case ObservationType.bodyTemperature:
        return '°C';
      case ObservationType.bloodPressureSystolic:
      case ObservationType.bloodPressureDiastolic:
        return 'mmHg';
      case ObservationType.oxygenSaturation:
        return '%';
      case ObservationType.heartRate:
        return 'bpm';
      case ObservationType.respiratoryRate:
        return 'breaths/min';
      case ObservationType.steps:
        return 'steps';
    }
  }

  Future<bool> submitCondition(ConditionModel condition) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        print('Error: No access token found in storage');
        return false;
      }

      // Get the current user's FHIR patient ID
      final fhirPatientId = await getFhirPatientId();
      if (fhirPatientId == null) {
        print('Error: Could not retrieve FHIR patient ID');
        return false;
      }

      // Create FHIR-compliant condition payload using model's method
      final fhirPayload = condition.toFhirJson();
      
      // Set patient reference if not already set
      if (fhirPatientId.isNotEmpty) {
        fhirPayload['subject'] = {
          'reference': 'Patient/$fhirPatientId'
        };
      }

      print('Submitting FHIR Condition:');
      print('Endpoint: /fhir/Condition');
      print('Patient ID: $fhirPatientId');
      print('Payload: $fhirPayload');

      final response = await _dio.post(
        '/fhir/Condition',
        data: fhirPayload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');
      
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      print('Error submitting condition: ${e.message}');
      print('Response status: ${e.response?.statusCode}');
      print('Response data: ${e.response?.data}');
      return false;
    } catch (e) {
      print('Unexpected error submitting condition: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getLatestObservations({int count = 1000}) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        print('Error: No access token found in storage');
        return [];
      }

      // Get the current user's FHIR patient ID
      final fhirPatientId = await getFhirPatientId();
      if (fhirPatientId == null) {
        print('Error: Could not retrieve FHIR patient ID');
        return [];
      }

      print('Fetching latest observations for patient: $fhirPatientId');
      
      final response = await _dio.get(
        '/fhir/Observation',
        queryParameters: {
          'patient': fhirPatientId,
          '_count': count,
          '_sort': '-date', // Sort by date descending (newest first)
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      print('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data.containsKey('entry')) {
          final entries = data['entry'] as List?;
          if (entries != null) {
            return entries.map((entry) {
              final resource = entry['resource'] as Map<String, dynamic>;
              return _parseObservationResource(resource);
            }).toList();
          }
        }
        return [];
      } else {
        print('Failed to fetch observations: ${response.statusCode}');
        return [];
      }
    } on DioException catch (e) {
      print('Error fetching observations: ${e.message}');
      print('Response status: ${e.response?.statusCode}');
      print('Response data: ${e.response?.data}');
      return [];
    } catch (e) {
      print('Unexpected error fetching observations: $e');
      return [];
    }
  }

  Map<String, dynamic> _parseObservationResource(Map<String, dynamic> resource) {
    try {
      // Extract key information from FHIR Observation resource
      final code = resource['code']?['coding']?[0];
      final valueQuantity = resource['valueQuantity'];
      final effectiveDateTime = resource['effectiveDateTime'];
      final note = resource['note']?[0]?['text'];

      return {
        'id': resource['id'],
        'type': code?['display'] ?? 'Unknown',
        'loincCode': code?['code'],
        'value': valueQuantity?['value'],
        'unit': valueQuantity?['unit'],
        'effectiveDateTime': effectiveDateTime,
        'notes': note,
        'status': resource['status'],
      };
    } catch (e) {
      print('Error parsing observation resource: $e');
      return {
        'id': resource['id'] ?? 'unknown',
        'type': 'Parse Error',
        'value': null,
        'unit': null,
        'effectiveDateTime': null,
        'notes': null,
        'status': 'unknown',
      };
    }
  }

  Future<List<Map<String, dynamic>>> getLatestConditions({int count = 1000}) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        print('Error: No access token found in storage');
        return [];
      }

      // Get the current user's FHIR patient ID
      final fhirPatientId = await getFhirPatientId();
      if (fhirPatientId == null) {
        print('Error: Could not retrieve FHIR patient ID');
        return [];
      }

      print('Fetching latest conditions for patient: $fhirPatientId');
      
      final response = await _dio.get(
        '/fhir/Condition',
        queryParameters: {
          'patient': fhirPatientId,
          '_count': count,
          '_sort': '-recorded-date', // Sort by recorded date descending (newest first)
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      print('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data.containsKey('entry')) {
          final entries = data['entry'] as List?;
          if (entries != null) {
            return entries.map((entry) {
              final resource = entry['resource'] as Map<String, dynamic>;
              return _parseConditionResource(resource);
            }).toList();
          }
        }
        return [];
      } else {
        print('Failed to fetch conditions: ${response.statusCode}');
        return [];
      }
    } on DioException catch (e) {
      print('Error fetching conditions: ${e.message}');
      print('Response status: ${e.response?.statusCode}');
      print('Response data: ${e.response?.data}');
      return [];
    } catch (e) {
      print('Unexpected error fetching conditions: $e');
      return [];
    }
  }

  Map<String, dynamic> _parseConditionResource(Map<String, dynamic> resource) {
    try {
      // Extract key information from FHIR Condition resource
      final code = resource['code'];
      final severity = resource['severity']?['coding']?[0];
      final clinicalStatus = resource['clinicalStatus']?['coding']?[0];
      final category = resource['category']?[0]?['coding']?[0];
      final recordedDate = resource['recordedDate'];
      final onsetDateTime = resource['onsetDateTime'];
      final note = resource['note']?[0]?['text'];

      // Extract condition text/display and code details
      String conditionText = 'Unknown Condition';
      String? snomedCode;
      String? codeSystem;
      
      if (code != null) {
        // Prioritize text field first (FHIR best practice)
        if (code['text'] != null) {
          conditionText = code['text'];
        } else if (code['coding'] != null && code['coding'].isNotEmpty) {
          final coding = code['coding'][0];
          conditionText = coding['display'] ?? conditionText;
        }
        
        // Extract SNOMED code details from coding array
        if (code['coding'] != null && code['coding'].isNotEmpty) {
          final coding = code['coding'][0];
          snomedCode = coding['code'];
          codeSystem = coding['system'];
        }
      }

      return {
        'id': resource['id'],
        'condition': conditionText,
        'conditionCode': snomedCode,
        'codeSystem': codeSystem,
        'severity': severity?['display'] ?? 'Unknown',
        'severityCode': severity?['code'],
        'clinicalStatus': clinicalStatus?['display'] ?? 'Unknown',
        'category': category?['display'] ?? 'Unknown',
        'recordedDate': recordedDate,
        'onsetDateTime': onsetDateTime,
        'notes': note,
        // Full FHIR resource for debugging
        'rawCode': code,
      };
    } catch (e) {
      print('Error parsing condition resource: $e');
      return {
        'id': resource['id'] ?? 'unknown',
        'condition': 'Parse Error',
        'severity': 'Unknown',
        'clinicalStatus': 'Unknown',
        'category': 'Unknown',
        'recordedDate': null,
        'onsetDateTime': null,
        'notes': null,
      };
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