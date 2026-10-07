import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../app/config/constants.dart';
import '../../../../../app/theme/colors.dart';
import '../../../../../app/theme/typography.dart';
import '../../../../../core/network/connectivity/connectivity_monitor.dart';
import '../../../../../core/error/error_view.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../../../core/widgets/app_icon.dart';
import '../../application/states/cached_state.dart';

/// The HIVE-spec freshness affordances for one [CachedState], stacked above
/// a list: a persistent offline line, the amber "Data from X ago • Tap to
/// refresh" bar for a stale copy, a quiet "Updating…" line during a
/// background revalidation, and the last refresh failure when there is still
/// data to show underneath.
///
/// Renders nothing when everything is fresh and online, so it can sit
/// unconditionally at the top of every cached list.
class CachedStatusBar extends ConsumerWidget {
  const CachedStatusBar({
    super.key,
    required this.state,
    required this.onRefresh,
    this.bottomGap,
  });

  final CachedState<Object?> state;
  final VoidCallback onRefresh;

  /// Space under the bar when at least one line rendered.
  final double? bottomGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final failure = state.failure;
    // Offline, the app-wide bar already says so; a red "You appear to be
    // offline" here would say it twice.
    final showFailure =
        failure != null &&
        state.hasValue &&
        !(!isOnline && failure is NetworkFailure);
    final lines = <Widget>[
      // Offline is said once, by the app-wide OfflineBar (offline audit,
      // 6 Oct); this bar only adds what is specific to the list.
      if (state.isStale && state.hasValue)
        AppErrorBanner(
          message: 'Data from ${_ago(state.cachedAt)} • Tap to refresh',
          onTap: onRefresh,
        ),
      if (failure != null && showFailure)
        AppErrorBanner(
          message: failure.userMessage,
          tone: AppBannerTone.danger,
          iconName: PhIcon.xCircle,
          onTap: failure.isRetryable ? onRefresh : null,
        ),
      if (state.isRefreshing && state.hasValue) const _UpdatingLine(),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          lines[i],
          SizedBox(
            height: i == lines.length - 1
                ? (bottomGap ?? AppSpacing.x4).h
                : AppSpacing.x2.h,
          ),
        ],
      ],
    );
  }

  static String _ago(DateTime? at) =>
      at == null ? 'earlier' : AppDates.relativeAgo(at);
}

/// "Updating…" — deliberately quiet: the data on screen is usable.
class _UpdatingLine extends StatelessWidget {
  const _UpdatingLine();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          SizedBox(
            width: 12.r,
            height: 12.r,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(width: AppSpacing.x2.w),
          Text(
            'Updating…',
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
