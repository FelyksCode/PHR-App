import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../../domain/entities/observation_entity.dart';
import '../models/observation_model.dart';

class BluetoothHeartRateService {
  static final BluetoothHeartRateService _instance = BluetoothHeartRateService._internal();
  factory BluetoothHeartRateService() => _instance;
  BluetoothHeartRateService._internal();

  // Stream controllers for different data types
  final _heartRateController = StreamController<double>.broadcast();
  final _deviceConnectionController = StreamController<fbp.BluetoothConnectionState>.broadcast();
  final _scanResultsController = StreamController<List<fbp.ScanResult>>.broadcast();

  // Getters for streams
  Stream<double> get heartRateStream => _heartRateController.stream;
  Stream<fbp.BluetoothConnectionState> get deviceConnectionStream => _deviceConnectionController.stream;
  Stream<List<fbp.ScanResult>> get scanResultsStream => _scanResultsController.stream;

  // Connected device and characteristics
  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothCharacteristic? _heartRateCharacteristic;
  fbp.BluetoothCharacteristic? _batteryCharacteristic;

  // Standard Bluetooth Service UUIDs
  static const String heartRateServiceUuid = "0000180d-0000-1000-8000-00805f9b34fb";
  static const String heartRateCharacteristicUuid = "00002a37-0000-1000-8000-00805f9b34fb";
  static const String batteryServiceUuid = "0000180f-0000-1000-8000-00805f9b34fb";
  static const String batteryLevelCharacteristicUuid = "00002a19-0000-1000-8000-00805f9b34fb";

  List<fbp.ScanResult> _scanResults = [];
  bool _isScanning = false;

  /// Initialize Bluetooth service
  Future<bool> initialize() async {
    try {
      // Check if Bluetooth is available
      if (await fbp.FlutterBluePlus.isAvailable == false) {
        debugPrint("Bluetooth not available on this device");
        return false;
      }

      // Check if Bluetooth is on
      if (await fbp.FlutterBluePlus.adapterState.first != fbp.BluetoothAdapterState.on) {
        debugPrint("Bluetooth is not turned on");
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("Error initializing Bluetooth: $e");
      return false;
    }
  }

  /// Start scanning for Bluetooth devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isScanning) return;

    try {
      _isScanning = true;
      _scanResults.clear();
      
      // Start scanning with service UUIDs filter
      await fbp.FlutterBluePlus.startScan(
        withServices: [fbp.Guid(heartRateServiceUuid)],
        timeout: timeout,
      );

      // Listen to scan results
      fbp.FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results;
        _scanResultsController.add(results);
      });

      // Wait for scan to complete
      await Future.delayed(timeout);
      await stopScan();
    } catch (e) {
      debugPrint("Error scanning for devices: $e");
      _isScanning = false;
    }
  }

  /// Stop scanning for devices
  Future<void> stopScan() async {
    try {
      await fbp.FlutterBluePlus.stopScan();
      _isScanning = false;
    } catch (e) {
      debugPrint("Error stopping scan: $e");
    }
  }

  /// Connect to a Bluetooth device
  Future<bool> connectToDevice(fbp.BluetoothDevice device) async {
    try {
      // Disconnect from current device if connected
      await disconnectDevice();

      // Connect to the new device
      await device.connect();
      _connectedDevice = device;

      // Listen to connection state
      device.connectionState.listen((state) {
        _deviceConnectionController.add(state);
        if (state == fbp.BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _heartRateCharacteristic = null;
          _batteryCharacteristic = null;
        }
      });

      // Discover services
      await _discoverServices(device);
      
      return true;
    } catch (e) {
      debugPrint("Error connecting to device: $e");
      return false;
    }
  }

  /// Discover services and characteristics
  Future<void> _discoverServices(fbp.BluetoothDevice device) async {
    try {
      List<fbp.BluetoothService> services = await device.discoverServices();

      for (fbp.BluetoothService service in services) {
        // Heart Rate Service
        if (service.uuid.toString().toLowerCase() == heartRateServiceUuid) {
          for (fbp.BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == heartRateCharacteristicUuid) {
              _heartRateCharacteristic = characteristic;
              await _subscribeToHeartRate(characteristic);
            }
          }
        }
        
        // Battery Service
        if (service.uuid.toString().toLowerCase() == batteryServiceUuid) {
          for (fbp.BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == batteryLevelCharacteristicUuid) {
              _batteryCharacteristic = characteristic;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error discovering services: $e");
    }
  }

  /// Subscribe to heart rate notifications
  Future<void> _subscribeToHeartRate(fbp.BluetoothCharacteristic characteristic) async {
    try {
      await characteristic.setNotifyValue(true);
      
      characteristic.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          double heartRate = _parseHeartRateData(value);
          _heartRateController.add(heartRate);
        }
      });
    } catch (e) {
      debugPrint("Error subscribing to heart rate: $e");
    }
  }

  /// Parse heart rate data according to Bluetooth specification
  double _parseHeartRateData(List<int> value) {
    try {
      // Heart Rate Measurement characteristic format
      // First byte contains flags
      int flags = value[0];
      
      // Check if heart rate format is 16-bit (bit 0 of flags)
      bool is16BitFormat = (flags & 0x01) != 0;
      
      double heartRate;
      if (is16BitFormat) {
        // 16-bit heart rate value
        heartRate = (value[2] << 8 | value[1]).toDouble();
      } else {
        // 8-bit heart rate value
        heartRate = value[1].toDouble();
      }
      
      return heartRate;
    } catch (e) {
      debugPrint("Error parsing heart rate data: $e");
      return 0.0;
    }
  }

  /// Get battery level from connected device
  Future<int?> getBatteryLevel() async {
    try {
      if (_batteryCharacteristic != null) {
        List<int> value = await _batteryCharacteristic!.read();
        return value.isNotEmpty ? value[0] : null;
      }
      return null;
    } catch (e) {
      debugPrint("Error reading battery level: $e");
      return null;
    }
  }

  /// Disconnect from current device
  Future<void> disconnectDevice() async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
        _heartRateCharacteristic = null;
        _batteryCharacteristic = null;
      }
    } catch (e) {
      debugPrint("Error disconnecting device: $e");
    }
  }

  /// Create observation from heart rate data
  ObservationEntity createHeartRateObservation(double heartRate, {String? notes}) {
    return ObservationModel.create(
      type: ObservationType.heartRate,
      value: heartRate,
      unit: 'bpm',
      notes: notes ?? 'Measured via Bluetooth device',
    );
  }

  /// Get list of previously paired devices
  Future<List<fbp.BluetoothDevice>> getPairedDevices() async {
    try {
      return await fbp.FlutterBluePlus.bondedDevices;
    } catch (e) {
      debugPrint("Error getting paired devices: $e");
      return [];
    }
  }

  /// Check if device is connected
  bool get isConnected => _connectedDevice != null;

  /// Get connected device info
  fbp.BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Get device name
  String getDeviceName(fbp.BluetoothDevice device) {
    return device.platformName.isNotEmpty 
        ? device.platformName 
        : device.remoteId.toString();
  }

  /// Dispose resources
  void dispose() {
    _heartRateController.close();
    _deviceConnectionController.close();
    _scanResultsController.close();
    disconnectDevice();
  }
}