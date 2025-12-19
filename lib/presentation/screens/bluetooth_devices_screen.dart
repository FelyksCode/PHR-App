import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../providers/bluetooth_providers.dart';

class BluetoothDevicesScreen extends ConsumerStatefulWidget {
  const BluetoothDevicesScreen({super.key});

  @override
  ConsumerState<BluetoothDevicesScreen> createState() => _BluetoothDevicesScreenState();
}

class _BluetoothDevicesScreenState extends ConsumerState<BluetoothDevicesScreen> {
  @override
  void initState() {
    super.initState();
    // Start scanning when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScan();
    });
  }

  void _startScan() async {
    await ref.read(bluetoothScanNotifierProvider.notifier).startScan();
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothInit = ref.watch(bluetoothInitProvider);
    final isScanning = ref.watch(bluetoothScanNotifierProvider);
    final scanResults = ref.watch(bluetoothScanProvider);
    final connectionState = ref.watch(bluetoothConnectionNotifierProvider);
    final connectedDevice = ref.watch(connectedDeviceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Bluetooth Devices'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Color(0xFF1C1C1E),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          IconButton(
            onPressed: isScanning ? null : _startScan,
            icon: Icon(
              isScanning ? Icons.stop : Icons.refresh,
              color: const Color(0xFF007AFF),
            ),
          ),
        ],
      ),
      body: bluetoothInit.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(error.toString()),
        data: (initialized) {
          if (!initialized) {
            return _buildBluetoothDisabledState();
          }
          return _buildDeviceList(scanResults, connectedDevice, connectionState, isScanning);
        },
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Bluetooth Error',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothDisabledState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bluetooth_disabled,
              size: 64,
              color: Color(0xFF8E8E93),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bluetooth Disabled',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please enable Bluetooth to connect to health devices',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                ref.refresh(bluetoothInitProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(
    AsyncValue<List<ScanResult>> scanResults,
    BluetoothDevice? connectedDevice,
    AsyncValue<bool> connectionState,
    bool isScanning,
  ) {
    return Column(
      children: [
        // Connected device section
        if (connectedDevice != null) _buildConnectedDeviceCard(connectedDevice),
        
        // Scanning indicator
        if (isScanning) _buildScanningIndicator(),
        
        // Device list
        Expanded(
          child: scanResults.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Error scanning: $error'),
            ),
            data: (results) {
              if (results.isEmpty && !isScanning) {
                return _buildEmptyState();
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final result = results[index];
                  return _buildDeviceCard(result, connectedDevice, connectionState);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedDeviceCard(BluetoothDevice device) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF007AFF), width: 2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bluetooth_connected,
            color: Color(0xFF007AFF),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF007AFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  device.platformName.isNotEmpty 
                      ? device.platformName 
                      : device.remoteId.toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(bluetoothConnectionNotifierProvider.notifier).disconnectDevice();
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'Scanning for devices...',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bluetooth_searching,
              size: 64,
              color: Color(0xFF8E8E93),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Devices Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Make sure your device is in pairing mode and supports heart rate monitoring',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(
    ScanResult result,
    BluetoothDevice? connectedDevice,
    AsyncValue<bool> connectionState,
  ) {
    final device = result.device;
    final isConnected = connectedDevice?.remoteId == device.remoteId;
    final deviceName = device.platformName.isNotEmpty 
        ? device.platformName 
        : 'Unknown Device';

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: ListTile(
        leading: Icon(
          isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
          color: isConnected ? const Color(0xFF007AFF) : const Color(0xFF8E8E93),
        ),
        title: Text(
          deviceName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.remoteId.toString()),
            if (result.rssi != 0)
              Text(
                'Signal: ${result.rssi} dBm',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8E8E93),
                ),
              ),
          ],
        ),
        trailing: connectionState.when(
          loading: () => const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (error, stack) => const Icon(Icons.error, color: Colors.red),
          data: (connected) => ElevatedButton(
            onPressed: isConnected
                ? () => ref.read(bluetoothConnectionNotifierProvider.notifier).disconnectDevice()
                : () => ref.read(bluetoothConnectionNotifierProvider.notifier).connectToDevice(device),
            style: ElevatedButton.styleFrom(
              backgroundColor: isConnected ? Colors.red : const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 36),
            ),
            child: Text(isConnected ? 'Disconnect' : 'Connect'),
          ),
        ),
      ),
    );
  }
}