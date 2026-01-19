# Quick Start Guide - Refactored Data Ingestion

## For Developers

### How to Use the New Architecture

#### 1. Checking Current Data Source
```dart
// In any widget with WidgetRef
final configState = ref.watch(dataSourceConfigProvider);

configState.when(
  data: (config) {
    print('Active source: ${config.type.displayName}');
    print('Is automatic: ${config.type.isAutomatic}');
  },
  loading: () => print('Loading...'),
  error: (e, _) => print('Error: $e'),
);
```

#### 2. Changing Data Source
```dart
// Get the notifier
final configNotifier = ref.read(dataSourceConfigProvider.notifier);

// Select Fitbit
await configNotifier.selectDataSource(DataSourceType.fitbit);

// Switch to manual mode
await configNotifier.selectDataSource(DataSourceType.manual);

// Or deactivate
await configNotifier.deactivate();
```

#### 3. Triggering Data Ingestion
```dart
// Get the service
final ingestionService = ref.read(dataIngestionServiceProvider);

// Single entry point for automatic ingestion
final result = await ingestionService.ingestHealthData();

if (result.success) {
  print('Synced: ${result.createdCount} created, ${result.failedCount} failed');
} else {
  print('Error: ${result.message}');
}
```

#### 4. Checking Ingestion Status
```dart
// Get friendly status message
final statusProvider = ref.watch(ingestionStatusProvider);

statusProvider.when(
  data: (status) => Text(status),
  loading: () => CircularProgressIndicator(),
  error: (e, _) => Text('Error'),
);
```

## For Users

### Setup Flow

1. **Open the app** → Defaults to Manual Entry mode

2. **Navigate to Settings** → Wearable Sources

3. **Select a data source:**
   - **Fitbit**: Automatic sync from Fitbit cloud
   - **Manual Entry**: No automatic sync, manual input only

4. **If Fitbit selected:**
   - Tap "Select & Connect Fitbit"
   - Complete OAuth in browser
   - Return to app
   - Tap "Sync now" to fetch data

5. **Verify active source:**
   - Dashboard shows "Active Source" badge
   - Sync button enabled only for active source

### Switching Sources

**To switch from Fitbit to Manual:**
1. Go to Data Sources
2. Tap "Select Manual Entry"
3. Confirm switch
4. Automatic sync disabled

**To switch from Manual to Fitbit:**
1. Go to Data Sources
2. Tap "Select & Connect Fitbit" on Fitbit card
3. Complete OAuth if not already connected
4. Automatic sync enabled

**To disconnect Fitbit:**
1. Go to Data Sources
2. Tap "Disconnect" on Fitbit card
3. Confirm disconnection
4. Automatically switched to Manual Entry mode

## Key Points

✅ **Only one automatic source** at a time  
✅ **Manual entry** always available  
✅ **No Health Connect** prompts or permissions  
✅ **Clear visual indicators** showing active source  
✅ **Persistent selection** across app restarts  

## Troubleshooting

### Sync button is disabled
**Cause:** Data source not selected or not connected  
**Solution:** 
1. Check active source on Data Sources screen
2. If Fitbit not selected, select it
3. If not connected, complete OAuth flow

### "No automatic data source configured" message
**Cause:** Manual mode is active  
**Solution:** Select Fitbit as data source to enable automatic sync

### Fitbit connected but can't sync
**Cause:** Fitbit is connected but not selected as active source  
**Solution:** Tap "Select Fitbit" on Data Sources screen

### Token expiring soon warning
**Cause:** OAuth token needs renewal  
**Solution:** Tap "Re-authorize" button to refresh token

## Code Examples

### Complete Fitbit Setup Flow
```dart
// 1. Select Fitbit as data source
final configNotifier = ref.read(dataSourceConfigProvider.notifier);
await configNotifier.selectDataSource(DataSourceType.fitbit);

// 2. Initiate OAuth (handled by FitbitVendorNotifier)
final fitbitNotifier = ref.read(fitbitVendorProvider.notifier);
final ok = await fitbitNotifier.selectFitbitVendor();

if (ok) {
  // 3. Launch OAuth in browser
  final uri = await fitbitNotifier.buildAuthorizeUri();
  await launchUrl(uri, mode: LaunchMode.externalApplication);
  
  // 4. After OAuth completion, user returns to app
  // 5. Trigger first sync
  final ingestionService = ref.read(dataIngestionServiceProvider);
  final result = await ingestionService.ingestHealthData();
  
  print('Initial sync: ${result.message}');
}
```

### Check If Automatic Sync Available
```dart
final isAutomatic = await ref.read(automaticIngestionAvailableProvider.future);

if (isAutomatic) {
  print('Automatic sync is enabled');
} else {
  print('Manual entry mode');
}
```

### Custom Sync UI
```dart
Widget buildSyncButton(WidgetRef ref) {
  final configState = ref.watch(dataSourceConfigProvider);
  final fitbitState = ref.watch(fitbitVendorProvider);
  final ingestionService = ref.read(dataIngestionServiceProvider);
  
  return ElevatedButton(
    onPressed: configState.maybeWhen(
      data: (config) {
        // Only enable if Fitbit selected and connected
        final isFitbit = config.type == DataSourceType.fitbit;
        final isConnected = fitbitState.status?.isConnected == true;
        final isSyncing = fitbitState.isSyncing;
        
        return (isFitbit && isConnected && !isSyncing)
            ? () async {
                final result = await ingestionService.ingestHealthData();
                // Handle result
              }
            : null;
      },
      orElse: () => null,
    ),
    child: Text('Sync Data'),
  );
}
```

## API Integration

### Backend Endpoint Flow

1. **User selects Fitbit:**
   ```
   POST /integrations/vendors/select
   Body: { "vendor": "fitbit" }
   ```

2. **User initiates OAuth:**
   ```
   GET /integrations/fitbit/authorize?token=<jwt>
   → Redirects to Fitbit OAuth
   → Callback to backend
   → Backend stores tokens
   ```

3. **App triggers sync:**
   ```
   POST /health/sync/immediate
   Headers: { Authorization: "Bearer <jwt>" }
   
   Response: {
     "status": "success",
     "created_count": 42,
     "failed_count": 0,
     "message": "Sync completed"
   }
   ```

4. **App checks status:**
   ```
   GET /integrations/fitbit/status
   
   Response: {
     "connected": true,
     "expires_at": "2025-12-28T10:00:00Z",
     "vendor": "fitbit"
   }
   ```

---

**Last Updated:** December 27, 2025  
**Version:** 1.0.0  
**Architecture:** Single Source Data Ingestion
