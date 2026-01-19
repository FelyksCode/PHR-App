import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';

/// Provider for last vendor sync timestamp from backend.
final vendorLastSyncProvider = FutureProvider<DateTime?>((ref) async {
  final api = ref.read(apiServiceProvider);

  final isOnline = await api.isOnline();
  if (!isOnline) return null;

  return api.getLastVendorSyncTimestamp();
});
