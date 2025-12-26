import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/app_error.dart';
import '../core/errors/app_error_logger.dart';

/// Simple local cache for latest observations and conditions to support offline views.
class LocalCacheService {
  static const _observationsKey = 'cached_latest_observations';
  static const _conditionsKey = 'cached_latest_conditions';

  Future<void> cacheObservations(List<Map<String, dynamic>> observations) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(observations);
      await prefs.setString(_observationsKey, encoded);
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Error caching observations',
          code: 'CACHE_OBS_ERROR',
          stackTrace: st,
          originalException: e,
        ),
        source: 'LocalCacheService.cacheObservations',
        severity: ErrorSeverity.medium,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getCachedObservations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_observationsKey);
      if (raw == null) {
        return [];
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      final result = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return result;
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Error decoding cached observations',
          code: 'CACHE_OBS_DECODE_ERROR',
          stackTrace: st,
          originalException: e,
        ),
        source: 'LocalCacheService.getCachedObservations',
        severity: ErrorSeverity.medium,
      );
      return [];
    }
  }

  Future<void> cacheConditions(List<Map<String, dynamic>> conditions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(conditions);
      await prefs.setString(_conditionsKey, encoded);
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Error caching conditions',
          code: 'CACHE_COND_ERROR',
          stackTrace: st,
          originalException: e,
        ),
        source: 'LocalCacheService.cacheConditions',
        severity: ErrorSeverity.medium,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getCachedConditions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_conditionsKey);
      if (raw == null) {
        return [];
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      final result = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return result;
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Error decoding cached conditions',
          code: 'CACHE_COND_DECODE_ERROR',
          stackTrace: st,
          originalException: e,
        ),
        source: 'LocalCacheService.getCachedConditions',
        severity: ErrorSeverity.medium,
      );
      return [];
    }
  }
}
