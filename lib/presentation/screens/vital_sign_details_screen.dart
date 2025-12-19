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
import 'package:phr_app/presentation/providers/vital_sign_config_provider.dart';
import '../widgets/common_widgets.dart';

class VitalSignDetailsScreen extends ConsumerStatefulWidget {
  final String vitalSignType;
  final List<Map<String, dynamic>> observations;

  const VitalSignDetailsScreen({
    super.key,
    required this.vitalSignType,
    required this.observations,
  });

  @override
  ConsumerState<VitalSignDetailsScreen> createState() => _VitalSignDetailsScreenState();
}

enum TimePeriod { hours24, days7, days30 }

class _VitalSignDetailsScreenState extends ConsumerState<VitalSignDetailsScreen> {
  late ScrollController _scrollController;
  TimePeriod _selectedPeriod = TimePeriod.days7;
  static const int _itemsPerPage = 20;
  int _currentPage = 1;
  late List<Map<String, dynamic>> _observations;

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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      setState(() {
        _currentPage++;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredObservations() {
    final now = DateTime.now();
    final Duration duration = switch (_selectedPeriod) {
      TimePeriod.hours24 => const Duration(hours: 24),
      TimePeriod.days7 => const Duration(days: 7),
      TimePeriod.days30 => const Duration(days: 30),
    };
    final cutoffDate = now.subtract(duration);

    return _observations.where((obs) {
      final dateTimeStr = obs['effectiveDateTime'] as String?;
      if (dateTimeStr == null) return false;
      final dateTime = DateTime.tryParse(dateTimeStr);
      if (dateTime == null) return false;
      return dateTime.isAfter(cutoffDate);
    }).toList();
  }

  List<FlSpot> _generateChartData(List<Map<String, dynamic>> filteredObs) {
    if (filteredObs.isEmpty) return [];

    // Sort by date
    final sorted = List<Map<String, dynamic>>.from(filteredObs)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a['effectiveDateTime'] as String? ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['effectiveDateTime'] as String? ?? '') ?? DateTime.now();
        return dateA.compareTo(dateB);
      });

