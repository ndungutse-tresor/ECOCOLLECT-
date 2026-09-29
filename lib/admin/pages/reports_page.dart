import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/ewaste_item.dart';
import '../admin_service.dart';
import '../admin_widgets.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // null means every status.
  ItemStatus? _status = ItemStatus.pending;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminService>().snapshot!;
    final base = _status == ItemStatus.pending
        ? s.toVerify
        : _status == null
            ? s.reports
            : s.withStatus(_status!);

    final query = _query.trim().toLowerCase();
    final reports = query.isEmpty
        ? base
        : base.where((r) {
            final member = s.member(r.userId);
            final haystack = [
              r.item.categoryName,
              r.handOverLabel,
              member?.name ?? '',
              member?.phone ?? '',
              member?.district ?? '',
            ].join(' ').toLowerCase();
            return haystack.contains(query);
          }).toList();

    String label(ItemStatus? status) {
      final count =
          status == null ? s.reports.length : s.withStatus(status).length;
      final name = switch (status) {
        null => 'All',
        ItemStatus.pending => 'To verify',
        _ => status.label,
      };
      return '$name · $count';
    }

    return AdminPage(
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Search by member, phone, item or drop-off point',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final status in [
              ItemStatus.pending,
              ItemStatus.collected,
              ItemStatus.recycled,
              ItemStatus.rejected,
              null,
            ])
              FilterPill(
                label: label(status),
                selected: _status == status,
                onTap: () => setState(() => _status = status),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (reports.isEmpty)
          const EmptyPanel(
            icon: Icons.inbox_rounded,
            message: 'No reports match these filters.',
          )
        else
          for (final report in reports) ReportCard(report: report),
      ],
    );
  }
}
