import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../providers/notification_permission_provider.dart';

class NotificationPermissionsScreen extends ConsumerStatefulWidget {
  const NotificationPermissionsScreen({super.key});

  @override
  ConsumerState<NotificationPermissionsScreen> createState() =>
      _NotificationPermissionsScreenState();
}

class _NotificationPermissionsScreenState
    extends ConsumerState<NotificationPermissionsScreen> {
  @override
  Widget build(BuildContext context) {
    final isRequestingPermissions = ref.watch(
      isRequestingNotificationPermissionsProvider,
    );

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
                    color: const Color(0xFFFF9500).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    size: 64,
                    color: Color(0xFFFF9500),
                  ),
                ),

                const SizedBox(height: 32),

                const Text(
                  'Stay Updated',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                const Text(
                  'Enable notifications to receive reminders about your health check-ups, medication schedules, and important health alerts.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8E8E93),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Notification features info
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
                      _buildNotificationFeature(
                        icon: Icons.schedule,
                        title: 'Health Reminders',
                        description:
                            'Get timely reminders for vital sign measurements',
                        color: const Color(0xFF007AFF),
                      ),
                      const SizedBox(height: 24),
                      _buildNotificationFeature(
                        icon: Icons.medication,
                        title: 'Medication Alerts',
                        description: 'Never miss your scheduled medications',
                        color: const Color(0xFF34C759),
                      ),
                      const SizedBox(height: 24),
                      _buildNotificationFeature(
                        icon: Icons.warning,
                        title: 'Health Alerts',
                        description:
                            'Important notifications about your health status',
                        color: const Color(0xFFFF3B30),
                      ),
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
                      Icon(Icons.lock, color: Color(0xFF34C759), size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Notifications are sent only to your device and respect your privacy preferences.',
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
                            : _requestNotificationPermission,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9500),
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
                            : const Text(
                                'Enable Notifications',
                                style: TextStyle(
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
                            : _skipNotifications,
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

  Widget _buildNotificationFeature({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _requestNotificationPermission() async {
    ref.read(isRequestingNotificationPermissionsProvider.notifier).state = true;

    try {
      final status = await ref
          .read(notificationPermissionProvider.notifier)
          .requestNotificationPermission();

      if (mounted) {
        ref.read(isRequestingNotificationPermissionsProvider.notifier).state =
            false;

        if (status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notifications enabled successfully!',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF34C759),
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Navigate to dashboard after a short delay
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                Navigator.of(context).pop(true);
              }
            });
          }
        } else if (status.isDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notifications disabled. You can enable them later in settings.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF8E8E93),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );

          // Auto-dismiss after showing message and navigate
          Future.delayed(const Duration(milliseconds: 2500), () {
            if (mounted) {
              Navigator.of(context).pop(false);
            }
          });
        } else if (status.isPermanentlyDenied) {
          // Open app settings if permanently denied
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notifications are permanently disabled. Please enable in app settings.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFFF9500),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () {
                  ref
                      .read(notificationPermissionProvider.notifier)
                      .openSettings();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ref.read(isRequestingNotificationPermissionsProvider.notifier).state =
            false;

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
      }
    }
  }

  void _skipNotifications() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.info, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You can enable notifications later in settings.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF8E8E93),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.of(context).pop(false);
        }
      });
    }
  }
}
