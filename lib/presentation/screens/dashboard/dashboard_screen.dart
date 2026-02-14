import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phr_app/data/models/notification_reminder.dart';
import 'package:phr_app/data/models/reminder_history_record.dart';
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
import '../../providers/notification_reminders_provider.dart';
import '../../providers/reminder_history_provider.dart';
import '../observations/observation_input_screen.dart';
import '../conditions/condition_screen.dart';
import '../observations/observations_history_screen.dart';
import '../conditions/conditions_history_screen.dart';
import '../settings/settings_screen.dart';
import '../vendors/vendor_selection_screen.dart';
import '../notifications/notifications_screen.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Hello, ${authState.user?.name ?? l10n.userFallback}',
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
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
            tooltip: l10n.settings,
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
              _buildReminderCard(context, ref, l10n),
              const SizedBox(height: 24),
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

  Widget _buildReminderCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final reminders = ref.watch(notificationRemindersProvider);
    final historyNotifier = ref.read(reminderHistoryProvider.notifier);
    final today = DateTime.now();

    NotificationReminder? nextReminder;
    DateTime? nextReminderDate;

    for (final reminder in reminders) {
      if (!reminder.enabled) continue;
      if (reminder.isDueOn(today) && !reminder.isCompletedOn(today)) {
        nextReminder = reminder;
        nextReminderDate = today;
        break;
      }
    }

    if (nextReminder == null) {
      DateTime closestDate = DateTime.now().add(const Duration(days: 365));
      for (final reminder in reminders) {
        if (!reminder.enabled) continue;
        final nextDate = _findNextReminderDate(reminder, today);
        if (nextDate != null && nextDate.isBefore(closestDate)) {
          closestDate = nextDate;
          nextReminder = reminder;
          nextReminderDate = nextDate;
        }
      }
    }

    final hasReminder = nextReminder != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: hasReminder
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.notifications_outlined, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nextReminder.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${nextReminderDate == today ? 'Today' : 'Upcoming'} • ${nextReminder.time.format(context)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (nextReminderDate == today)
                  TextButton(
                    onPressed: () {
                      final reminder = nextReminder;
                      if (reminder != null && nextReminderDate != null) {
                        final completedReminder = reminder.completeOn(
                          nextReminderDate,
                        );
                        ref
                            .read(notificationRemindersProvider.notifier)
                            .updateReminder(completedReminder);
                        final dateKey =
                            '${nextReminderDate.year.toString().padLeft(4, '0')}-${nextReminderDate.month.toString().padLeft(2, '0')}-${nextReminderDate.day.toString().padLeft(2, '0')}';
                        historyNotifier.add(
                          ReminderHistoryRecord(
                            id: '${reminder.id}-$dateKey',
                            reminderId: reminder.id,
                            title: reminder.title,
                            time: reminder.time,
                            dateKey: dateKey,
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.notifications_none, size: 20),
                const SizedBox(width: 12),
                const Text(
                  'No reminders set',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final newReminder =
                        await showModalBottomSheet<NotificationReminder>(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => const CreateReminderDialog(),
                        );
                    if (newReminder != null) {
                      ref
                          .read(notificationRemindersProvider.notifier)
                          .addReminder(newReminder);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_outlined, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fitbit Sync',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (lastSyncValue != null)
                      Text(
                        'Synced ${DateFormat('MMM d, HH:mm').format(lastSyncValue)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: connected ? Colors.grey.shade100 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  connected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: connected ? Colors.black : Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isBusy
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const VendorSelectionScreen(),
                        ),
                      );
                    },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(isBusy ? 'Loading...' : 'Manage Integration'),
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
              'Health Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            TextButton.icon(
              onPressed: () => _showActionsBottomSheet(context, l10n),
              icon: const Icon(Icons.add, size: 18, color: Colors.black),
              label: const Text(
                'Add',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSimplifiedStatCard(
          context,
          title: 'Observations',
          value: latestObservationsState.when(
            data: (obs) => obs.length.toString(),
            loading: () => '...',
            error: (_, __) => '0',
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ObservationsHistoryScreen(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildSimplifiedStatCard(
          context,
          title: 'Conditions',
          value: latestConditionsState.when(
            data: (cond) => cond.length.toString(),
            loading: () => '...',
            error: (_, __) => '0',
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ConditionsHistoryScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildSimplifiedStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
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
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.quickActions,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 20),
            _buildActionTile(
              context,
              title: l10n.vitalSigns,
              subtitle: l10n.recordMeasurements,
              icon: Icons.favorite,
              color: const Color(0xFFFF3B30),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ObservationInputScreen(),
                  ),
                );
              },
            ),
            _buildActionTile(
              context,
              title: l10n.conditionsLabel,
              subtitle: l10n.reportSymptoms,
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
          color: color.withValues(alpha: 0.1),
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
        style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Color(0xFF8E8E93),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text(
            'Offline Mode - Using cached data',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Find the next date when a reminder is due based on its recurrence interval.
  DateTime? _findNextReminderDate(
    NotificationReminder reminder,
    DateTime today,
  ) {
    final recurrence = reminder.interval ?? 'Daily';

    if (recurrence == 'Daily') {
      // For daily reminders, find the next day
      var nextDate = today.add(const Duration(days: 1));
      // Skip past dates if already completed
      while (reminder.isCompletedOn(nextDate)) {
        nextDate = nextDate.add(const Duration(days: 1));
      }
      return nextDate;
    }

    if (recurrence == 'Weekly') {
      // For weekly reminders, find the next occurrence of the target weekday
      final targetWeekday = reminder.weekDay ?? 1;
      var nextDate = today.add(const Duration(days: 1));

      while (nextDate.weekday != targetWeekday ||
          reminder.isCompletedOn(nextDate)) {
        nextDate = nextDate.add(const Duration(days: 1));
        if (nextDate.difference(today).inDays > 365) {
          return null; // Safety limit
        }
      }
      return nextDate;
    }

    if (recurrence == 'Monthly') {
      // For monthly reminders, find the next occurrence of the target day
      final targetDay = reminder.monthDay ?? 1;
      var nextDate = DateTime(today.year, today.month, targetDay);

      if (nextDate.isBefore(today) ||
          (nextDate == today && reminder.isCompletedOn(today))) {
        // Move to next month
        nextDate = DateTime(today.year, today.month + 1, targetDay);
      }

      // Handle month overflow
      if (nextDate.month > 12) {
        nextDate = DateTime(nextDate.year + 1, 1, targetDay);
      }

      // Skip if already completed
      while (reminder.isCompletedOn(nextDate)) {
        nextDate = DateTime(nextDate.year, nextDate.month + 1, targetDay);
        if (nextDate.month > 12) {
          nextDate = DateTime(nextDate.year + 1, 1, targetDay);
        }
        if (nextDate.difference(today).inDays > 365) {
          return null; // Safety limit
        }
      }
      return nextDate;
    }

    return null;
  }
}
