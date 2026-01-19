// Deprecated compatibility shim.
//
// The app no longer handles vendor health data pulls in Flutter.
// Use the new providers:
// - `vendorIntegrationProvider` for connection status / OAuth
// - `syncJobProvider` for triggering & polling backend-managed sync
// - `vendorBackgroundSyncServiceProvider` for WorkManager scheduling
// - `vendorLastSyncProvider` for backend timestamps

import '../../providers/vendor_integration_provider.dart';
import '../../providers/vendor_background_sync_provider.dart' as bg;
import '../../providers/vendor_last_sync_provider.dart' as last;

@Deprecated('Use vendorIntegrationProvider(\'fitbit\') instead.')
final fitbitVendorProvider = vendorIntegrationProvider('fitbit');

@Deprecated('Use providers/vendor_background_sync_provider.dart instead.')
final vendorBackgroundSyncServiceProvider =
    bg.vendorBackgroundSyncServiceProvider;

@Deprecated('Use providers/vendor_last_sync_provider.dart instead.')
final vendorLastSyncProvider = last.vendorLastSyncProvider;
