import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_mode_provider.dart';
import 'connectivity_provider.dart';
import '../../services/api_service.dart';

/// Fetches backend/FHIR health status from the /health endpoint.
final healthStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final api = ref.read(apiServiceProvider);
  final alreadyOffline = ref.read(offlineModeProvider);
  final connectivity = ref.read(connectivityProvider);

  if (alreadyOffline || !connectivity) {
    return {
      'status': 'degraded',
      'fhir': {'status': 'unknown'},
      'error': 'offline',
    };
  }

  try {
    final status = await api.getHealthStatus();
    final backendStatus = status['status']?.toString() ?? 'unknown';
    final error = status['error']?.toString();

    final isOffline = error == 'offline';
    final isTimeout = error == 'timeout';
    final isUnreachable = backendStatus == 'unreachable';

    final offline = isOffline || isTimeout || isUnreachable;
    ref.read(offlineModeProvider.notifier).state = offline;
    ref.read(connectivityProvider.notifier).state = !offline;
    return status;
  } catch (e) {
    // If health check fails, assume offline to prevent further fetch attempts
    ref.read(offlineModeProvider.notifier).state = true;
    ref.read(connectivityProvider.notifier).state = false;
    rethrow;
  }
});
