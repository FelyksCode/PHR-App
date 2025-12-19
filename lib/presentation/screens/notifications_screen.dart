import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/notification_reminders_provider.dart';
import '../../data/models/notification_reminder.dart';


class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

final showTutorialProvider = StateProvider<bool>((ref) => false);
final tutorialStepProvider = StateProvider<int>((ref) => 0);

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('notifications_tutorial_seen') ?? false;
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
              final newReminder = await showModalBottomSheet<NotificationReminder>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (context) => const CreateReminderDialog(),
              );
              if (newReminder != null) {
                ref.read(notificationRemindersProvider.notifier).addReminder(newReminder);
                // TODO: Schedule notification here
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
                          final toggled = NotificationReminder(
                            id: r.id,
                            title: r.title,
                            description: r.description,
                            time: r.time,
                            enabled: !r.enabled,
                          );
                          ref.read(notificationRemindersProvider.notifier).updateReminder(toggled);
                          return false;
                        }
                        return false;
                      },
                      background: Container(
                        color: r.enabled ? Colors.orange : Colors.green,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 24),
                        child: Icon(
                          r.enabled ? Icons.notifications_off : Icons.notifications_active,
                          color: Colors.white,
                        ),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        if (direction == DismissDirection.endToStart) {
                          ref.read(notificationRemindersProvider.notifier).removeReminder(r.id);
                          // TODO: Cancel scheduled notification here
                        }
                      },
                      child: Opacity(
                        opacity: r.enabled ? 1.0 : 0.5,
                        child: GestureDetector(
                          onTap: () async {
                            final editedReminder = await showModalBottomSheet<NotificationReminder>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (context) => CreateReminderDialog(reminder: r),
                            );
                            if (editedReminder != null) {
                              ref.read(notificationRemindersProvider.notifier).updateReminder(editedReminder);
                            }
                          },
                          child: _ReminderCard(
                            title: r.title,
                            subtitle: r.description + ' at ' + r.time.format(context),
                            icon: r.enabled ? Icons.alarm : Icons.alarm_off,
                            color: r.enabled ? const Color(0xFF007AFF) : const Color(0xFF8E8E93),
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

class CreateReminderDialog extends StatefulWidget {
  final NotificationReminder? reminder;
  
  const CreateReminderDialog({super.key, this.reminder});
  
  @override
  State<CreateReminderDialog> createState() => _CreateReminderDialogState();
}

class _CreateReminderDialogState extends State<CreateReminderDialog> {
  final _titleController = TextEditingController();
  String? _selectedVitalSign;
  String? _selectedInterval;
  String? _selectedDay;
  int? _selectedDate;
  TimeOfDay? _selectedTime;
  
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
    {
      'title': 'Heart Rate',
      'subtitle': 'Track your heart rate',
      'icon': '❤️',
    },
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
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    if (widget.reminder != null) {
      _titleController.text = widget.reminder!.title;
      final parts = widget.reminder!.description.split(' - ');
      _selectedVitalSign = parts[0];
      _selectedInterval = parts[1];
      if (parts.length > 2) {
        final extraInfo = parts[2];
        if (_selectedInterval == 'Weekly') {
          _selectedDay = extraInfo;
        } else if (_selectedInterval == 'Monthly') {
          _selectedDate = int.tryParse(extraInfo);
        }
      }
      _selectedTime = widget.reminder!.time;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    final isSelected = _selectedVitalSign == sign['title'];
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedVitalSign = sign['title']);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF007AFF) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF007AFF) : const Color(0xFFE5E5EA),
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
                                color: isSelected ? Colors.white : const Color(0xFF1C1C1E),
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
                  value: _selectedInterval,
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
                    setState(() => _selectedInterval = value);
                  },
                ),
                const SizedBox(height: 12),
                if (_selectedInterval == 'Weekly') ...[
                  DropdownButtonFormField<String>(
                    value: _selectedDay,
                    decoration: InputDecoration(
                      labelText: 'Day',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: _days.map((day) {
                      return DropdownMenuItem(
                        value: day,
                        child: Text(day),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedDay = value);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (_selectedInterval == 'Monthly') ...[
                  DropdownButtonFormField<int>(
                    value: _selectedDate,
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
                      setState(() => _selectedDate = value);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Time: ${_selectedTime?.format(context) ?? '--:--'}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() => _selectedTime = picked);
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
                            _selectedVitalSign != null && 
                            _selectedInterval != null &&
                            _selectedTime != null &&
                            (_selectedInterval != 'Weekly' || _selectedDay != null) &&
                            (_selectedInterval != 'Monthly' || _selectedDate != null)) {
                          String description = '$_selectedVitalSign - $_selectedInterval';
                          if (_selectedInterval == 'Weekly' && _selectedDay != null) {
                            description += ' - $_selectedDay';
                          } else if (_selectedInterval == 'Monthly' && _selectedDate != null) {
                            description += ' - $_selectedDate';
                          }
                          final reminder = NotificationReminder(
                            id: widget.reminder?.id ?? const Uuid().v4(),
                            title: _titleController.text,
                            description: description,
                            time: _selectedTime!,
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
              color: color.withOpacity(0.12),
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

class _TutorialOverlay extends StatelessWidget {
  final int step;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TutorialOverlay({
    required this.step,
    required this.onNext,
    required this.onSkip,
  });

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
        'description': 'Tap the + button in the top right to add a new reminder',
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

    final currentStep = steps[step];
    final isCenter = currentStep['position'] == 'center';
    final isAddButton = currentStep['highlight'] == 'add-button';

    return GestureDetector(
      onTap: () {}, // Prevent dismissing by tap
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Stack(
          children: [
            // Highlight add button
            if (isAddButton)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  margin: const EdgeInsets.only(top: 40, right: 16),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.0, end: 1.3),
                    duration: const Duration(milliseconds: 600),
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF007AFF), width: 3),
                            color: Colors.white.withOpacity(0.1),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Color(0xFF007AFF),
                            size: 30,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            // Dummy reminder card for swipe animations
            if (!isCenter && !isAddButton)
              Positioned(
                top: 120,
                left: 16,
                right: 16,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: currentStep['highlight'] == 'right' ? 80.0 : -80.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(value, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF007AFF), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
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
                                color: const Color(0xFF007AFF).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.alarm, color: Color(0xFF007AFF)),
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
                    );
                  },
                ),
              ),
            // Swipe direction indicator
            if (!isCenter && !isAddButton)
              Positioned(
                top: 150,
                left: currentStep['highlight'] == 'right' ? null : 16,
                right: currentStep['highlight'] == 'left' ? null : 16,
                child: Icon(
                  currentStep['highlight'] == 'right' 
                      ? Icons.arrow_forward 
                      : Icons.arrow_back,
                  color: const Color(0xFF007AFF),
                  size: 48,
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
                        color: Colors.black.withOpacity(0.3),
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
                                color: index == step 
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
                            onPressed: onSkip,
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 16,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: onNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007AFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(step < steps.length - 1 ? 'Next' : 'Done'),
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
