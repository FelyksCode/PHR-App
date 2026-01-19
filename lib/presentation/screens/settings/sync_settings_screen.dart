import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_service.dart';
import '../../../services/data_source_selection_service.dart';
import '../../../domain/entities/data_source_config.dart';
import '../../../providers/sync_job_provider.dart';
import '../../../providers/vendor_background_sync_provider.dart';
import '../../../data/models/backend_sync_status.dart';

const _syncIntervalKey = 'sync_interval_minutes';
// Default to 15 minutes, which is the minimum period
// supported by Android WorkManager for periodic tasks.
const int _defaultInterval = 15;

final intervalsProvider = Provider<List<int>>((ref) => [15, 30, 60, 120]);

final intervalLabelsProvider = Provider<List<String>>(
  (ref) => ['15 minutes (Minimum)', '30 minutes', '1 hour', '2 hours'],
);

final loadingProvider = StateProvider<bool>((ref) => true);
final selectedIntervalProvider = StateProvider<int>((ref) => _defaultInterval);

class SyncSettingsScreen extends ConsumerWidget {
  const SyncSettingsScreen({super.key});

  Future<void> _loadPrefs(WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    var stored = prefs.getInt(_syncIntervalKey) ?? _defaultInterval;

    // WorkManager on Android requires a minimum of 15 minutes
    // for periodic tasks. Migrate any older, shorter values
    // to the minimum supported interval.
    if (stored < 15) {
      stored = 15;
      await prefs.setInt(_syncIntervalKey, stored);
    }

    ref.read(selectedIntervalProvider.notifier).state = stored;

    // Best-effort backend sync status refresh (non-blocking)
    try {
      final apiService = ApiService();
      final isOnline = await apiService.isOnline();
      if (isOnline) {
        await ref.read(syncJobProvider.notifier).refreshStatus();
      }
    } catch (_) {
      // Ignore network or parsing errors and keep local default state
    }

    ref.read(loadingProvider.notifier).state = false;
  }

  Future<void> _updateSyncInterval(WidgetRef ref, int interval) async {
    ref.read(selectedIntervalProvider.notifier).state = interval;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_syncIntervalKey, interval);

    // Also (re)schedule vendor background sync with the selected interval.
    // Intervals are in minutes and are all >= 15, matching
    // Android WorkManager's minimum for periodic tasks.
    final frequency = Duration(minutes: interval);

    // Fire-and-forget scheduling; errors are handled inside the service.
    await ref
        .read(vendorBackgroundSyncServiceProvider)
        .schedulePeriodicVendorSync(frequency: frequency);
  }

  Future<void> _performSync(WidgetRef ref) async {
    try {
      final selectionService = DataSourceSelectionService();

      // Determine active vendor selection (UI metadata)
      final selectedConfig = await selectionService.getSelectedDataSource();

      if (!selectedConfig.isActive) {
        return;
      }

      final vendor = selectedConfig.type == DataSourceType.fitbit
          ? 'fitbit'
          : null;
      if (vendor == null) return;

      // Trigger backend-managed sync (202 Accepted). Provider polls /sync/status.
      await ref.read(syncJobProvider.notifier).triggerVendorSync(vendor);
    } catch (e) {
      // Non-blocking: provider surfaces errors
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(loadingProvider);
    final selectedInterval = ref.watch(selectedIntervalProvider);
    final intervals = ref.watch(intervalsProvider);
    final intervalLabels = ref.watch(intervalLabelsProvider);
    final syncJob = ref.watch(syncJobProvider);
    final statusType = syncJob.status?.status ?? BackendSyncStatusType.unknown;
    final statusText = statusType == BackendSyncStatusType.unknown
        ? 'unknown'
        : statusType.name;

    // Load prefs only once when loading is true
    if (loading) {
      _loadPrefs(ref);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          'Sync Settings',
          style: TextStyle(
            color: Color(0xFF1C1C1E),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        centerTitle: false,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Sync status card
                Container(
                  decoration: BoxDecoration(
                    color: _getSyncStatusColor(
                      statusType,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getSyncStatusColor(statusType),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getSyncStatusIcon(statusType),
                            color: _getSyncStatusColor(statusType),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status: $statusText',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _getSyncStatusColor(statusType),
                                  ),
                                ),
                                if (syncJob.error != null)
                                  Text(
                                    syncJob.error!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  )
                                else if (syncJob.status?.message != null &&
                                    syncJob.status!.message!.isNotEmpty)
                                  Text(
                                    syncJob.status!.message!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF8E8E93),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Manual sync button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: syncJob.isTriggering
                        ? null
                        : () => _performSync(ref),
                    icon: (syncJob.isTriggering || syncJob.isPolling)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.cloud_download),
                    label: Text(
                      (syncJob.isTriggering || syncJob.isPolling)
                          ? 'Syncing...'
                          : 'Sync Now',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Sync interval settings
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Auto Sync Interval',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1C1C1E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Choose how often your health data syncs automatically.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ...List.generate(
                        intervals.length,
                        (index) => Column(
                          children: [
                            ListTile(
                              onTap: () =>
                                  _updateSyncInterval(ref, intervals[index]),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: Icon(
                                selectedInterval == intervals[index]
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: selectedInterval == intervals[index]
                                    ? const Color(0xFF007AFF)
                                    : Colors.grey,
                              ),
                              title: Text(
                                intervalLabels[index],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1C1C1E),
                                ),
                              ),
                            ),
                            if (index < intervals.length - 1)
                              const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Color _getSyncStatusColor(BackendSyncStatusType type) {
    switch (type) {
      case BackendSyncStatusType.queued:
        return const Color(0xFFFF9500);
      case BackendSyncStatusType.running:
        return const Color(0xFF007AFF);
      case BackendSyncStatusType.success:
        return const Color(0xFF34C759);
      case BackendSyncStatusType.failed:
        return const Color(0xFFFF3B30);
      case BackendSyncStatusType.unknown:
        return const Color(0xFF8E8E93);
    }
  }

  IconData _getSyncStatusIcon(BackendSyncStatusType type) {
    switch (type) {
      case BackendSyncStatusType.queued:
        return Icons.schedule;
      case BackendSyncStatusType.running:
        return Icons.cloud_sync;
      case BackendSyncStatusType.success:
        return Icons.check_circle;
      case BackendSyncStatusType.failed:
        return Icons.error;
      case BackendSyncStatusType.unknown:
        return Icons.info;
    }
  }
}
