import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/observation_providers.dart';
import '../providers/condition_providers.dart';
import 'vital_signs_screen.dart';
import 'condition_screen.dart';
import 'health_sync_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final observationsState = ref.watch(observationsProvider);
    final conditionsState = ref.watch(conditionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Health Record'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(context),
            const SizedBox(height: 20),
            _buildActionCards(context),
            const SizedBox(height: 20),
            _buildRecentDataSection(context, observationsState, conditionsState),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.health_and_safety,
              size: 40,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            const SizedBox(height: 12),
            Text(
              'Your Health Dashboard',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track your vital signs and health conditions with FHIR-compliant data',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCards(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                title: 'Vital Signs',
                subtitle: 'Record measurements',
                icon: Icons.favorite,
                color: Colors.red,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const VitalSignsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                title: 'Conditions',
                subtitle: 'Report symptoms',
                icon: Icons.report_problem,
                color: Colors.orange,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ConditionScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Health sync action card (full width)
        _buildActionCard(
          context,
          title: 'Health Data Sync',
          subtitle: 'Sync from Health Connect/HealthKit',
          icon: Icons.sync,
          color: Colors.blue,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const HealthSyncScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentDataSection(
    BuildContext context,
    AsyncValue observationsState,
    AsyncValue conditionsState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Submissions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        observationsState.when(
          data: (observations) => _buildObservationsList(context, observations),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('Error loading observations: $error'),
        ),
        const SizedBox(height: 16),
        conditionsState.when(
          data: (conditions) => _buildConditionsList(context, conditions),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('Error loading conditions: $error'),
        ),
      ],
    );
  }

  Widget _buildObservationsList(BuildContext context, List observations) {
    if (observations.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey[600]),
              const SizedBox(width: 12),
              const Text('No vital signs recorded yet'),
            ],
          ),
        ),
      );
    }

    final recentObservations = observations.take(3).toList();
    
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.favorite, color: Colors.red[600]),
                const SizedBox(width: 8),
                Text(
                  'Recent Vital Signs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...recentObservations.map((obs) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  child: Icon(Icons.favorite, color: Colors.red[600], size: 20),
                ),
                title: Text(obs.type.displayName),
                subtitle: Text(DateFormat.yMd().add_Hm().format(obs.timestamp)),
                trailing: Text(
                  '${obs.value} ${obs.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildConditionsList(BuildContext context, List conditions) {
    if (conditions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey[600]),
              const SizedBox(width: 12),
              const Text('No conditions reported yet'),
            ],
          ),
        ),
      );
    }

    final recentConditions = conditions.take(3).toList();
    
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.report_problem, color: Colors.orange[600]),
                const SizedBox(width: 8),
                Text(
                  'Recent Conditions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...recentConditions.map((condition) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  child: Icon(Icons.report_problem, color: Colors.orange[600], size: 20),
                ),
                title: Text(condition.description),
                subtitle: Text(DateFormat.yMd().add_Hm().format(condition.timestamp)),
                trailing: Chip(
                  label: Text(
                    condition.severity.displayName,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: _getSeverityColor(condition.severity).withOpacity(0.1),
                ),
              )),
        ],
      ),
    );
  }

  Color _getSeverityColor(dynamic severity) {
    switch (severity.name) {
      case 'mild':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'severe':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}