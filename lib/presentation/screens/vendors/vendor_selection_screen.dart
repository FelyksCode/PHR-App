import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/fitbit_vendor_provider.dart';

class VendorSelectionScreen extends ConsumerWidget {
  const VendorSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fitbitVendorProvider);
    final notifier = ref.read(fitbitVendorProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Sources'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Observations',
            icon: const Icon(Icons.list_alt_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed('/observations');
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFFAFAFA),
      body: RefreshIndicator(
        onRefresh: notifier.refreshStatus,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha:0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha:0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            _FitbitCard(state: state, notifier: notifier),
          ],
        ),
      ),
    );
  }
}

class _FitbitCard extends StatelessWidget {
  const _FitbitCard({required this.state, required this.notifier});

  final FitbitVendorState state;
  final FitbitVendorNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final status = state.status;
    final connected = status?.isConnected == true;
    final expiringSoon = status?.isExpiringSoon == true;

    return Container(
      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B0B9).withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.watch, color: Color(0xFF00B0B9)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Fitbit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ),
              _ConnectionChip(connected: connected),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            connected
                ? 'Fitbit is connected through the PHR gateway.'
                : 'Connect Fitbit via backend-managed OAuth. The app never talks to Fitbit directly.',
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
          ),
          if (status?.expiresAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  expiringSoon ? Icons.warning_amber : Icons.schedule,
                  color: expiringSoon ? Colors.orange : const Color(0xFF8E8E93),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Token expires ${DateFormat('MMM d, HH:mm').format(status!.expiresAt!)}',
                  style: TextStyle(
                    color: expiringSoon ? Colors.orange : const Color(0xFF8E8E93),
                    fontWeight: expiringSoon ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: state.isSelecting
                      ? null
                      : () async {
                          final ok = await notifier.selectFitbitVendor();
                          if (ok) {
                            if (!context.mounted) return;
                            await _launchOAuth(context, notifier);
                          } else if (context.mounted) {
                            final error = 'Failed to start Fitbit authorization';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error)),
                            );
                          }
                        },
                  icon: const Icon(Icons.link),
                  label: Text(connected ? 'Re-authorize Fitbit' : 'Connect Fitbit'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Check status',
                onPressed: state.isLoading ? null : notifier.refreshStatus,
                icon: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: (!connected || state.isSyncing)
                ? null
                : () async {
                    final result = await notifier.triggerSync();
                    if (context.mounted && result != null) {
                      final created = result.createdCount;
                      final message = result.message ?? 'Sync completed';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$message (created: $created)')),
                      );
                    }
                  },
            icon: const Icon(Icons.sync),
            label: Text(state.isSyncing ? 'Syncing…' : 'Sync Fitbit Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
            ),
          ),
          if (state.lastSyncResult != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last sync: ${state.lastSyncResult!.status} — created ${state.lastSyncResult!.createdCount}, failed ${state.lastSyncResult!.failedCount}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _launchOAuth(BuildContext context, FitbitVendorNotifier notifier) async {
    final uri = await notifier.buildAuthorizeUri();
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch Fitbit authorization')),
      );
    }
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: connected ? const Color(0xFFE7F8EF) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connected ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: connected ? const Color(0xFF32D74B) : const Color(0xFF8E8E93),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'Connected' : 'Not connected',
            style: TextStyle(
              color: connected ? const Color(0xFF1C1C1E) : const Color(0xFF8E8E93),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
