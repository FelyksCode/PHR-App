import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/api_constants.dart';
import '../core/errors/api_error_mapper.dart';
import '../core/errors/app_error.dart';
import '../core/errors/app_error_logger.dart';
import '../core/secure_storage/secure_storage_service.dart';
import '../core/utils/concurrency_pool.dart';
import '../core/utils/retry_with_backoff.dart';
import '../data/models/condition_model.dart';
import '../data/models/backend_sync_status.dart';
import '../data/models/health_observation.dart';
import '../data/models/observation_model.dart';
import '../domain/entities/condition_input.dart';
import '../domain/entities/observation_entity.dart';
import '../providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MultipleConditionSubmitResult {
  final int total;
  final List<String> succeededLocalIds;
  final Map<String, String> failedByLocalId;

  const MultipleConditionSubmitResult({
    required this.total,
    required this.succeededLocalIds,
    required this.failedByLocalId,
  });

  int get succeededCount => succeededLocalIds.length;
  int get failedCount => failedByLocalId.length;
}

typedef UnauthorizedCallback = Future<void> Function();

/// @deprecated Use AppError instead. This is kept for backward compatibility.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

class ApiService {
  final Dio _dio;
  final UnauthorizedCallback? _onUnauthorized;
  String? _cachedFhirPatientId;
  DateTime? _lastUserInfoFetch;
  static const Duration _cacheExpiry = Duration(hours: 1);

  ApiService({UnauthorizedCallback? onUnauthorized, Dio? dio})
    : _dio = dio ?? _createDefaultDio(),
      _onUnauthorized = onUnauthorized {
    _setupInterceptors();
  }

