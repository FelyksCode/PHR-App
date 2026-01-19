# Data Ingestion Architecture Refactoring - Summary

## Overview
This refactoring enforces a **single automatic data ingestion path** at runtime, eliminating parallel data source requests and creating a clean, deterministic ingestion flow suitable for research validation.

## Changes Made

### 1. New Domain Entities

#### `DataSourceConfig` Entity
**File:** `lib/domain/entities/data_source_config.dart`

- **DataSourceType enum**: Defines supported data sources (Fitbit, Manual)
- **DataSourceConfig class**: Stores selected data source configuration
- Provides type-safe configuration with persistent storage support

### 2. New Services

#### `DataSourceSelectionService`
**File:** `lib/services/data_source_selection_service.dart`

- Manages persistent data source selection using SharedPreferences
- Ensures only one automatic ingestion path is active
- Methods:
  - `getSelectedDataSource()`: Retrieve current configuration
  - `setDataSource(DataSourceType)`: Set active data source
  - `deactivateDataSource()`: Switch to manual mode
  - `hasActiveAutomaticSource()`: Check if automatic sync is enabled

#### `DataIngestionService`
**File:** `lib/services/data_ingestion_service.dart`

- **Single entry point** for all automatic health data ingestion
- Routes ingestion requests based on selected data source
- Methods:
  - `ingestHealthData()`: Main ingestion entry point
  - `_ingestFromFitbit()`: Fitbit-specific ingestion logic
  - `getIngestionStatus()`: Get friendly status message

**Key Features:**
- Centralized ingestion logic
- No parallel API calls
- Backend handles Fitbit API → FHIR normalization → Observation creation
- Clear error handling and logging

### 3. New Providers

#### `DataSourceConfigNotifier`
**File:** `lib/providers/data_source_providers.dart`

- Manages data source configuration state with Riverpod
- Provides reactive state updates when source changes
- Methods:
  - `selectDataSource(DataSourceType)`: Change active source
  - `deactivate()`: Disable automatic sync
  - `refresh()`: Reload configuration

### 4. UI Refactoring

#### Vendor Selection Screen
**File:** `lib/presentation/screens/vendors/vendor_selection_screen.dart`

**Changes:**
- Added single source enforcement notice
- Displays active data source prominently
- Fitbit card shows selection status with visual indicators
- Manual entry option with explicit selection
- Sync button only enabled when Fitbit is both connected AND selected
- Disconnecting Fitbit automatically switches to manual mode

**Key Behaviors:**
- User must explicitly select ONE data source
- Visual feedback shows active vs. available sources
- Clear warnings when Fitbit is connected but not selected

#### Dashboard Screen
**File:** `lib/presentation/screens/dashboard/dashboard_screen.dart`

**Changes:**
- Integrated `DataSourceConfig` state
- Fitbit card shows:
  - "Active Source" badge when selected
  - Warning when connected but not selected as active source
  - Disabled sync button unless Fitbit is the active source
- No parallel Health Connect triggers

### 5. Architecture Improvements

**Before:**
```
┌─────────────┐     ┌──────────────┐
│ Health      │     │ Fitbit       │
│ Connect API │     │ Vendor API   │
└──────┬──────┘     └──────┬───────┘
       │                   │
       │ (Parallel calls)  │
       ├───────────┬───────┤
               ┌───▼───┐
               │  App  │
               └───────┘
```

**After:**
```
┌─────────────────────────┐
│ DataSourceConfig        │
│ (Single Source Storage) │
└───────────┬─────────────┘
            │
     ┌──────▼──────┐
     │ Ingestion   │
     │ Service     │
     └──────┬──────┘
            │
    ┌───────┴────────┐
    │                │
┌───▼───┐      ┌────▼────┐
│Fitbit │      │ Manual  │
│ API   │      │  Entry  │
└───────┘      └─────────┘
```

## Cleanup Completed

### Removed
- ❌ Parallel permission checks
- ❌ Redundant sync triggers
- ❌ Conditional branching mixing Health Connect and vendor logic

