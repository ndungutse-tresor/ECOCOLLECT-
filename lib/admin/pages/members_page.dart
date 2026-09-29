import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/constants.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../admin_service.dart';
import '../admin_widgets.dart';

/// Members ranked by verified recycling.
class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminService>().snapshot!;
    final query = _query.trim().toLowerCase();
    final rows = [
      for (final member in s.members.values)
        if (query.isEmpty ||
            '${member.name} ${member.phone} ${member.district}'
                .toLowerCase()
                .contains(query))
          (member, s.statsFor(member.id)),
    ]..sort((a, b) => b.$2.kg.compareTo(a.$2.kg));

    return AdminPage(
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Search members by name, phone or district',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          const EmptyPanel(
            icon: Icons.people_outline_rounded,
            message:
                'No members yet. They appear here after signing up in the app.',
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final (i, (member, stats)) in rows.indexed) ...[
                  if (i > 0) const Divider(indent: 16, endIndent: 16),
                  _MemberRow(rank: i + 1, member: member, stats: stats),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final int rank;
  final AdminMember member;
  final MemberStats stats;

  const _MemberRow({
    required this.rank,
    required this.member,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    Widget metric(String value, String label) => SizedBox(
          width: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );

    final metrics = [
      metric('${stats.reports}', 'reports'),
      metric(formatKg(stats.kg), 'verified'),
      metric(formatNumber(stats.points), 'points'),
      metric(formatRwf(stats.cashPaid), 'cash paid'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  initialsOf(member.name),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [
                        member.district,
                        member.phone,
                        member.email,
                        if (member.lastLoginAt != null)
                          'last login ${timeAgo(member.lastLoginAt!).toLowerCase()}',
                      ].where((v) => v.isNotEmpty).join(' · '),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (constraints.maxWidth >= 760) {
            return Row(children: [Expanded(child: identity), ...metrics]);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              identity,
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Wrap(spacing: 4, runSpacing: 8, children: metrics),
              ),
            ],
          );
        },
      ),
    );
  }
}
