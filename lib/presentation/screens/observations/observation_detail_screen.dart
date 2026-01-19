import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:phr_app/domain/entities/observation_entity.dart';
import 'package:phr_app/data/models/observation_model.dart';
import 'package:phr_app/presentation/providers/observation_service_provider.dart';
import 'package:phr_app/presentation/providers/observation_providers.dart';
import 'package:phr_app/presentation/providers/offline_queue_provider.dart';
import 'package:phr_app/presentation/providers/observation_detail_provider.dart';
import 'package:phr_app/presentation/widgets/blood_pressure_form.dart';
import 'package:phr_app/presentation/widgets/common_widgets.dart';

class ObservationDetailScreen extends ConsumerStatefulWidget {
  final ObservationType observationType;
  final List<Map<String, dynamic>> observations;

  const ObservationDetailScreen({
    super.key,
    required this.observationType,
    required this.observations,
  });

  @override
  ConsumerState<ObservationDetailScreen> createState() =>
      _ObservationDetailScreenState();
}

class _ObservationDetailScreenState
    extends ConsumerState<ObservationDetailScreen> {
  late ScrollController _scrollController;
  late List<Map<String, dynamic>> _observations;
  static const int _itemsPerPage = 10;

  bool get _isBloodPressure =>
      widget.observationType == ObservationType.bloodPressureSystolic ||
      widget.observationType == ObservationType.bloodPressureDiastolic;

  @override
  void initState() {
    super.initState();
    _observations = List.from(widget.observations);
    _scrollController = ScrollController();
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
      ref.read(observationDetailProvider.notifier).incrementPage();
    }
  }

  List<Map<String, dynamic>> _getFilteredObservations({
    bool Function(Map<String, dynamic>)? filter,
  }) {
    final detailState = ref.read(observationDetailProvider);
    final now = DateTime.now();
    final DateTime cutoffDate = switch (detailState.selectedPeriod) {
      // Today: from start of current day
      TimePeriod.hours24 => DateTime(now.year, now.month, now.day),
      // Last 7 days (rolling)
      TimePeriod.days7 => now.subtract(const Duration(days: 7)),
      // This month: from first day of current month
      TimePeriod.days30 => DateTime(now.year, now.month, 1),
    };

    return _observations.where((obs) {
      final dateTimeStr = obs['effectiveDateTime'] as String?;
      if (dateTimeStr == null) return false;
      final dateTime = DateTime.tryParse(dateTimeStr)?.toLocal();
      if (dateTime == null) return false;
      if (!dateTime.isAfter(cutoffDate)) return false;
      if (filter != null && !filter(obs)) return false;
      return true;
    }).toList();
  }

  List<FlSpot> _generateChartData(List<Map<String, dynamic>> filteredObs) {
    if (filteredObs.isEmpty) return [];

    // Sort by date
    final sorted = List<Map<String, dynamic>>.from(filteredObs)
      ..sort((a, b) {
        final dateA =
            DateTime.tryParse(
              a['effectiveDateTime'] as String? ?? '',
            )?.toLocal() ??
            DateTime.now();
        final dateB =
            DateTime.tryParse(
              b['effectiveDateTime'] as String? ?? '',
            )?.toLocal() ??
            DateTime.now();
        return dateA.compareTo(dateB);
      });

    return sorted.asMap().entries.map((entry) {
      final value = entry.value['value'];
      final numValue = value is num
          ? value.toDouble()
          : double.tryParse(value.toString()) ?? 0.0;
      return FlSpot(entry.key.toDouble(), numValue);
    }).toList();
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  List<Map<String, dynamic>> _groupBloodPressureHistory(
    List<Map<String, dynamic>> observations,
  ) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final obs in observations) {
      final dateStr = obs['effectiveDateTime'] as String?;
      if (dateStr == null) continue;

      final parsedDate =
          DateTime.tryParse(dateStr)?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0);

      // Handle FHIR panel format with components
      final components = obs['component'] as List<dynamic>?;
      if (components != null && components.isNotEmpty) {
        // This is a blood pressure panel observation
        final entry = grouped.putIfAbsent(
          dateStr,
          () => {
            'effectiveDateTime': dateStr,
            'date': parsedDate,
            'systolic': null,
            'diastolic': null,
            'unit': 'mmHg',
            'notes': obs['note'] != null
                ? (obs['note'] as List).isNotEmpty
                      ? (obs['note'][0]['text'] as String?)
                      : null
                : null,
          },
        );

        // Extract systolic and diastolic from components
        for (final component in components) {
          final code = component['code'] as Map<String, dynamic>?;
          final coding = code?['coding'] as List<dynamic>?;
          if (coding != null && coding.isNotEmpty) {
            final loincCode =
                (coding[0] as Map<String, dynamic>?)?['code'] as String?;
            final valueQuantity =
                component['valueQuantity'] as Map<String, dynamic>?;
            final value = valueQuantity?['value'];

            if (loincCode == '8480-6') {
              // Systolic
              entry['systolic'] ??= _toDouble(value);
            } else if (loincCode == '8462-4') {
              // Diastolic
              entry['diastolic'] ??= _toDouble(value);
            }
          }
        }
        continue;
      }

      // Handle legacy format with separate systolic/diastolic observations
      final type = (obs['type'] as String? ?? '').toLowerCase();
      final isSystolic = type.contains('systolic');
      final isDiastolic = type.contains('diastolic');
      if (!isSystolic && !isDiastolic) continue;

      final entry = grouped.putIfAbsent(
        dateStr,
        () => {
          'effectiveDateTime': dateStr,
          'date': parsedDate,
          'systolic': null,
          'diastolic': null,
          'unit': obs['unit'],
          'notes': obs['notes'],
        },
      );

      if (isSystolic) {
        entry['systolic'] ??= _toDouble(obs['value']);
      }
      if (isDiastolic) {
        entry['diastolic'] ??= _toDouble(obs['value']);
      }

      entry['unit'] ??= obs['unit'];
      entry['notes'] ??= obs['notes'];
    }

    final groupedList = grouped.values.toList();
    groupedList.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );
    return groupedList;
  }

  String _getChartTitle() {
    final detailState = ref.read(observationDetailProvider);
    return switch (detailState.selectedPeriod) {
      TimePeriod.hours24 => 'Today',
      TimePeriod.days7 => 'Last 7 Days',
      TimePeriod.days30 => 'This Month',
    };
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(observationDetailProvider);
    final appBarTitle = _isBloodPressure
        ? 'Blood Pressure'
        : widget.observationType.displayName;

    final filteredObservations = _getFilteredObservations();

    final bool isTodayPeriod = detailState.selectedPeriod == TimePeriod.hours24;
    final bool hasSingleTodayRecord =
        isTodayPeriod && filteredObservations.length == 1;

    List<Map<String, dynamic>> sortedObservations;
    int totalItems;
    int displayedItems;
    List<Map<String, dynamic>> paginatedObservations;
    bool hasMore;

    if (_isBloodPressure) {
      sortedObservations = _groupBloodPressureHistory(filteredObservations);
    } else {
      sortedObservations = List<Map<String, dynamic>>.from(filteredObservations)
        ..sort((a, b) {
          final dateA =
              DateTime.tryParse(
                a['effectiveDateTime'] as String? ?? '',
              )?.toLocal() ??
              DateTime.now();
          final dateB =
              DateTime.tryParse(
                b['effectiveDateTime'] as String? ?? '',
              )?.toLocal() ??
              DateTime.now();
          return dateB.compareTo(dateA);
        });
    }

    totalItems = sortedObservations.length;
    displayedItems = (detailState.currentPage * _itemsPerPage)
        .clamp(0, totalItems)
        .toInt();
    paginatedObservations = sortedObservations.take(displayedItems).toList();
    hasMore = displayedItems < totalItems;

    final latestObs = sortedObservations.isNotEmpty
        ? sortedObservations.first
        : null;
    final chartData = _isBloodPressure
        ? <FlSpot>[]
        : _generateChartData(filteredObservations);

    // Build BP chart series from grouped observations (systolic/diastolic values)
    final systolicSeries = _isBloodPressure
        ? sortedObservations
              .where((e) => e['systolic'] != null)
              .map(
                (e) => {
                  'value': e['systolic'],
                  'effectiveDateTime': e['effectiveDateTime'],
                },
              )
              .toList()
        : <Map<String, dynamic>>[];
    final diastolicSeries = _isBloodPressure
        ? sortedObservations
              .where((e) => e['diastolic'] != null)
              .map(
                (e) => {
                  'value': e['diastolic'],
                  'effectiveDateTime': e['effectiveDateTime'],
                },
              )
              .toList()
        : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(
            color: Color(0xFF1C1C1E),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _openVitalSignBottomSheet,
            icon: const Icon(Icons.add),
            tooltip: 'Add Measurement',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (latestObs != null) _buildStatsCard(latestObs),
            const SizedBox(height: 20),
            _buildPeriodSelector(),
            const SizedBox(height: 16),
            if (hasSingleTodayRecord)
              _buildSingleDataInfoCard(sortedObservations.first)
            else if (_isBloodPressure)
              _buildBloodPressureChartCard(systolicSeries, diastolicSeries)
            else if (chartData.isNotEmpty)
              _buildChartCard(chartData)
            else
              _buildEmptyChartCard(),
            const SizedBox(height: 20),
            _buildObservationsList(
              paginatedObservations,
              hasMore,
              totalItems,
              displayedItems,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildPeriodButton(TimePeriod.hours24, 'Today'),
          _buildPeriodButton(TimePeriod.days7, '7 days'),
          _buildPeriodButton(TimePeriod.days30, 'This month'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(TimePeriod period, String label) {
    final detailState = ref.watch(observationDetailProvider);
    final detailNotifier = ref.read(observationDetailProvider.notifier);
    final isSelected = detailState.selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          detailNotifier.setPeriod(period);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF8E8E93),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard(List<FlSpot> chartData) {
    // Calculate min and max for better chart scaling
    final values = chartData.map((spot) => spot.y).toList();
    final minValue = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.isEmpty
        ? 100.0
        : values.reduce((a, b) => a > b ? a : b);
    final padding = (maxValue - minValue) * 0.1;
    final minY = (minValue - padding).clamp(0.0, minValue);
    final maxY = maxValue + padding;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trend Chart - ${_getChartTitle()}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 280,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                minY: minY,
                barGroups: chartData.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.y,
                        color: const Color(0xFF007AFF),
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                    showingTooltipIndicators: [],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < chartData.length) {
                          final obs = _getFilteredObservations();
                          obs.sort((a, b) {
                            final dateA =
                                DateTime.tryParse(
                                  a['effectiveDateTime'] as String? ?? '',
                                )?.toLocal() ??
                                DateTime.now();
                            final dateB =
                                DateTime.tryParse(
                                  b['effectiveDateTime'] as String? ?? '',
                                )?.toLocal() ??
                                DateTime.now();
                            return dateA.compareTo(dateB);
                          });
                          if (index < obs.length) {
                            final detailState = ref.read(
                              observationDetailProvider,
                            );
                            final dateTime =
                                DateTime.tryParse(
                                  obs[index]['effectiveDateTime'] as String? ??
                                      '',
                                )?.toLocal() ??
                                DateTime.now();
                            final dateFormat =
                                detailState.selectedPeriod == TimePeriod.hours24
                                ? DateFormat('HH:mm')
                                : DateFormat('MM/dd');
                            return Text(
                              dateFormat.format(dateTime),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                      reservedSize: 40,
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodPressureChartCard(
    List<Map<String, dynamic>> systolic,
    List<Map<String, dynamic>> diastolic,
  ) {
    final systolicSpots = _generateChartData(systolic);
    final diastolicSpots = _generateChartData(diastolic);

    if (systolicSpots.isEmpty && diastolicSpots.isEmpty) {
      return _buildEmptyChartCard();
    }

    final allValues = [
      ...systolicSpots.map((e) => e.y),
      ...diastolicSpots.map((e) => e.y),
    ];
    final minValue = allValues.isEmpty
        ? 0.0
        : allValues.reduce((a, b) => a < b ? a : b);
    final maxValue = allValues.isEmpty
        ? 100.0
        : allValues.reduce((a, b) => a > b ? a : b);
    final padding = (maxValue - minValue) * 0.1;
    final minY = (minValue - padding).clamp(0.0, minValue);
    final maxY = maxValue + padding;

    List<FlSpot> normalize(List<FlSpot> spots) {
      // Ensure x is sequential for display
      return spots
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), e.value.y))
          .toList();
    }

    final systolicNorm = normalize(systolicSpots);
    final diastolicNorm = normalize(diastolicSpots);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Blood Pressure - ${_getChartTitle()}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _legendEntry(const Color(0xFF007AFF), 'Systolic'),
                  _legendEntry(const Color(0xFFFF3B30), 'Diastolic'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 280,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        final obs = _getFilteredObservations();
                        obs.sort((a, b) {
                          final dateA =
                              DateTime.tryParse(
                                a['effectiveDateTime'] as String? ?? '',
                              )?.toLocal() ??
                              DateTime.now();
                          final dateB =
                              DateTime.tryParse(
                                b['effectiveDateTime'] as String? ?? '',
                              )?.toLocal() ??
                              DateTime.now();
                          return dateA.compareTo(dateB);
                        });
                        if (idx >= 0 && idx < obs.length) {
                          final detailState = ref.read(
                            observationDetailProvider,
                          );
                          final dateTime =
                              DateTime.tryParse(
                                obs[idx]['effectiveDateTime'] as String? ?? '',
                              )?.toLocal() ??
                              DateTime.now();
                          final dateFormat =
                              detailState.selectedPeriod == TimePeriod.hours24
                              ? DateFormat('HH:mm')
                              : DateFormat('MM/dd');
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              dateFormat.format(dateTime),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  if (systolicNorm.isNotEmpty)
                    LineChartBarData(
                      spots: systolicNorm,
                      isCurved: true,
                      color: const Color(0xFF007AFF),
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                  if (diastolicNorm.isNotEmpty)
                    LineChartBarData(
                      spots: diastolicNorm,
                      isCurved: true,
                      color: const Color(0xFFFF3B30),
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendEntry(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF1C1C1E)),
        ),
      ],
    );
  }

  Widget _buildEmptyChartCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
      ),
      child: Column(
        children: [
          Icon(Icons.show_chart, color: Colors.grey[600], size: 48),
          const SizedBox(height: 12),
          const Text(
            'No data for this period',
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

  Widget _buildSingleDataInfoCard(Map<String, dynamic> obs) {
    final effectiveDateTime = obs['effectiveDateTime'] as String?;
    final dateTime = effectiveDateTime != null
        ? DateTime.tryParse(effectiveDateTime)?.toLocal() ?? DateTime.now()
        : DateTime.now();

    if (_isBloodPressure) {
      final systolic = obs['systolic'];
      final diastolic = obs['diastolic'];
      final unit = obs['unit'] as String? ?? 'mmHg';

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
              'Today\'s only measurement',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${systolic ?? '--'} / ${diastolic ?? '--'}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: Color(0xFF8E8E93),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Charts are shown when there are at least two measurements in the selected period.',
              style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
            ),
          ],
        ),
      );
    }

    final value = obs['value'];
    final unit = obs['unit'] as String?;
    final notes = obs['notes'] as String?;

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
            'Today\'s only measurement',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (value != null) ...[
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      unit,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Color(0xFF8E8E93)),
              const SizedBox(width: 8),
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime),
                style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
              ),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              notes,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1C1C1E),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Charts are shown when there are at least two measurements in the selected period.',
            style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(Map<String, dynamic> latestObs) {
    if (_isBloodPressure) {
      // Use grouped latest observation (with systolic/diastolic fields)
      final latestDate =
          DateTime.tryParse(
            latestObs['effectiveDateTime'] as String? ?? '',
          )?.toLocal() ??
          DateTime.now();

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Latest Reading',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${latestObs['systolic'] ?? '--'} / ${latestObs['diastolic'] ?? '--'}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  latestObs['unit'] as String? ?? 'mmHg',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: const Color(0xFF8E8E93),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(latestDate),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final effectiveDateTime = latestObs['effectiveDateTime'] as String?;
    final dateTime = effectiveDateTime != null
        ? DateTime.tryParse(effectiveDateTime)?.toLocal() ?? DateTime.now()
        : DateTime.now();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Latest Reading',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (latestObs['value'] != null) ...[
                Text(
                  '${latestObs['value']}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                if (latestObs['unit'] != null) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      latestObs['unit'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: const Color(0xFF8E8E93)),
              const SizedBox(width: 8),
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime),
                style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
              ),
            ],
          ),
          if (latestObs['notes'] != null &&
              (latestObs['notes'] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                latestObs['notes'] as String,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF1C1C1E),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildObservationsList(
    List<Map<String, dynamic>> observations,
    bool hasMore,
    int totalItems,
    int displayedItems,
  ) {
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
                const Icon(Icons.history, color: Color(0xFF007AFF)),
                const SizedBox(width: 8),
                Text(
                  'History ($totalItems)',
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
          if (observations.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600], size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'No records found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ...observations.map((obs) {
              final effectiveDateTime = obs['effectiveDateTime'] as String?;
              final dateTime = effectiveDateTime != null
                  ? DateTime.tryParse(effectiveDateTime)?.toLocal() ??
                        DateTime.now()
                  : DateTime.now();

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                title: Text(
                  DateFormat('MMM dd, yyyy').format(dateTime),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('hh:mm a').format(dateTime),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                    if (obs['notes'] != null &&
                        (obs['notes'] as String).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        obs['notes'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
                trailing: _isBloodPressure
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${obs['systolic'] ?? '--'} / ${obs['diastolic'] ?? '--'}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1C1C1E),
                            ),
                          ),
                          Text(
                            (obs['unit'] as String?) ?? 'mmHg',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      )
                    : (obs['value'] != null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${obs['value']}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1C1C1E),
                                  ),
                                ),
                                if (obs['unit'] != null)
                                  Text(
                                    obs['unit'] as String,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF8E8E93),
                                    ),
                                  ),
                              ],
                            )
                          : null),
              );
            }),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () {
                      ref
                          .read(observationDetailProvider.notifier)
                          .incrementPage();
                    },
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Load More'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF007AFF),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _openVitalSignBottomSheet() {
    final title = widget.observationType.displayName;
    final unit = widget.observationType.standardUnit;
    final observationType = widget.observationType;

    // Use unified BloodPressureForm for blood pressure
    if (observationType == ObservationType.bloodPressureSystolic ||
        observationType == ObservationType.bloodPressureDiastolic) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => BloodPressureForm(
          onSubmit: (systolic, diastolic, notes) {
            Navigator.pop(context);
            _submitBloodPressure(systolic, diastolic, notes);
          },
          isSubmitting: false,
        ),
      );
      return;
    }

    // Standard form for other observation types
    final valueController = TextEditingController();
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            _getIcon(widget.observationType),
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
                              title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1C1C1E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Record a new measurement',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Color(0xFF8E8E93)),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Manual entry section
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E5EA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Enter Reading',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1C1C1E),
                                ),
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                label: '$title ($unit)',
                                controller: valueController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                label: 'Notes (Optional)',
                                controller: notesController,
                                maxLines: 3,
                                hint:
                                    'Add any additional notes about this reading...',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => _submitSingleObservation(
                              title,
                              observationType,
                              valueController,
                              notesController,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007AFF),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('Submit $title'),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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

  /// Submits blood pressure as two separate FHIR-compliant observations
  /// Submits blood pressure as a single FHIR panel observation with components
  Future<void> _submitBloodPressure(
    double systolic,
    double diastolic,
    String? notes,
  ) async {
    try {
      final observationService = ref.read(observationServiceProvider);
      final queueService = ref.read(offlineQueueServiceProvider);

      // Check internet connectivity
      bool hasInternet = false;
      try {
        final result = await InternetAddress.lookup(
          '8.8.8.8',
        ).timeout(const Duration(seconds: 2));
        hasInternet = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      } catch (_) {
        hasInternet = false;
      }

      if (!mounted) return;

      if (hasInternet) {
        try {
          final success = await observationService
              .submitBloodPressurePanelObservation(
                systolic: systolic,
                diastolic: diastolic,
                notes: notes,
                source: DataSource.manual,
              );
          if (!mounted) return;

          if (success) {
            ref.invalidate(latestObservationsProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Blood Pressure recorded successfully'),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to record Blood Pressure')),
            );
          }
        } catch (e) {
          // Queue the observations on error
          final timestamp = DateTime.now();
          final systolicObs = ObservationModel.create(
            type: ObservationType.bloodPressureSystolic,
            value: systolic,
            unit: ObservationType.bloodPressureSystolic.standardUnit,
            source: DataSource.manual,
            notes: notes,
            timestamp: timestamp,
          );
          final diastolicObs = ObservationModel.create(
            type: ObservationType.bloodPressureDiastolic,
            value: diastolic,
            unit: ObservationType.bloodPressureDiastolic.standardUnit,
            source: DataSource.manual,
            notes: notes,
            timestamp: timestamp,
          );
          await queueService.queueObservation(systolicObs);
          await queueService.queueObservation(diastolicObs);
          ref.invalidate(queuedObservationsProvider);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Blood Pressure saved offline. Will sync when online.',
              ),
            ),
          );
        }
      } else {
        // No internet - queue the observations
        final timestamp = DateTime.now();
        final systolicObs = ObservationModel.create(
          type: ObservationType.bloodPressureSystolic,
          value: systolic,
          unit: ObservationType.bloodPressureSystolic.standardUnit,
          source: DataSource.manual,
          notes: notes,
          timestamp: timestamp,
        );
        final diastolicObs = ObservationModel.create(
          type: ObservationType.bloodPressureDiastolic,
          value: diastolic,
          unit: ObservationType.bloodPressureDiastolic.standardUnit,
          source: DataSource.manual,
          notes: notes,
          timestamp: timestamp,
        );
        await queueService.queueObservation(systolicObs);
        await queueService.queueObservation(diastolicObs);
        ref.invalidate(queuedObservationsProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Blood Pressure saved offline. Will sync when online.',
            ),
          ),
        );
      }

      if (mounted) {
        ref.read(observationDetailProvider.notifier).resetPage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  /// Submits a single observation (non-blood pressure)
  Future<void> _submitSingleObservation(
    String title,
    ObservationType observationType,
    TextEditingController valueController,
    TextEditingController notesController,
  ) async {
    try {
      final value = valueController.text.trim();
      final notes = notesController.text.trim();

      if (value.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please enter a value')));
        return;
      }

      // Create single observation
      final observation = ObservationModel.create(
        type: observationType,
        value: double.tryParse(value) ?? 0.0,
        unit: observationType.standardUnit,
        source: DataSource.manual,
        notes: notes.isNotEmpty ? notes : null,
      );

      final observationService = ref.read(observationServiceProvider);
      final queueService = ref.read(offlineQueueServiceProvider);

      // Check internet connectivity
      bool hasInternet = false;
      try {
        final result = await InternetAddress.lookup(
          '8.8.8.8',
        ).timeout(const Duration(seconds: 2));
        hasInternet = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      } catch (_) {
        hasInternet = false;
      }

      if (!mounted) return;

      if (hasInternet) {
        try {
          final success = await observationService.submitObservation(
            observation,
          );
          if (!mounted) return;

          if (success) {
            // Add to local observations list
            _observations.insert(0, {
              'effectiveDateTime': observation.timestamp.toIso8601String(),
              'value': observation.value,
              'unit': observation.unit,
              'notes': observation.notes,
            });
            ref.invalidate(latestObservationsProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title submitted successfully')),
            );
          } else {
            // Queue for later sync
            await queueService.queueObservation(observation);
            ref.invalidate(queuedObservationsProvider);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title saved offline. Will sync when online.'),
              ),
            );
          }
        } catch (e) {
          // Queue the data
          await queueService.queueObservation(observation);
          ref.invalidate(queuedObservationsProvider);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title saved offline. Will sync when online.'),
            ),
          );
        }
      } else {
        // No internet - queue directly
        await queueService.queueObservation(observation);
        ref.invalidate(queuedObservationsProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title saved offline. Will sync when online.'),
          ),
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ref.read(observationDetailProvider.notifier).resetPage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }
}
