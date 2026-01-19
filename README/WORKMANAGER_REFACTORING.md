# WorkManager Refactoring Summary

## Overview
This document describes the refactoring of the Flutter WorkManager setup to follow Android background execution best practices. The refactoring centralizes WorkManager initialization and creates a maintainable architecture for background tasks.

## Architecture Changes

### Before Refactoring
- ❌ Multiple WorkManager initializations (in `HealthSyncService` and `VendorBackgroundSyncService`)
- ❌ Separate callback dispatchers for each service
- ❌ Initialization mixed with business logic
- ❌ Delayed/on-demand initialization from UI components

### After Refactoring
- ✅ Single WorkManager initialization in `main()`
- ✅ Centralized callback dispatcher with task routing
- ✅ Clear separation of concerns
- ✅ Self-contained background task handlers

## File Changes

### 1. New File: `lib/services/workmanager_dispatcher.dart`
**Purpose:** Central dispatcher for all background tasks

**Key Components:**
- `workmanagerCallbackDispatcher()` - Single entry point for all background tasks
- `BackgroundTaskNames` - Constants for task names
- `TaskRegistry` - Maps task names to handlers
- `_handleHealthDataSync()` - Self-contained health sync handler
- `_handleVendorFitbitSync()` - Self-contained vendor sync handler

**Features:**
- Task routing by name
- Comprehensive logging
- Error handling and reporting
- Stateless, self-contained handlers

### 2. Updated: `lib/main.dart`
**Changes:**
```dart
// Added imports
import 'package:workmanager/workmanager.dart';
import 'dart:io';
import 'services/workmanager_dispatcher.dart';

// Added to main() before runApp()
if (Platform.isAndroid) {
  await Workmanager().initialize(
    workmanagerCallbackDispatcher,
    isInDebugMode: false,
  );
}
```

**Key Points:**
- WorkManager initialized exactly once
- Happens before `runApp()`
- Android-only initialization
- Uses centralized dispatcher

### 3. Updated: `lib/services/health_sync_service.dart`
**Changes:**
- ❌ Removed `initializeBackgroundSync()` method
- ❌ Removed `callbackDispatcher()` function
- ❌ Removed `syncTaskName` constant
- ✅ Import `workmanager_dispatcher.dart`
- ✅ Use `BackgroundTaskNames.healthDataSync` for task registration

**Preserved:**
- `schedulePeriodicSync()` - Registers periodic task
- `cancelPeriodicSync()` - Cancels periodic task
- `isPeriodicSyncEnabled()` - Checks sync status
- All business logic for foreground sync

### 4. Updated: `lib/services/vendor_background_sync_service.dart`
**Changes:**
- ❌ Removed `initializeVendorBackgroundSync()` method
- ❌ Removed `vendorCallbackDispatcher()` function
- ❌ Removed `vendorSyncTaskName` constant
- ❌ Removed `_calculateInitialDelay()` method (unused)
- ✅ Import `workmanager_dispatcher.dart`
- ✅ Use `BackgroundTaskNames.vendorFitbitSync` for task registration

**Preserved:**
- `schedulePeriodicVendorSync()` - Registers periodic task
- `cancelPeriodicVendorSync()` - Cancels periodic task
- `isPeriodicVendorSyncEnabled()` - Checks sync status
- `performVendorSync()` - Foreground sync logic

### 5. Updated: `lib/providers/health_sync_providers.dart`
**Changes:**
- ❌ Removed `initializeBackgroundSync()` method from `HealthSyncNotifier`

### 6. Updated: `lib/presentation/screens/health/health_sync_screen.dart`
**Changes:**
- ❌ Removed call to `initializeBackgroundSync()`
- ✅ Added comment explaining WorkManager is initialized in main()

### 7. Updated: `lib/presentation/screens/vendors/vendor_selection_screen.dart`
**Changes:**
- ❌ Removed call to `initializeVendorBackgroundSync()`
- ✅ Added comment explaining WorkManager is initialized in main()

## Task Registration Flow

### Health Data Sync
```
User enables periodic sync
  ↓
HealthSyncNotifier.schedulePeriodicSync()
  ↓
HealthSyncService.schedulePeriodicSync()
  ↓
Workmanager().registerPeriodicTask(
  taskId: 'health_sync_task',
  taskName: BackgroundTaskNames.healthDataSync
)
  ↓
SharedPreferences stores enabled state
```

### Background Task Execution
```
Android WorkManager triggers task
  ↓
workmanagerCallbackDispatcher() called
  ↓
TaskRegistry.getHandler(taskName)
  ↓
Handler executes (e.g., _handleHealthDataSync)
  ↓
Returns success/failure boolean
```

## Background Task Handlers

### Handler Requirements
All handlers must be:
1. **Self-contained** - No external dependencies that require BuildContext
2. **Stateless** - No UI state or provider dependencies
3. **Isolate-safe** - Can run in a background isolate
4. **Error-resilient** - Comprehensive error handling

### Handler Pattern
```dart
Future<bool> _handleTaskName(Map<String, dynamic>? inputData) async {
  try {
    // 1. Initialize required services
    ApiClient.initialize(baseUrl: ApiConstants.baseUrl);
    
    // 2. Create instances
    final service = SomeService();
    
    // 3. Perform work
    final result = await service.doWork();
    
    // 4. Return success/failure
    return result;
  } catch (e, st) {
    // 5. Log errors
    AppErrorLogger.logError(...);
    return false;
  }
}
```

## Task Names Reference

