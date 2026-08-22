/// Central switches for staged rollouts / demo behaviour.
///
/// Presentation-layer relevant flag today is [demoMode], which gates the
/// prototype-only affordances (prefilled demo credentials, the "Demo code:
/// 1234" hint, the reviewer screen-jump menu, banner auto-rotate). These come
/// straight from the design prototype and must never ship on a production auth
/// path — keep them behind this flag.
abstract final class FeatureFlags {
  FeatureFlags._();

  /// Enables demo affordances. `true` while this is a design prototype;
  /// flip to `false` (or wire to build flavor) for production.
  static const bool demoMode = true;

  /// Home promo banner auto-rotation (every [AppConstants.bannerInterval]).
  static const bool bannerAutoRotate = true;
}
