import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/bluetooth_providers.dart';
import '../providers/observation_providers.dart';

class HeartRateMonitorScreen extends ConsumerStatefulWidget {
  const HeartRateMonitorScreen({super.key});

  @override
  ConsumerState<HeartRateMonitorScreen> createState() => _HeartRateMonitorScreenState();
}

class _HeartRateMonitorScreenState extends ConsumerState<HeartRateMonitorScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updatePulseRate(double heartRate) {
    if (heartRate > 0) {
      final duration = Duration(milliseconds: (60000 / heartRate).round());
      _pulseController.duration = duration;
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectedDevice = ref.watch(connectedDeviceProvider);
    final heartRateStream = ref.watch(heartRateStreamProvider);
    final autoSubmit = ref.watch(heartRateAutoSubmitProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Heart Rate Monitor'),
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
            onPressed: () {
              Navigator.pushNamed(context, '/bluetooth-devices');
            },
            icon: Icon(
              connectedDevice != null ? Icons.bluetooth_connected : Icons.bluetooth,
              color: connectedDevice != null ? const Color(0xFF007AFF) : const Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection Status
            _buildConnectionStatus(connectedDevice),
            const SizedBox(height: 24),
            
            // Heart Rate Display
            heartRateStream.when(
              loading: () => _buildLoadingState(),
              error: (error, stack) => _buildErrorState(error.toString()),
              data: (heartRate) {
                _updatePulseRate(heartRate);
                return _buildHeartRateDisplay(heartRate);
              },
            ),
            
            const SizedBox(height: 24),
            
            // Auto Submit Toggle
            _buildAutoSubmitCard(autoSubmit),
            
            const SizedBox(height: 24),
            
            // Manual Submit Button
            _buildManualSubmitButton(heartRateStream.value),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(device) {
    if (device == null) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bluetooth_disabled, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No Device Connected',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                  const Text(
                    'Connect a heart rate monitor to start monitoring',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/bluetooth-devices');
              },
              child: const Text('Connect'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bluetooth_connected, color: Color(0xFF007AFF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Device Connected',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007AFF),
                  ),
                ),
                Text(
                  device.platformName.isNotEmpty 
                      ? device.platformName 
                      : device.remoteId.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Waiting for heart rate data...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartRateDisplay(double heartRate) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: heartRate > 0 ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite,
                    size: 60,
                    color: Color(0xFF007AFF),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            heartRate > 0 ? '${heartRate.round()}' : '--',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const Text(
            'BPM',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF8E8E93),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (heartRate > 0) ...[
            const SizedBox(height: 16),
            Text(
              _getHeartRateZone(heartRate),
              style: TextStyle(
                fontSize: 14,
                color: _getHeartRateZoneColor(heartRate),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAutoSubmitCard(bool autoSubmit) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync, color: Color(0xFF8E8E93)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Auto Submit',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  autoSubmit 
                      ? 'Automatically submit heart rate readings to FHIR'
                      : 'Manual submission only',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: autoSubmit,
            onChanged: (value) {
              ref.read(heartRateAutoSubmitProvider.notifier).toggleAutoSubmit();
            },
            activeColor: const Color(0xFF007AFF),
          ),
        ],
      ),
    );
  }

  Widget _buildManualSubmitButton(double? currentHeartRate) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: currentHeartRate != null && currentHeartRate > 0
            ? () => _submitCurrentHeartRate(currentHeartRate)
            : null,
        icon: const Icon(Icons.send),
        label: const Text('Submit Current Reading'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007AFF),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE5E5EA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _submitCurrentHeartRate(double heartRate) async {
    try {
      final bluetoothService = ref.read(bluetoothServiceProvider);
      final observation = bluetoothService.createHeartRateObservation(
        heartRate,
        notes: 'Manual submission from Bluetooth device',
      );
      
      await ref.read(observationSubmissionProvider.notifier).submitObservation(observation);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Heart rate submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting heart rate: $e')),
        );
      }
    }
  }

  String _getHeartRateZone(double heartRate) {
    if (heartRate < 60) return 'Below Normal';
    if (heartRate <= 100) return 'Normal Range';
    if (heartRate <= 150) return 'Elevated';
    if (heartRate <= 180) return 'High';
    return 'Very High';
  }

  Color _getHeartRateZoneColor(double heartRate) {
    if (heartRate < 60) return Colors.blue;
    if (heartRate <= 100) return Colors.green;
    if (heartRate <= 150) return Colors.orange;
    if (heartRate <= 180) return Colors.red;
    return Colors.purple;
  }
}