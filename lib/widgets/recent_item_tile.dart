import 'package:flutter/material.dart';
import '../models/ewaste_item.dart';
import '../services/ewaste_service.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import 'app_card.dart';
import 'item_detail_sheet.dart';
import 'status_chip.dart';

class RecentItemTile extends StatelessWidget {
  final EwasteItem item;
  final EwasteService service;

  /// Also shows where the item goes and the points it is worth.
  final bool detailed;

  const RecentItemTile({
    super.key,
    required this.item,
    required this.service,
    this.detailed = false,
  });

  @override
  Widget build(BuildContext context) {
    final category = item.category;
    final point = item.dropoffPointId == null
        ? null
        : service.getPointById(item.dropoffPointId!);

    return AppCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      onTap: () => showItemDetailSheet(context, item.id),
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(icon: category.icon, color: category.color, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.quantity} item${item.quantity == 1 ? '' : 's'} · '
                      '${formatKg(item.estimatedWeightKg)} · ${timeAgo(item.createdAt)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(status: item.status),
            ],
          ),
          if (detailed) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  item.disposalMethod == DisposalMethod.dropoff
                      ? Icons.place_outlined
                      : Icons.local_shipping_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.disposalMethod == DisposalMethod.dropoff
                        ? point?.name ?? 'Drop-off point'
                        : 'Home pickup',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Icon(
                  Icons.stars_rounded,
                  size: 16,
                  color:
                      item.isCredited ? AppColors.accent : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  item.isCredited
                      ? '+${item.ecoPoints} pts'
                      : '${item.ecoPoints} pts pending',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: item.isCredited
                        ? AppColors.accentDark
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
