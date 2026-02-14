import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/condition_providers.dart';
import '../../providers/offline_queue_provider.dart';
import '../../providers/conditions_history_provider.dart';
import 'condition_screen.dart';

class ConditionsHistoryScreen extends ConsumerStatefulWidget {
  const ConditionsHistoryScreen({super.key});

  @override
  ConsumerState<ConditionsHistoryScreen> createState() =>
      _ConditionsHistoryScreenState();
}

class _ConditionsHistoryScreenState
    extends ConsumerState<ConditionsHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  static const int _itemsPerPage = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      ref.read(conditionsHistoryProvider.notifier).incrementPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestConditionsState = ref.watch(latestConditionsProvider);
    final queuedConditionsState = ref.watch(queuedConditionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text(
          'Symptoms',
          style: TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF3498DB).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ConditionScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, color: Color(0xFF3498DB)),
              tooltip: 'Report Condition',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(conditionsHistoryProvider.notifier).resetPage();
          ref.invalidate(latestConditionsProvider);
          ref.invalidate(queuedConditionsProvider);
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              latestConditionsState.when(
                data: (conditions) =>
                    _buildConditionsList(conditions, queuedConditionsState),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stack) => Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE5E5EA),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.orange[600],
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Error loading conditions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8E8E93),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConditionsList(
    List<Map<String, dynamic>> conditions,
    AsyncValue<List<Map<String, dynamic>>> queuedConditionsState,
  ) {
    return queuedConditionsState.when(
      data: (queuedConditions) {
        // Also show queued conditions that haven't been synced yet
        final allConditions = [...conditions];
        final queuedCondList = queuedConditions.map((q) {
          final data = q['data'] as Map<String, dynamic>;
          return {
            'condition': data['description'] as String? ?? 'Unknown',
            'conditionCode': data['conditionCode'] as String?,
            'severity': data['severity'] as String? ?? 'Unknown',
            'recordedDate': data['timestamp'] as String?,
            'notes': data['notes'],
            'isQueued': true,
          };
        }).toList();

        allConditions.addAll(queuedCondList);

        // Calculate pagination
        final historyState = ref.watch(conditionsHistoryProvider);
        final totalItems = allConditions.length;
        final displayedItems = (historyState.currentPage * _itemsPerPage).clamp(
          0,
          totalItems,
        );

        // Sort newest-first before pagination, then take the current page.
        final sortedAll = [...allConditions]
          ..sort((a, b) {
            final da = _parseRecordedDate(a);
            final db = _parseRecordedDate(b);
            return db.compareTo(da);
          });
        final paginatedConditions = sortedAll.take(displayedItems).toList();
        final hasMore = displayedItems < totalItems;

        if (allConditions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
            ),
            child: Column(
              children: [
                Icon(Icons.report_outlined, color: Colors.grey[600], size: 48),
                const SizedBox(width: 12),
                const Text(
                  'No conditions reported yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Track your health conditions and symptoms',
                  style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const Icon(Icons.healing_rounded, color: Color(0xFF3498DB)),
                    const SizedBox(width: 12),
                    Text(
                      'Recorded Symptoms',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    if (hasMore) ...[
                      const Spacer(),
                      Text(
                        'Showing $displayedItems of $totalItems',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ..._buildGroupedConditionWidgets(paginatedConditions),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
        ),
        child: Column(
          children: [
            Icon(Icons.report_problem, color: Colors.orange[600]),
            const SizedBox(width: 8),
            Text(
              '${conditions.length} Conditions',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
              'Loading queue status...',
              style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
          ],
        ),
      ),
      error: (error, stack) {
        // Show conditions even if queue fails to load
        if (conditions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
            ),
            child: Column(
              children: [
                Icon(Icons.report_outlined, color: Colors.grey[600], size: 48),
                const SizedBox(width: 12),
                const Text(
                  'No conditions reported yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          );
        }

        // Calculate pagination for error case (showing conditions only, without queue)
        final totalItems = conditions.length;
        final historyState2 = ref.watch(conditionsHistoryProvider);
        final displayedItems = (historyState2.currentPage * _itemsPerPage)
            .clamp(0, totalItems);
        final sortedOnly = [...conditions]
          ..sort(
            (a, b) => _parseRecordedDate(b).compareTo(_parseRecordedDate(a)),
          );
        final paginatedConditions = sortedOnly.take(displayedItems).toList();
        final hasMore = displayedItems < totalItems;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.report_problem, color: Colors.orange[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${conditions.length} Conditions',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    if (hasMore) ...[
                      const Spacer(),
                      Text(
                        'Showing $displayedItems of $totalItems',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ..._buildGroupedConditionWidgets(paginatedConditions),
              if (hasMore)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref
                            .read(conditionsHistoryProvider.notifier)
                            .incrementPage();
                      },
                      icon: const Icon(Icons.expand_more, size: 20),
                      label: const Text('Load More'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFE5E5EA)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  IconData _getConditionIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'fatigue':
        return Icons.battery_0_bar;
      case 'headache':
        return Icons.psychology;
      case 'nausea':
        return Icons.sick;
      case 'dizziness':
        return Icons.tornado;
      case 'fever':
        return Icons.thermostat;
      case 'cough':
        return Icons.air;
      case 'pain':
        return Icons.warning;
      default:
        return Icons.medical_information;
    }
  }

  Color _getSeverityColorFromString(String severity) {
    switch (severity.toLowerCase()) {
      case 'mild':
        return const Color(0xFF34C759);
      case 'moderate':
        return const Color(0xFFFF9500);
      case 'severe':
        return const Color(0xFFFF3B30);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  DateTime _parseRecordedDate(Map<String, dynamic> condition) {
    final recordedDate = condition['recordedDate'] as String?;
    final parsed = recordedDate != null
        ? DateTime.tryParse(recordedDate)
        : null;
    return (parsed ?? DateTime.now()).toLocal();
  }

  DateTime _startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  String _dayHeaderLabel(DateTime day) {
    final now = DateTime.now();
    final today = _startOfDay(now);
    final yesterday = today.subtract(const Duration(days: 1));

    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    return DateFormat('MMM dd, yyyy').format(day);
  }

  List<Widget> _buildGroupedConditionWidgets(
    List<Map<String, dynamic>> conditions,
  ) {
    if (conditions.isEmpty) return const <Widget>[];

    final widgets = <Widget>[];
    DateTime? currentDay;

    for (final condition in conditions) {
      final dateTime = _parseRecordedDate(condition);
      final day = _startOfDay(dateTime);

      if (currentDay == null || day != currentDay) {
        currentDay = day;
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              _dayHeaderLabel(day),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8E8E93),
              ),
            ),
          ),
        );
      }

      widgets.add(_buildConditionTile(condition, dateTime: dateTime));
    }

    return widgets;
  }

  Widget _buildConditionTile(
    Map<String, dynamic> condition, {
    required DateTime dateTime,
  }) {
    final isQueued = condition['isQueued'] as bool? ?? false;
    final severity = condition['severity'] as String? ?? 'Unknown';
    final severityColor = _getSeverityColorFromString(severity);

    final conditionText = condition['condition'] as String? ?? 'Unknown';
    final capitalizedCondition = conditionText
        .split(' ')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : word)
        .join(' ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getConditionIcon(conditionText), color: severityColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  capitalizedCondition,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd • hh:mm a').format(dateTime),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isQueued ? 'Syncing...' : severity,
              style: TextStyle(
                color: severityColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
