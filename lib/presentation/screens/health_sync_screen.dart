import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../../domain/entities/health_sync_entity.dart';
import '../../providers/health_sync_providers.dart';
import '../../services/health_sync_service.dart';

class HealthSyncScreen extends ConsumerStatefulWidget {
  const HealthSyncScreen({super.key});

  @override
  ConsumerState<HealthSyncScreen> createState() => _HealthSyncScreenState();
}

class _HealthSyncScreenState extends ConsumerState<HealthSyncScreen> {
  Set<HealthDataType> _selectedDataTypes = {};
  bool _isPeriodicSyncEnabled = false;

  @override
  void initState() {
    super.initState();
    // Initialize background sync on Android
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(healthSyncNotifierProvider.notifier).initializeBackgroundSync();
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
          
          // Data types selection
          _buildDataTypesCard(context, supportedDataTypes, syncEntity, syncNotifier),
          
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

  Widget _buildDataTypesCard(
    BuildContext context,
    List<HealthDataType> supportedDataTypes,
    HealthSyncEntity syncEntity,
    HealthSyncNotifier syncNotifier,
  ) {
    if (_selectedDataTypes.isEmpty) {
      _selectedDataTypes = Set.from(syncEntity.permittedDataTypes);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Health Data Types',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Select the health data types you want to sync:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: supportedDataTypes.map((dataType) {
                final isSelected = _selectedDataTypes.contains(dataType);
                final isPermitted = syncEntity.permittedDataTypes.contains(dataType);
                
                return FilterChip(
                  label: Text(dataType.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDataTypes.add(dataType);
                      } else {
                        _selectedDataTypes.remove(dataType);
                      }
                    });
                  },
                  avatar: isPermitted 
                    ? const Icon(Icons.check_circle, size: 16, color: Colors.green)
                    : const Icon(Icons.circle, size: 16),
                  backgroundColor: isPermitted ? Colors.green.shade50 : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedDataTypes.isNotEmpty
                  ? () => _requestPermissions(context, syncNotifier)
                  : null,
                icon: const Icon(Icons.security),
                label: const Text('Request Permissions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
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
              value: _isPeriodicSyncEnabled,
              onChanged: (value) {
                setState(() {
                  _isPeriodicSyncEnabled = value;
                });
                
                if (value) {
                  syncNotifier.schedulePeriodicSync();
                } else {
                  syncNotifier.cancelPeriodicSync();
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
  Future<void> _requestPermissions(BuildContext context, HealthSyncNotifier syncNotifier) async {
    try {
      final granted = await syncNotifier.requestPermissions(_selectedDataTypes.toList());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              granted
                ? 'Permissions granted successfully!'
                : 'Some permissions were denied. Please check your device settings.',
            ),
            backgroundColor: granted ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting permissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _performSync(BuildContext context, HealthSyncNotifier syncNotifier) async {
    try {
      final result = await syncNotifier.performSync();
      
      if (mounted) {
        _showSyncResult(context, result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _performDeltaSync(BuildContext context, HealthSyncNotifier syncNotifier, HealthSyncEntity syncEntity) async {
    try {
      final since = syncEntity.lastSyncTime ?? DateTime.now().subtract(const Duration(days: 1));
      final result = await syncNotifier.performSync(since: since);
      
      if (mounted) {
        _showSyncResult(context, result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delta sync error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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