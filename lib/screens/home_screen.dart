import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/dropoff_point.dart';
import '../models/ewaste_item.dart';
import '../models/reward.dart';
import '../services/ewaste_service.dart';
import '../services/location_service.dart';
import '../services/shell_controller.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../utils/launcher.dart';
import '../widgets/app_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/recent_item_tile.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_chip.dart';
import 'ecopoints_screen.dart';
import 'profile_screen.dart';
import 'report_ewaste_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<EwasteService>();
    final shell = context.read<ShellController>();
    final recent = service.items.take(3).toList();
    final pending = service.pendingItems;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(service: service)),
          if (pending.isNotEmpty)
            SliverToBoxAdapter(
              child: _PendingBanner(
                count: pending.length,
                points: service.pendingPoints,
                onTap: () => shell.goTo(ShellController.history),
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.scale_rounded,
                      value: formatKg(service.totalWeightKg),
                      label: 'Collected',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      icon: Icons.devices_other_rounded,
                      value: '${service.totalItemsCollected}',
                      label: 'Items',
                      color: AppColors.sky,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      icon: Icons.eco_rounded,
                      value: formatKg(service.co2Prevented),
                      label: 'CO₂ avoided',
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 80.ms, duration: 350.ms),
          ),
          const SliverToBoxAdapter(
              child: SectionHeader(title: 'Quick actions')),
          SliverToBoxAdapter(
            child: AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.add_a_photo_rounded,
                      label: 'Report\ne-waste',
                      color: AppColors.primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReportEwasteScreen(),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.place_rounded,
                      label: 'Find\ndrop-off',
                      color: AppColors.sky,
                      onTap: () => shell.goTo(ShellController.map),
                    ),
                  ),
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.local_shipping_rounded,
                      label: 'Request\npickup',
                      color: AppColors.warning,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReportEwasteScreen(
                            initialMethod: DisposalMethod.pickup,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.redeem_rounded,
                      label: 'My\nrewards',
                      color: AppColors.purple,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EcoPointsScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 140.ms, duration: 350.ms),
          ),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Nearest drop-off',
              actionLabel: 'View map',
              onAction: () => shell.goTo(ShellController.map),
            ),
          ),
          SliverToBoxAdapter(
            child: _NearestPointCard(points: service.dropoffPoints)
                .animate()
                .fadeIn(delay: 200.ms, duration: 350.ms),
          ),
          const SliverToBoxAdapter(child: _TipCard()),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Recent activity',
              actionLabel: recent.isEmpty ? null : 'See all',
              onAction: () => shell.goTo(ShellController.history),
            ),
          ),
          if (recent.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No reports yet',
                message:
                    'Report your first e-waste item and start earning EcoPoints.',
                actionLabel: 'Report e-waste',
                onAction: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportEwasteScreen()),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: recent.length,
              itemBuilder: (context, i) =>
                  RecentItemTile(item: recent[i], service: service),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final EwasteService service;

  const _Header({required this.service});

  @override
  Widget build(BuildContext context) {
    final profile = service.profile;
    final level = service.level;
    final next = EcoLevel.nextAfter(level);
    final progress = EcoLevel.progress(service.earnedPoints);

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -20,
            child: Icon(
              Icons.recycling_rounded,
              size: 200,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        ),
                        child: Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            initialsOf(profile?.name ?? 'Eco'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${greetingForNow()} 👋',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            Text(
                              profile?.firstName ?? 'Muraho!',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PointsPill(points: service.ecoPoints),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppStrings.tagline,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconBadge(
                              icon: level.icon,
                              color: Colors.white,
                              background: Colors.white.withValues(alpha: 0.18),
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${level.name} level',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    next == null
                                        ? 'Top level reached. Amazing!'
                                        : '${next.minPoints - service.earnedPoints} pts to ${next.name}',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${(progress * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            builder: (_, value, __) => LinearProgressIndicator(
                              value: value,
                              minHeight: 8,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              color: AppColors.accentLight,
                            ),
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
      ),
    );
  }
}

class _PointsPill extends StatelessWidget {
  final int points;

  const _PointsPill({required this.points});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EcoPointsScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded,
                  size: 20, color: AppColors.accent),
              const SizedBox(width: 5),
              Text(
                formatNumber(points),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  final int count;
  final int points;
  final VoidCallback onTap;

  const _PendingBanner({
    required this.count,
    required this.points,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      color: AppColors.warningSoft,
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      shadow: null,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.hourglass_top_rounded,
            color: AppColors.warning,
            background: Colors.white,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count report${count == 1 ? '' : 's'} awaiting hand-over',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '+$points EcoPoints once you hand ${count == 1 ? 'it' : 'them'} over',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF92400E)),
        ],
      ),
    );
  }
}

class _NearestPointCard extends StatelessWidget {
  final List<DropoffPoint> points;

  const _NearestPointCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationService>();
    final List<DropoffPoint> ordered;
    if (location.hasPosition) {
      ordered = location.sortByDistance(points);
    } else {
      // Without a location, suggest a point that is open right now.
      ordered = [...points]..sort(
          (a, b) => (b.isOpenNow ? 1 : 0).compareTo(a.isOpenNow ? 1 : 0),
        );
    }
    final point = ordered.first;
    final distance = location.distanceTo(point);

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () => context.read<ShellController>().goTo(ShellController.map),
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(icon: point.typeIcon, color: point.typeColor, size: 50),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      distance != null
                          ? '${formatDistance(distance)} away · ${point.address}'
                          : '${point.typeLabel} · ${point.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OpenStatusChip(point: point),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            point.operatingHours,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Directions',
                onPressed: () => openDirections(context, point),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primarySoft,
                  foregroundColor: AppColors.primary,
                ),
                icon: const Icon(Icons.directions_rounded),
              ),
            ],
          ),
          if (!location.hasPosition) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    location.statusMessage.isNotEmpty
                        ? location.statusMessage
                        : 'Share your location to see the closest point.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (location.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: location.canOpenSettings
                        ? location.openSettings
                        : location.request,
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(
                      location.canOpenSettings ? 'Settings' : 'Near me',
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

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    final tip = AppConstants.tips[dayOfYear % AppConstants.tips.length];

    return AppCard(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      color: AppColors.primarySoft,
      shadow: null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(
            icon: Icons.lightbulb_rounded,
            color: AppColors.accentDark,
            background: Colors.white,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Eco tip of the day',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
