# Health Data Sync Extension

This document describes the health data synchronization functionality added to the Personal Health Record (PHR) Flutter application.

## Overview

The health sync extension allows the PHR app to automatically sync vital signs and health data from platform-specific health ecosystems:

- **Android**: Health Connect (Google's health platform)
- **iOS**: HealthKit (Apple's health platform)

## Architecture

### Domain Layer
- **HealthSyncEntity**: Represents sync status and configuration
- **HealthDataPoint**: Represents individual health data measurements
- **HealthSyncRepository**: Abstract interface for health data operations

### Data Layer
- **HealthSyncRepositoryImpl**: Concrete implementation using health plugins
- Platform-specific data conversion and API integration

### Presentation Layer
- **HealthSyncScreen**: Complete UI for managing health data sync
- **Health Sync Providers**: Riverpod state management for sync operations

### Services
- **HealthSyncService**: Business logic for sync operations and scheduling
- Background sync support (Android WorkManager)

## Features

### 🔄 Health Data Sync
- **Supported Data Types**:
  - Heart Rate
  - Blood Pressure (Systolic/Diastolic)
  - Body Temperature
  - Oxygen Saturation
  - Respiratory Rate
  - Steps
  - Body Weight
  - Body Height

### 📱 Platform Integration
- **Android**: Health Connect API integration
- **iOS**: HealthKit framework integration
- Automatic platform detection and appropriate API usage

### 🔐 Permission Management
- Granular permission requests per data type
- Visual permission status indicators
- Proper permission handling and error states

### ⏰ Sync Scheduling
- **Manual Sync**: On-demand data synchronization
- **Background Sync** (Android): Periodic automatic sync using WorkManager
- **Delta Sync**: Sync only new data since last update

### 💾 Data Processing
- **FHIR Compliance**: Automatic conversion to FHIR R4 format
- **LOINC Mapping**: Standard medical codes for observations
- **Data Source Tracking**: Clear attribution (HealthKit vs Health Connect)

## User Interface

### Health Sync Dashboard
- **Platform Status**: Shows current platform (Android/iOS) and support status
- **Sync Status Card**: Current sync state, last sync time, total observations
- **Data Type Selection**: Choose which health data to sync with visual permission status
- **Sync Controls**: Manual sync, delta sync, and background sync configuration

### Sync Status States
- 🔵 **Idle**: Ready to sync
- 🟠 **Syncing**: Currently processing data
- 🟢 **Success**: Sync completed successfully
- 🔴 **Failed**: Sync encountered an error
- 🟣 **Permission Denied**: Health permissions not granted
- ⚪ **No Data**: No new data available

## Technical Implementation

### Dependencies Added
```yaml
health: ^10.2.0                    # Health data access
permission_handler: ^11.0.1        # Permission management
workmanager: ^0.5.2               # Background tasks (Android)
shared_preferences: ^2.2.2        # Local storage
```

### Android Configuration
- Health Connect permissions in AndroidManifest.xml
- WorkManager service configuration
- Health Connect package queries

### iOS Configuration
- HealthKit usage descriptions in Info.plist
- Background app refresh capabilities

## Data Flow

1. **Permission Request**: User grants health data access permissions
2. **Data Retrieval**: App fetches health data from platform APIs
3. **Data Conversion**: Transform platform data to FHIR-compliant observations
4. **API Submission**: Send observations to FHIR gateway
5. **Status Update**: Update sync status and statistics

## Error Handling

- **Network Errors**: Graceful handling of API connectivity issues
- **Permission Errors**: Clear user guidance for permission setup
- **Data Errors**: Validation and error reporting for corrupt data
- **Platform Errors**: Platform-specific error handling and recovery

## Background Sync (Android)

- **WorkManager Integration**: Reliable background task scheduling
- **Battery Optimization**: Respects device battery and network constraints
- **Periodic Execution**: Configurable sync intervals (default: 1 hour)
- **Failure Handling**: Automatic retry with exponential backoff

## Security Considerations

- **Data Privacy**: All health data remains on-device until explicitly synced
- **Permission Scope**: Granular control over which data types are accessible
- **Secure Transport**: All API communications over HTTPS
- **Data Attribution**: Clear tracking of data sources for audit trails

## Usage Instructions

1. **Access Health Sync**: Tap "Health Data Sync" from the dashboard
2. **Grant Permissions**: Select desired data types and grant permissions
3. **Configure Sync**: Choose manual or automatic sync preferences
4. **Monitor Status**: View sync progress and manage synced observations

## Integration Points

- **Dashboard**: Health sync action card for easy access
- **Observations**: Synced data appears in vital signs list with source attribution
- **FHIR Gateway**: Seamless integration with existing backend infrastructure

## Future Enhancements

- **Data Filtering**: Advanced filtering by date range and data quality
- **Conflict Resolution**: Handle overlapping manual and synced data
- **Analytics**: Health trends and insights from synced data
- **Wearable Integration**: Direct sync from fitness trackers and smartwatches

## Testing

- **Manual Testing**: UI testing across Android and iOS platforms
- **Permission Testing**: Verify permission flows and error handling
- **Background Testing**: Validate WorkManager execution on Android
- **API Testing**: Confirm FHIR data submission and validation

## Support

For issues related to health data sync:
1. Check platform-specific health app settings
2. Verify app permissions in device settings
3. Review sync status and error messages in the app
4. Ensure network connectivity for data submission

---

*This health sync extension maintains full compatibility with the existing PHR application while adding powerful automatic data collection capabilities.*