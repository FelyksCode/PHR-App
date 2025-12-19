import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/condition_entity.dart';
import '../../data/models/condition_model.dart';
import '../providers/condition_providers.dart';
import '../providers/offline_queue_provider.dart';
import '../providers/observation_providers.dart';
import '../widgets/common_widgets.dart';

class ConditionScreen extends ConsumerStatefulWidget {
  const ConditionScreen({super.key});

  @override
  ConsumerState<ConditionScreen> createState() => _ConditionScreenState();
}

final _selectedCategoryProvider = StateProvider<ConditionCategory?>((ref) => null);
final _selectedConditionsProvider = StateProvider<Map<String, ConditionSeverity>>((ref) => {});
final _onsetDateProvider = StateProvider<DateTime?>((ref) => DateTime.now());
final _notesControllerProvider = Provider<TextEditingController>((ref) => TextEditingController());

class _ConditionScreenState extends ConsumerState<ConditionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _notesController;

  // Common conditions that have SNOMED codes
  final List<Map<String, String>> _commonConditions = [
    {'value': 'fatigue', 'display': 'Fatigue', 'code': '84229001'},
    {'value': 'headache', 'display': 'Headache', 'code': '25064002'},
    {'value': 'nausea', 'display': 'Nausea', 'code': '422587007'},
    {'value': 'dizziness', 'display': 'Dizziness', 'code': '404684003'},
    {'value': 'fever', 'display': 'Fever', 'code': '386661006'},
    {'value': 'cough', 'display': 'Cough', 'code': '49727002'},
    {'value': 'pain', 'display': 'Pain', 'code': '22253000'},
    {'value': 'shortness of breath', 'display': 'Shortness of breath', 'code': '267036007'},
    {'value': 'chest pain', 'display': 'Chest pain', 'code': '29857009'},
    {'value': 'abdominal pain', 'display': 'Abdominal pain', 'code': '21522001'},
  ];

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submissionState = ref.watch(conditionSubmissionProvider);
    final queueService = ref.watch(offlineQueueServiceProvider);
    final queuedItemsAsync = ref.watch(queuedItemsCountProvider);

    final selectedCategory = ref.watch(_selectedCategoryProvider);
    final selectedConditions = ref.watch(_selectedConditionsProvider);
    final onsetDate = ref.watch(_onsetDateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Report Condition'),
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
          // Offline indicator
          Consumer(
            builder: (context, ref, child) {
              final connectivityAsync = ref.watch(connectivityStatusProvider);
              return connectivityAsync.when(
                data: (isOnline) {
                  if (!isOnline) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                          const SizedBox(width: 4),
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
              );
            },
          ),
          // Sync button with queue count
          Consumer(
            builder: (context, ref, child) {
              final queueService = ref.watch(offlineQueueServiceProvider);
              final queuedItemsAsync = ref.watch(queuedItemsCountProvider);
              return queuedItemsAsync.when(
                data: (counts) {
                  final conditionsCount = counts['conditions'] ?? 0;
                  if (conditionsCount > 0) {
                    return Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.cloud_upload),
                          onPressed: () async {
                            final result = await queueService.syncQueuedData();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['message'] as String),
                                  backgroundColor: result['success'] as bool ? Colors.green : Colors.orange,
                                ),
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
                              '$conditionsCount',
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
              );
            },
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: submissionState.isLoading,
        message: 'Submitting condition...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                _buildConditionForm(ref, selectedCategory, selectedConditions, onsetDate, _notesController),
                const SizedBox(height: 32),
                _buildActionButtons(ref, _notesController),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionForm(
    WidgetRef ref,
    ConditionCategory? selectedCategory,
    Map<String, ConditionSeverity> selectedConditions,
    DateTime? onsetDate,
    TextEditingController notesController,
  ) {
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
            'Condition Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 16),
          CustomDropdown<ConditionCategory>(
            label: 'Category',
            value: selectedCategory,
            items: ConditionCategory.values,
            itemLabel: (category) => category.displayName,
            onChanged: (value) {
              ref.read(_selectedCategoryProvider.notifier).state = value;
              ref.read(_selectedConditionsProvider.notifier).state = {};
            },
            validator: (value) {
              if (value == null) return 'Category is required - please select one';
              return null;
            },
          ),
          const SizedBox(height: 24),
          _buildConditionChecklist(ref, selectedCategory, selectedConditions),
          const SizedBox(height: 16),
          _buildOnsetDatePicker(ref, onsetDate),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Additional Notes (Optional)',
            controller: notesController,
            hint: 'Any additional information or context',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildConditionGuide(),
        ],
      ),
    );
  }

  Widget _buildConditionChecklist(
    WidgetRef ref,
    ConditionCategory? selectedCategory,
    Map<String, ConditionSeverity> selectedConditions,
  ) {
    if (selectedCategory == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF8E8E93).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Please select a category first to view available conditions',
          style: TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 14,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Select Conditions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const Spacer(),
            Text(
              '${selectedConditions.length} selected',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (selectedConditions.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF007AFF), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap on conditions below to select them and set their severity',
                    style: TextStyle(
                      color: Color(0xFF007AFF),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Column(
          children: _commonConditions.map((condition) {
            final conditionValue = condition['value']!;
            final isSelected = selectedConditions.containsKey(conditionValue);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildConditionCard(ref, condition, isSelected, selectedConditions[conditionValue]),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildConditionCard(
    WidgetRef ref,
    Map<String, String> condition,
    bool isSelected,
    ConditionSeverity? selectedSeverity,
  ) {
    final conditionValue = condition['value']!;
    final conditionDisplay = condition['display']!;
    final conditionCode = condition['code']!;

    return GestureDetector(
      onTap: () {
        final notifier = ref.read(_selectedConditionsProvider.notifier);
        final current = Map<String, ConditionSeverity>.from(notifier.state);
        if (isSelected) {
          current.remove(conditionValue);
        } else {
          current[conditionValue] = ConditionSeverity.mild;
        }
        notifier.state = current;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF007AFF).withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF007AFF) : const Color(0xFFE5E5EA),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF007AFF) : const Color(0xFFE5E5EA),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conditionDisplay,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? const Color(0xFF007AFF) : const Color(0xFF1C1C1E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SNOMED: $conditionCode',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(height: 16),
              const Text(
                'Severity:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: ConditionSeverity.values.map((severity) {
                  final isSelectedSeverity = selectedSeverity == severity;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          final notifier = ref.read(_selectedConditionsProvider.notifier);
                          final current = Map<String, ConditionSeverity>.from(notifier.state);
                          current[conditionValue] = severity;
                          notifier.state = current;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelectedSeverity
                                ? _getSeverityColor(severity).withOpacity(0.2)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelectedSeverity
                                  ? _getSeverityColor(severity)
                                  : Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                severity.displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelectedSeverity
                                      ? _getSeverityColor(severity)
                                      : const Color(0xFF8E8E93),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(ConditionSeverity severity) {
    switch (severity) {
      case ConditionSeverity.mild:
        return const Color(0xFF34C759);
      case ConditionSeverity.moderate:
        return const Color(0xFFFF9500);
      case ConditionSeverity.severe:
        return const Color(0xFFFF3B30);
    }
  }

  Widget _buildOnsetDatePicker(WidgetRef ref, DateTime? onsetDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'When did this condition start? (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: onsetDate ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: const Color(0xFF007AFF),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              ref.read(_onsetDateProvider.notifier).state = date;
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E5EA)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    onsetDate != null
                      ? '${onsetDate.day}/${onsetDate.month}/${onsetDate.year}'
                      : 'Select onset date',
                    style: TextStyle(
                    fontSize: 16,
                    color: onsetDate != null
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFF8E8E93),
                    ),
                ),
                Row(
                  children: [
                    if (onsetDate != null)
                      GestureDetector(
                        onTap: () {
                          ref.read(_onsetDateProvider.notifier).state = null;
                        },
                        child: const Icon(
                          Icons.clear,
                          color: Color(0xFF8E8E93),
                          size: 20,
                        ),
                      ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.calendar_today,
                      color: Color(0xFF007AFF),
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConditionGuide() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF007AFF), size: 20),
              SizedBox(width: 8),
              Text(
                'Condition Guide',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF007AFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Available Conditions (with SNOMED codes):',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 8),
          ..._commonConditions.map((condition) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• ${condition['display']} (${condition['code']})',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1C1C1E),
                    height: 1.3,
                  ),
                ),
              )),
          const SizedBox(height: 12),
          const Text(
            'Severity Levels:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 8),
          ...ConditionSeverity.values.map((severity) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${severity.displayName}: ${severity.description}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildActionButtons(WidgetRef ref, TextEditingController notesController) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => _submitCondition(ref, notesController),
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
            onPressed: () => _clearForm(ref, notesController),
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

  void _submitCondition(WidgetRef ref, TextEditingController notesController) async {
    if (!_formKey.currentState!.validate()) return;
    final selectedCategory = ref.read(_selectedCategoryProvider);
    final selectedConditions = ref.read(_selectedConditionsProvider);
    final onsetDate = ref.read(_onsetDateProvider);
    final notes = notesController.text.trim().isNotEmpty ? notesController.text.trim() : null;
    final queueService = ref.read(offlineQueueServiceProvider);
    final apiService = ref.read(apiServiceProvider);

    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    if (selectedConditions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one condition')),
      );
      return;
    }

    // Check if online
    final isOnline = await queueService.isOnline();

    // Create a copy of the entries to avoid ConcurrentModificationError
    final conditionsToSubmit = Map<String, ConditionSeverity>.from(selectedConditions);

    // Submit each selected condition
    int successCount = 0;
    int queuedCount = 0;
    
    for (final entry in conditionsToSubmit.entries) {
      final conditionValue = entry.key;
      final severity = entry.value;

      final condition = ConditionModel.create(
        category: selectedCategory,
        severity: severity,
        description: conditionValue,
        notes: notes,
        onsetDate: onsetDate,
      );

      if (isOnline) {
        // Try to submit directly if online
        try {
          final success = await apiService.submitCondition(condition);
          if (success) {
            successCount++;
          } else {
            // If API returned false, queue it
            await queueService.queueCondition(condition);
            queuedCount++;
          }
        } catch (e) {
          // If submission fails due to network error, queue it
          print('Error submitting condition: $e');
          await queueService.queueCondition(condition);
          queuedCount++;
        }
      } else {
        // Queue for later if offline
        await queueService.queueCondition(condition);
        queuedCount++;
      }
    }

    // Show appropriate message and handle form clearing
    if (mounted) {
      // Refresh the queue providers to update history screens
      if (queuedCount > 0) {
        ref.invalidate(queuedConditionsProvider);
        ref.invalidate(queuedItemsCountProvider);
      }
      if (successCount > 0) {
        ref.invalidate(latestConditionsProvider);
      }
      
      if (queuedCount > 0) {
        // Some or all items were queued
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              queuedCount == conditionsToSubmit.length
                  ? 'No internet. Data saved and will sync automatically when online.'
                  : '$successCount submitted, $queuedCount queued for later sync',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        _clearForm(ref, notesController);
      } else if (successCount > 0) {
        // All items submitted successfully
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount condition(s) submitted successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        _clearForm(ref, notesController);
      }
    }
  }

  void _clearForm(WidgetRef ref, TextEditingController notesController) {
    if (!mounted) return;
    _formKey.currentState?.reset();
    notesController.clear();
    ref.read(_selectedCategoryProvider.notifier).state = null;
    ref.read(_selectedConditionsProvider.notifier).state = {};
    ref.read(_onsetDateProvider.notifier).state = null;
    ref.read(conditionSubmissionProvider.notifier).resetSubmissionState();
  }
}