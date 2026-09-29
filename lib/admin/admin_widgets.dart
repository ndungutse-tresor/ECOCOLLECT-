import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/ewaste_item.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/photo_view.dart';
import '../widgets/status_chip.dart';
import 'admin_service.dart';

/// Scrollable page body with a comfortable max width.
class AdminPage extends StatelessWidget {
  final List<Widget> children;

  const AdminPage({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

/// Lays children out in as many equal columns as fit.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final double spacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 220,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minTileWidth)
            .floor()
            .clamp(1, children.length);
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class KpiTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? detail;
  final VoidCallback? onTap;

  const KpiTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.detail,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, color: color, size: 40),
              const Spacer(),
              if (onTap != null)
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PanelTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const PanelTitle(
      {super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyPanel({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Filter pill used across admin pages.
class FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.textPrimary : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.textPrimary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Runs an admin action and reports the outcome in a snackbar.
Future<void> runAction(
  BuildContext context,
  Future<String?> Function() action,
  String success,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final error = await action();
  messenger.showSnackBar(
    SnackBar(
      content: Text(error ?? success),
      backgroundColor: error == null ? AppColors.primary : AppColors.error,
    ),
  );
}

/// Asks for a line of text. Returns null when cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  required String confirm,
  String? message,
  bool required = false,
  bool destructive = false,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final canSubmit = !required || controller.text.trim().isNotEmpty;
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message != null) ...[
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: label),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: destructive ? AppColors.error : null,
              ),
              onPressed: canSubmit
                  ? () => Navigator.pop(ctx, controller.text.trim())
                  : null,
              child: Text(confirm),
            ),
          ],
        );
      },
    ),
  );
}

/// Buttons that move a report through its lifecycle.
class ReportActions extends StatelessWidget {
  final AdminReport report;
  final bool compact;

  const ReportActions({super.key, required this.report, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final service = context.read<AdminService>();
    final item = report.item;
    final size = Size(0, compact ? 38 : 44);
    final pickup = item.disposalMethod == DisposalMethod.pickup;

    Future<void> setStatus(ItemStatus status, String message, {String? note}) =>
        runAction(
          context,
          () => service.setReportStatus(item.id, status, note: note),
          message,
        );

    Future<void> reject() async {
      final reason = await promptText(
        context,
        title: 'Reject this report?',
        label: 'Reason shown to the member (optional)',
        message: 'No EcoPoints will be credited.',
        confirm: 'Reject',
        destructive: true,
      );
      if (reason == null || !context.mounted) return;
      await setStatus(
        ItemStatus.rejected,
        'Report rejected',
        note: reason.isEmpty ? null : reason,
      );
    }

    final buttons = <Widget>[];
    switch (item.status) {
      case ItemStatus.pending:
        buttons.addAll([
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: size),
            onPressed: () => setStatus(
              ItemStatus.collected,
              '+${item.ecoPoints} EcoPoints credited to the member',
            ),
            icon: const Icon(Icons.verified_rounded, size: 18),
            label: Text(pickup ? 'Picked up' : 'Verify'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              foregroundColor: AppColors.error,
            ),
            onPressed: reject,
            child: const Text('Reject'),
          ),
        ]);
      case ItemStatus.collected:
        buttons.addAll([
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: size),
            onPressed: () =>
                setStatus(ItemStatus.recycled, 'Marked as recycled'),
            icon: const Icon(Icons.recycling_rounded, size: 18),
            label: const Text('Mark recycled'),
          ),
          TextButton(
            onPressed: () =>
                setStatus(ItemStatus.pending, 'Moved back to pending'),
            child: const Text('Undo'),
          ),
        ]);
      case ItemStatus.recycled:
        break;
      case ItemStatus.rejected:
        buttons.add(
          TextButton(
            onPressed: () => setStatus(ItemStatus.pending, 'Report restored'),
            child: const Text('Restore'),
          ),
        );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: buttons,
    );
  }
}

class ReportCard extends StatelessWidget {
  final AdminReport report;

  const ReportCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<AdminService>().snapshot!;
    final item = report.item;
    final member = snapshot.member(report.userId);
    final category = item.category;

