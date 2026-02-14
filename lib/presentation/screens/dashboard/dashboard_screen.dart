import 'package:flutter/material.dart';
import 'package:phr_app/core/config/app_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phr_app/data/models/notification_reminder.dart';
import 'package:phr_app/data/models/reminder_history_record.dart';
import 'package:phr_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:phr_app/presentation/providers/dashboard_calendar_provider.dart';
import 'package:phr_app/presentation/providers/synthetic_simulation_provider.dart';
import 'package:phr_app/providers/auth_provider.dart';
import 'package:phr_app/providers/data_source_providers.dart';
import 'package:phr_app/domain/entities/data_source_config.dart';
import 'package:phr_app/providers/vendor_integration_provider.dart';
import 'package:phr_app/providers/vendor_last_sync_provider.dart';
import 'package:phr_app/simulation/simulation_profile.dart';
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
import '../shared/day_details_screen.dart';
import '../vendors/vendor_selection_screen.dart';
import '../notifications/notifications_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final latestObservationsState = ref.watch(latestObservationsProvider);
    final latestConditionsState = ref.watch(latestConditionsProvider);
    final healthStatusState = ref.watch(healthStatusProvider);
    final authState = ref.watch(authProvider);
    final fitbitState = ref.watch(vendorIntegrationProvider('fitbit'));
    final fitbitNotifier = ref.read(
      vendorIntegrationProvider('fitbit').notifier,
    );
    final vendorLastSync = ref.watch(vendorLastSyncProvider);
    final calendarState = ref.watch(dashboardCalendarProvider);
    final calendarNotifier = ref.read(dashboardCalendarProvider.notifier);
    final dataSourceConfigState = ref.watch(dataSourceConfigProvider);
    final simulationState = ref.watch(syntheticSimulationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.greetingMorning,
              style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              authState.user?.name ?? l10n.userFallback,
              style: const TextStyle(
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
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings, color: Color(0xFF8E8E93)),
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConnectivityBanner(healthStatusState, l10n),
              const SizedBox(height: 16),
              if (AppConfig.isSimulation) ...[
                _buildSyntheticSimulationButton(
                  context,
                  ref,
                  simulationState,
                ),
                const SizedBox(height: 16),
              ],
              _buildCalendarView(context, ref, calendarState, calendarNotifier),
              const SizedBox(height: 16),
              _buildReminderCard(context, ref, l10n),
              const SizedBox(height: 20),
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

  Widget _buildSyntheticSimulationButton(
    BuildContext context,
    WidgetRef ref,
    SyntheticSimulationState simulationState,
  ) {
    final isRunning = simulationState.status == SyntheticSimulationStatus.running;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: isRunning
            ? null
            : () async {
                await _startSyntheticSimulationFlow(context, ref);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007AFF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        icon: isRunning
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.science_outlined),
        label: const Text(
          'Generate Synthetic Simulated Data',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _startSyntheticSimulationFlow(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final selectedProfile = await _pickSimulationProfile(context);
    if (!context.mounted) return;
    if (selectedProfile == null) return;

    while (true) {
      if (!context.mounted) return;
      final ok = await _runSyntheticSimulationWithProgressDialog(
        context,
        ref,
        selectedProfile,
      );

      if (!context.mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Synthetic patient data generated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh dashboard-relevant data.
        ref.invalidate(latestObservationsProvider);
        ref.invalidate(latestConditionsProvider);
        ref.invalidate(healthStatusProvider);
        return;
      }

      final state = ref.read(syntheticSimulationProvider);
      final message = state.errorMessage ?? 'Unknown error';

      final retry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Simulation failed'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );

      if (!context.mounted) return;
      if (retry != true) return;
    }
  }

  Future<SimulationProfile?> _pickSimulationProfile(
    BuildContext context,
  ) async {
    SimulationProfile? selection;

    return showModalBottomSheet<SimulationProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select simulation profile',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will generate synthetic symptom + condition data for research/testing only.',
                      style: TextStyle(color: Color(0xFF8E8E93)),
                    ),
                    const SizedBox(height: 12),
                    RadioGroup<SimulationProfile>(
                      groupValue: selection,
                      onChanged: (v) => setState(() => selection = v),
                      child: Column(
                        children: [
                          for (final profile in SimulationProfile.all)
                            RadioListTile<SimulationProfile>(
                              value: profile,
                              title: Text(profile.displayName),
                              subtitle: Text(_profileDescription(profile)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selection == null
                                ? null
                                : () => Navigator.of(context).pop(selection),
                            child: const Text('Confirm'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _profileDescription(SimulationProfile profile) {
    switch (profile.profileId) {
      case 'stable_outpatient':
        return 'Low symptom burden, mild severity baseline.';
      case 'treatment_side_effect':
        return 'Moderate symptoms with notable treatment side-effects.';
      case 'high_risk_outpatient':
        return 'Higher symptom burden and more severe presentations.';
      default:
        return 'Synthetic outpatient profile.';
    }
  }

  Future<bool> _runSyntheticSimulationWithProgressDialog(
    BuildContext context,
    WidgetRef ref,
    SimulationProfile profile,
  ) async {
    ref.read(syntheticSimulationProvider.notifier).reset();
    ref.read(syntheticSimulationProvider.notifier).run(profile: profile);

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _SyntheticSimulationProgressDialog(),
    );

    return ok == true;
  }

  Widget _buildCalendarView(
    BuildContext context,
    WidgetRef ref,
    DashboardCalendarState calendarState,
    DashboardCalendarNotifier calendarNotifier,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
      ),
      child: Column(
        children: [
          // Header with month/year and toggle
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        calendarNotifier.navigateToPreviousPeriod();
                      },
                      icon: const Icon(Icons.chevron_left, size: 24),
                      color: const Color(0xFF007AFF),
                    ),
                    Text(
                      calendarState.isMonthView
                          ? DateFormat(
                              'MMMM yyyy',
                            ).format(calendarState.focusedDate)
                          : 'Week of ${DateFormat('MMM dd').format(calendarState.focusedDate.subtract(Duration(days: calendarState.focusedDate.weekday - 1)))}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        calendarNotifier.navigateToNextPeriod();
                      },
                      icon: const Icon(Icons.chevron_right, size: 24),
                      color: const Color(0xFF007AFF),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    calendarNotifier.toggleViewMode();
                  },
                  icon: Icon(
                    calendarState.isMonthView
                        ? Icons.calendar_view_week
                        : Icons.calendar_month,
                    size: 24,
                  ),
                  color: const Color(0xFF007AFF),
                  tooltip: calendarState.isMonthView
                      ? 'Week View'
                      : 'Month View',
                ),
              ],
            ),
          ),
          // Calendar grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: calendarState.isMonthView
                ? _buildMonthCalendar(ref, calendarState, calendarNotifier)
                : _buildWeekCalendar(ref, calendarState, calendarNotifier),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildWeekCalendar(
    WidgetRef ref,
    DashboardCalendarState calendarState,
    DashboardCalendarNotifier calendarNotifier,
  ) {
    final today = DateTime.now();
    final startOfWeek = calendarState.focusedDate.subtract(
      Duration(days: calendarState.focusedDate.weekday - 1),
    );
    final weekDays = List.generate(
      7,
      (index) => startOfWeek.add(Duration(days: index)),
    );

    return Column(
      children: [
        // Day names
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        // Week days
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDays.map((date) {
            final isSelected =
                date.day == calendarState.selectedDate.day &&
                date.month == calendarState.selectedDate.month &&
                date.year == calendarState.selectedDate.year;
            final isToday =
                date.day == today.day &&
                date.month == today.month &&
                date.year == today.year;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  calendarNotifier.selectDate(date);
                  Navigator.of(ref.context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          DayDetailsScreen(selectedDate: date),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF007AFF)
                        : isToday
                        ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected || isToday
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : isToday
                            ? const Color(0xFF007AFF)
                            : const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMonthCalendar(
    WidgetRef ref,
    DashboardCalendarState calendarState,
    DashboardCalendarNotifier calendarNotifier,
  ) {
    final today = DateTime.now();
    final firstDayOfMonth = DateTime(
      calendarState.focusedDate.year,
      calendarState.focusedDate.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      calendarState.focusedDate.year,
      calendarState.focusedDate.month + 1,
      0,
    );
    final startingWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    final days = <Widget>[];

    // Day names
    days.add(
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
            .map(
              (day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );

    days.add(const SizedBox(height: 8));

    // Calendar days
    final weeks = <List<Widget>>[];
    var currentWeek = <Widget>[];

    // Empty cells before first day
    for (var i = 1; i < startingWeekday; i++) {
      currentWeek.add(const Expanded(child: SizedBox(height: 40)));
    }

    // Days of month
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(
        calendarState.focusedDate.year,
        calendarState.focusedDate.month,
        day,
      );
      final isSelected =
          date.day == calendarState.selectedDate.day &&
          date.month == calendarState.selectedDate.month &&
          date.year == calendarState.selectedDate.year;
      final isToday =
          date.day == today.day &&
          date.month == today.month &&
          date.year == today.year;

      currentWeek.add(
        Expanded(
          child: GestureDetector(
            onTap: () {
              calendarNotifier.selectDate(date);
              Navigator.of(ref.context).push(
                MaterialPageRoute(
                  builder: (context) => DayDetailsScreen(selectedDate: date),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF007AFF)
                    : isToday
                    ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: isSelected
                        ? Colors.white
                        : isToday
                        ? const Color(0xFF007AFF)
                        : const Color(0xFF1C1C1E),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      if ((startingWeekday + day - 1) % 7 == 0 || day == daysInMonth) {
        // Fill remaining cells in last week
        while (currentWeek.length < 7) {
          currentWeek.add(const Expanded(child: SizedBox(height: 40)));
        }
        weeks.add(List.from(currentWeek));
        currentWeek.clear();
      }
    }

    // Build weeks
    for (var week in weeks) {
      days.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: week,
          ),
        ),
      );
    }

    return Column(children: days);
  }

  Widget _buildReminderCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final reminders = ref.watch(notificationRemindersProvider);
    final historyNotifier = ref.read(reminderHistoryProvider.notifier);
    final today = DateTime.now();

    // Find the next upcoming reminder (either due today and not completed, or next interval)
    NotificationReminder? nextReminder;
    DateTime? nextReminderDate;

    for (final reminder in reminders) {
      if (!reminder.enabled) continue;

      // Check if due today and not completed
      if (reminder.isDueOn(today) && !reminder.isCompletedOn(today)) {
        nextReminder = reminder;
        nextReminderDate = today;
        break;
      }
    }

    // If no reminder due today or all completed, find next closest interval
    if (nextReminder == null) {
      DateTime closestDate = DateTime.now().add(
        const Duration(days: 365),
      ); // 1 year max

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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
      ),
      child: hasReminder
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: Color(0xFFFF9500),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nextReminderDate == today
                            ? 'Next Reminder'
                            : 'Upcoming Reminder',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nextReminder.title,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nextReminder.time.format(context),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: nextReminderDate == today
                      ? () {
                          // Mark the reminder as completed for the next reminder date and go to Day Details.
                          final reminder = nextReminder;
                          if (reminder != null && nextReminderDate != null) {
                            final completedReminder = reminder.completeOn(
                              nextReminderDate,
                            );
                            ref
                                .read(notificationRemindersProvider.notifier)
                                .updateReminder(completedReminder);
                            // Log history record
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
                            // Show snackbar confirmation
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "✓ Reminder '${reminder.title}' completed!",
                                ),
                                backgroundColor: const Color(0xFF32D74B),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: nextReminderDate == today
                        ? const Color(0xFF007AFF)
                        : const Color(0xFFD1D1D6),
                    foregroundColor: nextReminderDate == today
                        ? Colors.white
                        : const Color(0xFF8E8E93),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Complete',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E8E93).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_none,
                    size: 20,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Upcoming Reminders',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Stay on track with your health',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final newReminder =
                        await showModalBottomSheet<NotificationReminder>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (context) => const CreateReminderDialog(),
                        );
                    if (newReminder != null) {
                      ref
                          .read(notificationRemindersProvider.notifier)
                          .addReminder(newReminder);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'Add',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
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
    final isFitbitSelected = dataSourceConfig.type == DataSourceType.fitbit;

    final lastSyncValue = vendorLastSync.whenOrNull(data: (v) => v);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFitbitSelected
              ? const Color(0xFF00B0B9)
              : const Color(0xFFE5E5EA),
          width: isFitbitSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B0B9).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.watch, color: Color(0xFF00B0B9)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vendor Integration',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Selected: ${dataSourceConfig.type.displayName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                    if (lastSyncValue != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Last sync: '
                        '${DateFormat('MMM d, yyyy HH:mm').format(lastSyncValue)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: connected
                      ? const Color(0xFFE7F8EF)
                      : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      connected ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: connected
                          ? const Color(0xFF32D74B)
                          : const Color(0xFF8E8E93),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      connected ? 'Connected' : 'Not connected',
                      style: TextStyle(
                        color: connected
                            ? const Color(0xFF1C1C1E)
                            : const Color(0xFF8E8E93),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isBusy
                      ? null
                      : () async {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const VendorSelectionScreen(),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    isBusy
                        ? 'Loading…'
                        : connected
                        ? 'Manage'
                        : 'Setup',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectivityBanner(
    AsyncValue<Map<String, dynamic>> healthStatus,
    AppLocalizations l10n,
  ) {
    return healthStatus.when(
      data: (status) {
        final backendStatus = status['status']?.toString() ?? 'unknown';
        final fhirStatus = (status['fhir']?['status'] ?? 'unknown').toString();
        final error = status['error']?.toString();

        final isOffline = error == 'offline';
        final isTimeout = error == 'timeout';
        final hasConnectionIssue =
            isOffline || isTimeout || backendStatus == 'unreachable';
        final isFhirUnavailable = fhirStatus != 'connected';

        if (hasConnectionIssue) {
          return _buildNoticeBanner(
            icon: Icons.wifi_off,
            color: const Color(0xFFFF3B30),
            message: l10n.connectionIssueMessage,
          );
        }

        if (isFhirUnavailable) {
          return _buildNoticeBanner(
            icon: Icons.sync_problem,
            color: const Color(0xFFFF9500),
            message: l10n.fhirUnavailableMessage,
          );
        }

        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => _buildNoticeBanner(
        icon: Icons.wifi_off,
        color: const Color(0xFFFF3B30),
        message: l10n.connectionIssueMessage,
      ),
    );
  }

  Widget _buildNoticeBanner({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF1C1C1E),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
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
            Text(
              l10n.healthStatistics,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
            IconButton(
              onPressed: () => _showActionsBottomSheet(context, l10n),
              icon: const Icon(Icons.add, color: Color(0xFF007AFF)),
              tooltip: l10n.quickActions,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ObservationsHistoryScreen(),
                  ),
                );
              },
              child: _buildStatCard(
                context,
                title: l10n.vitalSigns,
                value: latestObservationsState.when(
                  data: (observations) => observations.length.toString(),
                  loading: () => null,
                  error: (_, __) => '0',
                ),
                subtitle: l10n.recorded,
                icon: Icons.favorite,
                color: const Color(0xFFFF3B30),
                isLoading: latestObservationsState.isLoading,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ConditionsHistoryScreen(),
                  ),
                );
              },
              child: _buildStatCard(
                context,
                title: l10n.conditionsLabel,
                value: latestConditionsState.when(
                  data: (conditions) => conditions.length.toString(),
                  loading: () => null,
                  error: (_, __) => '0',
                ),
                subtitle: l10n.reported,
                icon: Icons.report_problem,
                color: const Color(0xFFFF9500),
                isLoading: latestConditionsState.isLoading,
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
    required String? value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isLoading,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
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
                  '${value ?? '---'} $subtitle',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value ?? '0',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.viewAll,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 10, color: color),
                    ],
                  ),
                ),
              ],
            ),
        ],
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

class _SyntheticSimulationProgressDialog extends ConsumerStatefulWidget {
  const _SyntheticSimulationProgressDialog();

  @override
  ConsumerState<_SyntheticSimulationProgressDialog> createState() =>
      _SyntheticSimulationProgressDialogState();
}

class _SyntheticSimulationProgressDialogState
    extends ConsumerState<_SyntheticSimulationProgressDialog> {
  @override
  void initState() {
    super.initState();

    ref.listen<SyntheticSimulationState>(syntheticSimulationProvider, (
      previous,
      next,
    ) {
      if (!mounted) return;
      if (next.status == SyntheticSimulationStatus.success) {
        Navigator.of(context).pop(true);
      } else if (next.status == SyntheticSimulationStatus.error) {
        Navigator.of(context).pop(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(syntheticSimulationProvider);
    final stepText = state.step?.label ?? 'Initializing simulation…';
    final profileText = state.profile?.displayName;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Generating synthetic data'),
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stepText),
                  if (profileText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      profileText,
                      style: const TextStyle(color: Color(0xFF8E8E93)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
