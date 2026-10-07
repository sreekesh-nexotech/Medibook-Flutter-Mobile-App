import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which intro slide is showing. `autoDispose`, so the intro restarts at the
/// first slide if the screen is ever rebuilt from scratch.
///
/// Holds the index and nothing else — the screen owns the `PageController`
/// and keeps it in step, the same split `BannerController` uses on Home.
class OnboardingSlidesController extends StateNotifier<int> {
  OnboardingSlidesController(this._count) : super(0);

  /// How many slides there are — the screen's content, passed in so this
  /// layer does not import presentation (CL CODE-015).
  final int _count;

  bool get isLast => state >= _count - 1;

  /// Advance one slide, stopping at the last — the intro does not wrap.
  void next() {
    if (isLast) return;
    state = state + 1;
  }

  /// Jump to a slide — the dots and the `PageView`'s `onPageChanged`.
  void setIndex(int index) {
    if (_count <= 0) return;
    state = index.clamp(0, _count - 1);
  }
}

/// Keyed by the number of slides.
final onboardingSlidesProvider = StateNotifierProvider.autoDispose
    .family<OnboardingSlidesController, int, int>(
      (ref, count) => OnboardingSlidesController(count),
    );
