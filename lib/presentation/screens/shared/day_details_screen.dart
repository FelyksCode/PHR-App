import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/observation_providers.dart';
import '../../providers/condition_providers.dart';
import '../../providers/notification_reminders_provider.dart';
import '../../providers/reminder_history_provider.dart';
import '../../../data/models/notification_reminder.dart';
import '../../../data/models/reminder_history_record.dart';

class DayDetailsScreen extends ConsumerWidget {
  final DateTime selectedDate;

  const DayDetailsScreen({super.key, required this.selectedDate});

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final observationsState = ref.watch(latestObservationsProvider);
    final conditionsState = ref.watch(latestConditionsProvider);
    final reminders = ref.watch(notificationRemindersProvider);
    final history = ref.watch(reminderHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
              style: const TextStyle(
                color: Color(0xFF1C1C1E),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final yesterday = selectedDate.subtract(const Duration(days: 1));
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => DayDetailsScreen(selectedDate: yesterday),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final tomorrow = selectedDate.add(const Duration(days: 1));
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => DayDetailsScreen(selectedDate: tomorrow),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Vital Signs', Icons.favorite, const Color(0xFFFF3B30)),
            const SizedBox(height: 12),
            observationsState.when(
              data: (obs) {
                final dayObs = obs.where((o) {
                  final dateStr = o['effectiveDateTime'] as String? ?? o['issued'] as String?;
                  if (dateStr == null) return false;
                  final parsed = DateTime.tryParse(dateStr);
                  if (parsed == null) return false;
                  return _isSameDay(parsed.toLocal(), selectedDate.toLocal());
                }).toList();

                if (dayObs.isEmpty) {
                  return _buildEmptyState('No vital signs recorded for this day');
                }

                return _buildObservationList(dayObs);
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
              error: (_, __) => _buildEmptyState('Unable to load vital signs for this day'),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Conditions', Icons.report_problem, const Color(0xFFFF9500)),
            const SizedBox(height: 12),
            conditionsState.when(
              data: (conds) {
                final dayConds = conds.where((c) {
                  final dateStr = c['recordedDate'] as String? ?? c['onsetDateTime'] as String? ?? c['timestamp'] as String?;
                  if (dateStr == null) return false;
                  final parsed = DateTime.tryParse(dateStr);
                  if (parsed == null) return false;
                  return _isSameDay(parsed.toLocal(), selectedDate.toLocal());
                }).toList();

                if (dayConds.isEmpty) {
                  return _buildEmptyState('No conditions reported for this day');
                }

                return _buildConditionList(dayConds);
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
              error: (_, __) => _buildEmptyState('Unable to load conditions for this day'),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Reminders', Icons.notifications, const Color(0xFF007AFF)),
            const SizedBox(height: 12),
            _buildCompletedRemindersSection(history),
            const SizedBox(height: 12),
            _buildUpcomingRemindersSection(reminders),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF8E8E93),
          ),
        ),
      ),
    );
  }

  Widget _buildObservationList(List<Map<String, dynamic>> observations) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: observations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final obs = observations[index];
        final dateStr = obs['effectiveDateTime'] as String? ?? obs['issued'] as String?;
        final date = DateTime.tryParse(dateStr ?? '')?.toLocal();
        final timeLabel = date != null ? DateFormat('hh:mm a').format(date) : '--';
        final rawType = obs['type'] as String? ?? 'Observation';
        final typeLower = rawType.toLowerCase();
        final isBpPanel = typeLower.contains('blood pressure') ||
            (obs['loincCode'] == '35094-2') ||
            (obs['component'] is List && (obs['component'] as List).isNotEmpty);

        final displayType = isBpPanel ? 'Blood Pressure' : rawType;

        // Extract BP values if panel
        num? systolic;
        num? diastolic;
        String unit = obs['unit'] as String? ?? '';
        if (isBpPanel) {
          // Prefer pre-parsed values if present
          if (obs['systolicValue'] is num) {
            systolic = obs['systolicValue'] as num?;
          }
          if (obs['diastolicValue'] is num) {
            diastolic = obs['diastolicValue'] as num?;
          }

          // Fallback to component parsing
          final components = obs['component'] as List<dynamic>?;
          if (components != null && components.isNotEmpty) {
            for (final component in components) {
              final compCode = component['code']?['coding']?[0]?['code'] as String?;
              final vq = component['valueQuantity'] as Map<String, dynamic>?;
              final val = vq?['value'];
              if (compCode == '8480-6') {
                if (val is num) systolic = val;
              } else if (compCode == '8462-4') {
                if (val is num) diastolic = val;
              }
              // Prefer unit from component
              unit = vq?['unit'] as String? ?? unit;
            }
          }
          // Default unit for BP if still empty
          if (unit.isEmpty) unit = 'mmHg';
        }

        final value = obs['value'];
        final notes = obs['notes'] as String?;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayType,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeLabel,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                    ),
                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        notes,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isBpPanel) ...[
                    Text(
                      '${systolic?.toString() ?? '--'} / ${diastolic?.toString() ?? '--'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    Text(
                      unit,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                    ),
                  ] else ...[
                    Text(
                      value != null ? '$value' : '--',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    if ((unit).isNotEmpty)
                      Text(
                        unit,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                      ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConditionList(List<Map<String, dynamic>> conditions) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: conditions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final cond = conditions[index];
        final name = cond['condition'] as String? ?? cond['conditionCode'] as String? ?? 'Condition';
        final severity = cond['severity'] as String? ?? 'Unspecified';
        final dateStr = cond['recordedDate'] as String? ?? cond['onsetDateTime'] as String? ?? cond['timestamp'] as String?;
        final date = DateTime.tryParse(dateStr ?? '')?.toLocal();
        final timeLabel = date != null ? DateFormat('hh:mm a').format(date) : '--';
        final notes = cond['notes'] as String?;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    severity,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                timeLabel,
                style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  notes,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcomingRemindersSection(List<NotificationReminder> reminders) {
    final dueReminders = reminders.where((r) =>
      r.enabled &&
      r.isDueOn(selectedDate) &&
      !r.isCompletedOn(selectedDate) &&
      (DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
          .isAfter(DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day)) ||
       _isSameDay(selectedDate, r.createdAt))
    ).toList();
    if (dueReminders.isEmpty) {
      return _buildEmptyState('No upcoming reminders for this day');
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dueReminders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final r = dueReminders[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'At ${r.time.format(context)}${r.interval != null ? ' · ${r.interval}' : ''}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Upcoming',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletedRemindersSection(List<ReminderHistoryRecord> history) {
    final key = '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
    final records = history.where((h) => h.dateKey == key).toList();
    if (records.isEmpty) {
      return _buildEmptyState('No completed reminders for this day');
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final r = records[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Completed at ${r.time.format(context)}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F8EF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Color(0xFF32D74B),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Completed',
                      style: TextStyle(
                        color: Color(0xFF1C1C1E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
