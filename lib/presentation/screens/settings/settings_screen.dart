import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../profile/profile_screen.dart';
import '../../../services/export_service.dart';
import 'sync_settings_screen.dart';
import 'package:phr_app/l10n/app_localizations.dart';
import '../vendors/vendor_selection_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final locale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: const TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserProfileCard(context, authState.user),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    context,
                    title: 'Health & Privacy',
                    items: [
                      _buildSettingItem(
                        context,
                        title: 'Data Export',
                        subtitle: 'Export your health records',
                        icon: Icons.download_outlined,
                        color: const Color(0xFF2ECC71),
                        onTap: () => _exportData(context, ref),
                      ),
                      _buildSettingItem(
                        context,
                        title: 'Sync Settings',
                        subtitle: 'Configure automatic syncing',
                        icon: Icons.sync_rounded,
                        color: const Color(0xFF3498DB),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SyncSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        context,
                        title: 'Wearable Sources',
                        subtitle: 'Manage Fitbit connection',
                        icon: Icons.watch_outlined,
                        color: const Color(0xFFF1C40F),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const VendorSelectionScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    context,
                    title: 'App Preferences',
                    items: [
                      _buildSettingItem(
                        context,
                        title: l10n.languageSettings,
                        subtitle: locale.languageCode == 'id'
                            ? l10n.indonesian
                            : l10n.english,
                        icon: Icons.language_rounded,
                        color: const Color(0xFF2ECC71),
                        onTap: () => _showLanguageDialog(context, ref, l10n),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    context,
                    title: 'Support',
                    items: [
                      _buildSettingItem(
                        context,
                        title: 'Help Center',
                        subtitle: 'Get help and support',
                        icon: Icons.help_outline_rounded,
                        color: const Color(0xFF3498DB),
                        onTap: () {},
                      ),
                      _buildSettingItem(
                        context,
                        title: 'Contact Us',
                        subtitle: 'Send feedback or report issues',
                        icon: Icons.mail_outline_rounded,
                        color: const Color(0xFF2ECC71),
                        onTap: () {},
                      ),
                      _buildSettingItem(
                        context,
                        title: 'About',
                        subtitle: 'App version and legal info',
                        icon: Icons.info_outline_rounded,
                        color: Colors.grey,
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          _buildLogoutSection(context, ref),
        ],
      ),
    );
  }

  Widget _buildUserProfileCard(BuildContext context, dynamic user) {
    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2ECC71).withValues(alpha: 0.2), width: 4),
              ),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                child: Text(
                  (user?.name ?? 'U').isNotEmpty
                      ? (user?.name ?? 'U')[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2ECC71),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? 'User',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'user@example.com',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context, {
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade500,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2C3E50),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: Colors.grey.shade300,
      ),
    );
  }

  Widget _buildLogoutSection(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final shouldLogout =
                  await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF3B30),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  ) ??
                  false;

              if (shouldLogout) {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEF2F2),
              foregroundColor: const Color(0xFFE74C3C),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFFEE2E2)),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Preparing export...')),
    );

    try {
      final user = ref.read(authProvider).user;
      final exporter = ExportService();
      final path = await exporter.exportToPdf(
        userName: user?.name,
        userEmail: user?.email,
      );
      messenger.showSnackBar(SnackBar(content: Text('Exported to PDF: $path')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to export data: $e')),
      );
    }
  }

  void _showLanguageDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final currentLocale = ref.read(localeProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'en', label: Text(l10n.english)),
                ButtonSegment(value: 'id', label: Text(l10n.indonesian)),
              ],
              selected: {currentLocale.languageCode},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                final value = selection.first;
                ref.read(localeProvider.notifier).setLocale(Locale(value));
                Navigator.pop(context);
              },
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
