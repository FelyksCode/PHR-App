import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phr_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:phr_app/presentation/providers/connectivity_provider.dart';
import 'package:phr_app/providers/auth_provider.dart';
import 'package:phr_app/providers/data_source_providers.dart';
import 'package:phr_app/domain/entities/data_source_config.dart';
import 'package:phr_app/providers/vendor_integration_provider.dart';
import 'package:phr_app/providers/vendor_last_sync_provider.dart';
import '../../providers/observation_providers.dart';
import '../../providers/condition_providers.dart';
import '../../providers/health_status_provider.dart';
import '../observations/observation_input_screen.dart';
import '../conditions/condition_screen.dart';
import '../observations/observations_history_screen.dart';
import '../conditions/conditions_history_screen.dart';
import '../settings/settings_screen.dart';
import '../vendors/vendor_selection_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final latestObservationsState = ref.watch(latestObservationsProvider);
    final latestConditionsState = ref.watch(latestConditionsProvider);
    final authState = ref.watch(authProvider);
    final fitbitState = ref.watch(vendorIntegrationProvider('fitbit'));
    final fitbitNotifier = ref.read(
      vendorIntegrationProvider('fitbit').notifier,
    );
    final vendorLastSync = ref.watch(vendorLastSyncProvider);
    final dataSourceConfigState = ref.watch(dataSourceConfigProvider);
    final isOnline = ref.watch(connectivityProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good morning,',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              authState.user?.name ?? l10n.userFallback,
              style: const TextStyle(
                color: Color(0xFF2C3E50),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 80,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
              icon: const Icon(Icons.settings_rounded, color: Color(0xFF2ECC71)),
              tooltip: l10n.settings,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(latestObservationsProvider);
          ref.invalidate(latestConditionsProvider);
          ref.invalidate(healthStatusProvider);
          await fitbitNotifier.refreshStatus();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isOnline) ...[
                _buildOfflineBanner(),
                const SizedBox(height: 16),
              ],
              // Vendor integration card - aware of selected data source
              dataSourceConfigState.when(
                data: (config) => _buildFitbitStatusCard(
                  context,
                  fitbitState,
                  fitbitNotifier,
                  config,
                  vendorLastSync,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _buildFitbitStatusCard(
                  context,
                  fitbitState,
                  fitbitNotifier,
                  DataSourceConfig.defaultConfig,
                  vendorLastSync,
                ),
              ),
              const SizedBox(height: 20),
              _buildHealthStatistics(
                context,
                l10n,
                latestObservationsState,
                latestConditionsState,
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildFitbitStatusCard(
    BuildContext context,
    VendorIntegrationState state,
    VendorIntegrationNotifier notifier,
    DataSourceConfig dataSourceConfig,
    AsyncValue<DateTime?> vendorLastSync,
  ) {
    final connected = state.status?.isConnected == true;
    final isBusy = state.isLoading || state.isSelecting;
    final lastSyncValue = vendorLastSync.whenOrNull(data: (v) => v);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.blue.shade50.withValues(alpha: 0.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.blue.shade100.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sync_rounded, color: Color(0xFF3498DB), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wearable Sync',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    if (lastSyncValue != null)
                      Text(
                        'Last sync: ${DateFormat('MMM d, HH:mm').format(lastSyncValue)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: connected ? const Color(0xFFE8F8F0) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  connected ? 'Active' : 'Setup Required',
                  style: TextStyle(
                    color: connected ? const Color(0xFF27AE60) : const Color(0xFFE74C3C),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: isBusy
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const VendorSelectionScreen(),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3498DB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(isBusy ? 'Syncing...' : 'Manage Integration'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStatistics(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue latestObservationsState,
    AsyncValue latestConditionsState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Health Journey',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2C3E50),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton.icon(
                onPressed: () => _showActionsBottomSheet(context, l10n),
                icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF2ECC71)),
                label: const Text(
                  'Add',
                  style: TextStyle(
                    color: Color(0xFF2ECC71),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildThematicStatCard(
          context,
          title: 'Vitals & Records',
          subtitle: 'Track your body metrics',
          value: latestObservationsState.when(
            data: (obs) => (obs as List).length.toString(),
            loading: () => '...',
            error: (_, __) => '0',
          ),
          icon: Icons.favorite_rounded,
          color: const Color(0xFF2ECC71),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ObservationsHistoryScreen(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildThematicStatCard(
          context,
          title: 'Symptoms & Conditions',
          subtitle: 'Monitor your health status',
          value: latestConditionsState.when(
            data: (cond) => (cond as List).length.toString(),
            loading: () => '...',
            error: (_, __) => '0',
          ),
          icon: Icons.healing_rounded,
          color: const Color(0xFF3498DB),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ConditionsHistoryScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildThematicStatCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showActionsBottomSheet(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Record Health Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 24),
            _buildActionTile(
              context,
              title: 'Vital Sign',
              subtitle: 'Weight, Heart Rate, BP, etc.',
              icon: Icons.favorite_rounded,
              color: const Color(0xFF2ECC71),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ObservationInputScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              context,
              title: 'Symptoms',
              subtitle: 'Report how you feel',
              icon: Icons.healing_rounded,
              color: const Color(0xFF3498DB),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ConditionScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
          SizedBox(width: 12),
          Text(
            'Offline Mode - Local data only',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

}