| Task Name | Task ID | Purpose | Frequency |
|-----------|---------|---------|-----------|
| `health_data_sync` | `health_sync_task` | Sync health data from Health Connect | Hourly (configurable) |
| `vendor_fitbit_sync` | `fitbit_background_sync_task` | Sync Fitbit data via API | Hourly |

## API Reference

### Scheduling Tasks

**Health Sync:**
```dart
// Enable periodic sync
await ref.read(healthSyncNotifierProvider.notifier)
  .schedulePeriodicSync(interval: Duration(hours: 1));

// Disable periodic sync
await ref.read(healthSyncNotifierProvider.notifier)
  .cancelPeriodicSync();

// Check if enabled
final isEnabled = await ref.read(healthSyncNotifierProvider.notifier)
  .isPeriodicSyncEnabled();
```

**Vendor Sync:**
```dart
// Enable periodic sync
await ref.read(vendorBackgroundSyncServiceProvider)
  .schedulePeriodicVendorSync();

// Disable periodic sync
await ref.read(vendorBackgroundSyncServiceProvider)
  .cancelPeriodicVendorSync();

// Check if enabled
final isEnabled = await ref.read(vendorBackgroundSyncServiceProvider)
  .isPeriodicVendorSyncEnabled();
```

### Adding New Background Tasks

1. **Add task name constant:**
```dart
// In BackgroundTaskNames class
static const String myNewTask = 'my_new_task';
```

2. **Create handler:**
```dart
Future<bool> _handleMyNewTask(Map<String, dynamic>? inputData) async {
  // Self-contained implementation
  return true;
}
```

3. **Register handler:**
```dart
// In TaskRegistry._handlers map
BackgroundTaskNames.myNewTask: _handleMyNewTask,
```

4. **Create service methods:**
```dart
// In your service class
Future<void> scheduleMyTask() async {
  await Workmanager().registerPeriodicTask(
    'my_task_id',
    BackgroundTaskNames.myNewTask,
    frequency: Duration(hours: 1),
  );
}
```

## Best Practices

### ✅ DO
- Initialize WorkManager once in `main()`
- Use the centralized dispatcher for all tasks
- Keep handlers self-contained and stateless
- Route tasks by name using TaskRegistry
- Log task execution for debugging
- Handle errors gracefully in handlers
- Store task state in SharedPreferences
- Use constraints (network, battery) appropriately

### ❌ DON'T
- Initialize WorkManager in multiple places
- Create service-specific dispatchers
- Access BuildContext or UI state in handlers
- Use providers or dependency injection in handlers
- Schedule tasks before WorkManager is initialized
- Ignore error handling in background tasks
- Make assumptions about execution context

## Testing Background Tasks

### Enable Debug Mode
```dart
// In main.dart
await Workmanager().initialize(
  workmanagerCallbackDispatcher,
  isInDebugMode: true, // Enable for debugging
);
```

### Monitor Logs
Background tasks log with emoji prefixes:
- 🔄 Task started
- ✅ Task succeeded
- ⚠️ Task completed with warning
- ❌ Task failed
- 📊 Health sync specific
- 📋 Task details

### Manual Testing
```dart
// Trigger immediate execution (for testing)
await Workmanager().registerOneOffTask(
  'test-task-id',
  BackgroundTaskNames.healthDataSync,
  initialDelay: Duration(seconds: 10),
);
```

## Migration Checklist

- [x] Created centralized dispatcher file
- [x] Initialized WorkManager in main()
- [x] Removed duplicate initializations
- [x] Removed service-specific dispatchers
- [x] Updated task name references
- [x] Removed initialization method calls
- [x] Preserved existing task behavior
- [x] No new dependencies added
- [x] Error handling preserved
- [x] Logging added/preserved
- [x] Code compiles without errors

## Troubleshooting

### Tasks Not Executing
1. Check WorkManager is initialized in `main()`
2. Verify task is registered with correct task name
3. Check Android battery optimization settings
4. Enable debug mode and check logs

### Tasks Failing
1. Check handler logs for specific errors
2. Verify API client initialization in handler
3. Check network connectivity constraints
4. Review error logs in AppErrorLogger

### State Not Persisting
1. Verify SharedPreferences writes in schedule/cancel methods
2. Check task registration success
3. Verify periodic sync enabled state reads

## Performance Considerations

### Handler Optimization
- Handlers run in background isolates (limited resources)
- Keep handlers lightweight and focused
- Avoid expensive operations without constraints
- Use appropriate task constraints (network, battery)

### Scheduling Strategy
- Default: 1-hour intervals for both tasks
- Minimum: 15 minutes (Android constraint)
- Use appropriate constraints to save battery

### Resource Management
- Handlers create fresh service instances
- No persistent state between executions
- Each execution is independent

## Security Considerations

- Background tasks cannot access UI state
- API credentials must be stored securely
- SharedPreferences used for non-sensitive state only
- Error logs don't expose sensitive data

## Future Enhancements

### Potential Improvements
1. Dynamic task intervals based on user activity
2. Intelligent sync scheduling (off-peak hours)
3. Retry strategies for failed tasks
4. Task execution analytics
5. Background task monitoring UI
6. Exponential backoff for failures

### Extensibility
The architecture supports:
- Adding new task types easily
- Custom task handlers per feature
- Flexible task scheduling strategies
- Integration with other background services

## Conclusion

This refactoring achieves:
- ✅ Single point of WorkManager initialization
- ✅ Clean separation of concerns
- ✅ Maintainable background task architecture
- ✅ Self-contained, testable handlers
- ✅ Preserved existing functionality
- ✅ Better debugging and monitoring
- ✅ Scalable for future tasks

The new architecture follows Android best practices and provides a solid foundation for background task management.