    final summary = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBadge(icon: category.icon, color: category.color, size: 46),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  StatusChip(status: item.status),
                  if (item.awaitingVerification)
                    TagChip(
                      icon: Icons.front_hand_rounded,
                      label:
                          'Handed over ${timeAgo(item.userConfirmedAt!).toLowerCase()}',
                      color: const Color(0xFFB45309),
                      background: AppColors.warningSoft,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${item.quantity} item${item.quantity == 1 ? '' : 's'} · '
                '${formatKg(item.estimatedWeightKg)} · ${item.ecoPoints} pts · '
                'reported ${timeAgo(item.createdAt).toLowerCase()}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _InfoLine(
                icon: Icons.person_outline_rounded,
                text: member == null
                    ? 'Unknown member'
                    : '${member.name}${member.phone.isEmpty ? '' : ' · ${member.phone}'}',
              ),
              _InfoLine(
                icon: item.disposalMethod == DisposalMethod.pickup
                    ? Icons.local_shipping_outlined
                    : Icons.place_outlined,
                text: item.disposalMethod == DisposalMethod.pickup &&
                        item.pickup != null
                    ? 'Pickup ${formatShortDay(item.pickup!.date)}, '
                        '${item.pickup!.timeSlot.split(' · ').first.toLowerCase()} · '
                        '${item.pickup!.address}'
                    : report.handOverLabel,
              ),
            ],
          ),
        ),
      ],
    );

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => showReportDetails(context, report),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: summary),
                const SizedBox(width: 16),
                ReportActions(report: report, compact: true),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              summary,
              const SizedBox(height: 12),
              ReportActions(report: report, compact: true),
            ],
          );
        },
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

Future<void> showReportDetails(BuildContext context, AdminReport report) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ReportDialog(reportId: report.item.id),
  );
}

class _ReportDialog extends StatelessWidget {
  final String reportId;

  const _ReportDialog({required this.reportId});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AdminService>();
    final snapshot = service.snapshot;
    AdminReport? report;
    for (final r in snapshot?.reports ?? const <AdminReport>[]) {
      if (r.item.id == reportId) report = r;
    }
    if (report == null) {
      return const AlertDialog(content: Text('This report no longer exists.'));
    }
    final item = report.item;
    final member = snapshot!.member(report.userId);
    final pickup = item.pickup;

    Widget row(String label, String value, {bool copy = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  label,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: SelectableText(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (copy)
                IconButton(
                  tooltip: 'Copy',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: value)),
                  icon: const Icon(Icons.copy_rounded),
                ),
            ],
          ),
        );

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconBadge(
                    icon: item.category.icon,
                    color: item.category.color,
                    size: 52,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.categoryName,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  StatusChip(status: item.status),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (item.photoUrl != null) ...[
                const SizedBox(height: 16),
                PhotoView(
                  path: service.photoUrl(item.photoUrl!),
                  height: 240,
                ),
              ],
              const SizedBox(height: 16),
              row('Quantity', '${item.quantity}'),
              row('Estimated weight', formatKg(item.estimatedWeightKg)),
              row('Condition', item.condition.label),
              row('EcoPoints', '${item.ecoPoints}'),
              if (item.description?.isNotEmpty == true)
                row('Member note', item.description!),
              const Divider(height: 24),
              row('Member', member?.name ?? 'Unknown'),
              if (member != null && member.phone.isNotEmpty)
                row('Phone', member.phone, copy: true),
              if (member != null) row('District', member.district),
              const Divider(height: 24),
              if (pickup != null) ...[
                row('Pickup address', pickup.address, copy: true),
                row('Pickup time',
                    '${formatShortDay(pickup.date)} · ${pickup.timeSlot}'),
                if (pickup.phone.isNotEmpty)
                  row('Pickup phone', pickup.phone, copy: true),
              ] else
                row('Drop-off point', report.handOverLabel),
              row('Reported', formatDateTime(item.createdAt)),
              if (item.userConfirmedAt != null)
                row('Member handed over',
                    formatDateTime(item.userConfirmedAt!)),
              if (item.collectedAt != null)
                row('Verified', formatDateTime(item.collectedAt!)),
              if (item.recycledAt != null)
                row('Recycled', formatDateTime(item.recycledAt!)),
              if (item.adminNote?.isNotEmpty == true)
                row('Admin note', item.adminNote!),
              const SizedBox(height: 18),
              ReportActions(report: report),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal single-hue bars with text labels.
class BarList extends StatelessWidget {
  final List<(String label, double value, Widget? leading)> rows;
  final String Function(double) format;

  const BarList({super.key, required this.rows, required this.format});

  @override
  Widget build(BuildContext context) {
    final max = rows.fold(0.0, (m, r) => r.$2 > m ? r.$2 : m);
    if (max == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Nothing verified yet.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return Column(
      children: [
        for (final (label, value, leading) in rows)
          Tooltip(
            message: '$label: ${format(value)}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  if (leading != null) ...[leading, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              format(value),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LayoutBuilder(
                          builder: (context, c) => Stack(
                            children: [
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              Container(
                                height: 8,
                                width: value == 0
                                    ? 0
                                    : (c.maxWidth * value / max)
                                        .clamp(4.0, c.maxWidth),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
