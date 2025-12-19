import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/observation_providers.dart';
import '../providers/condition_providers.dart';
import 'vital_signs_screen_wrapper.dart';
import 'condition_screen.dart';
import 'observations_history_screen.dart';
import 'conditions_history_screen.dart';

class HealthHistoryScreen extends ConsumerWidget {
  const HealthHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestObservationsState = ref.watch(latestObservationsProvider);
    final latestConditionsState = ref.watch(latestConditionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          'Health History',
          style: TextStyle(
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
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'vital_signs') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const VitalSignsScreenWrapper(),
                  ),
                );
              } else if (value == 'conditions') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ConditionScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'vital_signs',
                child: Row(
                  children: [
                    Icon(Icons.favorite, color: Color(0xFFFF3B30)),
                    SizedBox(width: 8),
                    Text('Record Vital Signs'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'conditions',
                child: Row(
                  children: [
                    Icon(Icons.report_problem, color: Color(0xFFFF9500)),
                    SizedBox(width: 8),
                    Text('Report Condition'),
                  ],
                ),
              ),
            ],
            icon: const Icon(
              Icons.add,
              color: Color(0xFF007AFF),
            ),
            tooltip: 'Quick Actions',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.refresh(latestObservationsProvider);
          ref.refresh(latestConditionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHistoryCard(
                context,
                title: 'Vital Signs History',
                subtitle: latestObservationsState.when(
                  data: (observations) => '${observations.length} recorded',
                  loading: () => 'Loading...',
                  error: (_, __) => 'Error loading data',
                ),
                icon: Icons.favorite,
                color: const Color(0xFFFF3B30),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ObservationsHistoryScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildHistoryCard(
                context,
                title: 'Conditions History',
                subtitle: latestConditionsState.when(
                  data: (conditions) => '${conditions.length} reported',
                  loading: () => 'Loading...',
                  error: (_, __) => 'Error loading data',
                ),
                icon: Icons.report_problem,
                color: const Color(0xFFFF9500),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ConditionsHistoryScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFF8E8E93),
            ),
          ],
        ),
      ),
    );
  }
}