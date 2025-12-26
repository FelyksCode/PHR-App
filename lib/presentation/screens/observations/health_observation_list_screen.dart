import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/health_observation_provider.dart';
import 'observation_input_screen.dart';
import '../vendors/vendor_selection_screen.dart';

class HealthObservationListScreen extends ConsumerStatefulWidget {
  const HealthObservationListScreen({super.key});

  @override
  ConsumerState<HealthObservationListScreen> createState() => _HealthObservationListScreenState();
}

class _HealthObservationListScreenState extends ConsumerState<HealthObservationListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<Map<String, String>> _filters = const [
    {'key': 'all', 'label': 'All'},
    {'key': 'heart_rate', 'label': 'Heart Rate'},
    {'key': 'spo2', 'label': 'SpO2'},
    {'key': 'body_weight', 'label': 'Body Weight'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final filter = _filters[_tabController.index]['key']!;
      ref.read(healthObservationListProvider.notifier).setFilter(filter);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(healthObservationListProvider);
    final notifier = ref.read(healthObservationListProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wearable Observations'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Data sources',
            icon: const Icon(Icons.link_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VendorSelectionScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF007AFF),
          unselectedLabelColor: const Color(0xFF8E8E93),
          indicatorColor: const Color(0xFF007AFF),
          tabs: _filters.map((f) => Tab(text: f['label'])).toList(),
        ),
      ),
      backgroundColor: const Color(0xFFFAFAFA),
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha:0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha:0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            if (state.items.isEmpty && !state.isLoading)
              _EmptyState(onManualInputTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ObservationInputScreen()),
                );
              }),
            ...state.items.map((item) => _ObservationTile(item.display, item.value, item.unit, item.effectiveDateTime)),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (state.hasMore && !state.isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  onPressed: notifier.loadMore,
                  child: const Text('Load more'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ObservationTile extends StatelessWidget {
  const _ObservationTile(this.display, this.value, this.unit, this.date);

  final String display;
  final double? value;
  final String? unit;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final formattedDate = date != null ? DateFormat('MMM d, yyyy • HH:mm').format(date!) : 'Date unknown';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.insights, color: Color(0xFF007AFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formattedDate,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value?.toStringAsFixed(1) ?? '--',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF007AFF),
                ),
              ),
              if (unit != null)
                Text(
                  unit!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onManualInputTap});

  final VoidCallback onManualInputTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
      ),
      child: Column(
        children: [
          Icon(Icons.watch_off, color: Colors.grey[600], size: 48),
          const SizedBox(height: 12),
          const Text(
            'No wearable data. Use manual input or connect Fitbit.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Color(0xFF1C1C1E), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onManualInputTap,
            child: const Text('Add manual observation'),
          ),
        ],
      ),
    );
  }
}
