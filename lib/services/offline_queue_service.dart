import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/condition_model.dart';
import '../data/models/observation_model.dart';
import '../domain/entities/observation_entity.dart';
import 'api_service.dart';

class OfflineQueueService {
  static const String _observationsQueueKey = 'offline_observations_queue';
  static const String _conditionsQueueKey = 'offline_conditions_queue';
  
  final ApiService _apiService;
  final Connectivity _connectivity = Connectivity();
  
  OfflineQueueService(this._apiService) {
    _setupConnectivityListener();
  }
  
  void _setupConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((result) async {
      if (result.isNotEmpty && result.first != ConnectivityResult.none) {
        await syncQueuedData();
      }
    });
  }
  
  // Check if device is online
  Future<bool> isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    // Also verify with a quick ping-like check
    if (connectivityResult.isEmpty || connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }
    // If connectivity reports we're online, return true
    // The actual API call will fail gracefully if there's no real internet
    return true;
  }
  
  // Queue observation for later submission
  Future<void> queueObservation(ObservationEntity observation) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_observationsQueueKey) ?? '[]';
    final queue = List<Map<String, dynamic>>.from(json.decode(queueJson));
    
    queue.add({
      'data': observation.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    await prefs.setString(_observationsQueueKey, json.encode(queue));
  }
  
  // Queue condition for later submission
  Future<void> queueCondition(ConditionModel condition) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_conditionsQueueKey) ?? '[]';
    final queue = List<Map<String, dynamic>>.from(json.decode(queueJson));
    
    queue.add({
      'data': condition.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    await prefs.setString(_conditionsQueueKey, json.encode(queue));
  }
  
  // Get queued observations count
  Future<int> getQueuedObservationsCount() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_observationsQueueKey) ?? '[]';
    final queue = List<Map<String, dynamic>>.from(json.decode(queueJson));
    return queue.length;
  }
  
  // Get queued conditions count
  Future<int> getQueuedConditionsCount() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_conditionsQueueKey) ?? '[]';
    final queue = List<Map<String, dynamic>>.from(json.decode(queueJson));
    return queue.length;
  }
  
  // Sync all queued data
  Future<Map<String, dynamic>> syncQueuedData() async {
    if (!await isOnline()) {
      return {
        'success': false,
        'message': 'No internet connection',
      };
    }
    
    int successCount = 0;
    int failureCount = 0;
    
    // Sync observations
    final observationsResult = await _syncObservations();
    successCount += observationsResult['success'] as int;
    failureCount += observationsResult['failure'] as int;
    
    // Sync conditions
    final conditionsResult = await _syncConditions();
    successCount += conditionsResult['success'] as int;
    failureCount += conditionsResult['failure'] as int;
    
    return {
      'success': failureCount == 0,
      'successCount': successCount,
      'failureCount': failureCount,
      'message': failureCount == 0
          ? 'All queued data synced successfully ($successCount items)'
          : 'Synced $successCount items, $failureCount failed',
    };
  }
  
  // Sync queued observations
  Future<Map<String, int>> _syncObservations() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_observationsQueueKey) ?? '[]';
    final queue = List<Map<String, dynamic>>.from(json.decode(queueJson));
    
    if (queue.isEmpty) {
      return {'success': 0, 'failure': 0};
    }
    
    int successCount = 0;
    int failureCount = 0;
    final failedItems = <Map<String, dynamic>>[];
    
    for (final item in queue) {
      try {
        final observationData = item['data'] as Map<String, dynamic>;
        final observation = ObservationEntity.fromJson(observationData);
        
        // Convert entity to model for API submission
        final observationModel = ObservationModel.fromEntity(observation);
        final success = await _apiService.submitObservation(observationModel);
        
        if (success) {
          successCount++;
        } else {
          failureCount++;
          failedItems.add(item);
        }
      } catch (e) {
        failureCount++;
        failedItems.add(item);
      }
    }
    
    // Save only failed items back to queue
    await prefs.setString(_observationsQueueKey, json.encode(failedItems));
    
    return {'success': successCount, 'failure': failureCount};
  }
  
  // Sync queued conditions
  Future<Map<String, int>> _syncConditions() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_conditionsQueueKey) ?? '[]';
    final queue = List<Map<String, dynamic>>.from(json.decode(queueJson));
    
    if (queue.isEmpty) {
      return {'success': 0, 'failure': 0};
    }
    
    int successCount = 0;
    int failureCount = 0;
    final failedItems = <Map<String, dynamic>>[];
    
    for (final item in queue) {
      try {
        final conditionData = item['data'] as Map<String, dynamic>;
        final condition = ConditionModel.fromJson(conditionData);
        
        final success = await _apiService.submitCondition(condition);
        
        if (success) {
          successCount++;
        } else {
          failureCount++;
          failedItems.add(item);
        }
      } catch (e) {
        failureCount++;
        failedItems.add(item);
      }
    }
    
    // Save only failed items back to queue
    await prefs.setString(_conditionsQueueKey, json.encode(failedItems));
    
    return {'success': successCount, 'failure': failureCount};
  }
  
  // Get all queued observations
  Future<List<Map<String, dynamic>>> getQueuedObservations() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_observationsQueueKey) ?? '[]';
    final queue = List<Map<String, dynamic>>.from(json.decode(queueJson));
    return queue;
  }
  
  // Get all queued conditions
  Future<List<Map<String, dynamic>>> getQueuedConditions() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_conditionsQueueKey) ?? '[]';
    final queue = List<Map<String, dynamic>>.from(json.decode(queueJson));
    return queue;
  }
  
  // Clear all queued data
  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_observationsQueueKey);
    await prefs.remove(_conditionsQueueKey);
  }
}
