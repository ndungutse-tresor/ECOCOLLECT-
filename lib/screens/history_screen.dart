import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/ewaste_item.dart';
import '../services/ewaste_service.dart';
import '../utils/constants.dart';
import '../widgets/app_card.dart';
import '../widgets/recent_item_tile.dart';
import '../widgets/status_chip.dart';
import 'report_ewaste_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  ItemStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<EwasteService>();
    final all = service.items;
    final items =
        _filter == null ? all : all.where((i) => i.status == _filter).toList();

    int count(ItemStatus s) => all.where((i) => i.status == s).length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My reports'),
          automaticallyImplyLeading: false,
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: AppCard(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    for (final status in ItemStatus.values) ...[
                      Expanded(
                        child: _Counter(
                          status: status,
                          count: count(status),
                        ),
                      ),
                      if (status != ItemStatus.values.last)
                        Container(
                          width: 1,
                          height: 40,
                          color: AppColors.border,
                        ),
                    ],
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  children: [
                    _FilterChip(
                      label: 'All · ${all.length}',
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    for (final status in ItemStatus.values)
                      _FilterChip(
                        label: '${status.label} · ${count(status)}',
                        selected: _filter == status,
                        onTap: () => setState(() => _filter = status),
                      ),
                  ],
                ),
              ),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: _filter == null
                        ? 'No reports yet'
                        : 'Nothing ${_filter!.label.toLowerCase()} yet',
                    message: _filter == null
                        ? 'Report your first e-waste item. It only takes a minute.'
                        : 'Reports will show up here as they move along.',
                    actionLabel: _filter == null ? 'Report e-waste' : null,
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportEwasteScreen(),
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 24),
                sliver: SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) => RecentItemTile(
                    item: items[i],
                    service: service,
                    detailed: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final ItemStatus status;
  final int count;

  const _Counter({required this.status, required this.count});

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(status);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(style.icon, size: 18, color: style.foreground),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          status.label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.textPrimary : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
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
      ),
    );
  }
}
