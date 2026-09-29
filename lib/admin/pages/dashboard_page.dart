import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/constants.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../admin_service.dart';
import '../admin_widgets.dart';

class DashboardPage extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const DashboardPage({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminService>().snapshot!;
    final toVerify = s.toVerify;
    final pickups = s.pickupsToDo;
    final activeMembers =
        s.members.keys.where((id) => s.statsFor(id).kg > 0).length;

    final attention = toVerify.take(5).toList();

    return AdminPage(
      children: [
        ResponsiveGrid(
          minTileWidth: 210,
          children: [
            KpiTile(
              icon: Icons.scale_rounded,
              color: AppColors.primary,
              label: 'Verified e-waste',
              value: formatKg(s.totalKg),
              detail: '${formatKg(s.co2Kg)} CO₂ avoided',
            ),
            KpiTile(
              icon: Icons.fact_check_rounded,
              color: AppColors.warning,
              label: 'Reports to verify',
              value: '${toVerify.length}',
              detail: '${s.awaitingVerificationCount} already handed over',
              onTap: () => onNavigate(1),
            ),
            KpiTile(
              icon: Icons.local_shipping_rounded,
              color: AppColors.sky,
              label: 'Pickups to do',
              value: '${pickups.length}',
              detail: pickups.isEmpty
                  ? 'Nothing scheduled'
                  : 'Next: ${formatShortDay(pickups.first.item.pickup!.date)}',
              onTap: () => onNavigate(2),
            ),
            KpiTile(
              icon: Icons.payments_rounded,
              color: AppColors.purple,
              label: 'Cash payouts due',
              value: formatRwf(s.cashOwedRwf),
              detail:
                  '${s.claimsToPay.length} requests · ${formatRwf(s.cashPaidRwf)} paid',
              onTap: () => onNavigate(3),
            ),
            KpiTile(
              icon: Icons.people_alt_rounded,
              color: AppColors.success,
              label: 'Members',
              value: '${s.members.length}',
              detail: '$activeMembers with verified recycling',
              onTap: () => onNavigate(4),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final needsAttention = AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PanelTitle(
                    title: 'Needs attention',
                    subtitle: 'Oldest reports first; handed-over items on top',
                    trailing: TextButton(
                      onPressed: () => onNavigate(1),
                      child: const Text('All reports'),
                    ),
                  ),
                  if (attention.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'All caught up. No reports waiting.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    for (final report in attention)
                      _AttentionRow(report: report),
                ],
              ),
            );

            final charts = Column(
              children: [
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PanelTitle(
                        title: 'Verified by district',
                        subtitle: 'Kilograms handed over',
                      ),
                      BarList(
                        format: formatKg,
                        rows: [
                          for (final e in s.kgByDistrict.entries)
                            (e.key, e.value, null),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PanelTitle(
                        title: 'Verified by category',
                        subtitle: 'Kilograms handed over',
                      ),
                      BarList(
                        format: formatKg,
                        rows: [
                          for (final e in s.kgByCategory)
                            (
                              e.key.name,
                              e.value,
                              IconBadge(
                                icon: e.key.icon,
                                color: e.key.color,
                                size: 32,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

            if (constraints.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: needsAttention),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: charts),
                ],
              );
            }
            return Column(
              children: [needsAttention, const SizedBox(height: 16), charts],
            );
          },
        ),
      ],
    );
  }
}

class _AttentionRow extends StatelessWidget {
  final AdminReport report;

  const _AttentionRow({required this.report});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminService>().snapshot!;
    final item = report.item;
    final member = s.member(report.userId);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showReportDetails(context, report),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            IconBadge(
              icon: item.category.icon,
              color: item.category.color,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.categoryName} · ${formatKg(item.estimatedWeightKg)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${member?.name ?? 'Unknown'} · ${report.handOverLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (item.awaitingVerification)
              const TagChip(
                label: 'Handed over',
                color: Color(0xFFB45309),
                background: AppColors.warningSoft,
              )
            else
              Text(
                timeAgo(item.createdAt),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            if (MediaQuery.sizeOf(context).width >= 760) ...[
              const SizedBox(width: 8),
              ReportActions(report: report, compact: true),
            ],
          ],
        ),
      ),
    );
  }
}
