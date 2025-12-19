import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _syncIntervalKey = 'sync_interval_minutes';
const int _defaultInterval = 10;
final intervalsProvider = Provider<List<int>>((ref) => [5, 10, 15, 30, 60, 120]);
final intervalLabelsProvider = Provider<List<String>>((ref) => [
  '5 minutes',
  '10 minutes (Default)',
  '15 minutes',
  '30 minutes',
  '1 hour',
  '2 hours',
]);
final loadingProvider = StateProvider<bool>((ref) => true);
final selectedIntervalProvider = StateProvider<int>((ref) => _defaultInterval);

class SyncSettingsScreen extends ConsumerWidget {
  const SyncSettingsScreen({super.key});

  Future<void> _loadPrefs(WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    ref.read(selectedIntervalProvider.notifier).state = prefs.getInt(_syncIntervalKey) ?? _defaultInterval;
    ref.read(loadingProvider.notifier).state = false;
  }

  Future<void> _updateSyncInterval(WidgetRef ref, int interval) async {
    ref.read(selectedIntervalProvider.notifier).state = interval;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_syncIntervalKey, interval);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(loadingProvider);
    final selectedInterval = ref.watch(selectedIntervalProvider);
    final intervals = ref.watch(intervalsProvider);
    final intervalLabels = ref.watch(intervalLabelsProvider);

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
                              'Sync Interval',
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
                            RadioListTile<int>(
                              value: intervals[index],
                              groupValue: selectedInterval,
                              onChanged: (value) {
                                if (value != null) {
                                  _updateSyncInterval(ref, value);
                                }
                              },
                              title: Text(
                                intervalLabels[index],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1C1C1E),
                                ),
                              ),
                              activeColor: const Color(0xFF007AFF),
                            ),
                            if (index < intervals.length - 1)
                              const Divider(height: 1, indent: 16, endIndent: 16),
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
}
