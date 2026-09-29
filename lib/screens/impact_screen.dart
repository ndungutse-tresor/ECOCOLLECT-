import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import '../models/ewaste_item.dart';
import '../services/ewaste_service.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/stat_card.dart';

class ImpactScreen extends StatelessWidget {
  const ImpactScreen({super.key});

  // Approximate equivalents used for the "that's like…" figures.
  static const _co2PerCarKm = 0.25;
  static const _co2PerPhoneCharge = 0.0082;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<EwasteService>();
    final co2 = service.co2Prevented;
    final goalProgress = (co2 / AppConstants.personalCo2Goal).clamp(0.0, 1.0);
    final community = service.communityStats;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your impact'),
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            // CO2 ring
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircularPercentIndicator(
                    radius: 62,
                    lineWidth: 11,
                    percent: goalProgress,
                    animation: true,
                    animationDuration: 900,
                    circularStrokeCap: CircularStrokeCap.round,
                    progressColor: AppColors.primary,
                    backgroundColor: AppColors.primarySoft,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          trimDecimals(co2, 1),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const Text(
                          'kg CO₂',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Emissions avoided',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(goalProgress * 100).round()}% of your '
                          '${AppConstants.personalCo2Goal.round()} kg goal',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Equivalent(
                          icon: Icons.directions_car_filled_rounded,
                          value: formatNumber((co2 / _co2PerCarKm).round()),
                          label: 'km of driving',
                        ),
                        const SizedBox(height: 8),
                        _Equivalent(
                          icon: Icons.battery_charging_full_rounded,
                          value: formatNumber(
                            (co2 / _co2PerPhoneCharge).round(),
                          ),
                          label: 'phone charges',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                'Equivalents are approximate.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.scale_rounded,
                    value: formatKg(service.totalWeightKg),
                    label: 'E-waste handed over',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    icon: Icons.devices_other_rounded,
                    value: '${service.totalItemsCollected}',
                    label: 'Items handed over',
                    color: AppColors.sky,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.stars_rounded,
                    value: formatNumber(service.earnedPoints),
                    label: 'EcoPoints earned',
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    icon: Icons.recycling_rounded,
                    value: '${service.recycledItems.length}',
                    label: 'Reports recycled',
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SectionHeader(
              title: 'By category',
              subtitle: 'Weight you have handed over',
              padding: EdgeInsets.fromLTRB(4, 26, 4, 12),
            ),
            AppCard(
              child: _CategoryBreakdown(entries: service.weightByCategory),
            ),
            const SectionHeader(
              title: 'Monthly activity',
              subtitle: 'Kilograms handed over, last 6 months',
              padding: EdgeInsets.fromLTRB(4, 26, 4, 12),
            ),
            AppCard(
              padding: const EdgeInsets.fromLTRB(12, 18, 16, 12),
              child: _MonthlyChart(data: service.monthlyWeights()),
            ),
            const SectionHeader(
              title: 'Community impact',
              subtitle: 'EcoCollect members across Kigali',
              padding: EdgeInsets.fromLTRB(4, 26, 4, 12),
            ),
            AppCard(
              gradient: AppColors.heroGradient,
              shadow: AppShadows.card,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      _CommunityMetric(
                        icon: Icons.people_alt_rounded,
                        value: formatNumber(community['totalUsers']!),
                        label: 'Members',
                      ),
                      _CommunityMetric(
                        icon: Icons.scale_rounded,
                        value: formatKg(community['totalWeightKg']!.toDouble()),
                        label: 'Collected',
                      ),
                      _CommunityMetric(
                        icon: Icons.eco_rounded,
                        value: formatKg(community['co2Prevented']!.toDouble()),
                        label: 'CO₂ avoided',
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    child: Divider(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  Row(
                    children: [
                      _CommunityMetric(
                        icon: Icons.local_shipping_rounded,
                        value: '${community['activeCollectors']}',
                        label: 'Collectors',
                      ),
                      _CommunityMetric(
                        icon: Icons.place_rounded,
                        value: '${community['dropoffPoints']}',
                        label: 'Drop-off points',
                      ),
                      _CommunityMetric(
                        icon: Icons.devices_other_rounded,
                        value: formatNumber(community['totalItems']!),
                        label: 'Items',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              color: AppColors.successSoft,
              shadow: null,
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.public_rounded, color: AppColors.success),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rwanda generates over 16,000 tonnes of e-waste per year. Every kilogram you recycle matters!',
                      style: TextStyle(height: 1.45, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Equivalent extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _Equivalent({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '≈ $value ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: label,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final List<MapEntry<EwasteCategory, double>> entries;

  const _CategoryBreakdown({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Hand over your first item to see a breakdown here.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    final max = entries.first.value;
    final total = entries.fold(0.0, (sum, e) => sum + e.value);

    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Tooltip(
              message:
                  '${entry.key.name}: ${formatKg(entry.value)} (${(entry.value / total * 100).round()}%)',
              child: Row(
                children: [
                  IconBadge(
                    icon: entry.key.icon,
                    color: entry.key.color,
                    size: 34,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              formatKg(entry.value),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LayoutBuilder(
                          builder: (context, constraints) => Stack(
                            children: [
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: entry.value / max),
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeOutCubic,
                                builder: (_, value, __) => Container(
                                  height: 8,
                                  width: math.max(
                                    4,
                                    constraints.maxWidth * value,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
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
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  final List<MonthlyTotal> data;

  const _MonthlyChart({required this.data});

  static double _niceMax(double value) {
    if (value <= 0) return 1;
    final magnitude = math.pow(10, (math.log(value) / math.ln10).floor());
    for (final step in [1, 2, 2.5, 5, 10]) {
      final candidate = step * magnitude;
      if (candidate >= value) return candidate.toDouble();
    }
    return (10 * magnitude).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    const plotHeight = 140.0;
    const axisWidth = 44.0;
    final peak = data.map((d) => d.weightKg).fold(0.0, math.max);
    final top = _niceMax(peak);
    final peakIndex =
        peak > 0 ? data.indexWhere((d) => d.weightKg == peak) : -1;
    final lastIndex = data.length - 1;

    Widget gridLine(double fraction) => Positioned(
          left: axisWidth,
          right: 0,
          bottom: plotHeight * fraction,
          child: Container(height: 1, color: AppColors.border),
        );

    Widget axisLabel(double fraction) => Positioned(
          left: 0,
          width: axisWidth - 8,
          bottom: plotHeight * fraction - 7,
          child: Text(
            formatKg(top * fraction),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
        );

    return Column(
      children: [
        SizedBox(
          height: plotHeight + 20,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                top: 20,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    gridLine(0.5),
                    gridLine(1),
                    axisLabel(0),
                    axisLabel(0.5),
                    axisLabel(1),
                    Positioned(
                      left: axisWidth,
                      right: 0,
                      bottom: 0,
                      child: Container(height: 1, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                left: axisWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < data.length; i++)
                      Expanded(
                        child: _Bar(
                          total: data[i],
                          fraction: data[i].weightKg / top,
                          plotHeight: plotHeight,
                          showLabel: data[i].weightKg > 0 &&
                              (i == peakIndex || i == lastIndex),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: axisWidth),
            for (var i = 0; i < data.length; i++)
              Expanded(
                child: Text(
                  DateFormat('MMM').format(data[i].month),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        i == lastIndex ? FontWeight.w800 : FontWeight.w600,
                    color: i == lastIndex
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final MonthlyTotal total;
  final double fraction;
  final double plotHeight;
  final bool showLabel;

  const _Bar({
    required this.total,
    required this.fraction,
    required this.plotHeight,
    required this.showLabel,
  });

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy').format(total.month);
    return Tooltip(
      message: '$label: ${formatKg(total.weightKg)}',
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        // Full-height hit target, larger than the bar itself.
        color: Colors.transparent,
        height: plotHeight + 20,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (showLabel)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  formatKg(total.weightKg),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => Container(
                width: 22,
                height:
                    total.weightKg > 0 ? math.max(4, plotHeight * value) : 0,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _CommunityMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.75), size: 20),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}
