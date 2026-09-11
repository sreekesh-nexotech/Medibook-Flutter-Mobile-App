import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/medibook_seed.dart';

/// Home promo-banner index. `autoDispose`, so it resets when Home leaves the
/// tree.
///
/// ## Why the timer left this class (audit §3.3.8)
///
/// The finding was that the banner *"rotates every 4s with no pause and no
/// check for the reduce-motion setting"*. The check cannot live here: the
/// answer depends on `MediaQuery.disableAnimations`, which needs a
/// `BuildContext`, and a controller that starts a `Timer` in its constructor
/// has already decided to animate before any widget can ask.
///
/// So this holds the index and nothing else. `PromoBannerCard` owns the clock,
/// resolved through `AppCarouselAutoplay.resolve(context, …)` — which returns
/// null when autoplay must not run — and pauses it on touch. A controller with
/// no timer also cannot leak one.
class BannerController extends StateNotifier<int> {
  BannerController() : super(0);

  final int _count = MedibookSeed.banners.length;

  /// Advance one slide, wrapping. Safe with an empty banner list.
  void next() {
    if (_count <= 0) return;
    state = (state + 1) % _count;
  }

  /// Go back one slide, wrapping.
  void previous() {
    if (_count <= 0) return;
    state = (state - 1 + _count) % _count;
  }

  /// Jump to a slide — the carousel's `onPageChanged` and the dots.
  void setIndex(int index) {
    if (_count <= 0) return;
    state = index % _count;
  }
}

final bannerControllerProvider =
    StateNotifierProvider.autoDispose<BannerController, int>(
      (ref) => BannerController(),
    );
