import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phr_app/domain/entities/questionnaire_entity.dart';
import 'package:phr_app/presentation/widgets/questionnaire_item_widget.dart';
import 'package:phr_app/services/api_service.dart';
import 'package:phr_app/core/errors/app_error.dart';
import 'package:phr_app/core/errors/app_error_logger.dart';
import 'package:phr_app/domain/entities/condition_input.dart';
import '../../providers/questionnaire_provider.dart';

class ConditionInputScreen extends ConsumerStatefulWidget {
  const ConditionInputScreen({super.key});

  @override
  ConsumerState<ConditionInputScreen> createState() =>
      _ConditionInputScreenState();
}

class _ConditionInputScreenState extends ConsumerState<ConditionInputScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _notesController;

  // Submission UI state (kept local to avoid changing the UI structure).
  bool _isSubmitting = false;
  int _progressDone = 0;
  int _progressTotal = 0;
  final Map<String, String> _requestIdByLocalId = {};
  Set<String> _failedLocalIds = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitQuestionnaire() async {
    final response = ref.read(questionnaireResponseProvider);

    if (response.answeredQuestions.isEmpty) {
      _showErrorSnackbar(
        'No symptoms reported. Please select at least one symptom.',
      );
      return;
    }

    if (_isSubmitting) return;

    // If there are previous failures, keep only those as retry candidates.
    final answered = response.answeredQuestions;
    final retryTargets = _failedLocalIds.isEmpty
        ? answered
        : answered
              .where((q) => _failedLocalIds.contains(q.questionId))
              .toList();
    final isRetry = _failedLocalIds.isNotEmpty && retryTargets.isNotEmpty;

    setState(() {
      _isSubmitting = true;
      _progressDone = 0;
      _progressTotal = isRetry ? retryTargets.length : answered.length;
    });

    try {
      // Get patient ID from API service
      final apiService = ref.read(apiServiceProvider);
      final patientId = await apiService.getFhirPatientId();

      if (patientId == null || patientId.isEmpty) {
        _showErrorSnackbar('Patient ID not available. Please log in again.');
        ref.read(questionnaireSubmittingProvider.notifier).state = false;
        return;
      }

      // Update metadata
      ref
          .read(questionnaireResponseProvider.notifier)
          .setMetadata(
            patientId,
            null, // No encounter ID for now
          );

      // Update notes if provided
      if (_notesController.text.isNotEmpty) {
        ref
            .read(questionnaireResponseProvider.notifier)
            .setNotes(_notesController.text);
      }

      // Submit via FHIR endpoint
      final isOnline = await apiService.isOnline();

      if (!isOnline) {
        // Queue for offline submission
        _showSuccessSnackbar(
          'Conditions saved offline. Will sync when connected.',
        );
      } else {
        final updatedResponse = ref.read(questionnaireResponseProvider);

        final targets = isRetry
            ? updatedResponse.answeredQuestions
                  .where((q) => _failedLocalIds.contains(q.questionId))
                  .toList()
            : updatedResponse.answeredQuestions;

        final note = _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim();

        final inputs = targets.map((q) {
          final existingId = _requestIdByLocalId[q.questionId];
          final reqId = existingId ?? ConditionInput.generateClientRequestId();
          _requestIdByLocalId[q.questionId] = reqId;

          return ConditionInput.fromQuestionResponse(
            response: q,
            patientId: patientId,
            recordedDate: updatedResponse.timestamp,
            encounterId: updatedResponse.encounterId,
            clientRequestId: reqId,
            note: note,
          );
        }).toList();

        final result = await apiService.submitMultipleConditions(
          inputs,
          onProgress: (done, total) {
            if (!mounted) return;
            setState(() {
              _progressDone = done;
              _progressTotal = total;
            });
          },
        );

        // Clear successes, keep failures so the user can retry.
        for (final localId in result.succeededLocalIds) {
          ref
              .read(questionnaireResponseProvider.notifier)
              .clearQuestion(localId);
          _requestIdByLocalId.remove(localId);
        }

        final failedIds = result.failedByLocalId.keys.toSet();
        _failedLocalIds = failedIds;

        if (result.failedCount == 0) {
          _showSuccessSnackbar('Conditions reported successfully');
          ref.read(questionnaireResponseProvider.notifier).reset();
          _notesController.clear();
          _tabController.index = 0;
          _failedLocalIds = <String>{};
        } else {
          _showPartialFailureSnackbar(
            succeeded: result.succeededCount,
            failed: result.failedCount,
          );
        }
      }
    } catch (e, stack) {
      final appError = e is AppError
          ? e
          : UnknownError(
              'Failed to submit questionnaire',
              code: 'QUESTIONNAIRE_SUBMIT_FAILED',
              stackTrace: stack,
              originalException: e,
            );

      AppErrorLogger.logError(
        appError,
        source: 'ConditionInputScreen._submitQuestionnaire',
        severity: ErrorSeverity.medium,
      );

      _showErrorSnackbar(appError.message);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showPartialFailureSnackbar({
    required int succeeded,
    required int failed,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$succeeded succeeded, $failed failed'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Retry Failed',
          textColor: Colors.white,
          onPressed: () {
            if (!_isSubmitting) {
              _submitQuestionnaire();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentResponse = ref.watch(questionnaireResponseProvider);
    final answerCountCurrent = ref.watch(answeredCountCurrentProvider);
    final answerCountSideEffects = ref.watch(answeredCountSideEffectsProvider);
    final isSubmitting = _isSubmitting;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Symptoms & Side Effects'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Color(0xFF1C1C1E),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          indicatorColor: Colors.blue,
          tabs: [
            Tab(text: 'Current Symptoms ($answerCountCurrent)'),
            Tab(text: 'Side Effects ($answerCountSideEffects)'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Tabs content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Current Symptoms Tab
                _buildCategoryList('current_symptom', currentResponse),

                // Side Effects Tab
                _buildCategoryList('side_effect', currentResponse),
              ],
            ),
          ),

          // Notes section and Submit button
          _buildBottomSection(currentResponse, isSubmitting),
        ],
      ),
    );
  }

  Widget _buildCategoryList(String category, QuestionnaireResponse response) {
    final questions = response.getResponsesByCategory(category);

    if (questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No questions available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        top: 12,
        bottom: 280, // Space for bottom sheet
      ),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final q = questions[index];
        return QuestionnaireItemWidget(
          response: q,
          isAnswered: q.isAnswered,
          onSeverityChanged: (severity) {
            ref
                .read(questionnaireResponseProvider.notifier)
                .setSeverity(q.questionId, severity);
          },
          onClear: () {
            ref
                .read(questionnaireResponseProvider.notifier)
                .clearQuestion(q.questionId);
          },
        );
      },
    );
  }

  Widget _buildBottomSection(
    QuestionnaireResponse response,
    bool isSubmitting,
  ) {
    final totalAnswered = response.answeredQuestions.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    totalAnswered == 0
                        ? 'No symptoms reported yet'
                        : '$totalAnswered symptom${totalAnswered > 1 ? 's' : ''} reported',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Optional notes field
          Text(
            'Additional Notes (Optional)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              hintText: 'Add any additional notes or observations...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: isSubmitting || totalAnswered == 0
                  ? null
                  : _submitQuestionnaire,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: isSubmitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.grey.shade400,
                        ),
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                isSubmitting
                    ? 'Submitting $_progressDone/$_progressTotal…'
                    : 'Submit Report',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
