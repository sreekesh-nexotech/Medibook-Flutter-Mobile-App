import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';

/// Brand-coloured pull-to-refresh (audit §3.9.4 — none of the three scrolling
/// feeds could be refreshed by pulling, which is the gesture every patient will
/// try first when their appointment list looks stale).
///
/// ## The physics trap this wrapper closes
///
/// `RefreshIndicator` only fires when its scrollable **reports that it can
/// scroll**. The Appointments, Records and Notifications screens are
/// `SingleChildScrollView`s wrapping a `Column`, and a short list does not
/// overscroll — so a plain `RefreshIndicator` around them silently does
/// nothing whenever the content happens to fit on screen. That is the exact
/// shape of the bug that gets shipped, because it only appears when the list is
/// short.
///
/// The fix is `physics: const AlwaysScrollableScrollPhysics()` on the
/// **scrollable**, and this wrapper applies it for you: [child] is scanned and
/// its physics replaced via [ScrollConfiguration], so a feature agent cannot
/// get it wrong by forgetting a parameter. It works with a `ListView`, a
/// `SingleChildScrollView`, a `CustomScrollView` or a `GridView`, and with a
/// short list or a long one.
///
/// ```dart
/// AppRefreshIndicator(
///   onRefresh: () => ref.read(controller.notifier).reload(),
///   child: SingleChildScrollView(child: Column(children: [...])),
/// )
/// ```
///
/// [onRefresh] must return a `Future` that completes when the reload is done —
/// the spinner stays up until it does, which is what makes the gesture feel
/// like it worked.
class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.displacement,
    this.semanticsLabel = 'Refresh',
    this.edgeOffset = 0,
  });

  /// Runs the reload. The indicator shows until the future completes.
  final Future<void> Function() onRefresh;

  /// The scrollable. Its physics are forced to always-scrollable (see the class
  /// doc) so the gesture works even when the content fits on screen.
  final Widget child;

  /// How far down the spinner settles, in raw design px. Defaults to 40.
  final double? displacement;

  /// What a screen reader announces for the refresh affordance.
  final String semanticsLabel;

  /// Offset for a scrollable that starts below a pinned header.
  final double edgeOffset;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.brand,
      backgroundColor: AppColors.surface,
      strokeWidth: 2.5.w,
      displacement: (displacement ?? 40).h,
      edgeOffset: edgeOffset.h,
      semanticsLabel: semanticsLabel,
      child: ScrollConfiguration(
        // Applies AlwaysScrollableScrollPhysics to every scrollable beneath,
        // so `SingleChildScrollView(child: Column(...))` overscrolls and the
        // pull is detected even when the content is shorter than the viewport.
        behavior: const _AlwaysScrollableBehavior(),
        child: child,
      ),
    );
  }
}

/// A [ScrollBehavior] that makes descendant scrollables always scrollable.
///
/// This is what lets [AppRefreshIndicator] work without the caller having to
/// remember `physics: const AlwaysScrollableScrollPhysics()` on their
/// `SingleChildScrollView`.
///
/// Note: a scrollable that sets its **own** `physics` explicitly wins over
/// this behaviour. So if a screen passes `physics:` to its scroll view, it must
/// use `AlwaysScrollableScrollPhysics` itself.
class _AlwaysScrollableBehavior extends MaterialScrollBehavior {
  const _AlwaysScrollableBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const AlwaysScrollableScrollPhysics().applyTo(
        super.getScrollPhysics(context),
      );
}

/// The always-scrollable physics, exposed for the rare screen that must pass
/// `physics:` itself (a nested scroll view, a custom snap).
///
/// ```dart
/// SingleChildScrollView(
///   physics: appRefreshPhysics,
///   child: ...,
/// )
/// ```
const ScrollPhysics appRefreshPhysics = AlwaysScrollableScrollPhysics();
