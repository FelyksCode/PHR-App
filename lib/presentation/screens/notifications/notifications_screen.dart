import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phr_app/data/models/notification_reminder.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/notification_reminders_provider.dart';
import '../../providers/reminder_creation_provider.dart';
import '../../../providers/notification_service_provider.dart';
import '../../../services/notification_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

final showTutorialProvider = StateProvider<bool>((ref) => false);
final tutorialStepProvider = StateProvider<int>((ref) => 0);

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstTime();
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    final notificationService = ref.read(notificationServiceProvider);

    await notificationService.requestNotificationPermission();

    debugPrint('[NotificationsScreen] Notification permission');
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial =
        prefs.getBool('notifications_tutorial_seen') ?? false;
    if (!hasSeenTutorial && mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ref.read(showTutorialProvider.notifier).state = true;
        }
      });
    }
  }

  void _startTutorial() {
    ref.read(tutorialStepProvider.notifier).state = 0;
    ref.read(showTutorialProvider.notifier).state = true;
  }

  void _nextStep() {
    final step = ref.read(tutorialStepProvider);
    if (step < 3) {
      ref.read(tutorialStepProvider.notifier).state = step + 1;
    } else {
      _closeTutorial();
    }
  }

  Future<void> _closeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_tutorial_seen', true);
    if (!mounted) return;
    ref.read(showTutorialProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(notificationRemindersProvider);
    final showTutorial = ref.watch(showTutorialProvider);
    final tutorialStep = ref.watch(tutorialStepProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          'Notifications',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Tutorial',
            onPressed: _startTutorial,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Reminder',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final newReminder =
                  await showModalBottomSheet<NotificationReminder>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (context) => const CreateReminderDialog(),
                  );
              if (!mounted) return;
              if (newReminder != null) {
                ref
                    .read(notificationRemindersProvider.notifier)
                    .addReminder(newReminder);

                // Schedule notification
                final notificationService = ref.read(
                  notificationServiceProvider,
                );
                await notificationService.scheduleNotification(
                  id: newReminder.id,
                  title: newReminder.title,
                  body: newReminder.description,
                  interval: _mapInterval(newReminder.interval),
                  weekDay: newReminder.weekDay,
                  monthDay: newReminder.monthDay,
                  time: newReminder.time,
                );

                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Reminder "${newReminder.title}" scheduled',
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: reminders.isEmpty
          ? const Center(child: Text('No reminders yet.'))
          : Stack(
              children: [
                ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reminders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final r = reminders[i];
                    return Dismissible(
                      key: ValueKey(r.id),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.endToStart) {
                          // Delete
                          return true;
                        } else if (direction == DismissDirection.startToEnd) {
                          // Toggle enabled
                          final toggled = r.copyWith(enabled: !r.enabled);
                          ref
                              .read(notificationRemindersProvider.notifier)
                              .updateReminder(toggled);

                          // Handle notification scheduling based on enabled state
                          final notificationService = ref.read(
                            notificationServiceProvider,
                          );
                          if (toggled.enabled) {
                            // Re-enable: schedule notification
                            await notificationService.scheduleNotification(
                              id: toggled.id,
                              title: toggled.title,
                              body: toggled.description,
                              interval: _mapInterval(toggled.interval),
                              weekDay: toggled.weekDay,
                              monthDay: toggled.monthDay,
                              time: toggled.time,
                            );
                          } else {
                            // Disable: cancel notification
                            await notificationService.cancelNotification(
                              toggled.id,
                            );
                          }

                          return false;
                        }
                        return false;
                      },
                      background: Container(
                        color: r.enabled ? Colors.orange : Colors.green,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 24),
                        child: Icon(
                          r.enabled
                              ? Icons.notifications_off
                              : Icons.notifications_active,
                          color: Colors.white,
                        ),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) async {
                        if (direction == DismissDirection.endToStart) {
                          ref
                              .read(notificationRemindersProvider.notifier)
                              .removeReminder(r.id);

                          // Cancel scheduled notification
                          final notificationService = ref.read(
                            notificationServiceProvider,
                          );
                          final messenger = ScaffoldMessenger.of(context);
                          await notificationService.cancelNotification(r.id);

                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Reminder "${r.title}" deleted'),
                            ),
                          );
                        }
                      },
                      child: Opacity(
                        opacity: r.enabled ? 1.0 : 0.5,
                        child: GestureDetector(
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final editedReminder =
                                await showModalBottomSheet<
                                  NotificationReminder
                                >(
                                  context: context,
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  builder: (context) =>
                                      CreateReminderDialog(reminder: r),
                                );
                            if (!mounted) return;
                            if (editedReminder != null) {
                              ref
                                  .read(notificationRemindersProvider.notifier)
                                  .updateReminder(editedReminder);

                              // Reschedule notification with updated data
                              final notificationService = ref.read(
                                notificationServiceProvider,
                              );
                              await notificationService.cancelNotification(
                                editedReminder.id,
                              );
                              if (editedReminder.enabled) {
                                await notificationService.scheduleNotification(
                                  id: editedReminder.id,
                                  title: editedReminder.title,
                                  body: editedReminder.description,
                                  interval: _mapInterval(
                                    editedReminder.interval,
                                  ),
                                  weekDay: editedReminder.weekDay,
                                  monthDay: editedReminder.monthDay,
                                  time: editedReminder.time,
                                );
                              }

                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Reminder "${editedReminder.title}" updated',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: _ReminderCard(
                            title: r.title,
                            subtitle:
                                '${r.description} at ${r.time.format(context)}',
                            icon: r.enabled ? Icons.alarm : Icons.alarm_off,
                            color: r.enabled
                                ? const Color(0xFF007AFF)
                                : const Color(0xFF8E8E93),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (showTutorial)
                  _TutorialOverlay(
                    step: tutorialStep,
                    onNext: _nextStep,
                    onSkip: _closeTutorial,
                  ),
              ],
            ),
    );
  }
}

