import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/cash_reward.dart';
import '../../utils/constants.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../admin_service.dart';
import '../admin_widgets.dart';

enum _PayoutFilter { toPay, paid, rejected, all }

class PayoutsPage extends StatefulWidget {
  const PayoutsPage({super.key});

  @override
  State<PayoutsPage> createState() => _PayoutsPageState();
}

class _PayoutsPageState extends State<PayoutsPage> {
  _PayoutFilter _filter = _PayoutFilter.toPay;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminService>().snapshot!;

    List<AdminClaim> claimsFor(_PayoutFilter filter) => switch (filter) {
          _PayoutFilter.toPay => s.claimsToPay,
          _PayoutFilter.paid =>
            s.claims.where((c) => c.claim.status == ClaimStatus.paid).toList(),
          _PayoutFilter.rejected => s.claims
              .where((c) => c.claim.status == ClaimStatus.rejected)
              .toList(),
          _PayoutFilter.all => s.claims,
        };

    String label(_PayoutFilter filter) {
      final name = switch (filter) {
        _PayoutFilter.toPay => 'To pay',
        _PayoutFilter.paid => 'Paid',
        _PayoutFilter.rejected => 'Rejected',
        _PayoutFilter.all => 'All',
      };
      return '$name · ${claimsFor(filter).length}';
    }

    final claims = claimsFor(_filter);

    return AdminPage(
      children: [
        ResponsiveGrid(
          minTileWidth: 240,
          children: [
            KpiTile(
              icon: Icons.pending_actions_rounded,
              color: AppColors.warning,
              label: 'Owed to members',
              value: formatRwf(s.cashOwedRwf),
              detail: '${s.claimsToPay.length} open requests',
            ),
            KpiTile(
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              label: 'Paid out',
              value: formatRwf(s.cashPaidRwf),
              detail:
                  '${s.claims.where((c) => c.claim.status == ClaimStatus.paid).length} payments',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in _PayoutFilter.values)
              FilterPill(
                label: label(filter),
                selected: _filter == filter,
                onTap: () => setState(() => _filter = filter),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (claims.isEmpty)
          const EmptyPanel(
            icon: Icons.payments_outlined,
            message: 'No payout requests here.',
          )
        else
          for (final claim in claims) _ClaimCard(entry: claim),
      ],
    );
  }
}

class _ClaimCard extends StatelessWidget {
  final AdminClaim entry;

  const _ClaimCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final service = context.read<AdminService>();
    final s = context.watch<AdminService>().snapshot!;
    final claim = entry.claim;
    final member = s.member(entry.userId);
    final verifiedKg = s.statsFor(entry.userId).kg;
    final milestone = claim.milestone;
    final eligible = milestone == null || verifiedKg >= milestone.kg;

    Future<void> update(ClaimStatus status, String message,
            {String? reference, String? note}) =>
        runAction(
          context,
          () => service.updateClaim(
            claim.id,
            status,
            reference: reference,
            note: note,
          ),
          message,
        );

    Future<void> markPaid() async {
      final reference = await promptText(
        context,
        title: 'Mark ${formatRwf(claim.amountRwf)} as paid',
        label: 'Mobile Money transaction ID',
        message:
            'Send the money to ${claim.momoNumber} (${claim.provider}), then enter the transaction ID from the confirmation SMS.',
        confirm: 'Mark as paid',
        required: true,
      );
      if (reference == null || !context.mounted) return;
      await update(ClaimStatus.paid, 'Payout marked as paid',
          reference: reference);
    }

    Future<void> reject() async {
      final reason = await promptText(
        context,
        title: 'Reject this payout?',
        label: 'Reason shown to the member',
        confirm: 'Reject',
        required: true,
        destructive: true,
      );
      if (reason == null || !context.mounted) return;
      await update(ClaimStatus.rejected, 'Payout rejected', note: reason);
    }

    final (statusColor, statusBg) = switch (claim.status) {
      ClaimStatus.requested => (const Color(0xFFB45309), AppColors.warningSoft),
      ClaimStatus.approved => (const Color(0xFF0369A1), AppColors.skySoft),
      ClaimStatus.paid => (const Color(0xFF15803D), AppColors.successSoft),
      ClaimStatus.rejected => (const Color(0xFFB42318), AppColors.errorSoft),
    };

    final size = const Size(0, 40);
    final actions = <Widget>[
      if (claim.status == ClaimStatus.requested)
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: size),
          onPressed: () => update(ClaimStatus.approved, 'Payout approved'),
          child: const Text('Approve'),
        ),
      if (claim.status == ClaimStatus.approved)
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: size,
            backgroundColor: AppColors.success,
          ),
          onPressed: markPaid,
          icon: const Icon(Icons.send_to_mobile_rounded, size: 18),
          label: const Text('Mark as paid'),
        ),
      if (claim.isOpen)
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: size,
            foregroundColor: AppColors.error,
          ),
          onPressed: reject,
          child: const Text('Reject'),
        ),
    ];

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              formatRwf(claim.amountRwf),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            TagChip(
              label: claim.status.label,
              color: statusColor,
              background: statusBg,
            ),
            if (milestone != null)
              TagChip(
                icon: eligible ? Icons.verified_rounded : Icons.warning_rounded,
                label: '${milestone.kg.round()} kg milestone · '
                    '${formatKg(verifiedKg)} verified',
                color: eligible ? AppColors.primary : AppColors.error,
                background:
                    eligible ? AppColors.primarySoft : AppColors.errorSoft,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${member?.name ?? 'Unknown member'} · ${member?.district ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: SelectableText(
                '${claim.provider} · ${claim.momoNumber}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            IconButton(
              tooltip: 'Copy number',
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: claim.momoNumber)),
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ),
        Text(
          'Requested ${formatDateTime(claim.requestedAt)}'
          '${claim.reference == null ? '' : ' · Ref ${claim.reference}'}'
          '${claim.note == null ? '' : ' · ${claim.note}'}',
          style:
              const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      ],
    );

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final badge = IconBadge(
            icon: Icons.payments_rounded,
            color: statusColor,
            size: 46,
          );
          if (constraints.maxWidth >= 760) {
            return Row(
              children: [
                badge,
                const SizedBox(width: 14),
                Expanded(child: details),
                const SizedBox(width: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  badge,
                  const SizedBox(width: 14),
                  Expanded(child: details),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          );
        },
      ),
    );
  }
}
