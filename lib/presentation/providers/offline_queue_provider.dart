import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/offline_queue_service.dart';
import '../../services/api_service.dart';

final offlineQueueServiceProvider = Provider<OfflineQueueService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return OfflineQueueService(apiService);
});

final queuedItemsCountProvider = StreamProvider<Map<String, int>>((ref) async* {
  final queueService = ref.watch(offlineQueueServiceProvider);

  while (true) {
    final observationsCount = await queueService.getQueuedObservationsCount();
    final conditionsCount = await queueService.getQueuedConditionsCount();

    yield {
      'observations': observationsCount,
      'conditions': conditionsCount,
      'total': observationsCount + conditionsCount,
    };

    await Future.delayed(const Duration(seconds: 5));
  }
});

// Provider to monitor online/offline status
final connectivityStatusProvider = StreamProvider<bool>((ref) async* {
  final queueService = ref.watch(offlineQueueServiceProvider);

  // Check initial status
  yield await queueService.isOnline();

  // Monitor connectivity changes every 3 seconds
  while (true) {
    await Future.delayed(const Duration(seconds: 3));
    yield await queueService.isOnline();
  }
});

// Provider to get queued observations data
final queuedObservationsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final queueService = ref.watch(offlineQueueServiceProvider);
  return queueService.getQueuedObservations();
});

// Provider to get queued conditions data
final queuedConditionsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final queueService = ref.watch(offlineQueueServiceProvider);
  return queueService.getQueuedConditions();
});
