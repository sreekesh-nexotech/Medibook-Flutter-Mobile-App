import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity/connectivity_monitor.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/states/app_error_view.dart';

/// The HIVE-spec affordances above a cached list or detail, in one place:
///
/// * offline (Scenario 3) — a persistent info bar;
/// * stale (> 24 h, Scenario 5) — the amber "Data from X ago • Tap to
///   refresh" bar;
/// * a failed revalidation with rows still on screen — a danger bar whose
///   tap retries;
/// * "updating…" while a background revalidation runs.
///
/// Renders nothing when everything is fresh and online, so it costs no space
/// in the normal state.
class FreshnessBar extends ConsumerWidget {
  const FreshnessBar({
    super.key,
    this.isStale = false,
    this.revalidating = false,
    this.cachedAt,
    this.failure,
    this.onRefresh,
    this.hasContent = true,
  });

  final bool isStale;
  final bool revalidating;
  final DateTime? cachedAt;

  /// The last revalidation failure, when content is still shown.
  final Failure? failure;
  final VoidCallback? onRefresh;

  /// False when nothing is on screen: then the screen's own error view says
  /// it is offline, and "Showing what was saved" would be untrue
  /// (BL-CACHE-017).
  final bool hasContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;

    if (!online) {
      // "Offline" is said once, by the app-wide OfflineBar; here only how old
      // the saved copy is.
      if (!hasContent || cachedAt == null) return const SizedBox.shrink();
      return AppErrorBanner(
        message: 'Saved ${AppDates.relativeAgo(cachedAt!)}',
        tone: AppBannerTone.info,
        iconName: PhIcon.clock,
      );
    }
    if (failure != null) {
      return AppErrorBanner(
        message: 'Could not update — ${failure!.userMessage}',
        tone: AppBannerTone.danger,
        iconName: PhIcon.xCircle,
        onTap: onRefresh,
      );
    }
    if (isStale) {
      return AppErrorBanner(
        message: cachedAt == null
            ? 'This may be out of date • Tap to refresh'
            : 'Data from ${AppDates.relativeAgo(cachedAt!)} • Tap to refresh',
        tone: AppBannerTone.warning,
        onTap: onRefresh,
      );
    }
    if (revalidating) {
      return const AppErrorBanner(
        message: 'Updating…',
        tone: AppBannerTone.info,
        iconName: PhIcon.clock,
      );
    }
    return const SizedBox.shrink();
  }
}
