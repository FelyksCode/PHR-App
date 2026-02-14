import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/observation_providers.dart';
import '../../providers/condition_providers.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
              style: const TextStyle(
                color: Color(0xFF2C3E50),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
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
            icon: const Icon(Icons.chevron_right_rounded),
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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Vital Signs',
              Icons.favorite_rounded,
              const Color(0xFF2ECC71),
            ),
            const SizedBox(height: 16),
            observationsState.when(
              data: (obs) {
                final dayObs = obs.where((o) {
                  final dateStr =
                      o['effectiveDateTime'] as String? ??
                      o['issued'] as String?;
                  if (dateStr == null) return false;
                  final parsed = DateTime.tryParse(dateStr);
                  if (parsed == null) return false;
                  return _isSameDay(parsed.toLocal(), selectedDate.toLocal());
                }).toList();

                if (dayObs.isEmpty) {
                  return _buildEmptyState(
                    'No vital signs recorded for this day',
                  );
                }

                return _buildObservationList(dayObs);
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) =>
                  _buildEmptyState('Unable to load vital signs for this day'),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(
              'Symptoms & Conditions',
              Icons.healing_rounded,
              const Color(0xFF3498DB),
            ),
            const SizedBox(height: 16),
            conditionsState.when(
              data: (conds) {
                final dayConds = conds.where((c) {
                  final dateStr =
                      c['recordedDate'] as String? ??
                      c['onsetDateTime'] as String? ??
                      c['timestamp'] as String?;
                  if (dateStr == null) return false;
                  final parsed = DateTime.tryParse(dateStr);
                  if (parsed == null) return false;
                  return _isSameDay(parsed.toLocal(), selectedDate.toLocal());
                }).toList();

                if (dayConds.isEmpty) {
                  return _buildEmptyState(
                    'No conditions reported for this day',
                  );
                }

                return _buildConditionList(dayConds);
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) =>
                  _buildEmptyState('Unable to load conditions for this day'),
            ),
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
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
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
        final dateStr =
            obs['effectiveDateTime'] as String? ?? obs['issued'] as String?;
        final date = DateTime.tryParse(dateStr ?? '')?.toLocal();
        final timeLabel = date != null
            ? DateFormat('hh:mm a').format(date)
            : '--';
        final rawType = obs['type'] as String? ?? 'Observation';
        final typeLower = rawType.toLowerCase();
        final isBpPanel =
            typeLower.contains('blood pressure') ||
            (obs['loincCode'] == '35094-2') ||
            (obs['component'] is List && (obs['component'] as List).isNotEmpty);

        final displayType = isBpPanel ? 'Blood Pressure' : rawType;

        num? systolic;
        num? diastolic;
        String unit = obs['unit'] as String? ?? '';
        if (isBpPanel) {
          if (obs['systolicValue'] is num) {
            systolic = obs['systolicValue'] as num?;
          }
          if (obs['diastolicValue'] is num) {
            diastolic = obs['diastolicValue'] as num?;
          }

          final components = obs['component'] as List<dynamic>?;
          if (components != null && components.isNotEmpty) {
            for (final component in components) {
              final compCode =
                  component['code']?['coding']?[0]?['code'] as String?;
              final vq = component['valueQuantity'] as Map<String, dynamic>?;
              final val = vq?['value'];
              if (compCode == '8480-6') {
                if (val is num) systolic = val;
              } else if (compCode == '8462-4') {
                if (val is num) diastolic = val;
              }
              unit = vq?['unit'] as String? ?? unit;
            }
          }
          if (unit.isEmpty) unit = 'mmHg';
        }

        final value = obs['value'];
        final notes = obs['notes'] as String?;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayType,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notes,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
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
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE74C3C),
                      ),
                    ),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    Text(
                      value != null ? '$value' : '--',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2ECC71),
                      ),
                    ),
                    if ((unit).isNotEmpty)
                      Text(
                        unit,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w600,
                        ),
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
        final name =
            cond['condition'] as String? ??
            cond['conditionCode'] as String? ??
            'Condition';
        final severity = cond['severity'] as String? ?? 'Unspecified';
        final dateStr =
            cond['recordedDate'] as String? ??
            cond['onsetDateTime'] as String? ??
            cond['timestamp'] as String?;
        final date = DateTime.tryParse(dateStr ?? '')?.toLocal();
        final timeLabel = date != null
            ? DateFormat('hh:mm a').format(date)
            : '--';
        final notes = cond['notes'] as String?;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3498DB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      severity,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3498DB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                timeLabel,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  notes,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