NotificationInterval _mapInterval(String? interval) {
  switch (interval) {
    case 'Weekly':
      return NotificationInterval.weekly;
    case 'Monthly':
      return NotificationInterval.monthly;
    case 'Daily':
    default:
      return NotificationInterval.daily;
  }
}

class CreateReminderDialog extends ConsumerStatefulWidget {
  final NotificationReminder? reminder;

  const CreateReminderDialog({super.key, this.reminder});

  @override
  ConsumerState<CreateReminderDialog> createState() =>
      _CreateReminderDialogState();
}

class _CreateReminderDialogState extends ConsumerState<CreateReminderDialog> {
  final _titleController = TextEditingController();

  final List<Map<String, dynamic>> _vitalSigns = [
    {
      'title': 'Body Weight',
      'subtitle': 'Track your weight changes',
      'icon': '⚖️',
    },
    {
      'title': 'Body Height',
      'subtitle': 'Record your height measurement',
      'icon': '📏',
    },
    {
      'title': 'Body Temperature',
      'subtitle': 'Monitor body temperature',
      'icon': '🌡️',
    },
    {'title': 'Heart Rate', 'subtitle': 'Track your heart rate', 'icon': '❤️'},
    {
      'title': 'Blood Pressure',
      'subtitle': 'Record systolic and diastolic BP',
      'icon': '🩸',
    },
    {
      'title': 'Oxygen Saturation',
      'subtitle': 'Monitor blood oxygen levels',
      'icon': '🫁',
    },
  ];

