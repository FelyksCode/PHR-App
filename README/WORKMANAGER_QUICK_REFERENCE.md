# WorkManager Quick Reference

## Overview
Centralized WorkManager setup with single initialization point and task registry pattern.

## Key Files
- **Dispatcher**: [lib/services/workmanager_dispatcher.dart](../lib/services/workmanager_dispatcher.dart)
- **Initialization**: [lib/main.dart](../lib/main.dart)
- **Health Sync**: [lib/services/health_sync_service.dart](../lib/services/health_sync_service.dart)
- **Vendor Sync**: [lib/services/vendor_background_sync_service.dart](../lib/services/vendor_background_sync_service.dart)

## Quick Usage

### Enable/Disable Background Sync

**Health Data Sync:**
```dart
// Enable
await ref.read(healthSyncNotifierProvider.notifier)
  .schedulePeriodicSync(interval: Duration(hours: 1));

// Disable
await ref.read(healthSyncNotifierProvider.notifier)
  .cancelPeriodicSync();
```

**Vendor (Fitbit) Sync:**
```dart
// Enable
await ref.read(vendorBackgroundSyncServiceProvider)
  .schedulePeriodicVendorSync();

// Disable
await ref.read(vendorBackgroundSyncServiceProvider)
  .cancelPeriodicVendorSync();
```

## Task Names
- `health_data_sync` - Health Connect data sync
- `vendor_fitbit_sync` - Fitbit vendor sync

## Adding a New Task

### 1. Add Task Name
```dart
// In workmanager_dispatcher.dart > BackgroundTaskNames
static const String myTask = 'my_task_name';
```

### 2. Create Handler
```dart
// In workmanager_dispatcher.dart
Future<bool> _handleMyTask(Map<String, dynamic>? inputData) async {
  try {
    // Initialize services
    ApiClient.initialize(baseUrl: ApiConstants.baseUrl);
    
    // Do work
    final result = await doWork();
    
    return result;
  } catch (e, st) {
    AppErrorLogger.logError(/* ... */);
    return false;
  }
}
```

### 3. Register Handler
```dart
// In workmanager_dispatcher.dart > TaskRegistry._handlers
static final Map<String, TaskHandler> _handlers = {
  BackgroundTaskNames.healthDataSync: _handleHealthDataSync,
  BackgroundTaskNames.vendorFitbitSync: _handleVendorFitbitSync,
  BackgroundTaskNames.myTask: _handleMyTask, // Add this
};
```

### 4. Create Service Methods
```dart
class MyService {
  static const String taskId = 'my_task_id';
  
  Future<void> scheduleTask() async {
    if (Platform.isAndroid) {
      await Workmanager().registerPeriodicTask(
        taskId,
        BackgroundTaskNames.myTask,
        frequency: Duration(hours: 1),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    }
  }
  
  Future<void> cancelTask() async {
    if (Platform.isAndroid) {
      await Workmanager().cancelByUniqueName(taskId);
    }
  }
}
```

## Handler Rules

### ✅ DO
- Keep handlers self-contained
- Initialize services within handler
- Use try-catch for error handling
- Return boolean (true = success)
- Log execution status

### ❌ DON'T
- Access BuildContext
- Use Riverpod providers
- Access UI state
- Make assumptions about execution context
- Forget error handling

## Debugging

### Enable Debug Mode
```dart
// In main.dart
await Workmanager().initialize(
  workmanagerCallbackDispatcher,
  isInDebugMode: true, // <-- Change to true
);
```

### Log Prefixes
- 🔄 Task started
- ✅ Task succeeded
- ⚠️ Warning
- ❌ Error
- 📊 Health sync
- 📋 Details

### Test Task Manually
```dart
await Workmanager().registerOneOffTask(
  'test-id',
  BackgroundTaskNames.myTask,
  initialDelay: Duration(seconds: 10),
);
```

## Common Issues

### Task Not Running
- Check WorkManager initialized in main()
- Verify correct task name
- Check Android battery settings
- Enable debug mode and check logs

### Task Failing
- Review handler error logs
- Check API initialization
- Verify network constraints
- Check permissions

## Architecture

```
┌─────────────────────────────────────────┐
│            main.dart                    │
│  Workmanager().initialize()             │
│    (called once before runApp)          │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│     workmanager_dispatcher.dart         │
│  ┌───────────────────────────────────┐  │
│  │ workmanagerCallbackDispatcher()   │  │
│  │   ↓                               │  │
│  │ TaskRegistry.getHandler(taskName) │  │
│  │   ↓                               │  │
│  │ Execute handler                   │  │
│  └───────────────────────────────────┘  │
└──────────────┬──────────────────────────┘
               │
        ┌──────┴───────┐
        ▼              ▼
┌──────────────┐ ┌──────────────┐
│ Health Sync  │ │ Vendor Sync  │
│   Handler    │ │   Handler    │
└──────────────┘ └──────────────┘
```

## Best Practices

1. **Single Initialization** - Only in main()
2. **Task Registry** - Central routing
3. **Self-Contained Handlers** - No external state
4. **Error Handling** - Always catch and log
5. **Logging** - Debug and monitor
6. **Constraints** - Battery and network

## Reference Documentation
See [WORKMANAGER_REFACTORING.md](WORKMANAGER_REFACTORING.md) for complete details.
