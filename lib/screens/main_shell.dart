import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/shell_controller.dart';
import '../utils/constants.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'impact_screen.dart';
import 'map_screen.dart';
import 'report_ewaste_screen.dart';

/// Bottom navigation with a raised "Report" button in the middle.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Tabs are built the first time they are opened, then kept alive.
  final _visited = <int>{ShellController.home};

  static const _tabs = [
    HomeScreen(),
    MapScreen(),
    HistoryScreen(),
    ImpactScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    final index = shell.index;
    _visited.add(index);

    return PopScope(
      canPop: index == ShellController.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goTo(ShellController.home);
      },
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: [
            for (var i = 0; i < _tabs.length; i++)
              _visited.contains(i) ? _tabs[i] : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: _BottomBar(
          index: index,
          onSelect: shell.goTo,
          onReport: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ReportEwasteScreen()),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onReport;

  const _BottomBar({
    required this.index,
    required this.onSelect,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x140B3D2C),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                selected: index == ShellController.home,
                onTap: () => onSelect(ShellController.home),
              ),
              _NavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map_rounded,
                label: 'Drop-off',
                selected: index == ShellController.map,
                onTap: () => onSelect(ShellController.map),
              ),
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: 'Report e-waste',
                    child: GestureDetector(
                      onTap: onReport,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primaryLight, AppColors.primary],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'History',
                selected: index == ShellController.history,
                onTap: () => onSelect(ShellController.history),
              ),
              _NavItem(
                icon: Icons.insights_outlined,
                activeIcon: Icons.insights_rounded,
                label: 'Impact',
                selected: index == ShellController.impact,
                onTap: () => onSelect(ShellController.impact),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child:
                    Icon(selected ? activeIcon : icon, color: color, size: 24),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
