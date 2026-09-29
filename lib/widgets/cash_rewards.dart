import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/cash_reward.dart';
import '../services/ewaste_service.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import 'app_card.dart';

/// Mobile Money milestones: progress, claim buttons and payout status.
class CashRewardsCard extends StatelessWidget {
  final EwasteService service;

  const CashRewardsCard({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final kg = service.totalWeightKg;
    final next = service.nextCashMilestone;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.payments_rounded,
                color: AppColors.success,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${formatKg(kg)} verified',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      next == null
                          ? 'You reached every milestone. Amazing!'
                          : '${formatKg(next.kg - kg)} more to earn ${formatRwf(next.amountRwf)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (service.cashPaidRwf > 0)
                TagChip(
                  label: '${formatRwf(service.cashPaidRwf)} paid',
                  color: const Color(0xFF15803D),
                  background: AppColors.successSoft,
                ),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (kg / next.kg).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.surfaceMuted,
                color: AppColors.success,
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (final milestone in CashMilestone.all) ...[
            const Divider(),
            _MilestoneRow(milestone: milestone, service: service),
          ],
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final CashMilestone milestone;
  final EwasteService service;

  const _MilestoneRow({required this.milestone, required this.service});

  @override
  Widget build(BuildContext context) {
    final kg = service.totalWeightKg;
    final reached = kg >= milestone.kg;
    final claim = service.latestClaimFor(milestone);
    final canClaim = service.canClaimCash(milestone);
    const green = Color(0xFF15803D);

    String subtitle;
    Widget trailing;
    if (!reached) {
      subtitle = '${formatKg(milestone.kg - kg)} to go';
      trailing = const Icon(
        Icons.lock_outline_rounded,
        color: AppColors.textMuted,
      );
    } else if (canClaim) {
      final note = claim?.note;
      subtitle = claim?.status == ClaimStatus.rejected
          ? 'Last claim not approved${note == null ? '' : ': $note'}'
          : 'Unlocked · ready to claim';
      trailing = FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          backgroundColor: AppColors.success,
        ),
        onPressed: () => showClaimSheet(context, milestone),
        child: const Text('Claim'),
      );
    } else {
      final c = claim!;
      switch (c.status) {
        case ClaimStatus.requested:
          subtitle =
              'Requested ${timeAgo(c.requestedAt).toLowerCase()} · ${c.provider}';
          trailing = const TagChip(
            label: 'Requested',
            color: Color(0xFFB45309),
            background: AppColors.warningSoft,
          );
        case ClaimStatus.approved:
          subtitle = 'Approved · payment on its way to ${c.momoNumber}';
          trailing = const TagChip(
            label: 'Approved',
            color: Color(0xFF0369A1),
            background: AppColors.skySoft,
          );
        case ClaimStatus.paid:
          final ref = c.reference;
          subtitle =
              'Sent to ${c.momoNumber}${ref == null ? '' : ' · Ref $ref'}';
          trailing = const TagChip(
            icon: Icons.check_circle_rounded,
            label: 'Paid',
            color: green,
            background: AppColors.successSoft,
          );
        case ClaimStatus.rejected:
          subtitle = c.note ?? 'Not approved';
          trailing = const TagChip(
            label: 'Rejected',
            color: Color(0xFFB42318),
            background: AppColors.errorSoft,
          );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: reached ? AppColors.successSoft : AppColors.surfaceMuted,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${milestone.kg.round()}',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: reached ? green : AppColors.textSecondary,
                  ),
                ),
                Text(
                  'kg',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: reached ? green : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatRwf(milestone.amountRwf),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
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
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

Future<void> showClaimSheet(BuildContext context, CashMilestone milestone) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ClaimSheet(milestone: milestone),
  );
}

class _ClaimSheet extends StatefulWidget {
  final CashMilestone milestone;

  const _ClaimSheet({required this.milestone});

  @override
  State<_ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends State<_ClaimSheet> {
  late final TextEditingController _phone;
  String _provider = CashClaim.providers.first;
  bool _submitting = false;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(
      text: context.read<EwasteService>().profile?.phone ?? '',
    );
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!isValidRwandaPhone(_phone.text)) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _submitting = true);
    final service = context.read<EwasteService>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final claim = await service.claimCash(
      widget.milestone,
      momoNumber: _phone.text,
      provider: _provider,
    );
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: claim == null ? null : AppColors.primary,
        content: Text(
          claim == null
              ? 'This reward cannot be claimed right now.'
              : 'Payout requested! Track it under Cash rewards.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.milestone;
    final phoneInvalid = _showErrors && !isValidRwandaPhone(_phone.text);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Claim ${formatRwf(m.amountRwf)}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'For handing over ${m.kg.round()} kg of e-waste. The EcoCollect team checks your claim, then sends the money to your Mobile Money account.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Pay to', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final provider in CashClaim.providers) ...[
                  Expanded(
                    child: _ProviderOption(
                      label: provider,
                      selected: provider == _provider,
                      onTap: () => setState(() => _provider = provider),
                    ),
                  ),
                  if (provider != CashClaim.providers.last)
                    const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Mobile Money number',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
              ],
              decoration: InputDecoration(
                hintText: '07X XXX XXXX',
                prefixIcon: const Icon(Icons.phone_android_rounded),
                errorText:
                    phoneInvalid ? 'Enter a valid Rwandan mobile number' : null,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Request payout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ProviderOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      shadow: null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      color: selected ? AppColors.primarySoft : AppColors.surface,
      border: Border.all(
        color: selected ? AppColors.primary : AppColors.border,
        width: selected ? 1.8 : 1,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? AppColors.primary : AppColors.textMuted,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
