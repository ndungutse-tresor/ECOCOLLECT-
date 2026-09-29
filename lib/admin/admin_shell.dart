import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/constants.dart';
import '../utils/format.dart';
import '../widgets/app_logo.dart';
import 'admin_service.dart';
import 'pages/dashboard_page.dart';
import 'pages/members_page.dart';
import 'pages/payouts_page.dart';
import 'pages/pickups_page.dart';
import 'pages/reports_page.dart';

class _Section {
  final String title;
  final String subtitle;
  final IconData icon;
  final IconData selectedIcon;

  const _Section(this.title, this.subtitle, this.icon, this.selectedIcon);
}

const _sections = [
  _Section('Dashboard', 'Overview of collection and payouts',
      Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  _Section('Reports', 'Verify hand-overs and track recycling',
      Icons.fact_check_outlined, Icons.fact_check_rounded),
  _Section('Pickups', 'Home collections to schedule',
      Icons.local_shipping_outlined, Icons.local_shipping_rounded),
  _Section('Payouts', 'Mobile Money cash rewards', Icons.payments_outlined,
      Icons.payments_rounded),
  _Section('Members', 'Everyone recycling with EcoCollect',
      Icons.people_outline_rounded, Icons.people_alt_rounded),
];

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AdminService>();
    final s = service.snapshot!;
    final badges = [
      0,
      s.toVerify.length,
      s.pickupsToDo.length,
      s.claimsToPay.length,
      0,
    ];

    final page = switch (_index) {
      0 => DashboardPage(onNavigate: _go),
      1 => const ReportsPage(),
      2 => const PickupsPage(),
      3 => const PayoutsPage(),
      _ => const MembersPage(),
    };

    Widget icon(int i, bool selected) {
      final child = Icon(
        selected ? _sections[i].selectedIcon : _sections[i].icon,
      );
      return badges[i] == 0
          ? child
          : Badge(label: Text('${badges[i]}'), child: child);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final body = Column(
          children: [
            _TopBar(section: _sections[_index], compact: !wide),
            if (service.error != null)
              MaterialBanner(
                backgroundColor: AppColors.warningSoft,
                leading: const Icon(Icons.cloud_off_rounded,
                    color: AppColors.warning),
                content: Text('Could not refresh: ${service.error}'),
                actions: [
                  TextButton(
                    onPressed: service.refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            Expanded(child: page),
          ],
        );

        return Scaffold(
          body: Row(
            children: [
              if (wide)
                NavigationRail(
                  extended: constraints.maxWidth >= 1200,
                  minExtendedWidth: 220,
                  backgroundColor: AppColors.surface,
                  indicatorColor: AppColors.primarySoft,
                  selectedIndex: _index,
                  onDestinationSelected: _go,
                  selectedIconTheme:
                      const IconThemeData(color: AppColors.primary),
                  selectedLabelTextStyle: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppLogo(size: 40),
                        if (constraints.maxWidth >= 1200) ...[
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EcoCollect',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Admin',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: IconButton(
                          tooltip: 'Sign out',
                          onPressed: service.signOut,
                          icon: const Icon(Icons.logout_rounded),
                        ),
                      ),
                    ),
                  ),
                  destinations: [
                    for (var i = 0; i < _sections.length; i++)
                      NavigationRailDestination(
                        icon: icon(i, false),
                        selectedIcon: icon(i, true),
                        label: Text(_sections[i].title),
                      ),
                  ],
                ),
              if (wide) const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: _go,
                  backgroundColor: AppColors.surface,
                  indicatorColor: AppColors.primarySoft,
                  destinations: [
                    for (var i = 0; i < _sections.length; i++)
                      NavigationDestination(
                        icon: icon(i, false),
                        selectedIcon: icon(i, true),
                        label: _sections[i].title,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final _Section section;
  final bool compact;

  const _TopBar({required this.section, required this.compact});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AdminService>();
    final updated = service.snapshot?.generatedAt;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    updated == null
                        ? section.subtitle
                        : '${section.subtitle} · updated ${timeAgo(updated).toLowerCase()}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (service.loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else
              IconButton(
                tooltip: 'Refresh',
                onPressed: service.refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            if (compact)
              IconButton(
                tooltip: 'Sign out',
                onPressed: service.signOut,
                icon: const Icon(Icons.logout_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
