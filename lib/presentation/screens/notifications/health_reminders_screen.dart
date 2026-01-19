import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phr_app/l10n/app_localizations.dart';
import '../../../providers/notification_permission_provider.dart';
import '../../../providers/notification_service_provider.dart';

const _remindersKey = 'health_reminders_enabled';
const _vibrateKey = 'health_reminders_vibrate';

final remindersLoadingProvider = StateProvider<bool>((ref) => true);
final remindersEnabledProvider = StateProvider<bool>((ref) => true);
final vibrateEnabledProvider = StateProvider<bool>((ref) => true);

class HealthRemindersScreen extends ConsumerWidget {
  const HealthRemindersScreen({super.key});

  Future<void> _loadPrefs(WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    ref.read(remindersEnabledProvider.notifier).state =
        prefs.getBool(_remindersKey) ?? true;
    ref.read(vibrateEnabledProvider.notifier).state =
        prefs.getBool(_vibrateKey) ?? true;
    ref.read(remindersLoadingProvider.notifier).state = false;
  }

  void _showPermissionDeniedSnackBar(
    BuildContext context,
    WidgetRef ref,
    PermissionStatus status,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Notification permission is required to enable reminders.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF9500),
        behavior: SnackBarBehavior.floating,
        action: status.isPermanentlyDenied
            ? SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () {
                  ref
                      .read(notificationPermissionProvider.notifier)
                      .openSettings();
                },
              )
            : null,
      ),
    );
  }

  Future<bool> _ensureNotificationPermission(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final currentStatus = await ref
        .read(notificationPermissionProvider.notifier)
        .checkPermissionStatus();

    if (currentStatus.isGranted) {
      return true;
    }

    final newStatus = await ref
        .read(notificationPermissionProvider.notifier)
        .requestNotificationPermission();

    if (!newStatus.isGranted) {
      if (context.mounted) {
        _showPermissionDeniedSnackBar(context, ref, newStatus);
      }
      return false;
    }

    return true;
  }

  Future<void> _updateReminders(
    WidgetRef ref,
    bool value,
    BuildContext context,
  ) async {
    if (value) {
      final hasPermission = await _ensureNotificationPermission(context, ref);
      if (!hasPermission) return;
    }

    // Permission granted or disabling reminders, proceed
    ref.read(remindersEnabledProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindersKey, value);

    final notificationService = ref.read(notificationServiceProvider);

    if (!value) {
      // Master switch OFF: cancel all scheduled reminder notifications so they
      // stop appearing in the notification bar.
      await notificationService.cancelAllHealthReminderNotifications();
      return;
    }

    // Master switch ON: reschedule all enabled reminders.
    await notificationService.rescheduleAllHealthReminderNotifications();
  }

  Future<void> _updateVibrate(WidgetRef ref, bool value) async {
    ref.read(vibrateEnabledProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrateKey, value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final loading = ref.watch(remindersLoadingProvider);
    final remindersEnabled = ref.watch(remindersEnabledProvider);
    final vibrateEnabled = ref.watch(vibrateEnabledProvider);

    // Load prefs only once when loading is true
    if (loading) {
      _loadPrefs(ref);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          l10n.healthReminders,
          style: const TextStyle(
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
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        value: remindersEnabled,
                        onChanged: (val) => _updateReminders(ref, val, context),
                        title: Text(
                          l10n.enableReminders,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                        subtitle: Text(
                          l10n.enableRemindersDesc,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        value: vibrateEnabled,
                        onChanged: remindersEnabled
                            ? (val) => _updateVibrate(ref, val)
                            : null,
                        title: Text(
                          l10n.vibrate,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                        subtitle: Text(
                          l10n.vibrateDesc,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8E8E93),
                          ),
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
