import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/ewaste_service.dart';
import '../services/shell_controller.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/app_logo.dart';
import '../widgets/sync_status.dart';
import 'ecopoints_screen.dart';
import '../widgets/server_settings.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openTab(BuildContext context, int tab) {
    context.read<ShellController>().goTo(tab);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _logout(BuildContext context) async {
    final service = context.read<EwasteService>();
    final waiting = service.unsyncedCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: Text(
          waiting > 0
              ? '$waiting change${waiting == 1 ? '' : 's'} have not reached the server yet and will be lost. Connect to the internet and sync first to keep them.'
              : 'Your reports, points and rewards stay safe in your account. Log in again any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await service.logout();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<EwasteService>();
    final profile = service.profile;
    final level = service.level;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.heroGradient,
                  ),
                  child: Text(
                    initialsOf(profile?.name ?? 'Eco'),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  profile?.name ?? 'Guest',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (profile != null) profile.district,
                    if (profile != null)
                      'Member since ${DateFormat('MMM yyyy').format(profile.memberSince)}',
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TagChip(
                  icon: level.icon,
                  label: '${level.name} level',
                  color: AppColors.primary,
                  background: AppColors.primarySoft,
                ),
                const SizedBox(height: 18),
                if (profile != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit profile'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                _ProfileStat(
                  value: formatNumber(service.ecoPoints),
                  label: 'EcoPoints',
                ),
                _ProfileStat(
                  value: formatKg(service.totalWeightKg),
                  label: 'Recycled',
                ),
                _ProfileStat(
                  value: '${service.items.length}',
                  label: 'Reports',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _MenuTile(
                  icon: Icons.redeem_rounded,
                  title: 'Rewards & vouchers',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EcoPointsScreen()),
                  ),
                ),
                _MenuTile(
                  icon: Icons.receipt_long_rounded,
                  title: 'My reports',
                  onTap: () => _openTab(context, ShellController.history),
                ),
                _MenuTile(
                  icon: Icons.map_rounded,
                  title: 'Drop-off map',
                  onTap: () => _openTab(context, ShellController.map),
                ),
                if (profile != null && profile.phone.isNotEmpty)
                  _MenuTile(
                    icon: Icons.phone_outlined,
                    title: profile.phone,
                    subtitle: 'Used by collectors for pickups',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconBadge(
                      icon: Icons.cloud_sync_rounded,
                      color: AppColors.primary,
                      size: 38,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Server connection',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SyncStatusChip(),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  service.syncEnabled
                      ? service.serverUrl
                      : 'Sync is off. Data stays on this device.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (service.syncStatus == SyncStatus.offline &&
                    service.syncError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    service.syncError!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.warning,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                        onPressed: () => showServerDialog(context),
                        child: const Text('Change server'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                        onPressed: service.syncEnabled ? service.sync : null,
                        child: const Text('Sync now'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _MenuTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About EcoCollect',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: AppStrings.appName,
                    applicationVersion: '1.0.0',
                    applicationIcon: const AppLogo(size: 52),
                    children: const [
                      SizedBox(height: 8),
                      Text(
                        'EcoCollect Rwanda makes e-waste recycling as easy as a tap: '
                        'report your old electronics, drop them off or book a pickup, '
                        'and earn EcoPoints for every item you hand over.',
                      ),
                    ],
                  ),
                ),
                _MenuTile(
                  icon: Icons.lock_reset_rounded,
                  title: 'Change password',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  ),
                ),
                _MenuTile(
                  icon: Icons.logout_rounded,
                  title: 'Log out',
                  color: AppColors.error,
                  onTap: () => _logout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;

  const _ProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color color;

  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.color = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: IconBadge(
        icon: icon,
        color: color == AppColors.textPrimary ? AppColors.primary : color,
        size: 38,
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
    );
  }
}
