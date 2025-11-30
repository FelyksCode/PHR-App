import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/observation_entity.dart';
import '../../data/models/observation_model.dart';
import '../providers/observation_providers.dart';
import '../widgets/common_widgets.dart';

class VitalSignsScreen extends ConsumerStatefulWidget {
  const VitalSignsScreen({super.key});

  @override
  ConsumerState<VitalSignsScreen> createState() => _VitalSignsScreenState();
}

class _VitalSignsScreenState extends ConsumerState<VitalSignsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _oxygenController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _temperatureController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _oxygenController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submissionState = ref.watch(observationSubmissionProvider);

    ref.listen<AsyncValue<bool?>>(observationSubmissionProvider, (previous, next) {
      next.whenOrNull(
        data: (success) {
          if (success == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vital signs submitted successfully!')),
            );
            _clearForm();
          } else if (success == false) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to submit vital signs.')),
            );
          }
        },
        error: (error, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          );
        },
      );
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Vital Signs'),
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
      body: LoadingOverlay(
        isLoading: submissionState.isLoading,
        message: 'Submitting vital signs...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildVitalSignsForm(),
                const SizedBox(height: 32),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVitalSignsForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vital Signs',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Body Weight (kg)',
            controller: _weightController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            validator: (value) {
              if (value == null || value.isEmpty) return 'Weight is required';
              final weight = double.tryParse(value);
              if (weight == null || weight <= 0) return 'Enter valid weight';
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Body Height (cm)',
            controller: _heightController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            validator: (value) {
              if (value == null || value.isEmpty) return 'Height is required';
              final height = double.tryParse(value);
              if (height == null || height <= 0) return 'Enter valid height';
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Body Temperature (°C)',
            controller: _temperatureController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            validator: (value) {
              if (value == null || value.isEmpty) return 'Temperature is required';
              final temp = double.tryParse(value);
              if (temp == null || temp <= 0) return 'Enter valid temperature';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  label: 'Systolic BP (mmHg)',
                  controller: _systolicController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    final systolic = int.tryParse(value);
                    if (systolic == null || systolic <= 0) return 'Invalid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  label: 'Diastolic BP (mmHg)',
                  controller: _diastolicController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    final diastolic = int.tryParse(value);
                    if (diastolic == null || diastolic <= 0) return 'Invalid';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Oxygen Saturation (%)',
            controller: _oxygenController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            validator: (value) {
              if (value == null || value.isEmpty) return 'SpO₂ is required';
              final spo2 = double.tryParse(value);
              if (spo2 == null || spo2 <= 0) return 'Enter valid SpO₂';
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Notes (Optional)',
            controller: _notesController,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _submitVitalSigns,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Submit to FHIR Gateway'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _clearForm,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1C1C1E),
              side: const BorderSide(color: Color(0xFFE5E5EA)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Clear Form'),
          ),
        ),
      ],
    );
  }

  void _submitVitalSigns() async {
    if (!_formKey.currentState!.validate()) return;

    final observations = <ObservationEntity>[
      ObservationModel.create(
        type: ObservationType.bodyWeight,
        value: double.parse(_weightController.text),
        unit: 'kg',
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      ),
      ObservationModel.create(
        type: ObservationType.bodyHeight,
        value: double.parse(_heightController.text),
        unit: 'cm',
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      ),
      ObservationModel.create(
        type: ObservationType.bodyTemperature,
        value: double.parse(_temperatureController.text),
        unit: '°C',
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      ),
      ObservationModel.create(
        type: ObservationType.bloodPressureSystolic,
        value: double.parse(_systolicController.text),
        unit: 'mmHg',
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      ),
      ObservationModel.create(
        type: ObservationType.bloodPressureDiastolic,
        value: double.parse(_diastolicController.text),
        unit: 'mmHg',
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      ),
      ObservationModel.create(
        type: ObservationType.oxygenSaturation,
        value: double.parse(_oxygenController.text),
        unit: '%',
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      ),
    ];

    for (final observation in observations) {
      await ref.read(observationSubmissionProvider.notifier).submitObservation(observation);
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _weightController.clear();
    _heightController.clear();
    _temperatureController.clear();
    _systolicController.clear();
    _diastolicController.clear();
    _oxygenController.clear();
    _notesController.clear();
    ref.read(observationSubmissionProvider.notifier).resetSubmissionState();
  }
}