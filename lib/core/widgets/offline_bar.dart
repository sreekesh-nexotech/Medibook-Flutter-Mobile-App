import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';
import '../network/connectivity/connectivity_monitor.dart';
import 'app_icon.dart';

/// The one offline indicator for the whole app (offline audit, 6 Oct 2026).
///
/// Wraps every route (it sits in `MaterialApp.builder`), so no screen can
/// forget to say it, and the wording is the same everywhere. While the app is
/// offline a slim bar fills the status-bar area and the line below it; the
/// page underneath loses that top inset, so nothing is covered. It goes away
/// by itself when the connection returns — screens reload on reconnect.
///
/// Two cases, told apart by [ConnectivityMonitor.hasRoute]:
/// * no network at all (airplane mode, no Wi-Fi or data) — "You're offline";
/// * a network, but requests are not getting through (captive portal, server
///   down) — "Can't reach Medibook right now".
///
/// Screens keep their own explanation only where there is nothing saved to
/// show (an error view with Try Again).
class OfflineBar extends ConsumerWidget {
  const OfflineBar({super.key, required this.child});

  final Widget child;

  /// What the bar says; also what tests and the screen reader read.
  static const String noNetwork =
      "You're offline — showing what was saved on this phone.";
  static const String unreachable =
      "Can't reach Medibook right now — showing what was saved on this phone.";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    if (online) return child;

    final monitor = ref.read(connectivityMonitorProvider);
    final text = monitor.hasRoute ? unreachable : noNetwork;
    final media = MediaQuery.of(context);

    return Column(
      children: [
        // Light status-bar icons over the navy bar, whatever the page asks.
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Semantics(
            liveRegion: true,
            container: true,
            label: text,
            child: ExcludeSemantics(
              child: Material(
                color: AppColors.textStrong,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16.w,
                    media.padding.top + 6.h,
                    16.w,
                    8.h,
                  ),
                  child: Row(
                    children: [
                      AppIcon(
                        PhIcon.warningCircleFill,
                        size: 16,
                        color: AppColors.textOnBrand,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(
                            size: AppFontSize.xs,
                            weight: AppText.medium,
                            color: AppColors.textOnBrand,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          // The bar has taken the status-bar inset; the page must not add it
          // again.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
