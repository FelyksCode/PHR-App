import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phr_app/l10n/app_localizations.dart';


const _remindersKey = 'health_reminders_enabled';
const _vibrateKey = 'health_reminders_vibrate';

final remindersLoadingProvider = StateProvider<bool>((ref) => true);
final remindersEnabledProvider = StateProvider<bool>((ref) => true);
final vibrateEnabledProvider = StateProvider<bool>((ref) => true);

class HealthRemindersScreen extends ConsumerWidget {
  const HealthRemindersScreen({super.key});

  Future<void> _loadPrefs(WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    ref.read(remindersEnabledProvider.notifier).state = prefs.getBool(_remindersKey) ?? true;
    ref.read(vibrateEnabledProvider.notifier).state = prefs.getBool(_vibrateKey) ?? true;
    ref.read(remindersLoadingProvider.notifier).state = false;
  }

  Future<void> _updateReminders(WidgetRef ref, bool value) async {
    ref.read(remindersEnabledProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindersKey, value);
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
                        onChanged: (val) => _updateReminders(ref, val),
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
                        onChanged: remindersEnabled ? (val) => _updateVibrate(ref, val) : null,
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
