import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/network/connectivity/connectivity_monitor.dart';
import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';

/// The HIVE-spec affordances for a cached read, in one strip
/// (`docs-flutter/HIVE implementation.md`):
///
/// * offline → nothing here: the app-wide `OfflineBar` says it (Scenario 3);
/// * stale (> 24 h) → the amber "Data from … · Tap to refresh" bar
///   (Scenario 5), [onRefresh] forcing an immediate retry;
/// * revalidating → the quiet "Updating…" line (Scenario 2).
///
/// Renders nothing when the data is fresh and the device is online.
class CacheStatusBar extends ConsumerWidget {
  const CacheStatusBar({super.key, required this.result, this.onRefresh});

  final CachedResult<Object?>? result;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final data = result;

    // Offline is said once, by the app-wide OfflineBar; an empty section
    // shows its own error view with Try Again.
    if (!online) return const SizedBox.shrink();
    if (data == null) return const SizedBox.shrink();
    if (data.isStale) {
      return Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.x3.h),
        child: AppErrorBanner(
          message:
              'Data from ${AppDates.relativeAgo(data.cachedAt)} · '
              'Tap to refresh',
          onTap: onRefresh,
        ),
      );
    }
    if (data.revalidating) {
      return Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.x2.h),
        child: Row(
          children: [
            const AppInlineLoader(size: 12),
            SizedBox(width: 6.w),
            Text(
              'Updating…',
              style: AppText.poppins(
                size: AppFontSize.xxs,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
