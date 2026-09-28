import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/ewaste_item.dart';
import '../services/ewaste_service.dart';
import '../services/shell_controller.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../utils/launcher.dart';
import '../widgets/app_card.dart';
import '../widgets/status_chip.dart';

class ReportSuccessScreen extends StatelessWidget {
  final String itemId;

  const ReportSuccessScreen({super.key, required this.itemId});

  void _close(BuildContext context, int tab) {
    context.read<ShellController>().goTo(tab);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<EwasteService>();
    final item = service.getItemById(itemId);
    if (item == null) return const Scaffold();

    final dropoff = item.disposalMethod == DisposalMethod.dropoff;
    final point =
        dropoff ? service.getPointById(item.dropoffPointId ?? '') : null;
    final pickup = item.pickup;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(context, ShellController.home);
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      Center(
                        child: Container(
                          width: 128,
                          height: 128,
                          decoration: const BoxDecoration(
                            color: AppColors.successSoft,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.success.withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.check_rounded,
                                size: 52, color: Colors.white),
                          ),
                        ),
                      )
                          .animate()
                          .scale(
                            begin: const Offset(0.5, 0.5),
                            duration: 700.ms,
                            curve: Curves.elasticOut,
                          )
                          .fadeIn(duration: 250.ms),
                      const SizedBox(height: 28),
                      const Text(
                        'Report submitted!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                      const SizedBox(height: 10),
                      Text(
                        dropoff
                            ? 'Bring your ${item.categoryName.toLowerCase()} to the drop-off point below and confirm the hand-over in the app.'
                            : 'A registered collector will call you to confirm your pickup.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 24),
                      AppCard(
                        color: AppColors.surfaceMuted,
                        shadow: null,
                        border: Border.all(color: AppColors.border),
                        child: dropoff && point != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      IconBadge(
                                        icon: point.typeIcon,
                                        color: point.typeColor,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              point.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Text(
                                              point.address,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      OpenStatusChip(point: point),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          point.operatingHours,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        openDirections(context, point),
                                    icon: const Icon(Icons.directions_rounded),
                                    label: const Text('Get directions'),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  const IconBadge(
                                    icon: Icons.local_shipping_rounded,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pickup == null
                                              ? 'Home pickup'
                                              : '${formatShortDay(pickup.date)} · ${pickup.timeSlot.split(' · ').last}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (pickup != null)
                                          Text(
                                            pickup.address,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                      const SizedBox(height: 14),
                      Center(
                        child: TagChip(
                          icon: Icons.stars_rounded,
                          label: '+${item.ecoPoints} EcoPoints pending hand-over',
                          color: AppColors.accentDark,
                          background: AppColors.accentSoft,
                        ),
                      ).animate().fadeIn(delay: 500.ms),
                      const Spacer(),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => _close(context, ShellController.home),
                        child: const Text('Back to home'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            _close(context, ShellController.history),
                        child: const Text('View my reports'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
