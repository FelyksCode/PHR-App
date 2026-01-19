import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../../main.dart'; // Import for permissionsRequestedProvider
import '../../../services/health_connect_service.dart';
import '../../../constants/health_permissions.dart';
import 'notification_permissions_screen.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

final isRequestingPermissionsProvider = StateProvider<bool>((ref) => false);

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  @override
  Widget build(BuildContext context) {
    final platform = Platform.isIOS ? 'HealthKit' : 'Health Connect';
    final platformIcon = Platform.isIOS ? Icons.phone_iphone : Icons.android;
    final isRequestingPermissions = ref.watch(isRequestingPermissionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  48,
            ),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    platformIcon,
                    size: 64,
                    color: const Color(0xFF007AFF),
                  ),
                ),

                const SizedBox(height: 32),

                const Text(
                  'Health Data Access',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                Text(
                  'We need access to your $platform data to provide personalized health insights and sync your vital signs.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8E8E93),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Permissions info
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE5E5EA),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      for (
                        int i = 0;
                        i < HealthPermissions.permissionCategories.length;
                        i++
                      ) ...[
                        _buildPermissionItem(
                          category: HealthPermissions.permissionCategories[i],
                        ),
                        if (i <
                            HealthPermissions.permissionCategories.length - 1)
                          const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Privacy notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF34C759).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.security, color: Color(0xFF34C759), size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your health data is encrypted and stored securely. We never share your personal information.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1C1C1E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isRequestingPermissions
                            ? null
                            : _requestPermissions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isRequestingPermissions
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Allow Access to $platform',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: TextButton(
                        onPressed: isRequestingPermissions
                            ? null
                            : _skipPermissions,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF8E8E93),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Skip for now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({required HealthPermissionCategory category}) {
    // Map icon string to IconData
    IconData getIconData(String iconName) {
      switch (iconName) {
        case 'favorite':
          return Icons.favorite;
        case 'thermostat':
          return Icons.thermostat;
        case 'monitor_weight':
          return Icons.monitor_weight;
        case 'air':
          return Icons.air;
        default:
          return Icons.health_and_safety;
      }
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Color(category.color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            getIconData(category.icon),
            color: Color(category.color),
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                category.description,
                style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _requestPermissions() async {
    ref.read(isRequestingPermissionsProvider.notifier).state = true;

    try {
      bool permissionsGranted = false;

      // Initialize Health Connect service
      final healthService = HealthConnectService.instance;
      await healthService.initialize();

      // Check Health Connect status first
      final healthConnectStatus = await healthService.getHealthConnectStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Health Connect Status: ${healthConnectStatus.toString().split('.').last}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF007AFF),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Check if Health Connect features are available
      final featuresAvailable = await healthService.isFeatureAvailable();

      // Additional check: Is Health Connect actually installed?
      final healthConnectInstalled = await healthService
          .isHealthConnectInstalled();

      if (!featuresAvailable || !healthConnectInstalled) {
        if (mounted) {
          ref.read(isRequestingPermissionsProvider.notifier).state = false;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      !healthConnectInstalled
                          ? 'Health Connect app is not installed. Install from Play Store.'
                          : 'Health Connect is not available. Please install from Play Store.',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFFF9500),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Install',
                textColor: Colors.white,
                onPressed: () async {
                  try {
                    await healthService.installHealthConnect();
                  } catch (e) {
                    // Handle installation error
                  }
                },
              ),
            ),
          );
        }
        return;
      }

      // Define health data types to request
      final permissions = HealthPermissions.requiredPermissions;

      // First check if we already have all permissions (similar to getGrantedPermissions check)
      final hasAllPermissions = await healthService.hasAllPermissions(
        permissions: permissions,
      );

      if (hasAllPermissions) {
        // All permissions already granted
        permissionsGranted = true;

        if (mounted) {
          ref.read(isRequestingPermissionsProvider.notifier).state = false;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All health permissions were already granted!',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF34C759),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // Get already granted permissions to show user what's missing
        final grantedPermissions = await healthService.getGrantedPermissions(
          permissions: permissions,
        );
        final missingCount = permissions.length - grantedPermissions.length;

        // Show user what permissions they already have
        if (grantedPermissions.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${grantedPermissions.length} permissions granted. Need $missingCount more.',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF007AFF),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        final accessTypes = HealthPermissions.accessTypes;

        // Show that we're requesting permissions
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Opening Health Connect permission dialog...',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF007AFF),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        try {
          // Request permissions using the service (this will only request missing ones)
          permissionsGranted = await healthService.requestHealthPermissions(
            permissions: permissions,
            accessTypes: accessTypes,
          );
        } catch (e) {
          if (mounted) {
            ref.read(isRequestingPermissionsProvider.notifier).state = false;

            if (e.toString().contains('Permission launcher not found') ||
                e.toString().contains('launcher not found')) {
              // Handle the specific "Permission launcher not found" error
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Health Connect app is required but not properly installed. Please install it from Google Play Store.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFFFF3B30),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'Install',
                    textColor: Colors.white,
                    onPressed: () async {
                      try {
                        await healthService.installHealthConnect();
                      } catch (installError) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Please manually install Health Connect from Play Store: ${installError.toString()}',
                              ),
                              backgroundColor: const Color(0xFFFF9500),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              );
            } else {
              // Handle other permission errors
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Permission request failed: ${e.toString()}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFFFF3B30),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }

          // Mark as requested to prevent infinite loop
          ref.read(permissionsRequestedProvider.notifier).state = true;
          return;
        }
      }

      if (mounted) {
        ref.read(isRequestingPermissionsProvider.notifier).state = false;

        if (permissionsGranted) {
          // DO NOT mark permissions as requested yet - wait for notification permissions screen

          if (!hasAllPermissions) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Health permissions granted successfully!',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Color(0xFF34C759),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }

          // Navigate to notification permissions screen after a short delay
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) =>
                          const NotificationPermissionsScreen(),
                    ),
                  )
                  .then((notificationGranted) {
                    // After notification permissions are handled, mark as requested
                    if (mounted) {
                      ref.read(permissionsRequestedProvider.notifier).state =
                          true;
                    }
                  });
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Permissions were denied. You can grant them later.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Color(0xFFFF9500),
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Still mark as requested even if some denied
          ref.read(permissionsRequestedProvider.notifier).state = true;
        }
      }
    } catch (e) {
      if (mounted) {
        ref.read(isRequestingPermissionsProvider.notifier).state = false;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error: ${e.toString()}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF3B30),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Mark as requested anyway to prevent infinite loop
        ref.read(permissionsRequestedProvider.notifier).state = true;
      }
    }
  }

  void _skipPermissions() {
    if (mounted) {
      // Mark permissions as requested (even if skipped)
      ref.read(permissionsRequestedProvider.notifier).state = true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.info, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You can enable permissions later in Health Sync.',
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF8E8E93),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // AuthWrapper will automatically navigate to dashboard
    }
  }
}
