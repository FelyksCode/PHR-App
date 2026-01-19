import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../services/vendor_background_sync_service.dart';

// Provider for VendorBackgroundSyncService
final vendorBackgroundSyncServiceProvider =
    Provider<VendorBackgroundSyncService>((ref) {
      final apiService = ref.read(apiServiceProvider);
      return VendorBackgroundSyncService(apiService);
    });
