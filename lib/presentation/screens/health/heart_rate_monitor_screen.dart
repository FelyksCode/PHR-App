import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phr_app/data/models/observation_model.dart';
import 'package:phr_app/domain/entities/observation_entity.dart';
import '../../providers/observation_providers.dart';

class HeartRateMonitorScreen extends ConsumerStatefulWidget {
  const HeartRateMonitorScreen({super.key});

  @override
  ConsumerState<HeartRateMonitorScreen> createState() => _HeartRateMonitorScreenState();
}

class _HeartRateMonitorScreenState extends ConsumerState<HeartRateMonitorScreen> {
  final TextEditingController _heartRateController = TextEditingController();

  @override
  void dispose() {
    _heartRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildManualInputCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, color: Colors.blue),
          const SizedBox(height: 12),
          const Text(
            'Manual Heart Rate Entry',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your heart rate measurement manually. Your readings will be saved to your health record.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualInputCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite,
              size: 60,
              color: Color(0xFF007AFF),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _heartRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration: InputDecoration(
              hintText: 'Enter heart rate (BPM)',
              hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _submitHeartRate,
              icon: const Icon(Icons.send),
              label: const Text('Submit Heart Rate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE5E5EA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitHeartRate() async {
    final heartRateText = _heartRateController.text.trim();
    final heartRate = double.tryParse(heartRateText);

    if (heartRate == null || heartRate <= 0) {
      _showErrorSnackBar('Please enter a valid heart rate value');
      return;
    }

    try {
      // Create observation from manual entry
      final observation = ObservationModel.create(
        type: ObservationType.heartRate,
        value: heartRate,
        unit: 'bpm',
        notes: 'Manual entry',
      );

      await ref.read(observationSubmissionProvider.notifier).submitObservation(observation);

      if (mounted) {
        _heartRateController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Heart rate submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error submitting heart rate: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
