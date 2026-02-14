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
      TimePeriod.hours24 => DateTime(now.year, now.month, now.day),
      TimePeriod.days7 => now.subtract(const Duration(days: 7)),
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

    final sorted = List<Map<String, dynamic>>.from(filteredObs)
      ..sort((a, b) {
        final dateA =
            DateTime.tryParse(a['effectiveDateTime'] as String? ?? '')?.toLocal() ??
            DateTime.now();
        final dateB =
            DateTime.tryParse(b['effectiveDateTime'] as String? ?? '')?.toLocal() ??
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

      final components = obs['component'] as List<dynamic>?;
      if (components != null && components.isNotEmpty) {
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
              entry['systolic'] ??= _toDouble(value);
            } else if (loincCode == '8462-4') {
              entry['diastolic'] ??= _toDouble(value);
            }
          }
        }
        continue;
      }

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
    }

    final groupedList = grouped.values.toList();
    groupedList.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );
    return groupedList;
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
    if (_isBloodPressure) {
      sortedObservations = _groupBloodPressureHistory(filteredObservations);
    } else {
      sortedObservations = List<Map<String, dynamic>>.from(filteredObservations)
        ..sort((a, b) {
          final dateA =
              DateTime.tryParse(a['effectiveDateTime'] as String? ?? '')?.toLocal() ??
              DateTime.now();
          final dateB =
              DateTime.tryParse(b['effectiveDateTime'] as String? ?? '')?.toLocal() ??
              DateTime.now();
          return dateB.compareTo(dateA);
        });
    }

    final totalItems = sortedObservations.length;
    final displayedItems = (detailState.currentPage * _itemsPerPage)
        .clamp(0, totalItems)
        .toInt();
    final paginatedObservations = sortedObservations.take(displayedItems).toList();
    final hasMore = displayedItems < totalItems;

    final latestObs = sortedObservations.isNotEmpty
        ? sortedObservations.first
        : null;
    final chartData = _isBloodPressure
        ? <FlSpot>[]
        : _generateChartData(filteredObservations);

    final systolicSeries = _isBloodPressure
        ? sortedObservations
              .where((e) => e['systolic'] != null)
              .map((e) => {'value': e['systolic'], 'effectiveDateTime': e['effectiveDateTime']})
              .toList()
        : <Map<String, dynamic>>[];
    final diastolicSeries = _isBloodPressure
        ? sortedObservations
              .where((e) => e['diastolic'] != null)
              .map((e) => {'value': e['diastolic'], 'effectiveDateTime': e['effectiveDateTime']})
              .toList()
        : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _openVitalSignBottomSheet,
            icon: const Icon(Icons.add_rounded, color: Colors.black),
            tooltip: 'Add Measurement',
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (latestObs != null) _buildStatsCard(latestObs),
            const SizedBox(height: 24),
            _buildPeriodSelector(),
            const SizedBox(height: 20),
            if (hasSingleTodayRecord)
              _buildSingleDataInfoCard(sortedObservations.first)
            else if (_isBloodPressure)
              _buildBloodPressureChartCard(systolicSeries, diastolicSeries)
            else if (chartData.isNotEmpty)
              _buildChartCard(chartData)
            else
              _buildEmptyChartCard(),
            const SizedBox(height: 24),
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
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildPeriodButton(TimePeriod.hours24, 'Today'),
          _buildPeriodButton(TimePeriod.days7, 'Week'),
          _buildPeriodButton(TimePeriod.days30, 'Month'),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard(List<FlSpot> chartData) {
    final values = chartData.map((spot) => spot.y).toList();
    final minValue = values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.isEmpty ? 100.0 : values.reduce((a, b) => a > b ? a : b);
    final padding = (maxValue - minValue) * 0.15;
    final minY = (minValue - padding).clamp(0.0, minValue);
    final maxY = maxValue + padding;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trend',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
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
                        color: Colors.black,
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(0),
                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade100,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
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
    if (systolicSpots.isEmpty && diastolicSpots.isEmpty) return _buildEmptyChartCard();

    final allValues = [...systolicSpots.map((e) => e.y), ...diastolicSpots.map((e) => e.y)];
    final minValue = allValues.isEmpty ? 0.0 : allValues.reduce((a, b) => a < b ? a : b);
    final maxValue = allValues.isEmpty ? 100.0 : allValues.reduce((a, b) => a > b ? a : b);
    final padding = (maxValue - minValue) * 0.15;
    final minY = (minValue - padding).clamp(0.0, minValue);
    final maxY = maxValue + padding;

    List<FlSpot> normalize(List<FlSpot> spots) =>
        spots.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.y)).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Row(
                children: [
                  _legendEntry(Colors.black, 'Sys'),
                  const SizedBox(width: 12),
                  _legendEntry(Colors.grey, 'Dia'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                titlesData: FlTitlesData(
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(0),
                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade100,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: normalize(systolicSpots),
                    isCurved: true,
                    color: Colors.black,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: normalize(diastolicSpots),
                    isCurved: true,
                    color: Colors.grey[400],
                    barWidth: 2.5,
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
          style: const TextStyle(fontSize: 12, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildEmptyChartCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, color: Colors.grey[300], size: 32),
          const SizedBox(height: 12),
          Text(
            'No data available',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleDataInfoCard(Map<String, dynamic> obs) {
    final dateTime = DateTime.tryParse(obs['effectiveDateTime'] as String? ?? '')?.toLocal() ?? DateTime.now();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Entry'.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _isBloodPressure
                    ? '${obs['systolic'] ?? '--'} / ${obs['diastolic'] ?? '--'}'
                    : '${obs['value'] ?? '--'}',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Text(
                (obs['unit'] as String?) ?? '',
                style: TextStyle(fontSize: 16, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            DateFormat('hh:mm a').format(dateTime),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(Map<String, dynamic> latestObs) {
    final latestDate = DateTime.tryParse(latestObs['effectiveDateTime'] as String? ?? '')?.toLocal() ?? DateTime.now();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest Reading'.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey[400],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _isBloodPressure
                    ? '${latestObs['systolic'] ?? '--'} / ${latestObs['diastolic'] ?? '--'}'
                    : '${latestObs['value'] ?? '--'}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  (latestObs['unit'] as String?) ?? '',
                  style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            DateFormat('MMMM dd, yyyy • hh:mm a').format(latestDate),
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (hasMore)
              Text(
                'Showing $displayedItems of $totalItems',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (observations.isEmpty)
          const Center(child: Text('No records found', style: TextStyle(color: Colors.grey)))
        else
          ...observations.map((obs) {
            final dateTime = DateTime.tryParse(obs['effectiveDateTime'] as String? ?? '')?.toLocal() ?? DateTime.now();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMM dd, yyyy').format(dateTime),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          DateFormat('hh:mm a').format(dateTime),
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _isBloodPressure
                            ? '${obs['systolic'] ?? '--'} / ${obs['diastolic'] ?? '--'}'
                            : '${obs['value'] ?? '--'}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      Text(
                        (obs['unit'] as String?) ?? '',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        if (hasMore)
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => ref.read(observationDetailProvider.notifier).incrementPage(),
              child: const Text('Load More', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  void _openVitalSignBottomSheet() {
    final title = widget.observationType.displayName;
    final unit = widget.observationType.standardUnit;
    final observationType = widget.observationType;

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

    final valueController = TextEditingController();
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 32),
            CustomTextField(
              label: 'Value ($unit)',
              controller: valueController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            ),
            const SizedBox(height: 24),
            CustomTextField(
              label: 'Notes',
              controller: notesController,
              maxLines: 2,
              hint: 'Optional notes',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _submitSingleObservation(
                  title,
                  observationType,
                  valueController,
                  notesController,
                ),
                child: Text('Save Measurement'.toUpperCase()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitBloodPressure(
    double systolic,
    double diastolic,
    String? notes,
  ) async {
    try {
      final observationService = ref.read(observationServiceProvider);
      final queueService = ref.read(offlineQueueServiceProvider);

      bool hasInternet = false;
      try {
        final result = await InternetAddress.lookup('8.8.8.8').timeout(const Duration(seconds: 2));
        hasInternet = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      } catch (_) {
        hasInternet = false;
      }

      if (!mounted) return;

      if (hasInternet) {
        try {
          final success = await observationService.submitBloodPressurePanelObservation(
                systolic: systolic,
                diastolic: diastolic,
                notes: notes,
                source: DataSource.manual,
              );
          if (!mounted) return;

          if (success) {
            ref.invalidate(latestObservationsProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Blood Pressure recorded successfully')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to record Blood Pressure')),
            );
          }
        } catch (e) {
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
            const SnackBar(content: Text('Blood Pressure saved offline. Will sync when online.')),
          );
        }
      } else {
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
          const SnackBar(content: Text('Blood Pressure saved offline. Will sync when online.')),
        );
      }

      if (mounted) {
        ref.read(observationDetailProvider.notifier).resetPage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a value')));
        return;
      }

      final observation = ObservationModel.create(
        type: observationType,
        value: double.tryParse(value) ?? 0.0,
        unit: observationType.standardUnit,
        source: DataSource.manual,
        notes: notes.isNotEmpty ? notes : null,
      );

      final observationService = ref.read(observationServiceProvider);
      final queueService = ref.read(offlineQueueServiceProvider);

      bool hasInternet = false;
      try {
        final result = await InternetAddress.lookup('8.8.8.8').timeout(const Duration(seconds: 2));
        hasInternet = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      } catch (_) {
        hasInternet = false;
      }

      if (!mounted) return;

      if (hasInternet) {
        try {
          final success = await observationService.submitObservation(observation);
          if (!mounted) return;

          if (success) {
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
            await queueService.queueObservation(observation);
            ref.invalidate(queuedObservationsProvider);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title saved offline. Will sync when online.')),
            );
          }
        } catch (e) {
          await queueService.queueObservation(observation);
          ref.invalidate(queuedObservationsProvider);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title saved offline. Will sync when online.')),
          );
        }
      } else {
        await queueService.queueObservation(observation);
        ref.invalidate(queuedObservationsProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title saved offline. Will sync when online.')),
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ref.read(observationDetailProvider.notifier).resetPage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }
}
