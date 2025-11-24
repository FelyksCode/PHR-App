import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/condition_entity.dart';
import '../../data/models/condition_model.dart';
import '../providers/condition_providers.dart';
import '../widgets/common_widgets.dart';

class ConditionScreen extends ConsumerStatefulWidget {
  const ConditionScreen({super.key});

  @override
  ConsumerState<ConditionScreen> createState() => _ConditionScreenState();
}

class _ConditionScreenState extends ConsumerState<ConditionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  
  ConditionCategory? _selectedCategory;
  ConditionSeverity? _selectedSeverity;

  @override
  void dispose() {
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submissionState = ref.watch(conditionSubmissionProvider);

    ref.listen<AsyncValue<bool?>>(conditionSubmissionProvider, (previous, next) {
      next.whenOrNull(
        data: (success) {
          if (success == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Condition submitted successfully!')),
            );
            _clearForm();
          } else if (success == false) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to submit condition.')),
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
      appBar: AppBar(
        title: const Text('Report Condition'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: LoadingOverlay(
        isLoading: submissionState.isLoading,
        message: 'Submitting condition...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildConditionForm(),
                const SizedBox(height: 32),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Condition Details', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            CustomDropdown<ConditionCategory>(
              label: 'Category',
              value: _selectedCategory,
              items: ConditionCategory.values,
              itemLabel: (category) => category.displayName,
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
              validator: (value) {
                if (value == null) return 'Please select a category';
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomDropdown<ConditionSeverity>(
              label: 'Severity',
              value: _selectedSeverity,
              items: ConditionSeverity.values,
              itemLabel: (severity) => severity.displayName,
              onChanged: (value) {
                setState(() {
                  _selectedSeverity = value;
                });
              },
              validator: (value) {
                if (value == null) return 'Please select severity';
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Description',
              controller: _descriptionController,
              hint: 'Describe the condition, symptom, or side effect',
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Description is required';
                }
                if (value.trim().length < 5) {
                  return 'Please provide more details (at least 5 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Additional Notes (Optional)',
              controller: _notesController,
              hint: 'Any additional information or context',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildSeverityInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Severity Guide',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...ConditionSeverity.values.map((severity) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${severity.displayName}: ${severity.description}',
                  style: Theme.of(context).textTheme.bodySmall,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              )),
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
            onPressed: _submitCondition,
            child: const Text('Submit to FHIR Gateway'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _clearForm,
            child: const Text('Clear Form'),
          ),
        ),
      ],
    );
  }

  void _submitCondition() async {
    if (!_formKey.currentState!.validate()) return;

    final condition = ConditionModel.create(
      category: _selectedCategory!,
      severity: _selectedSeverity!,
      description: _descriptionController.text.trim(),
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    await ref.read(conditionSubmissionProvider.notifier).submitCondition(condition);
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _descriptionController.clear();
    _notesController.clear();
    setState(() {
      _selectedCategory = null;
      _selectedSeverity = null;
    });
    ref.read(conditionSubmissionProvider.notifier).resetSubmissionState();
  }
}