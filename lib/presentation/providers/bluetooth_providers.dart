import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/bluetooth_service.dart';
import 'observation_providers.dart';

// Provider for Bluetooth service instance
final bluetoothServiceProvider = Provider<BluetoothHeartRateService>((ref) {
  return BluetoothHeartRateService();
});

// Provider for Bluetooth initialization status
final bluetoothInitProvider = FutureProvider<bool>((ref) async {
  final bluetoothService = ref.read(bluetoothServiceProvider);
  return await bluetoothService.initialize();
});

// Provider for scan results
final bluetoothScanProvider = StreamProvider<List<fbp.ScanResult>>((ref) {
  final bluetoothService = ref.read(bluetoothServiceProvider);
  return bluetoothService.scanResultsStream;
});

// Provider for device connection state
final bluetoothConnectionProvider = StreamProvider<fbp.BluetoothConnectionState>((ref) {
  final bluetoothService = ref.read(bluetoothServiceProvider);
  return bluetoothService.deviceConnectionStream;
});

// Provider for heart rate stream
final heartRateStreamProvider = StreamProvider<double>((ref) {
  final bluetoothService = ref.read(bluetoothServiceProvider);
  return bluetoothService.heartRateStream;
});

// Provider for connected device
final connectedDeviceProvider = Provider<fbp.BluetoothDevice?>((ref) {
  final bluetoothService = ref.read(bluetoothServiceProvider);
  return bluetoothService.connectedDevice;
});

// Notifier for Bluetooth scanning state
class BluetoothScanNotifier extends StateNotifier<bool> {
  BluetoothScanNotifier(this.ref) : super(false);
  
  final Ref ref;

  Future<void> startScan() async {
    if (state) return; // Already scanning
    
    state = true;
    try {
      final bluetoothService = ref.read(bluetoothServiceProvider);
      await bluetoothService.startScan();
    } catch (e) {
      debugPrint('Error starting scan: $e');
    } finally {
      state = false;
    }
  }

  Future<void> stopScan() async {
    final bluetoothService = ref.read(bluetoothServiceProvider);
    await bluetoothService.stopScan();
    state = false;
  }
}

// Provider for scanning state
final bluetoothScanNotifierProvider = StateNotifierProvider<BluetoothScanNotifier, bool>((ref) {
  return BluetoothScanNotifier(ref);
});

// Notifier for device connection
class BluetoothConnectionNotifier extends StateNotifier<AsyncValue<bool>> {
  BluetoothConnectionNotifier(this.ref) : super(const AsyncValue.data(false));
  
  final Ref ref;

  Future<void> connectToDevice(fbp.BluetoothDevice device) async {
    state = const AsyncValue.loading();
    
    try {
      final bluetoothService = ref.read(bluetoothServiceProvider);
      final success = await bluetoothService.connectToDevice(device);
      state = AsyncValue.data(success);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> disconnectDevice() async {
    state = const AsyncValue.loading();
    
    try {
      final bluetoothService = ref.read(bluetoothServiceProvider);
      await bluetoothService.disconnectDevice();
      state = const AsyncValue.data(false);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

// Provider for connection management
final bluetoothConnectionNotifierProvider = 
    StateNotifierProvider<BluetoothConnectionNotifier, AsyncValue<bool>>((ref) {
  return BluetoothConnectionNotifier(ref);
});

// Notifier for automatic heart rate data submission
class HeartRateAutoSubmitNotifier extends StateNotifier<bool> {
  HeartRateAutoSubmitNotifier(this.ref) : super(false) {
    _listenToHeartRate();
  }
  
  final Ref ref;
  
  void toggleAutoSubmit() {
    state = !state;
  }
  
  void _listenToHeartRate() {
    ref.listen(heartRateStreamProvider, (previous, next) {
      next.whenData((heartRate) {
        if (state && heartRate > 0) {
          _submitHeartRate(heartRate);
        }
      });
    });
  }
  
  void _submitHeartRate(double heartRate) async {
    try {
      final bluetoothService = ref.read(bluetoothServiceProvider);
      final observation = bluetoothService.createHeartRateObservation(heartRate);
      await ref.read(observationSubmissionProvider.notifier).submitObservation(observation);
    } catch (e) {
      debugPrint('Error auto-submitting heart rate: $e');
    }
  }
}

// Provider for auto-submit functionality
final heartRateAutoSubmitProvider = StateNotifierProvider<HeartRateAutoSubmitNotifier, bool>((ref) {
  return HeartRateAutoSubmitNotifier(ref);
});

// Provider for paired devices
final pairedDevicesProvider = FutureProvider<List<fbp.BluetoothDevice>>((ref) async {
  final bluetoothService = ref.read(bluetoothServiceProvider);
  return await bluetoothService.getPairedDevices();
});