    return sorted.asMap().entries.map((entry) {
      final value = entry.value['value'];
      final numValue = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0.0;
      return FlSpot(entry.key.toDouble(), numValue);
    }).toList();
  }

  String _getChartTitle() {
    return switch (_selectedPeriod) {
      TimePeriod.hours24 => 'Last 24 Hours',
      TimePeriod.days7 => 'Last 7 Days',
      TimePeriod.days30 => 'Last 30 Days',
    };
  }

  @override
  Widget build(BuildContext context) {
    final filteredObservations = _getFilteredObservations();
    final sortedObservations = List<Map<String, dynamic>>.from(filteredObservations)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a['effectiveDateTime'] as String? ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['effectiveDateTime'] as String? ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

    final totalItems = sortedObservations.length;
    final displayedItems = (_currentPage * _itemsPerPage).clamp(0, totalItems);
    final paginatedObservations = sortedObservations.take(displayedItems).toList();
    final hasMore = displayedItems < totalItems;

    final latestObs = sortedObservations.isNotEmpty ? sortedObservations.first : null;
    final chartData = _generateChartData(filteredObservations);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          widget.vitalSignType,
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
            if (chartData.isNotEmpty) _buildChartCard(chartData) else _buildEmptyChartCard(),
            const SizedBox(height: 20),
            _buildObservationsList(paginatedObservations, hasMore, totalItems, displayedItems),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openVitalSignBottomSheet(),
        backgroundColor: const Color(0xFF007AFF),
        child: const Icon(Icons.add, color: Colors.white),
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
          _buildPeriodButton(TimePeriod.hours24, '24H'),
          _buildPeriodButton(TimePeriod.days7, '7D'),
          _buildPeriodButton(TimePeriod.days30, '30D'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(TimePeriod period, String label) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = period;
            _currentPage = 1;
          });
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
    final minValue = values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.isEmpty ? 100.0 : values.reduce((a, b) => a > b ? a : b);
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
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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
                            final dateA = DateTime.tryParse(a['effectiveDateTime'] as String? ?? '') ?? DateTime.now();
                            final dateB = DateTime.tryParse(b['effectiveDateTime'] as String? ?? '') ?? DateTime.now();
                            return dateA.compareTo(dateB);
                          });
                          if (index < obs.length) {
                            final dateTime = DateTime.tryParse(obs[index]['effectiveDateTime'] as String? ?? '') ?? DateTime.now();
                            final dateFormat = _selectedPeriod == TimePeriod.hours24
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

  Widget _buildStatsCard(Map<String, dynamic> latestObs) {
    final effectiveDateTime = latestObs['effectiveDateTime'] as String?;
    final dateTime = effectiveDateTime != null
        ? DateTime.tryParse(effectiveDateTime) ?? DateTime.now()
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
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
          if (latestObs['notes'] != null && (latestObs['notes'] as String).isNotEmpty) ...[
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
                  'History (${observations.length})',
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
                  ? DateTime.tryParse(effectiveDateTime) ?? DateTime.now()
                  : DateTime.now();

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    if (obs['notes'] != null && (obs['notes'] as String).isNotEmpty) ...[
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
                trailing: obs['value'] != null
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
                    : null,
              );
            }),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentPage++;
                      });
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
    final vitalSignData = ref.read(vitalSignDataProvider(widget.vitalSignType));
    if (vitalSignData == null) {
      if (!mounted) return;
      // Show a quick hint when the provided vitalSignType is not supported
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot add this vital sign type.')),
      );
      return;
    }

    final title = vitalSignData['title'] as String;
    final subtitle = vitalSignData['subtitle'] as String;
    final icon = vitalSignData['icon'] as String;
    final unit = vitalSignData['unit'] as String;
    final type = vitalSignData['type'] as String;
    final observationType = vitalSignData['observationType'] as String;

    final valueController = TextEditingController();
    final diastolicController = TextEditingController();
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
                            icon,
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
                              subtitle,
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
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFF8E8E93),
                        ),
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
                              if (type == 'dual' && title == 'Blood Pressure') ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomTextField(
                                        label: 'Systolic ($unit)',
                                        controller: valueController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CustomTextField(
                                        label: 'Diastolic ($unit)',
                                        controller: diastolicController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                CustomTextField(
                                  label: '$title ($unit)',
                                  controller: valueController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: title == 'Heart Rate'
                                      ? [FilteringTextInputFormatter.digitsOnly]
                                      : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                ),
                              ],
                              const SizedBox(height: 16),
                              CustomTextField(
                                label: 'Notes (Optional)',
                                controller: notesController,
                                maxLines: 3,
                                hint: 'Add any additional notes about this reading...',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => _submitVitalSign(title, observationType, valueController, diastolicController, notesController),
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


  void _submitVitalSign(
    String title,
    String observationType,
    TextEditingController valueController,
    TextEditingController diastolicController,
    TextEditingController notesController,
  ) async {
    try {
      final value = valueController.text.trim();
      final diastolic = diastolicController.text.trim();
      final notes = notesController.text.trim();

      if (value.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a value')),
        );
        return;
      }

      if (observationType == 'blood_pressure' && diastolic.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter both systolic and diastolic values')),
        );
        return;
      }

      // Create observation entity/entities
      List<ObservationEntity?> observations = [];

      if (observationType == 'blood_pressure') {
        // For blood pressure, create both systolic and diastolic
        observations.add(ObservationModel.create(
          type: ObservationType.bloodPressureSystolic,
          value: double.tryParse(value) ?? 0.0,
          unit: 'mmHg',
          notes: notes.isNotEmpty ? notes : null,
        ));
        observations.add(ObservationModel.create(
          type: ObservationType.bloodPressureDiastolic,
          value: double.tryParse(diastolic) ?? 0.0,
          unit: 'mmHg',
          notes: notes.isNotEmpty ? notes : null,
        ));
      } else {
        final obsType = switch (observationType) {
          'body_weight' => ObservationType.bodyWeight,
          'body_height' => ObservationType.bodyHeight,
          'body_temperature' => ObservationType.bodyTemperature,
          'heart_rate' => ObservationType.heartRate,
          'oxygen_saturation' => ObservationType.oxygenSaturation,
          _ => ObservationType.bodyWeight,
        };

        observations.add(ObservationModel.create(
          type: obsType,
          value: double.tryParse(value) ?? 0.0,
          unit: _getUnitForType(title),
          notes: notes.isNotEmpty ? notes : null,
        ));
      }

      // Filter out null observations
      final validObservations = observations.whereType<ObservationEntity>().toList();

      if (validObservations.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error creating observation')),
        );
        return;
      }

      // Get services
      final observationService = ref.read(observationServiceProvider);
      final queueService = ref.read(offlineQueueServiceProvider);

      // Check actual internet connectivity
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
          // Try to submit online
          final success = await observationService.submitMultipleObservations(validObservations);
          if (!mounted) return;
          if (success) {
            // Add new observations to local list
            for (final obs in validObservations) {
              _observations.insert(0, {
                'effectiveDateTime': obs.timestamp.toIso8601String(),
                'value': obs.value,
                'unit': obs.unit,
                'notes': obs.notes,
              });
            }
            // Refresh provider to update history
            ref.invalidate(latestObservationsProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title submitted successfully')),
            );
          } else {
            // Submission failed, queue for later
            for (final obs in validObservations) {
              await queueService.queueObservation(obs);
            }
            ref.invalidate(queuedObservationsProvider);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title saved offline. Will sync when online.')),
            );
          }
        } catch (e) {
          // Network error - queue the data
          for (final obs in validObservations) {
            await queueService.queueObservation(obs);
          }
          ref.invalidate(queuedObservationsProvider);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title saved offline. Will sync when online.')),
          );
        }
      } else {
        // No internet - queue directly
        for (final obs in validObservations) {
          await queueService.queueObservation(obs);
        }
        ref.invalidate(queuedObservationsProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title saved offline. Will sync when online.')),
        );
      }

      if (mounted) {
        Navigator.pop(context);
        // Refresh the list
        setState(() {
          _currentPage = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  String _getUnitForType(String title) {
    return switch (title) {
      'Body Weight' => 'kg',
      'Body Height' => 'cm',
      'Body Temperature' => '°C',
      'Heart Rate' => 'bpm',
      'Oxygen Saturation' => '%',
      _ => '',
    };
  }
}
