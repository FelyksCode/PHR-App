import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/sync_job_provider.dart';
import '../../../providers/vendor_integration_provider.dart';
import '../../../providers/data_source_providers.dart';
import '../../../domain/entities/data_source_config.dart';

class VendorSelectionScreen extends ConsumerWidget {
  const VendorSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitbitState = ref.watch(vendorIntegrationProvider('fitbit'));
    final fitbitNotifier = ref.read(
      vendorIntegrationProvider('fitbit').notifier,
    );
    final syncState = ref.watch(syncJobProvider);
    final syncNotifier = ref.read(syncJobProvider.notifier);
    final configState = ref.watch(dataSourceConfigProvider);
    final configNotifier = ref.read(dataSourceConfigProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Sources'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        centerTitle: false,
      ),
      backgroundColor: const Color(0xFFFAFAFA),
      body: RefreshIndicator(
        onRefresh: () async {
          await fitbitNotifier.refreshStatus();
          await syncNotifier.refreshStatus();
          await configNotifier.refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Single source enforcement notice
            const SizedBox(height: 16),

            // Current active source display
            configState.when(
              data: (config) => _buildActiveSourceCard(context, config),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildErrorCard(context, e.toString()),
            ),
            const SizedBox(height: 16),

            // Fitbit card
            if (fitbitState.error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fitbitState.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            configState.maybeWhen(
              data: (config) => _FitbitCard(
                state: fitbitState,
                notifier: fitbitNotifier,
                syncState: syncState,
                syncNotifier: syncNotifier,
                config: config,
                configNotifier: configNotifier,
              ),
              orElse: () => const SizedBox(),
            ),
            const SizedBox(height: 16),

            // Manual entry option
            configState.maybeWhen(
              data: (config) =>
                  _buildManualEntryCard(context, config, configNotifier),
              orElse: () => const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSourceCard(BuildContext context, DataSourceConfig config) {
    final isActive = config.isActive && config.type.isAutomatic;

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
              Icon(
                isActive ? Icons.check_circle : Icons.cancel,
                color: isActive
                    ? const Color(0xFF32D74B)
                    : const Color(0xFF8E8E93),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Active Data Source',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config.type.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (config.selectedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Selected: ${DateFormat('MMM d, yyyy HH:mm').format(config.selectedAt!)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(error, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildManualEntryCard(
    BuildContext context,
    DataSourceConfig config,
    DataSourceConfigNotifier configNotifier,
  ) {
    final isSelected = config.type == DataSourceType.manual;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF007AFF) : const Color(0xFFE5E5EA),
          width: isSelected ? 2 : 1,
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
                  color: const Color(0xFF8E8E93).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit, color: Color(0xFF8E8E93)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Manual Entry Only',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Color(0xFF007AFF),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Selected',
                        style: TextStyle(
                          color: Color(0xFF007AFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Disable automatic sync and enter health data manually through the app.',
            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isSelected
                ? null
                : () async {
                    final confirmed =
                        await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Switch to Manual Entry?'),
                            content: const Text(
                              'This will disable automatic data sync. You will need to enter health data manually.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Confirm'),
                              ),
                            ],
                          ),
                        ) ??
                        false;

                    if (confirmed && context.mounted) {
                      final ok = await configNotifier.selectDataSource(
                        DataSourceType.manual,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Switched to manual entry mode'
                                  : 'Failed to switch mode',
                            ),
                          ),
                        );
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: isSelected
                  ? const Color(0xFFF2F2F7)
                  : const Color(0xFF007AFF),
              foregroundColor: isSelected
                  ? const Color(0xFF8E8E93)
                  : Colors.white,
            ),
            child: Text(
              isSelected ? 'Currently Active' : 'Select Manual Entry',
            ),
          ),
        ],
      ),
    );
  }
}

class _FitbitCard extends StatelessWidget {
  const _FitbitCard({
    required this.state,
    required this.notifier,
    required this.syncState,
    required this.syncNotifier,
    required this.config,
    required this.configNotifier,
  });

  final VendorIntegrationState state;
  final VendorIntegrationNotifier notifier;
  final SyncJobState syncState;
  final SyncJobNotifier syncNotifier;
  final DataSourceConfig config;
  final DataSourceConfigNotifier configNotifier;