  final List<String> _intervals = ['Daily', 'Weekly', 'Monthly'];
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.reminder != null) {
      _titleController.text = widget.reminder!.title;
      final parts = widget.reminder!.description.split(' - ');
      final vitalSign = parts[0];
      final interval = parts[1];
      String? day;
      int? date;
      if (parts.length > 2) {
        final extraInfo = parts[2];
        if (interval == 'Weekly') {
          day = extraInfo;
        } else if (interval == 'Monthly') {
          date = int.tryParse(extraInfo);
        }
      }
      // Initialize provider state after frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(reminderCreationProvider.notifier)
            .initializeFromReminder(
              vitalSign: vitalSign,
              interval: interval,
              day: day,
              date: date,
              time: widget.reminder!.time,
            );
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reminderState = ref.watch(reminderCreationProvider);
    final reminderNotifier = ref.read(reminderCreationProvider.notifier);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 1.0,
      maxChildSize: 1.0,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const Text(
                  'Create Reminder',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Vital Sign',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _vitalSigns.map((sign) {
                    final isSelected =
                        reminderState.selectedVitalSign == sign['title'];
                    return GestureDetector(
                      onTap: () {
                        reminderNotifier.setVitalSign(sign['title']);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF007AFF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF007AFF)
                                : const Color(0xFFE5E5EA),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sign['icon'],
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sign['title'],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF1C1C1E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Interval',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reminderState.selectedInterval,
                  decoration: InputDecoration(
                    labelText: 'Interval',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: _intervals.map((interval) {
                    return DropdownMenuItem(
                      value: interval,
                      child: Text(interval),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) reminderNotifier.setInterval(value);
                  },
                ),
                const SizedBox(height: 12),
                if (reminderState.selectedInterval == 'Weekly') ...[
                  DropdownButtonFormField<String>(
                    initialValue: reminderState.selectedDay,
                    decoration: InputDecoration(
                      labelText: 'Day',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: _days.map((day) {
                      return DropdownMenuItem(value: day, child: Text(day));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) reminderNotifier.setDay(value);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (reminderState.selectedInterval == 'Monthly') ...[
                  DropdownButtonFormField<int>(
                    initialValue: reminderState.selectedDate,
                    decoration: InputDecoration(
                      labelText: 'Date of Month',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: List.generate(28, (index) => index + 1).map((date) {
                      return DropdownMenuItem(
                        value: date,
                        child: Text('$date'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) reminderNotifier.setDate(value);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Time: ${reminderState.selectedTime?.format(context) ?? '--:--'}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime:
                              reminderState.selectedTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          reminderNotifier.setTime(picked);
                        }
                      },
                      icon: const Icon(Icons.access_time),
                      label: const Text('Pick Time'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (_titleController.text.isNotEmpty &&
                            reminderState.selectedVitalSign != null &&
                            reminderState.selectedInterval != null &&
                            reminderState.selectedTime != null &&
                            (reminderState.selectedInterval != 'Weekly' ||
                                reminderState.selectedDay != null) &&
                            (reminderState.selectedInterval != 'Monthly' ||
                                reminderState.selectedDate != null)) {
                          String description =
                              '${reminderState.selectedVitalSign} - ${reminderState.selectedInterval}';
                          if (reminderState.selectedInterval == 'Weekly' &&
                              reminderState.selectedDay != null) {
                            description += ' - ${reminderState.selectedDay}';
                          } else if (reminderState.selectedInterval ==
                                  'Monthly' &&
                              reminderState.selectedDate != null) {
                            description += ' - ${reminderState.selectedDate}';
                          }
                          // Map day name to weekday int
                          int? weekDay;
                          if (reminderState.selectedInterval == 'Weekly' &&
                              reminderState.selectedDay != null) {
                            const mapping = {
                              'Monday': 1,
                              'Tuesday': 2,
                              'Wednesday': 3,
                              'Thursday': 4,
                              'Friday': 5,
                              'Saturday': 6,
                              'Sunday': 7,
                            };
                            weekDay = mapping[reminderState.selectedDay!];
                          }

                          final reminder = NotificationReminder(
                            id: widget.reminder?.id ?? const Uuid().v4(),
                            title: _titleController.text,
                            description: description,
                            time: reminderState.selectedTime!,
                            enabled: true,
                            interval: reminderState.selectedInterval,
                            weekDay: weekDay,
                            monthDay:
                                reminderState.selectedInterval == 'Monthly'
                                ? reminderState.selectedDate
                                : null,
                            completedDates: widget.reminder?.completedDates,
                            isComplete: widget.reminder?.isComplete ?? false,
                            createdAt:
                                widget.reminder?.createdAt ?? DateTime.now(),
                          );
                          Navigator.pop(context, reminder);
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ReminderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialOverlay extends StatefulWidget {
  final int step;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TutorialOverlay({
    required this.step,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<_TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<_TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> steps = [
      {
        'title': 'Welcome to Reminders!',
        'description': 'Set reminders to track your vital signs regularly',
        'icon': Icons.notifications_active,
        'position': 'center',
      },
      {
        'title': 'Create a Reminder',
        'description':
            'Tap the + button in the top right to add a new reminder',
        'icon': Icons.add_circle_outline,
        'position': 'top-right',
        'highlight': 'add-button',
      },
      {
        'title': 'Swipe Right to Toggle',
        'description': 'Swipe right on a reminder to enable or disable it',
        'icon': Icons.swipe_right,
        'position': 'top',
        'highlight': 'right',
      },
      {
        'title': 'Swipe Left to Delete',
        'description': 'Swipe left on a reminder to delete it permanently',
        'icon': Icons.swipe_left,
        'position': 'top',
        'highlight': 'left',
      },
    ];

    final currentStep = steps[widget.step];
    final isCenter = currentStep['position'] == 'center';
    final isAddButton = currentStep['highlight'] == 'add-button';

    return GestureDetector(
      onTap: () {}, // Prevent dismissing by tap
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Stack(
          children: [
            // Highlight add button
            if (isAddButton)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  margin: const EdgeInsets.only(top: 40, right: 16),
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 1.0,
                      end: 1.15,
                    ).animate(_scaleAnim),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF007AFF),
                          width: 3,
                        ),
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Color(0xFF007AFF),
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            // Dummy reminder card for swipe animations
            if (!isCenter && !isAddButton)
              Positioned(
                top: 120,
                left: 16,
                right: 16,
                child: AnimatedBuilder(
                  animation: _slideAnim,
                  builder: (context, child) {
                    final isRight = currentStep['highlight'] == 'right';
                    final dx = (isRight ? 1 : -1) * (_slideAnim.value * 40.0);
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: child!,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF007AFF),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF007AFF,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.alarm,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Health Check',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1C1C1E),
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Heart Rate - Daily at 09:00',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF8E8E93),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Swipe direction indicator
            if (!isCenter && !isAddButton)
              Positioned(
                top: 150,
                left: currentStep['highlight'] == 'right' ? null : 16,
                right: currentStep['highlight'] == 'left' ? null : 16,
                child: AnimatedBuilder(
                  animation: _slideAnim,
                  builder: (context, _) {
                    final isRight = currentStep['highlight'] == 'right';
                    final dx = (isRight ? 1 : -1) * (_slideAnim.value * 8.0);
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: Icon(
                        isRight ? Icons.arrow_forward : Icons.arrow_back,
                        color: const Color(0xFF007AFF),
                        size: 48,
                      ),
                    );
                  },
                ),
              ),
            // Content
            Align(
              alignment: isCenter ? Alignment.center : Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: isCenter ? 0 : (isAddButton ? 120 : 250),
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        currentStep['icon'],
                        size: 48,
                        color: const Color(0xFF007AFF),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        currentStep['title'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1C1E),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentStep['description'],
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF8E8E93),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ...List.generate(steps.length, (index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: index == widget.step
                                    ? const Color(0xFF007AFF)
                                    : const Color(0xFFE5E5EA),
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: widget.onSkip,
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 16,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: widget.onNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007AFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              widget.step < steps.length - 1 ? 'Next' : 'Done',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
