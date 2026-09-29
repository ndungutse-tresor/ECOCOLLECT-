import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/constants.dart';
import '../../utils/format.dart';
import '../admin_service.dart';
import '../admin_widgets.dart';

/// Home pickups waiting for a collector, grouped by day.
class PickupsPage extends StatelessWidget {
  const PickupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pickups = context.watch<AdminService>().snapshot!.pickupsToDo;
    final today = DateUtils.dateOnly(DateTime.now());

    String dayLabel(DateTime date) {
      final day = DateUtils.dateOnly(date);
      final diff = day.difference(today).inDays;
      final name = formatShortDay(day);
      if (diff < 0) return 'Overdue · $name';
      if (diff == 0) return 'Today · $name';
      if (diff == 1) return 'Tomorrow · $name';
      return name;
    }

    final groups = <String, List<AdminReport>>{};
    for (final report in pickups) {
      groups
          .putIfAbsent(dayLabel(report.item.pickup!.date), () => [])
          .add(report);
    }

    return AdminPage(
      children: [
        if (pickups.isEmpty)
          const EmptyPanel(
            icon: Icons.local_shipping_outlined,
            message:
                'No pickups scheduled. New requests from the app show up here.',
          )
        else
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
              child: Text(
                '${entry.key} · ${entry.value.length} pickup${entry.value.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: entry.key.startsWith('Overdue')
                      ? AppColors.error
                      : AppColors.textPrimary,
                ),
              ),
            ),
            for (final report in entry.value) ReportCard(report: report),
          ],
      ],
    );
  }
}
