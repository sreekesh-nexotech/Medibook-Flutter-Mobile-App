import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/config/feature_flags.dart';
import '../../../../core/mock_data/medibook_seed.dart';

/// Home promo-banner index + auto-rotation. `autoDispose` so the timer is torn
/// down when Home is not on screen. Tapping the banner advances manually and
/// restarts the interval.
class BannerController extends StateNotifier<int> {
  BannerController() : super(0) {
    if (FeatureFlags.bannerAutoRotate) _start();
  }

  Timer? _timer;
  final int _count = MedibookSeed.banners.length;

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(AppConstants.bannerInterval, (_) => _advance());
  }

  void _advance() => state = (state + 1) % _count;

  /// Manual tap: advance and reset the auto-rotate clock.
  void next() {
    _advance();
    if (FeatureFlags.bannerAutoRotate) _start();
  }

  /// Keep in sync when the carousel is swiped directly.
  void setIndex(int index) => state = index % _count;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final bannerControllerProvider =
    StateNotifierProvider.autoDispose<BannerController, int>(
      (ref) => BannerController(),
    );
