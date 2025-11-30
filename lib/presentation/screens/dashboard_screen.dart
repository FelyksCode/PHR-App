import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/observation_providers.dart';
import '../providers/condition_providers.dart';
import '../../providers/auth_provider.dart';
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
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good morning',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              'John Doe',
              style: TextStyle(
                color: Color(0xFF1C1C1E),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 70,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'actions') {
                // Navigate to actions page
                _showActionsBottomSheet(context);
              } else if (value == 'logout') {
                // Show confirmation dialog
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                ) ?? false;
                
                if (shouldLogout) {
                  ref.read(authProvider.notifier).logout();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'actions',
                child: Row(
                  children: [
                    Icon(Icons.apps),
                    SizedBox(width: 8),
                    Text('Quick Actions'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHealthSyncCard(context),
            const SizedBox(height: 20),
            _buildHealthStatistics(context, observationsState, conditionsState),
            const SizedBox(height: 20),
            _buildRecentDataSection(context, observationsState, conditionsState),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthSyncCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sync,
                  size: 24,
                  color: Color(0xFF007AFF),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health Data Sync',
                      style: TextStyle(
                        color: Color(0xFF1C1C1E),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sync from Health Connect/HealthKit',
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const HealthSyncScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Open Health Sync',
                style: TextStyle(
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

  Widget _buildHealthStatistics(BuildContext context, AsyncValue observationsState, AsyncValue conditionsState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Health Statistics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Vital Signs',
                value: observationsState.when(
                  data: (observations) => observations.length.toString(),
                  loading: () => '---',
                  error: (_, __) => '0',
                ),
                subtitle: 'Recorded',
                icon: Icons.favorite,
                color: const Color(0xFFFF3B30),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Conditions',
                value: conditionsState.when(
                  data: (conditions) => conditions.length.toString(),
                  loading: () => '---',
                  error: (_, __) => '0',
                ),
                subtitle: 'Reported',
                icon: Icons.report_problem,
                color: const Color(0xFFFF9500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Last Sync',
                value: '--',
                subtitle: 'Hours ago',
                icon: Icons.sync,
                color: const Color(0xFF007AFF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Data Points',
                value: observationsState.when(
                  data: (observations) => (observations.length * 6).toString(),
                  loading: () => '---',
                  error: (_, __) => '0',
                ),
                subtitle: 'Total',
                icon: Icons.analytics,
                color: const Color(0xFF34C759),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8E8E93),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
        ],
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
        const Text(
          'Recent Submissions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
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
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600]),
            const SizedBox(width: 12),
            const Text('No vital signs recorded yet'),
          ],
        ),
      );
    }

    final recentObservations = observations.take(3).toList();
    
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
                Icon(Icons.favorite, color: Colors.red[600]),
                const SizedBox(width: 8),
                const Text(
                  'Recent Vital Signs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
          ),
          ...recentObservations.map((obs) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFFF3B30).withOpacity(0.1),
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
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600]),
            const SizedBox(width: 12),
            const Text('No conditions reported yet'),
          ],
        ),
      );
    }

    final recentConditions = conditions.take(3).toList();
    
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
                const Text(
                  'Recent Conditions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
          ),
          ...recentConditions.map((condition) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFFF9500).withOpacity(0.1),
                  child: Icon(Icons.report_problem, color: Colors.orange[600], size: 20),
                ),
                title: Text(condition.description),
                subtitle: Text(DateFormat.yMd().add_Hm().format(condition.timestamp)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(condition.severity).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    condition.severity.displayName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  void _showActionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 20),
            _buildActionTile(
              context,
              title: 'Vital Signs',
              subtitle: 'Record measurements',
              icon: Icons.favorite,
              color: const Color(0xFFFF3B30),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const VitalSignsScreen(),
                  ),
                );
              },
            ),
            _buildActionTile(
              context,
              title: 'Conditions',
              subtitle: 'Report symptoms',
              icon: Icons.report_problem,
              color: const Color(0xFFFF9500),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ConditionScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1C1C1E),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF8E8E93),
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Color(0xFF8E8E93),
      ),
    );
  }

  Color _getSeverityColor(dynamic severity) {
    switch (severity.name) {
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
}