  static Dio _createDefaultDio() {
    return Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: ApiConstants.defaultHeaders,
      ),
    );
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _handleUnauthorized();
          }
          handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint(obj.toString()),
        ),
      );
    }
  }

  Future<String?> _getAccessToken() async {
    return await SecureStorageService.getAccessToken();
  }

  Future<void> _handleUnauthorized() async {
    await SecureStorageService.clearAll();
    await _onUnauthorized?.call();
  }

  ApiException _mapDioError(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    String message = error.message ?? 'Unexpected error';

    if (data is Map<String, dynamic>) {
      message =
          data['message']?.toString() ?? data['detail']?.toString() ?? message;
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      message = 'Connection timeout. Please try again.';
    } else if (error.type == DioExceptionType.connectionError ||
        error.error is SocketException) {
      message = 'Network error. Please check your connection.';
    }

    return ApiException(message, statusCode: status);
  }

  Future<Map<String, dynamic>?> getCurrentUserInfo() async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        AppErrorLogger.logError(
          UnknownError(
            'No access token found in storage',
            code: 'API_NO_TOKEN',
          ),
          source: 'ApiService.getCurrentUserInfo',
          severity: ErrorSeverity.low,
        );
        return null;
      }

      final response = await _dio.get(
        '/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final userInfo = response.data;
        // Cache the FHIR patient ID
        _cachedFhirPatientId = userInfo['fhir_patient_id']?.toString();
        _lastUserInfoFetch = DateTime.now();
        return userInfo;
      }
      return null;
    } on DioException catch (e, st) {
      AppErrorLogger.logError(
        ApiErrorMapper.fromException(e, stackTrace: st),
        source: 'ApiService.getCurrentUserInfo',
        severity: ErrorSeverity.medium,
      );
      return null;
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Unexpected error fetching current user info',
          code: 'API_USERINFO_UNEXPECTED',
          stackTrace: st,
          originalException: e,
        ),
        source: 'ApiService.getCurrentUserInfo',
        severity: ErrorSeverity.high,
      );
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
      final isOffline =
          e.type == DioExceptionType.connectionError ||
          e.error is SocketException;
      final isTimeout =
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout;

      return {
        'status': 'degraded',
        'fhir': {'status': 'unknown'},
        'error': isOffline
            ? 'offline'
            : isTimeout
            ? 'timeout'
            : (e.message ?? 'error'),
      };
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Unexpected error fetching health status',
          code: 'API_HEALTH_STATUS_UNEXPECTED',
          stackTrace: st,
          originalException: e,
        ),
        source: 'ApiService.getHealthStatus',
        severity: ErrorSeverity.medium,
      );
      return {
        'status': 'degraded',
        'fhir': {'status': 'unknown'},
        'error': e.toString(),
      };
    }
  }

  Future<void> selectVendor(String vendor) async {
    try {
      await _dio.post(
        ApiConstants.vendorSelectEndpoint,
        data: {'vendor': vendor},
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<void> disconnectVendor(String vendor) async {
    try {
      await _dio.post(
        ApiConstants.vendorDisconnectEndpoint,
        data: {'vendor': vendor},
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Uri> buildFitbitAuthorizeUri() async {
    return buildVendorAuthorizeUri('fitbit');
  }

  Future<Uri> buildVendorAuthorizeUri(String vendor) async {
    final base = _dio.options.baseUrl.endsWith('/')
        ? _dio.options.baseUrl.substring(0, _dio.options.baseUrl.length - 1)
        : _dio.options.baseUrl;

    final token = await _getAccessToken();
    final path = '/integrations/$vendor/authorize';
    final uri = Uri.parse('$base$path');
    if (token == null || token.isEmpty) {
      return uri;
    }

    final params = Map<String, String>.from(uri.queryParameters);
    params['token'] = token;
    return uri.replace(queryParameters: params);
  }

  Future<FitbitStatus> getFitbitStatus() async {
    return getVendorStatus('fitbit');
  }

  Future<FitbitStatus> getVendorStatus(String vendor) async {
    try {
      final response = await _dio.get('/integrations/$vendor/status');
      if (response.data is Map<String, dynamic>) {
        return FitbitStatus.fromJson(response.data as Map<String, dynamic>);
      }
      throw ApiException('Unexpected $vendor status response');
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Clean API: triggers Fitbit sync (job-based ingestion).
  Future<String?> triggerFitbitSync() => triggerVendorSync(vendor: 'fitbit');

  /// Clean API: fetch backend sync job status.
  Future<BackendSyncStatus> getSyncStatus() => getBackendSyncStatus();

  /// Clean API: fetch standardized observations from backend.
  Future<PaginatedHealthObservations> fetchObservations({
    String? type,
    int page = 1,
    int pageSize = 20,
  }) => fetchHealthObservations(type: type, page: page, pageSize: pageSize);

  /// Triggers a backend-managed vendor sync job.
  ///
  /// Expected behavior: 202 Accepted with no health data returned.
  Future<String?> triggerVendorSync({required String vendor}) async {
    try {
      final response = await _dio.post(ApiConstants.vendorSyncEndpoint(vendor));

      final status = response.statusCode ?? 0;
      if (status == 202 || status == 200 || status == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data['sync_job_id']?.toString() ??
              data['job_id']?.toString() ??
              data['id']?.toString();
        }
        return null;
      }

      throw ApiException(
        'Unexpected response triggering $vendor sync',
        statusCode: status,
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Retrieves backend sync job status.
  Future<BackendSyncStatus> getBackendSyncStatus() async {
    try {
      final response = await _dio.get(ApiConstants.syncStatusEndpoint);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final vendors = data['vendors'];
        if (vendors is List && vendors.isNotEmpty) {
          final mapped = vendors.whereType<Map<String, dynamic>>().toList();
          if (mapped.isNotEmpty) {
            // Prefer fitbit entry when present, otherwise fall back to first.
            final vendorEntry = mapped.firstWhere(
              (v) => v['vendor']?.toString().toLowerCase() == 'fitbit',
              orElse: () => mapped.first,
            );
            return BackendSyncStatus.fromJson(vendorEntry);
          }
        }

        return BackendSyncStatus.fromJson(data);
      }
      if (data is String) {
        return BackendSyncStatus.fromJson({'status': data});
      }
      return const BackendSyncStatus(status: BackendSyncStatusType.unknown);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Fetch the last vendor sync timestamp from the backend.
  Future<DateTime?> getLastVendorSyncTimestamp() async {
    try {
      final response = await _dio.get(ApiConstants.vendorsEndpoint);
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;

      final integrations = data['integrations'];
      if (integrations is! List || integrations.isEmpty) return null;

      final mapped = integrations.whereType<Map<String, dynamic>>().toList();
      if (mapped.isEmpty) return null;

      // Prefer the active integration if present, otherwise first in list
      final active = mapped.firstWhere(
        (i) => i['is_active'] == true,
        orElse: () => mapped.first,
      );

      final rawTs = active['last_sync_at']?.toString();
      if (rawTs == null || rawTs.isEmpty) return null;

      return DateTime.tryParse(rawTs)?.toLocal();
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<PaginatedHealthObservations> fetchHealthObservations({
    String? type,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.observationsEndpoint,
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (type != null && type.isNotEmpty && type != 'all') 'type': type,
        },
      );

      final data = response.data;
      List<dynamic> rawItems = [];
      int? total;
      var currentPage = page;
      var currentPageSize = pageSize;

      if (data is Map<String, dynamic>) {
        final items = data['items'] ?? data['results'] ?? data['data'];
        if (items is List) {
          rawItems = items;
        }
        total = data['total'] is int
            ? data['total'] as int
            : int.tryParse(data['total']?.toString() ?? '');
        currentPage = data['page'] is int ? data['page'] as int : currentPage;
        currentPageSize = data['page_size'] is int
            ? data['page_size'] as int
            : int.tryParse(data['page_size']?.toString() ?? '') ??
                  currentPageSize;
      } else if (data is List) {
        rawItems = data;
      }

      final observations = rawItems
          .whereType<Map<String, dynamic>>()
          .map(HealthObservation.fromJson)
          .toList();

      return PaginatedHealthObservations(
        items: observations,
        page: currentPage,
        pageSize: currentPageSize,
        total: total,
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Lightweight connectivity check to avoid expensive API calls when offline.
  Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 2));
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
        AppErrorLogger.logError(
          UnknownError(
            'No access token found in storage',
            code: 'API_NO_TOKEN_OBS',
          ),
          source: 'ApiService.submitObservation',
          severity: ErrorSeverity.medium,
        );
        return false;
      }

      // Get the current user's FHIR patient ID
      final fhirPatientId = await getFhirPatientId();
      if (fhirPatientId == null) {
        AppErrorLogger.logError(
          UnknownError(
            'Could not retrieve FHIR patient ID',
            code: 'API_NO_FHIR_ID_OBS',
          ),
          source: 'ApiService.submitObservation',
          severity: ErrorSeverity.medium,
        );
        return false;
      }

      // Create FHIR-compliant observation payload
      final fhirPayload = _createFhirObservation(observation, fhirPatientId);

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

      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e, st) {
      AppErrorLogger.logError(
        ApiErrorMapper.fromException(e, stackTrace: st),
        source: 'ApiService.submitObservation',
        severity: ErrorSeverity.medium,
      );
      return false;
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Unexpected error submitting observation',
          code: 'API_OBS_UNEXPECTED',
          stackTrace: st,
          originalException: e,
        ),
        source: 'ApiService.submitObservation',
        severity: ErrorSeverity.high,
      );
      return false;
    }
  }

  /// Submit a blood pressure panel observation with systolic and diastolic components
  /// Follows FHIR standard with component-based structure
  Future<bool> submitBloodPressurePanelObservation({
    required double systolic,
    required double diastolic,
    String? notes,
    DataSource source = DataSource.manual,
  }) async {
    try {
      // Get the stored access token
      final token = await _getAccessToken();
      if (token == null) {
        AppErrorLogger.logError(
          UnknownError(
            'No access token found in storage',
            code: 'API_NO_TOKEN_BP',
          ),
          source: 'ApiService.submitBloodPressurePanelObservation',
          severity: ErrorSeverity.medium,
        );
        return false;
      }

      // Get the current user's FHIR patient ID
      final fhirPatientId = await getFhirPatientId();
      if (fhirPatientId == null) {
        AppErrorLogger.logError(
          UnknownError(
            'Could not retrieve FHIR patient ID',
            code: 'API_NO_FHIR_ID_BP',
          ),
          source: 'ApiService.submitBloodPressurePanelObservation',
          severity: ErrorSeverity.medium,
        );
        return false;
      }

      // Create FHIR Blood Pressure Panel observation
      final fhirPayload = ObservationModel.createBloodPressurePanelFhir(
        systolic: systolic,
        diastolic: diastolic,
        patientId: fhirPatientId,
        notes: notes,
        source: source,
        category: ObservationCategory.vitalSigns,
      );

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

      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e, st) {
      AppErrorLogger.logError(
        ApiErrorMapper.fromException(e, stackTrace: st),
        source: 'ApiService.submitBloodPressurePanelObservation',
        severity: ErrorSeverity.medium,
      );
      return false;
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Unexpected error submitting blood pressure observation',
          code: 'API_BP_UNEXPECTED',
          stackTrace: st,
          originalException: e,
        ),
        source: 'ApiService.submitBloodPressurePanelObservation',
        severity: ErrorSeverity.high,
      );
      return false;
    }
  }

  Map<String, dynamic> _createFhirObservation(
    ObservationModel observation,
    String fhirPatientId,
  ) {
    return {
      "resourceType": "Observation",
      "status": "final",
      "category": [
        {
          "coding": [
            {
              "system":
                  "http://terminology.hl7.org/CodeSystem/observation-category",
              "code": "vital-signs",
              "display": "Vital Signs",
            },
          ],
        },
      ],
      "code": {
        "coding": [
          {
            "system": "http://loinc.org",
            "code": observation.type.loincCode,
            "display": observation.type.displayName,
          },
        ],
      },
      "subject": {"reference": "Patient/$fhirPatientId"},
      "effectiveDateTime": observation.timestamp.toIso8601String(),
      "valueQuantity": {
        "value": observation.value,
        "unit": _getDisplayUnit(observation.type),
        "system": "http://unitsofmeasure.org",
        "code": observation.type.standardUnit,
      },
      if (observation.notes != null)
        "note": [
          {"text": observation.notes},
        ],
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
      case ObservationType.caloriesBurned:
        return 'kcal';
    }
  }

  Future<bool> submitCondition(ConditionModel condition) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        AppErrorLogger.logError(
          UnknownError(
            'No access token found in storage',
            code: 'API_NO_TOKEN_COND',
          ),
          source: 'ApiService.submitCondition',
          severity: ErrorSeverity.medium,
        );
        return false;
      }

      // Get the current user's FHIR patient ID
      final fhirPatientId = await getFhirPatientId();
      if (fhirPatientId == null) {
        AppErrorLogger.logError(
          UnknownError(
            'Could not retrieve FHIR patient ID',
            code: 'API_NO_FHIR_ID_COND',
          ),
          source: 'ApiService.submitCondition',
          severity: ErrorSeverity.medium,
        );
        return false;
      }

      // Create FHIR-compliant condition payload using model's method
      final fhirPayload = condition.toFhirJson();

      // Set patient reference if not already set
      if (fhirPatientId.isNotEmpty) {
        fhirPayload['subject'] = {'reference': 'Patient/$fhirPatientId'};
      }

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

      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e, st) {
      AppErrorLogger.logError(
        ApiErrorMapper.fromException(e, stackTrace: st),
        source: 'ApiService.submitCondition',
        severity: ErrorSeverity.medium,
      );
      return false;
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Unexpected error submitting condition',
          code: 'API_COND_UNEXPECTED',
          stackTrace: st,
          originalException: e,
        ),
        source: 'ApiService.submitCondition',
        severity: ErrorSeverity.high,
      );
      return false;
    }
  }

  /// Submit multiple conditions in one user action.
  ///
  /// Backend constraint: one FHIR Condition per call.
  ///
  /// - Sends one request per condition
  /// - Limits concurrency to 3
  /// - Retries transient errors (429/502/503/504) with exponential backoff (max 3 retries)
  /// - Includes client-side idempotency key in Condition.identifier[0]
  Future<MultipleConditionSubmitResult> submitMultipleConditions(
    List<ConditionInput> conditions, {
    void Function(int completed, int total)? onProgress,
  }) async {
    if (conditions.isEmpty) {
      return const MultipleConditionSubmitResult(
        total: 0,
        succeededLocalIds: [],
        failedByLocalId: {},
      );
    }

    final token = await _getAccessToken();
    if (token == null) {
      return MultipleConditionSubmitResult(
        total: conditions.length,
        succeededLocalIds: const [],
        failedByLocalId: {
          for (final c in conditions) c.localId: 'Not authenticated',
        },
      );
    }

    var completed = 0;
    final succeeded = <String>[];
    final failed = <String, String>{};

    Future<void> submitOne(ConditionInput input) async {
      final payload = input.toFhirConditionJson();

      await retryWithBackoff(
        () async {
          final response = await _dio.post(
            '/fhir/Condition',
            data: payload,
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            ),
          );

          final code = response.statusCode ?? 0;
          if (code == 200 || code == 201) return;

          throw ApiException(
            'Unexpected response submitting condition',
            statusCode: code,
          );
        },
        shouldRetry: (error) {
          if (error is ApiException) {
            final code = error.statusCode;
            return code == 429 || code == 502 || code == 503 || code == 504;
          }
          if (error is DioException) {
            final code = error.response?.statusCode;
            return code == 429 || code == 502 || code == 503 || code == 504;
          }
          return false;
        },
        maxRetries: 3,
      );
    }

    await runWithConcurrencyLimit<ConditionInput, void>(
      items: conditions,
      limit: 3,
      task: (input, _) async {
        try {
          await submitOne(input);
          succeeded.add(input.localId);
        } on DioException catch (e) {
          final apiErr = _mapDioError(e);
          failed[input.localId] = apiErr.message;
        } on ApiException catch (e) {
          failed[input.localId] = e.message;
        } catch (e) {
          failed[input.localId] = e.toString();
        } finally {
          completed += 1;
          onProgress?.call(completed, conditions.length);
        }
      },
    );

    return MultipleConditionSubmitResult(
      total: conditions.length,
      succeededLocalIds: succeeded,
      failedByLocalId: failed,
    );
  }

  /// Submit a FHIR Bundle (transaction) containing multiple Condition resources
  /// This is used by the questionnaire system to batch submit symptoms and side effects
  Future<bool> submitFhirBundle(Map<String, dynamic> bundle) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        AppErrorLogger.logError(
          UnknownError(
            'No access token found in storage',
            code: 'API_NO_TOKEN_BUNDLE',
          ),
          source: 'ApiService.submitFhirBundle',
          severity: ErrorSeverity.medium,
        );
        return false;
      }

      final response = await _dio.post(
        '/fhir/Condition',
        data: bundle,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e, st) {
      AppErrorLogger.logError(
        ApiErrorMapper.fromException(e, stackTrace: st),
        source: 'ApiService.submitFhirBundle',
        severity: ErrorSeverity.medium,
      );
      return false;
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Unexpected error submitting FHIR bundle',
          code: 'API_BUNDLE_UNEXPECTED',
          stackTrace: st,
          originalException: e,
        ),
        source: 'ApiService.submitFhirBundle',
        severity: ErrorSeverity.high,
      );
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getLatestObservations({
    int count = 1000,
  }) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        AppErrorLogger.logError(
          UnknownError(
            'No access token found in storage',
            code: 'API_NO_TOKEN_OBS_FETCH',
          ),
          source: 'ApiService.getLatestObservations',
          severity: ErrorSeverity.medium,
        );
        return [];
      }

      // Get the current user's FHIR patient ID
      final fhirPatientId = await getFhirPatientId();
      if (fhirPatientId == null) {
        AppErrorLogger.logError(
          UnknownError(
            'Could not retrieve FHIR patient ID',
            code: 'API_NO_FHIR_ID_OBS_FETCH',
          ),
          source: 'ApiService.getLatestObservations',
          severity: ErrorSeverity.medium,
        );
        return [];
      }

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
        return [];
      }
    } on DioException catch (e, st) {
      AppErrorLogger.logError(
        ApiErrorMapper.fromException(e, stackTrace: st),
        source: 'ApiService.getLatestObservations',
        severity: ErrorSeverity.medium,
      );
      return [];
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Unexpected error fetching observations',
          code: 'API_OBS_FETCH_UNEXPECTED',
          stackTrace: st,
          originalException: e,
        ),
        source: 'ApiService.getLatestObservations',
        severity: ErrorSeverity.high,
      );
      return [];
    }
  }

  Map<String, dynamic> _parseObservationResource(
    Map<String, dynamic> resource,
  ) {
    try {
      // Extract key information from FHIR Observation resource
      final code = resource['code']?['coding']?[0];
      final valueQuantity = resource['valueQuantity'];
      final effectiveDateTime = resource['effectiveDateTime'];
      final note = resource['note']?[0]?['text'];
      final components = resource['component'] as List?;

      String type = code?['display'] ?? 'Unknown';
      final loincCode = code?['code'] as String?;
      dynamic value = valueQuantity?['value'];
      String? unit = valueQuantity?['unit'] as String?;

      num? systolicValue;
      num? diastolicValue;

      // If this is a component-based BP panel, extract component values
      if (components != null && components.isNotEmpty) {
        // Classify as Blood Pressure when panel code or display indicates it
        if ((type.toLowerCase().contains('blood pressure')) ||
            loincCode == '35094-2') {
          type = 'Blood Pressure';
        }

        for (final component in components) {
          final compCode = component['code']?['coding']?[0]?['code'] as String?;
          final compVQ = component['valueQuantity'] as Map<String, dynamic>?;
          final compVal = compVQ?['value'];
          if (compCode == '8480-6') {
            // Systolic
            if (compVal is num) systolicValue = compVal;
          } else if (compCode == '8462-4') {
            // Diastolic
            if (compVal is num) diastolicValue = compVal;
          }
          // Prefer unit from component if missing
          unit ??= compVQ?['unit'] as String?;
        }
        // At panel level, value is not present; keep null
        value = value; // unchanged
      }

      return {
        'id': resource['id'],
        'type': type,
        'loincCode': loincCode,
        'value': value,
        'unit': unit,
        'effectiveDateTime': effectiveDateTime,
        'notes': note,
        'status': resource['status'],
        if (components != null) 'component': components,
        if (systolicValue != null) 'systolicValue': systolicValue,
        if (diastolicValue != null) 'diastolicValue': diastolicValue,
      };
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Error parsing observation resource',
          code: 'API_OBS_PARSE_ERROR',
          stackTrace: st,
          originalException: e,
        ),
        source: 'ApiService._parseObservationResource',
        severity: ErrorSeverity.low,
      );
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

  Future<List<Map<String, dynamic>>> getLatestConditions({
    int count = 1000,
  }) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        AppErrorLogger.logError(
          UnknownError(
            'No access token found in storage',
            code: 'API_NO_TOKEN_COND_FETCH',
          ),
          source: 'ApiService.getLatestConditions',
          severity: ErrorSeverity.medium,
        );
        return [];
      }

      // Get the current user's FHIR patient ID
      final fhirPatientId = await getFhirPatientId();
      if (fhirPatientId == null) {
        AppErrorLogger.logError(
          UnknownError(
            'Could not retrieve FHIR patient ID',
            code: 'API_NO_FHIR_ID_COND_FETCH',
          ),
          source: 'ApiService.getLatestConditions',
          severity: ErrorSeverity.medium,
        );
        return [];
      }

      final response = await _dio.get(
        '/fhir/Condition',
        queryParameters: {
          'patient': fhirPatientId,
          '_count': count,
          '_sort':
              '-recorded-date', // Sort by recorded date descending (newest first)
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

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
        return [];
      }
    } on DioException catch (e, st) {
      AppErrorLogger.logError(
        ApiErrorMapper.fromException(e, stackTrace: st),
        source: 'ApiService.getLatestConditions',
        severity: ErrorSeverity.medium,
      );
      return [];
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Unexpected error fetching conditions',
          code: 'API_COND_FETCH_UNEXPECTED',
          stackTrace: st,
          originalException: e,
        ),
        source: 'ApiService.getLatestConditions',
        severity: ErrorSeverity.high,
      );
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
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Error parsing condition resource',
          code: 'API_COND_PARSE_ERROR',
          stackTrace: st,
          originalException: e,
        ),
        source: 'ApiService._parseConditionResource',
        severity: ErrorSeverity.low,
      );
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
    } on DioException catch (e, st) {
      AppErrorLogger.logError(
        ApiErrorMapper.fromException(e, stackTrace: st),
        source: 'ApiService.getHealthData',
        severity: ErrorSeverity.medium,
      );
      return null;
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Unexpected error fetching health data',
          code: 'API_HEALTH_DATA_UNEXPECTED',
          stackTrace: st,
          originalException: e,
        ),
        source: 'ApiService.getHealthData',
        severity: ErrorSeverity.high,
      );
      return null;
    }
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(
    onUnauthorized: () async {
      await ref.read(authProvider.notifier).logout();
    },
  );
});
