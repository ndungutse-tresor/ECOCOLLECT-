import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/reward.dart';
import '../services/ewaste_service.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/cash_rewards.dart';

class EcoPointsScreen extends StatelessWidget {
  const EcoPointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<EwasteService>();
    final redemptions = service.redemptions;

    return Scaffold(
      appBar: AppBar(title: const Text('EcoPoints & rewards')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _BalanceCard(service: service),
          const SectionHeader(
            title: 'Cash rewards',
            subtitle: 'Recycle a lot and get paid to Mobile Money',
            padding: EdgeInsets.fromLTRB(4, 26, 4, 12),
          ),
          CashRewardsCard(service: service),
          const SectionHeader(
            title: 'Rewards',
            subtitle: 'Swap your points for something good',
            padding: EdgeInsets.fromLTRB(4, 26, 4, 12),
          ),
          for (final (i, reward) in Reward.catalog.indexed)
            _RewardCard(reward: reward, balance: service.ecoPoints)
                .animate()
                .fadeIn(delay: (60 * i).ms, duration: 300.ms)
                .slideY(begin: 0.1),
          if (redemptions.isNotEmpty) ...[
            const SectionHeader(
              title: 'My vouchers',
              subtitle: 'Tap a code to copy it',
              padding: EdgeInsets.fromLTRB(4, 26, 4, 12),
            ),
            for (final redemption in redemptions)
              _VoucherTile(redemption: redemption),
          ],
          const SectionHeader(
            title: 'How to earn',
            padding: EdgeInsets.fromLTRB(4, 26, 4, 12),
          ),
          const AppCard(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                _EarnRow(
                  icon: Icons.scale_rounded,
                  title: 'Recycle by weight',
                  subtitle: '10 points per kilogram handed over',
                  points: '+10/kg',
                ),
                Divider(),
                _EarnRow(
                  icon: Icons.devices_other_rounded,
                  title: 'Hand over items',
                  subtitle: '5 points for every item',
                  points: '+5/item',
                ),
                Divider(),
                _EarnRow(
                  icon: Icons.people_alt_rounded,
                  title: 'Refer friends',
                  subtitle: '25 points when a friend joins',
                  points: '+25',
                  comingSoon: true,
                ),
                Divider(),
                _EarnRow(
                  icon: Icons.event_available_rounded,
                  title: 'Weekly streak',
                  subtitle: 'Recycle 4 weeks in a row',
                  points: '+50',
                  comingSoon: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final EwasteService service;

  const _BalanceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final level = service.level;
    final next = EcoLevel.nextAfter(level);
    final progress = EcoLevel.progress(service.earnedPoints);

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Icon(
              Icons.stars_rounded,
              size: 170,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Available balance',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(level.icon, size: 15, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            level.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Icon(Icons.stars_rounded,
                        color: AppColors.accentLight, size: 34),
                    const SizedBox(width: 8),
                    Text(
                      formatNumber(service.ecoPoints),
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'pts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    color: AppColors.accentLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  next == null
                      ? 'You reached the top level: ${level.name}!'
                      : '${next.minPoints - service.earnedPoints} more points to reach ${next.name}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Divider(color: Colors.white.withValues(alpha: 0.2)),
                ),
                Row(
                  children: [
                    _MiniStat(
                      label: 'Earned',
                      value: formatNumber(service.earnedPoints),
                    ),
                    _MiniStat(
                      label: 'Pending',
                      value: formatNumber(service.pendingPoints),
                    ),
                    _MiniStat(
                      label: 'Spent',
                      value: formatNumber(service.spentPoints),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final Reward reward;
  final int balance;

  const _RewardCard({required this.reward, required this.balance});

  Future<void> _redeem(BuildContext context) async {
    final service = context.read<EwasteService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Redeem ${reward.title}?'),
        content: Text(
          '${reward.cost} EcoPoints will be deducted from your balance. '
          'You will have ${balance - reward.cost} points left.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final redemption = await service.redeem(reward);
    if (!context.mounted) return;
    if (redemption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough EcoPoints for this reward.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => _VoucherDialog(reward: reward, code: redemption.code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final affordable = balance >= reward.cost;
    final missing = reward.cost - balance;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: reward.icon, color: reward.color, size: 50),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reward.description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TagChip(
                      icon: Icons.stars_rounded,
                      label: '${reward.cost} pts',
                      color: AppColors.accentDark,
                      background: AppColors.accentSoft,
                    ),
                    const Spacer(),
                    if (affordable)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          textStyle: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: () => _redeem(context),
                        child: const Text('Redeem'),
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded,
                              size: 15, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '$missing more pts',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (!affordable) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (balance / reward.cost).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceMuted,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherDialog extends StatelessWidget {
  final Reward reward;
  final String code;

  const _VoucherDialog({required this.reward, required this.code});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon: reward.icon, color: reward.color, size: 72)
              .animate()
              .scale(
                begin: const Offset(0.6, 0.6),
                curve: Curves.elasticOut,
                duration: 700.ms,
              ),
          const SizedBox(height: 18),
          const Text(
            'Enjoy your reward!',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Show this code to claim your ${reward.title.toLowerCase()}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),
          _CodeBox(code: code),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}

class _CodeBox extends StatelessWidget {
  final String code;

  const _CodeBox({required this.code});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voucher code copied')),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _VoucherTile extends StatelessWidget {
  final Redemption redemption;

  const _VoucherTile({required this.redemption});

  @override
  Widget build(BuildContext context) {
    final reward = redemption.reward;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () {
        Clipboard.setData(ClipboardData(text: redemption.code));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copied ${redemption.code}')),
        );
      },
      child: Row(
        children: [
          IconBadge(
            icon: reward?.icon ?? Icons.redeem_rounded,
            color: reward?.color ?? AppColors.primary,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward?.title ?? 'Reward',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${formatDate(redemption.redeemedAt)} · ${redemption.cost} pts',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            redemption.code,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.copy_rounded, size: 16, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _EarnRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String points;
  final bool comingSoon;

  const _EarnRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.points,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          IconBadge(icon: icon, color: AppColors.primary, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (comingSoon) ...[
                      const SizedBox(width: 6),
                      const TagChip(
                        label: 'Soon',
                        color: AppColors.textSecondary,
                        background: AppColors.surfaceMuted,
                      ),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            points,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.accentDark,
            ),
          ),
        ],
      ),
    );
  }
}
