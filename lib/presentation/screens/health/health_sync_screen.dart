import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phr_app/domain/entities/health_sync_entity.dart';
import 'dart:io';

import 'package:phr_app/providers/health_sync_providers.dart';

import '../../../services/health_sync_service.dart';


class HealthSyncScreen extends ConsumerStatefulWidget {
  const HealthSyncScreen({super.key});

  @override
  ConsumerState<HealthSyncScreen> createState() => _HealthSyncScreenState();
}

final periodicSyncEnabledProvider = StateProvider<bool>((ref) => false);

class _HealthSyncScreenState extends ConsumerState<HealthSyncScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(healthSyncNotifierProvider.notifier).initializeBackgroundSync();
      final syncNotifier = ref.read(healthSyncNotifierProvider.notifier);
      final isEnabled = await syncNotifier.isPeriodicSyncEnabled();
      ref.read(periodicSyncEnabledProvider.notifier).state = isEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(healthSyncNotifierProvider);
    final supportedDataTypes = ref.watch(supportedHealthDataTypesProvider);
    final syncNotifier = ref.read(healthSyncNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Data Sync'),
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => syncNotifier.refresh(),
          ),
        ],
      ),
      body: syncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text('Error: $error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => syncNotifier.refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (syncEntity) => _buildSyncContent(context, syncEntity, supportedDataTypes, syncNotifier),
      ),
    );
  }

  Widget _buildSyncContent(
    BuildContext context,
    HealthSyncEntity syncEntity,
    List<HealthDataType> supportedDataTypes,
    HealthSyncNotifier syncNotifier,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Platform info card
          _buildPlatformInfoCard(context, syncNotifier),
          
          const SizedBox(height: 16),
          
          // Sync status card
          _buildSyncStatusCard(context, syncEntity),
          
          const SizedBox(height: 16),
          
          // Sync controls
          _buildSyncControlsCard(context, syncEntity, syncNotifier),
          
          if (Platform.isAndroid) ...[
            const SizedBox(height: 16),
            _buildBackgroundSyncCard(context, syncNotifier),
          ],
        ],
      ),
    );
  }

  Widget _buildPlatformInfoCard(BuildContext context, HealthSyncNotifier syncNotifier) {
    final platform = Platform.isIOS ? 'iOS (HealthKit)' : 'Android (Health Connect)';
    final icon = Platform.isIOS ? Icons.phone_iphone : Icons.android;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    platform,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Health data sync supported',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              syncNotifier.isSupported ? Icons.check_circle : Icons.cancel,
              color: syncNotifier.isSupported ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard(BuildContext context, HealthSyncEntity syncEntity) {
    final statusColor = _getStatusColor(syncEntity.status);
    final statusIcon = _getStatusIcon(syncEntity.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Sync Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Status', syncEntity.status.displayName, statusColor),
            if (syncEntity.lastSyncTime != null) ...[
              const SizedBox(height: 8),
              _buildStatusRow('Last Sync', _formatDateTime(syncEntity.lastSyncTime!), Colors.grey.shade600),
            ],
            const SizedBox(height: 8),
            _buildStatusRow('Total Synced', '${syncEntity.totalSyncedObservations} observations', Colors.grey.shade600),
            if (syncEntity.errorMessage != null) ...[
              const SizedBox(height: 8),
              _buildStatusRow('Error', syncEntity.errorMessage!, Colors.red),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: valueColor),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncControlsCard(
    BuildContext context,
    HealthSyncEntity syncEntity,
    HealthSyncNotifier syncNotifier,
  ) {
    final canSync = syncEntity.permittedDataTypes.isNotEmpty && 
                   syncEntity.status != SyncStatus.syncing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync Controls',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canSync
                  ? () => _performSync(context, syncNotifier)
                  : null,
                icon: syncEntity.status == SyncStatus.syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync),
                label: Text(
                  syncEntity.status == SyncStatus.syncing
                    ? 'Syncing...'
                    : 'Sync Now',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: canSync
                  ? () => _performDeltaSync(context, syncNotifier, syncEntity)
                  : null,
                icon: const Icon(Icons.update),
                label: const Text('Sync Recent Data'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundSyncCard(BuildContext context, HealthSyncNotifier syncNotifier) {
    final isPeriodicSyncEnabled = ref.watch(periodicSyncEnabledProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Background Sync (Android)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Periodic Sync'),
              subtitle: const Text('Automatically sync health data every hour'),
              value: isPeriodicSyncEnabled,
              onChanged: (value) async {
                ref.read(periodicSyncEnabledProvider.notifier).state = value;
                try {
                  if (value) {
                    await syncNotifier.schedulePeriodicSync();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Background sync enabled'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    await syncNotifier.cancelPeriodicSync();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.info, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Background sync disabled'),
                          ],
                        ),
                        backgroundColor: Colors.blue,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  // Revert state if operation failed
                  ref.read(periodicSyncEnabledProvider.notifier).state = !value;
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Failed to ${value ? 'enable' : 'disable'} background sync: ${e.toString()}'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Colors.blue;
      case SyncStatus.syncing:
        return Colors.orange;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.failed:
        return Colors.red;
      case SyncStatus.permissionDenied:
        return Colors.purple;
      case SyncStatus.noData:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Icons.schedule;
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.success:
        return Icons.check_circle;
      case SyncStatus.failed:
        return Icons.error;
      case SyncStatus.permissionDenied:
        return Icons.block;
      case SyncStatus.noData:
        return Icons.info;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Action methods
  Future<void> _performSync(BuildContext context, HealthSyncNotifier syncNotifier) async {
    try {
      final result = await syncNotifier.performSync();

      if (!context.mounted) return;
      _showSyncResult(context, result);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performDeltaSync(BuildContext context, HealthSyncNotifier syncNotifier, HealthSyncEntity syncEntity) async {
    try {
      final since = syncEntity.lastSyncTime ?? DateTime.now().subtract(const Duration(days: 1));
      final result = await syncNotifier.performSync(since: since);

      if (!context.mounted) return;
      _showSyncResult(context, result);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delta sync error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSyncResult(BuildContext context, SyncResult result) {
    Color backgroundColor;
    IconData icon;
    
    if (result.isSuccess) {
      backgroundColor = Colors.green;
      icon = Icons.check_circle;
    } else if (result.isNoData) {
      backgroundColor = Colors.blue;
      icon = Icons.info;
    } else if (result.isPermissionDenied) {
      backgroundColor = Colors.purple;
      icon = Icons.block;
    } else {
      backgroundColor = Colors.red;
      icon = Icons.error;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(result.message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}