  @override
  Widget build(BuildContext context) {
    final status = state.status;
    final connected = status?.isConnected == true;
    final expiringSoon = status?.isExpiringSoon == true;
    final isSelected = config.type == DataSourceType.fitbit;
    final jobStatus = syncState.status?.status;
    final jobLabel = jobStatus?.name ?? 'unknown';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF00B0B9) : const Color(0xFFE5E5EA),
          width: isSelected ? 2 : 1,
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
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B0B9).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Color(0xFF00B0B9),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Selected',
                        style: TextStyle(
                          color: Color(0xFF00B0B9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            connected
                ? 'Fitbit is connected and ready for automatic data sync.'
                : 'Connect Fitbit via backend-managed OAuth for automatic sync.',
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
          ),

          // Connection status
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                connected ? Icons.cloud_done : Icons.cloud_off,
                size: 18,
                color: connected
                    ? const Color(0xFF32D74B)
                    : const Color(0xFF8E8E93),
              ),
              const SizedBox(width: 6),
              Text(
                connected ? 'Connected to Fitbit Cloud' : 'Not connected',
                style: TextStyle(
                  fontSize: 13,
                  color: connected
                      ? const Color(0xFF32D74B)
                      : const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
                    color: expiringSoon
                        ? Colors.orange
                        : const Color(0xFF8E8E93),
                    fontWeight: expiringSoon
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Select as data source button
          if (!isSelected && !connected)
            ElevatedButton.icon(
              onPressed: state.isSelecting
                  ? null
                  : () async {
                      // First select this as the data source
                      final sourceSelected = await configNotifier
                          .selectDataSource(DataSourceType.fitbit);
                      if (!sourceSelected) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Failed to select Fitbit as data source',
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      // Then initiate OAuth flow
                      final ok = await notifier.selectVendor();
                      if (ok) {
                        if (!context.mounted) return;
                        await _launchOAuth(context, notifier);
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Failed to start Fitbit authorization',
                            ),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.link),
              label: const Text('Select & Connect Fitbit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B0B9),
                foregroundColor: Colors.white,
              ),
            ),

          // Connection management buttons
          if (connected || isSelected) ...[
            Row(
              children: [
                if (connected)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: state.isSelecting
                          ? null
                          : () async {
                              await _launchOAuth(context, notifier);
                            },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Re-authorize'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: state.isSelecting
                          ? null
                          : () async {
                              final ok = await notifier.selectVendor();
                              if (ok) {
                                if (!context.mounted) return;
                                await _launchOAuth(context, notifier);
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Failed to start Fitbit authorization',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.link),
                      label: const Text('Connect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B0B9),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                if (connected)
                  ElevatedButton.icon(
                    onPressed: state.isLoading
                        ? null
                        : () async {
                            final confirmed =
                                await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Disconnect Fitbit?'),
                                    content: const Text(
                                      'This will disconnect Fitbit and switch to manual entry mode. You can reconnect anytime.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text(
                                          'Disconnect',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;

                            if (confirmed && context.mounted) {
                              final ok = await notifier.disconnect();
                              if (ok) {
                                // Also switch to manual mode
                                await configNotifier.selectDataSource(
                                  DataSourceType.manual,
                                );
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Fitbit disconnected - switched to manual entry'
                                          : 'Failed to disconnect Fitbit',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      foregroundColor: Colors.red,
                    ),
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                  )
                else
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

            // Sync button - only enabled if Fitbit is selected AND connected
            ElevatedButton.icon(
              onPressed: (!isSelected || !connected || syncState.isTriggering)
                  ? null
                  : () async {
                      await syncNotifier.triggerVendorSync('fitbit');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Sync request sent. You can monitor status below.',
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.sync),
              label: Text(
                (syncState.isTriggering || syncState.isPolling)
                    ? 'Syncing…'
                    : 'Sync Fitbit',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: (!isSelected || !connected)
                    ? const Color(0xFFF2F2F7)
                    : const Color(0xFF007AFF),
                foregroundColor: (!isSelected || !connected)
                    ? const Color(0xFF8E8E93)
                    : Colors.white,
              ),
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Color(0xFF8E8E93),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Sync status: $jobLabel',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ),
              ],
            ),
            if (syncState.error != null) ...[
              const SizedBox(height: 6),
              Text(
                syncState.error!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
            if (syncState.status?.message != null &&
                syncState.status!.message!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                syncState.status!.message!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
              ),
            ],
            if (!isSelected && connected) ...[
              const SizedBox(height: 8),
              const Text(
                '⚠️ Fitbit is connected but not selected as active source. Select Fitbit above to enable sync.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _launchOAuth(
    BuildContext context,
    VendorIntegrationNotifier notifier,
  ) async {
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
