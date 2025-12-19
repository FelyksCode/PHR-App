import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Simple local cache for latest observations and conditions to support offline views.
class LocalCacheService {
  static const _observationsKey = 'cached_latest_observations';
  static const _conditionsKey = 'cached_latest_conditions';

  Future<void> cacheObservations(List<Map<String, dynamic>> observations) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(observations);
      final success = await prefs.setString(_observationsKey, encoded);
      print('✅ Cached ${observations.length} observations (success: $success)');
      print('📦 Data size: ${encoded.length} bytes');
      if (observations.isNotEmpty) {
        print('📝 Sample: ${observations.first}');
      }
      
      // Verify immediately after saving
      final verify = prefs.getString(_observationsKey);
      print('🔍 Verification: ${verify != null ? "Data saved successfully" : "WARNING: Data not found after save!"}');
    } catch (e, stack) {
      print('❌ Error caching observations: $e');
      print('Stack: $stack');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedObservations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      print('🔍 Looking for cached observations with key: $_observationsKey');
      final raw = prefs.getString(_observationsKey);
      if (raw == null) {
        print('⚠️ No cached observations found');
        // Check all keys to debug
        final allKeys = prefs.getKeys();
        print('📋 All SharedPreferences keys: $allKeys');
        return [];
      }
      print('📦 Found cached data: ${raw.length} bytes');
      final decoded = jsonDecode(raw) as List<dynamic>;
      final result = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      print('✅ Retrieved ${result.length} cached observations');
      if (result.isNotEmpty) {
        print('📝 Sample: ${result.first}');
      }
      return result;
    } catch (e, stack) {
      print('❌ Error decoding cached observations: $e');
      print('Stack: $stack');
      return [];
    }
  }

  Future<void> cacheConditions(List<Map<String, dynamic>> conditions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(conditions);
      final success = await prefs.setString(_conditionsKey, encoded);
      print('✅ Cached ${conditions.length} conditions (success: $success)');
      print('📦 Data size: ${encoded.length} bytes');
      if (conditions.isNotEmpty) {
        print('📝 Sample: ${conditions.first}');
      }
      
      // Verify immediately after saving
      final verify = prefs.getString(_conditionsKey);
      print('🔍 Verification: ${verify != null ? "Data saved successfully" : "WARNING: Data not found after save!"}');
    } catch (e, stack) {
      print('❌ Error caching conditions: $e');
      print('Stack: $stack');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedConditions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      print('🔍 Looking for cached conditions with key: $_conditionsKey');
      final raw = prefs.getString(_conditionsKey);
      if (raw == null) {
        print('⚠️ No cached conditions found');
        // Check all keys to debug
        final allKeys = prefs.getKeys();
        print('📋 All SharedPreferences keys: $allKeys');
        return [];
      }
      print('📦 Found cached data: ${raw.length} bytes');
      final decoded = jsonDecode(raw) as List<dynamic>;
      final result = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      print('✅ Retrieved ${result.length} cached conditions');
      if (result.isNotEmpty) {
        print('📝 Sample: ${result.first}');
      }
      return result;
    } catch (e, stack) {
      print('❌ Error decoding cached conditions: $e');
      print('Stack: $stack');
      return [];
    }
  }
}
