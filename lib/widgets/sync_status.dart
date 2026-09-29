import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ewaste_service.dart';
import '../utils/constants.dart';
import '../utils/format.dart';

/// Compact cloud status; tap to sync now.
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<EwasteService>();
    final (icon, label, color) = describeSync(service);

    return Tooltip(
      message: service.syncError ?? 'Tap to sync now',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: service.syncEnabled ? service.sync : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (service.syncStatus == SyncStatus.syncing)
                SizedBox(
                  width: 14,
                  height: 14,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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

/// Icon, short label and colour for the current sync state.
(IconData, String, Color) describeSync(EwasteService service) {
  switch (service.syncStatus) {
    case SyncStatus.off:
      return (
        Icons.cloud_off_rounded,
        'This device only',
        AppColors.textSecondary
      );
    case SyncStatus.idle:
      return (Icons.cloud_queue_rounded, 'Connecting', AppColors.textSecondary);
    case SyncStatus.syncing:
      return (Icons.sync_rounded, 'Syncing', AppColors.sky);
    case SyncStatus.synced:
      final at = service.lastSyncedAt;
      return (
        Icons.cloud_done_rounded,
        at == null ? 'Synced' : 'Synced ${timeAgo(at).toLowerCase()}',
        AppColors.success,
      );
    case SyncStatus.offline:
      final waiting = service.unsyncedCount;
      return (
        Icons.cloud_off_rounded,
        waiting > 0 ? 'Offline · $waiting to sync' : 'Offline',
        AppColors.warning,
      );
  }
}
