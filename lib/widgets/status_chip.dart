import 'package:flutter/material.dart';
import '../models/ewaste_item.dart';
import '../models/dropoff_point.dart';
import '../utils/constants.dart';
import 'app_card.dart';

class StatusStyle {
  final Color foreground;
  final Color background;
  final IconData icon;

  const StatusStyle(this.foreground, this.background, this.icon);

  static StatusStyle of(ItemStatus status) {
    switch (status) {
      case ItemStatus.pending:
        return const StatusStyle(
          Color(0xFFB45309),
          AppColors.warningSoft,
          Icons.schedule_rounded,
        );
      case ItemStatus.collected:
        return const StatusStyle(
          Color(0xFF0369A1),
          AppColors.skySoft,
          Icons.local_shipping_rounded,
        );
      case ItemStatus.recycled:
        return const StatusStyle(
          Color(0xFF15803D),
          AppColors.successSoft,
          Icons.check_circle_rounded,
        );
      case ItemStatus.rejected:
        return const StatusStyle(
          Color(0xFFB42318),
          AppColors.errorSoft,
          Icons.block_rounded,
        );
    }
  }
}

class StatusChip extends StatelessWidget {
  final ItemStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(status);
    return TagChip(
      label: status.label,
      color: style.foreground,
      background: style.background,
      icon: style.icon,
    );
  }
}

class OpenStatusChip extends StatelessWidget {
  final DropoffPoint point;

  const OpenStatusChip({super.key, required this.point});

  @override
  Widget build(BuildContext context) {
    final open = point.isOpenNow;
    return TagChip(
      label: open ? 'Open now' : 'Closed',
      color: open ? const Color(0xFF15803D) : const Color(0xFFB42318),
      background: open ? AppColors.successSoft : AppColors.errorSoft,
    );
  }
}
