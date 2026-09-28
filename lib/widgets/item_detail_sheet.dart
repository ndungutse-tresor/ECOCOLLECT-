import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dropoff_point.dart';
import '../models/ewaste_item.dart';
import '../services/ewaste_service.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../utils/launcher.dart';
import 'app_card.dart';
import 'photo_view.dart';
import 'status_chip.dart';

Future<void> showItemDetailSheet(BuildContext context, String itemId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ItemDetailSheet(itemId: itemId),
  );
}

class ItemDetailSheet extends StatelessWidget {
  final String itemId;

  const ItemDetailSheet({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<EwasteService>();
    final item = service.getItemById(itemId);
    if (item == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('This report is no longer available.')),
      );
    }

    final category = item.category;
    final point = item.dropoffPointId == null
        ? null
        : service.getPointById(item.dropoffPointId!);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(icon: category.icon, color: category.color, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Reported ${formatDateTime(item.createdAt)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(status: item.status),
              ],
            ),
            if (item.photoPath != null) ...[
              const SizedBox(height: 18),
              PhotoView(path: item.photoPath!, height: 190),
            ],
            const SizedBox(height: 18),
            _Section(
              children: [
                _DetailRow('Quantity',
                    '${item.quantity} item${item.quantity == 1 ? '' : 's'}'),
                _DetailRow('Est. weight', formatKg(item.estimatedWeightKg)),
                _DetailRow('Condition', item.condition.label),
                if (item.description != null && item.description!.isNotEmpty)
                  _DetailRow('Note', item.description!),
              ],
            ),
            const SizedBox(height: 12),
            if (item.disposalMethod == DisposalMethod.dropoff)
              _DropoffSection(point: point)
            else
              _PickupSection(pickup: item.pickup),
            const SizedBox(height: 22),
            const Text(
              'Progress',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _Timeline(item: item),
            const SizedBox(height: 16),
            _PointsBanner(item: item),
            if (item.isPending) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _confirmHandOver(context, item),
                icon: const Icon(Icons.task_alt_rounded),
                label: Text(
                  item.disposalMethod == DisposalMethod.dropoff
                      ? "I've dropped it off"
                      : 'Collector picked it up',
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => _cancel(context, item),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Cancel this report'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmHandOver(BuildContext context, EwasteItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final points =
        await context.read<EwasteService>().confirmHandOver(item.id);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Thank you! +$points EcoPoints credited to your balance.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _cancel(BuildContext context, EwasteItem item) async {
    final service = context.read<EwasteService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel report?'),
        content: const Text(
          'This report will be removed and its pending EcoPoints will not be credited.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel report'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    navigator.pop();
    await service.cancelItem(item.id);
    messenger.showSnackBar(const SnackBar(content: Text('Report cancelled.')));
  }
}

class _Section extends StatelessWidget {
  final List<Widget> children;

  const _Section({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropoffSection extends StatelessWidget {
  final DropoffPoint? point;

  const _DropoffSection({required this.point});

  @override
  Widget build(BuildContext context) {
    final point = this.point;
    if (point == null) return const SizedBox.shrink();
    return _Section(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              IconBadge(icon: point.typeIcon, color: point.typeColor, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${point.address} · ${point.operatingHours}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              OpenStatusChip(point: point),
              const Spacer(),
              TextButton.icon(
                onPressed: () => openDirections(context, point),
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: const Text('Directions'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickupSection extends StatelessWidget {
  final PickupDetails? pickup;

  const _PickupSection({required this.pickup});

  @override
  Widget build(BuildContext context) {
    final pickup = this.pickup;
    if (pickup == null) {
      return const _Section(children: [_DetailRow('Disposal', 'Home pickup')]);
    }
    return _Section(
      children: [
        const _DetailRow('Disposal', 'Home pickup'),
        _DetailRow('Address', pickup.address),
        _DetailRow('When', '${formatShortDay(pickup.date)}\n${pickup.timeSlot}'),
        if (pickup.phone.isNotEmpty) _DetailRow('Phone', pickup.phone),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  final EwasteItem item;

  const _Timeline({required this.item});

  @override
  Widget build(BuildContext context) {
    final dropoff = item.disposalMethod == DisposalMethod.dropoff;
    final steps = [
      (
        'Reported',
        formatDateTime(item.createdAt),
        true,
      ),
      (
        dropoff ? 'Dropped off' : 'Picked up',
        item.collectedAt != null
            ? formatDateTime(item.collectedAt!)
            : dropoff
                ? 'Waiting for you to drop it off'
                : 'A collector will call you to confirm',
        item.collectedAt != null,
      ),
      (
        'Recycled',
        item.recycledAt != null
            ? formatDateTime(item.recycledAt!)
            : 'Processed safely by a certified recycler',
        item.recycledAt != null,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            steps[i].$3 ? AppColors.primary : AppColors.surface,
                        border: Border.all(
                          color: steps[i].$3
                              ? AppColors.primary
                              : AppColors.border,
                          width: 2,
                        ),
                      ),
                      child: steps[i].$3
                          ? const Icon(Icons.check_rounded,
                              size: 15, color: Colors.white)
                          : null,
                    ),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: steps[i + 1].$3
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].$1,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: steps[i].$3
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          steps[i].$2,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PointsBanner extends StatelessWidget {
  final EwasteItem item;

  const _PointsBanner({required this.item});

  @override
  Widget build(BuildContext context) {
    final credited = item.isCredited;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: credited ? AppColors.accentSoft : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: credited
              ? AppColors.accent.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.stars_rounded,
            color: credited ? AppColors.accent : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              credited
                  ? '+${item.ecoPoints} EcoPoints credited'
                  : '+${item.ecoPoints} EcoPoints once handed over',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: credited ? AppColors.accentDark : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
