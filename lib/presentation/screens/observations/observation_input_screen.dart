import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phr_app/data/models/observation_model.dart';
import 'package:phr_app/domain/entities/observation_entity.dart';

import '../../providers/observation_service_provider.dart';
import '../../providers/observation_providers.dart';
import '../../providers/offline_queue_provider.dart';
import '../../providers/observation_input_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/blood_pressure_form.dart';

class ObservationInputScreen extends ConsumerStatefulWidget {
  final ObservationCategory? category;

  const ObservationInputScreen({super.key, this.category});

  @override
  ConsumerState<ObservationInputScreen> createState() =>
      _ObservationInputScreenState();
}

class _ObservationInputScreenState
    extends ConsumerState<ObservationInputScreen> {
  final _searchController = TextEditingController();
  final Map<String, TextEditingController> _valueControllers = {};
  final Map<String, TextEditingController> _notesControllers = {};

  // Observation types to display
  List<ObservationType> get _observationTypes {
    // Filter by category if specified, otherwise show vital signs
    final category = widget.category ?? ObservationCategory.vitalSigns;

    if (category == ObservationCategory.vitalSigns) {
      return [
        ObservationType.bodyWeight,
        ObservationType.bodyHeight,
        ObservationType.bodyTemperature,
        ObservationType.heartRate,
        ObservationType
            .bloodPressureSystolic, // Shows as "Blood Pressure", handles both values
        // bloodPressureDiastolic is hidden - handled together with systolic
        ObservationType.oxygenSaturation,
        ObservationType.respiratoryRate,
      ];
    } else if (category == ObservationCategory.activity) {
      return [ObservationType.steps];
    }

    return ObservationType.values;
  }

  @override
  void initState() {
    super.initState();
    // Trigger rebuild when search text changes
    _searchController.addListener(() {
      if (mounted) {
        ref.read(observationSearchProvider.notifier).state = _searchController.text;
      }
    });

    // Initialize controllers for all observation types
    for (final type in _observationTypes) {
      _valueControllers[type.name] = TextEditingController();
      _notesControllers[type.name] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var c in _valueControllers.values) {
      c.dispose();
    }
    for (var c in _notesControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submitObservation(ObservationType type) async {
    final valueController = _valueControllers[type.name]!;
    final notesController = _notesControllers[type.name]!;

    final value = double.tryParse(valueController.text);
    if (value == null) {
      _showSnackBar('Please enter a valid number', isError: true);
      return;
    }

    ref.read(observationInputProvider.notifier).setSubmitting(true);

    try {
      final observation = ObservationModel.create(
        type: type,
        value: value,
        unit: type.standardUnit,
        category: widget.category ?? ObservationCategory.vitalSigns,
        source: DataSource.manual,
        notes: notesController.text.isEmpty ? null : notesController.text,
      );

      final observationService = ref.read(observationServiceProvider);
      final success = await observationService.submitObservation(observation);

      if (!mounted) return;

      if (success) {
        _showSnackBar('${type.displayName} recorded successfully');
        valueController.clear();
        notesController.clear();

        // Refresh observation lists
        ref.invalidate(latestObservationsProvider);
        ref.invalidate(observationsProvider);
      } else {
        _showSnackBar('Failed to record ${type.displayName}', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        ref.read(observationInputProvider.notifier).setSubmitting(false);
      }
    }
  }

  /// Submits blood pressure as a single FHIR panel observation with components
  /// This matches the FHIR standard structure with systolic and diastolic as components
  Future<void> _submitBloodPressure(
    double systolic,
    double diastolic,
    String? notes,
  ) async {
    ref.read(observationInputProvider.notifier).setSubmitting(true);

    try {
      final observationService = ref.read(observationServiceProvider);
      final success = await observationService.submitBloodPressurePanelObservation(
        systolic: systolic,
        diastolic: diastolic,
        notes: notes,
        source: DataSource.manual,
      );

      if (!mounted) return;

      if (success) {
        _showSnackBar('Blood Pressure recorded successfully');

        // Refresh observation lists
        ref.invalidate(latestObservationsProvider);
        ref.invalidate(observationsProvider);
      } else {
        _showSnackBar('Failed to record Blood Pressure', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        ref.read(observationInputProvider.notifier).setSubmitting(false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInputDialog(ObservationType type) {
    // Special handling for blood pressure - use unified form
    if (type == ObservationType.bloodPressureSystolic) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => BloodPressureForm(
          onSubmit: (systolic, diastolic, notes) {
            Navigator.pop(context);
            _submitBloodPressure(systolic, diastolic, notes);
          },
          isSubmitting: ref.read(observationInputProvider).isSubmitting,
        ),
      );
      return;
    }

    // Standard form for other observation types
    final valueController = _valueControllers[type.name]!;
    final notesController = _notesControllers[type.name]!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_getIcon(type), style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.displayName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Enter ${type.standardUnit}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Value input
              TextField(
                controller: valueController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Value',
                  suffixText: type.standardUnit,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Notes input
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: ref.read(observationInputProvider).isSubmitting
                      ? null
                      : () {
                          Navigator.pop(context);
                          _submitObservation(type);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Record',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getIcon(ObservationType type) {
    switch (type) {
      case ObservationType.bodyWeight:
        return '⚖️';
      case ObservationType.bodyHeight:
        return '📏';
      case ObservationType.bodyTemperature:
        return '🌡️';
      case ObservationType.heartRate:
        return '❤️';
      case ObservationType.bloodPressureSystolic:
      case ObservationType.bloodPressureDiastolic:
        return '🩸';
      case ObservationType.oxygenSaturation:
        return '🫁';
      case ObservationType.respiratoryRate:
        return '💨';
      case ObservationType.steps:
        return '👣';
      case ObservationType.caloriesBurned:
        return '🔥';
    }
  }

  String _getCardDisplayName(ObservationType type) {
    // Show unified "Blood Pressure" label instead of "Blood Pressure - Systolic"
    if (type == ObservationType.bloodPressureSystolic) {
      return 'Blood Pressure';
    }
    return type.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final connectivityAsync = ref.watch(connectivityStatusProvider);
    final queuedItemsAsync = ref.watch(queuedItemsCountProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(widget.category?.display ?? 'Vital Signs'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        actions: [
          // Offline indicator
          connectivityAsync.when(
            data: (isOnline) {
              if (!isOnline) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        'Offline',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Sync button
          queuedItemsAsync.when(
            data: (counts) {
              final observationsCount = counts['observations'] ?? 0;
              if (observationsCount > 0) {
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.cloud_upload),
                      onPressed: () async {
                        final queueService = ref.read(
                          offlineQueueServiceProvider,
                        );
                        final result = await queueService.syncQueuedData();
                        if (mounted) {
                          _showSnackBar(
                            result['message'] as String,
                            isError: !(result['success'] as bool),
                          );
                        }
                      },
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$observationsCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: ref.watch(observationInputProvider).isSubmitting,
        message: 'Recording observation...',
        child: Column(
          children: [
            // Search bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search observations...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Observation cards
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: (() {
                  final search = ref.watch(observationSearchProvider);
                  final allTypes = _observationTypes;
                  final filtered = search.isEmpty
                      ? allTypes
                      : allTypes
                          .where((type) =>
                              type.displayName
                                  .toLowerCase()
                                  .contains(search.toLowerCase()) ||
                              type.name
                                  .toLowerCase()
                                  .contains(search.toLowerCase()))
                          .toList();
                  return filtered.length;
                })(),
                itemBuilder: (context, index) {
                  final search = ref.watch(observationSearchProvider);
                  final allTypes = _observationTypes;
                  final filteredTypes = search.isEmpty
                      ? allTypes
                      : allTypes
                          .where((type) =>
                              type.displayName
                                  .toLowerCase()
                                  .contains(search.toLowerCase()) ||
                              type.name
                                  .toLowerCase()
                                  .contains(search.toLowerCase()))
                          .toList();
                  final type = filteredTypes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: InkWell(
                      onTap: () => _showInputDialog(type),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF).withValues(alpha:0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  _getIcon(type),
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getCardDisplayName(type),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to record',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Colors.grey[400]),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Duplicate class definition removed