### Preserved
- ✅ Manual entry path (always available)
- ✅ Existing auth and Observation persistence
- ✅ FHIR-compatible data model
- ✅ Backend vendor normalization

### Disabled (Not Removed)
- Health Connect code paths remain in codebase but are not triggered
- HealthSyncScreen exists but is not accessible from UI
- Can be fully removed in future cleanup if desired

## Data Flow

### 1. User Selects Data Source
```dart
// In VendorSelectionScreen
await configNotifier.selectDataSource(DataSourceType.fitbit);
```

### 2. Configuration Persisted
```dart
// DataSourceSelectionService
SharedPreferences stores:
{
  "type": "fitbit",
  "selectedAt": "2025-12-27T10:00:00Z",
  "isActive": true
}
```

### 3. Ingestion Triggered
```dart
// Dashboard or automatic trigger
final result = await ingestionService.ingestHealthData();

// Routes internally:
if (config.type == DataSourceType.fitbit) {
  return _ingestFromFitbit(); // → Backend /health/sync/immediate
}
```

### 4. Backend Processing
```
Backend receives request → Calls Fitbit API → Normalizes to FHIR → Creates Observations
```

## Backend Requirements

**Existing endpoints used:**
- `POST /integrations/vendors/select` - Select vendor
- `POST /integrations/vendors/disconnect` - Disconnect vendor
- `GET /integrations/fitbit/status` - Check connection status
- `GET /integrations/fitbit/authorize` - OAuth flow
- `POST /health/sync/immediate` - Trigger sync

**Expected backend behavior:**
- Accept single ingestion request
- Route based on user's selected vendor (stored backend-side via `/vendors/select`)
- Normalize vendor data to FHIR Observation format
- Return sync results (created count, failed count, etc.)

## Testing Checklist

- [ ] Select Fitbit as data source → Connect → Verify sync works
- [ ] Disconnect Fitbit → Verify automatic switch to manual mode
- [ ] Select Manual mode → Verify sync button disabled
- [ ] Connect Fitbit but don't select → Verify warning shown, sync disabled
- [ ] Verify only one data source can be active at a time
- [ ] Verify configuration persists across app restarts

## Constraints Met

✅ **Single automatic path**: Only one data source active at runtime  
✅ **Vendor priority**: Fitbit → Manual fallback  
✅ **No parallel calls**: Health Connect never triggered alongside vendor  
✅ **Persistent selection**: SharedPreferences stores choice  
✅ **Clean entry point**: `ingestHealthData()` single method  
✅ **Minimal changes**: No new vendors, no schedulers, existing auth preserved  
✅ **Research-ready**: Deterministic, single-path ingestion  

## Future Enhancements

1. **Complete Health Connect removal**: Remove unused code if never needed
2. **Additional vendors**: Extend DataSourceType enum (e.g., Apple Health, Samsung Health)
3. **Automatic sync scheduling**: Add background job to call `ingestHealthData()` periodically
4. **Conflict resolution**: Handle overlapping manual + automatic data
5. **Data quality filters**: Add filtering logic in ingestion service

## Files Changed

**New Files:**
- `lib/domain/entities/data_source_config.dart`
- `lib/services/data_source_selection_service.dart`
- `lib/services/data_ingestion_service.dart`
- `lib/providers/data_source_providers.dart`

**Modified Files:**
- `lib/presentation/screens/vendors/vendor_selection_screen.dart`
- `lib/presentation/screens/dashboard/dashboard_screen.dart`

**Unchanged (Available for future use):**
- Health Connect service/repository code
- HealthSyncScreen (not accessible from UI)

## Migration Notes

**For existing users:**
- First app launch after update: Default to manual mode
- Users with existing Fitbit connection: Must re-select Fitbit as active source
- Health Connect permissions: No longer requested (code disabled)

**For new users:**
- Default: Manual entry mode
- Clear UI to select and activate Fitbit
- No confusion from multiple data source options

---

**Date:** December 27, 2025  
**Architecture Pattern:** Single Source of Truth for Data Ingestion  
**Suitable for:** Research validation, deterministic data flows, single-vendor scenarios
