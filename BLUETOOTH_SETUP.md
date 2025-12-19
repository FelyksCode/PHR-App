# Bluetooth Heart Rate Monitoring Setup

## Overview
This implementation adds Bluetooth Low Energy (BLE) heart rate monitoring capability to your PHR app, allowing users to connect smartwatches, fitness trackers, and dedicated heart rate monitors.

## Features Added

### 1. Bluetooth Service (`bluetooth_service.dart`)
- **Device Discovery**: Scans for BLE devices with heart rate service
- **Connection Management**: Connects/disconnects from heart rate monitors
- **Real-time Data**: Streams heart rate data using standard Bluetooth Heart Rate Profile
- **Data Parsing**: Correctly parses heart rate measurements according to Bluetooth specification
- **Battery Monitoring**: Reads battery level from connected devices

### 2. Heart Rate Monitor Screen (`heart_rate_monitor_screen.dart`)
- **Live Heart Rate Display**: Shows current heart rate with animated heart icon
- **Connection Status**: Visual indicator of device connection state
- **Heart Rate Zones**: Color-coded zones (Normal, Elevated, High, etc.)
- **Auto-Submit Toggle**: Automatically submit readings to FHIR gateway
- **Manual Submit**: One-tap submission of current reading

### 3. Bluetooth Device Management (`bluetooth_devices_screen.dart`)
- **Device Scanning**: Search for nearby heart rate monitors
- **Pairing Interface**: Connect/disconnect from devices
- **Signal Strength**: Shows RSSI values for device selection
- **Connection State**: Real-time connection status updates

### 4. Integration with Vital Signs
- Added "Heart Rate Monitor" card in vital signs screen
- Bluetooth icon to distinguish from manual entry
- Direct navigation to heart rate monitoring

## Supported Devices

### Compatible Device Types:
- **Smartwatches**: Apple Watch, Samsung Galaxy Watch, Fitbit, etc.
- **Fitness Trackers**: Garmin, Polar, Suunto devices
- **Chest Straps**: Polar H10, Wahoo TICKR, etc.
- **Medical Devices**: Any device supporting Bluetooth Heart Rate Profile

### Bluetooth Standards Supported:
- **Heart Rate Service UUID**: `0x180D`
- **Heart Rate Characteristic**: `0x2A37`
- **Battery Service**: `0x180F` (for battery level)
- **Bluetooth Low Energy (BLE)**: Version 4.0+

## Setup Instructions

### 1. Dependencies Added
```yaml
flutter_blue_plus: ^1.32.12  # Bluetooth Low Energy support
```

### 2. Android Permissions (AndroidManifest.xml)
```xml
<!-- Bluetooth permissions -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Bluetooth hardware features -->
<uses-feature android:name="android.hardware.bluetooth" android:required="false" />
<uses-feature android:name="android.hardware.bluetooth_le" android:required="false" />
```

### 3. iOS Permissions (Info.plist)
Add to `ios/Runner/Info.plist`:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to heart rate monitors and health devices</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to connect to heart rate monitors and health devices</string>
```

## Usage Flow

### 1. Device Connection
1. Open app and go to "Vital Signs"
2. Tap "Heart Rate Monitor" card
3. Tap Bluetooth icon to open device scanner
4. Turn on your heart rate device and put it in pairing mode
5. Select device from scan results and tap "Connect"

### 2. Heart Rate Monitoring
1. Once connected, return to Heart Rate Monitor screen
2. Watch real-time heart rate updates with animated display
3. Enable "Auto Submit" for automatic FHIR submissions
4. Or use "Submit Current Reading" for manual submissions

### 3. Data Integration
- All heart rate data automatically creates FHIR Observations
- Data is submitted to your FHIR gateway with proper formatting
- Observations include device source information in notes

## Technical Implementation

### Data Flow:
1. **Device Discovery**: BLE scan finds heart rate services
2. **Connection**: Establish GATT connection to selected device
3. **Service Discovery**: Find Heart Rate and Battery services
4. **Notifications**: Subscribe to heart rate characteristic notifications
5. **Data Parsing**: Convert raw bytes to BPM using Bluetooth specification
6. **Stream Processing**: Real-time updates through Riverpod streams
7. **FHIR Integration**: Create and submit Observation resources

### Error Handling:
- Bluetooth availability checks
- Connection state monitoring
- Automatic reconnection attempts
- Graceful degradation when Bluetooth unavailable

### Performance Considerations:
- Efficient battery usage through proper BLE implementation
- Background processing limitations handled
- Memory management for continuous data streams

## Extending the Implementation

### Adding More Vital Signs:
To support additional Bluetooth health devices:

1. **Add new service UUIDs** in `bluetooth_service.dart`
2. **Implement data parsers** for specific characteristics
3. **Create observation models** for new data types
4. **Update UI screens** for new device types

### Example Services to Add:
- **Blood Pressure**: Service UUID `0x1810`
- **Weight Scale**: Service UUID `0x181D`
- **Glucose Meter**: Service UUID `0x1808`
- **Pulse Oximeter**: Service UUID `0x1822`

### Custom Device Support:
For proprietary devices, implement custom characteristic parsing in the `_parseHeartRateData` method pattern.

## Troubleshooting

### Common Issues:

1. **Device Not Found**:
   - Ensure device is in pairing mode
   - Check device supports Bluetooth Heart Rate Profile
   - Verify location permissions granted

2. **Connection Fails**:
   - Move closer to device
   - Restart Bluetooth on phone
   - Clear app cache and retry

3. **No Data Received**:
   - Check device battery level
   - Ensure proper wear (for wearable devices)
   - Verify device compatibility

4. **Permission Errors**:
   - Grant all Bluetooth and location permissions
   - Check Android/iOS version compatibility

## Future Enhancements

### Planned Features:
- **Multi-device support**: Connect multiple devices simultaneously
- **Historical data sync**: Retrieve stored data from devices
- **Device-specific profiles**: Custom settings per device type
- **Advanced analytics**: Heart rate variability, trends analysis
- **Offline storage**: Cache data when network unavailable

This Bluetooth integration transforms your PHR app into a comprehensive health monitoring platform, providing seamless connectivity with modern health devices while maintaining FHIR compliance for professional healthcare integration.