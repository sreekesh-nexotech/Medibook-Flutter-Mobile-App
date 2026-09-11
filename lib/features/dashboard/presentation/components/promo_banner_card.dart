import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/config/feature_flags.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/promo_banner.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/utils/motion.dart';
import '../../../../core/widgets/app_carousel_dots.dart';
import '../controllers/banner_controller.dart';

/// The 150px rotating promo banner.
///
/// ## What the audit changed here (§3.3.8)
///
/// The finding: the banner *"rotates every 4s with no pause and no check for
/// the reduce-motion setting"* — a WCAG 2.2.2 failure twice over. Three fixes,
/// all of which live in this widget because all three need a `BuildContext`:
///
/// 1. **Reduce motion.** The interval comes from
///    `AppCarouselAutoplay.resolve(context, …)`, which returns **null** when
///    the OS asks for animations to be removed. A null interval means no timer
///    is ever created — the banner simply sits on one slide, swipeable.
/// 2. **Pause on touch.** Any pointer on the carousel cancels the timer and
///    restarts it [AppCarouselAutoplay.pauseAfterInteraction] later, so
///    reading a slide does not race the clock.
/// 3. **Manual control.** The pages are now genuinely swipeable and
///    [AppCarouselDots] are tappable, so the carousel can be driven rather
///    than only watched.
///
/// The index still lives in `bannerControllerProvider`; this widget owns only
/// the clock and the `PageController`.
class PromoBannerCard extends ConsumerStatefulWidget {
  const PromoBannerCard({super.key});

  @override
  ConsumerState<PromoBannerCard> createState() => _PromoBannerCardState();
}

class _PromoBannerCardState extends ConsumerState<PromoBannerCard> {
  // The banner controller starts at index 0 (autoDispose → fresh on entry), so
  // the initial page aligns without reading the provider here.
  final PageController _controller = PageController();

  Timer? _autoplay;
  Timer? _resume;

  /// The resolved interval, or null when autoplay must not run. Recomputed in
  /// [didChangeDependencies] because the reduce-motion setting can change
  /// while the app is open.
  Duration? _interval;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _interval = AppCarouselAutoplay.resolve(
      context,
      enabled: FeatureFlags.bannerAutoRotate,
      interval: AppConstants.bannerInterval,
    );
    _restartAutoplay();
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _resume?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restartAutoplay() {
    _autoplay?.cancel();
    final interval = _interval;
    if (interval == null) return;
    _autoplay = Timer.periodic(interval, (_) {
      if (!mounted) return;
      ref.read(bannerControllerProvider.notifier).next();
    });
  }

  /// Stop rotating while the patient is interacting, and for a grace period
  /// after (WCAG 2.2.2 "pause").
  void _pauseForInteraction() {
    _autoplay?.cancel();
    _resume?.cancel();
    if (_interval == null) return;
    _resume = Timer(AppCarouselAutoplay.pauseAfterInteraction, () {
      if (!mounted) return;
      _restartAutoplay();
    });
  }

  void _goTo(int index) {
    _pauseForInteraction();
    ref.read(bannerControllerProvider.notifier).setIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(promoBannersProvider);
    final index = ref.watch(bannerControllerProvider);

    if (banners.isEmpty) return const SizedBox.shrink();

    // Keep the page in step with the controller's index (autoplay / dots).
    ref.listen<int>(bannerControllerProvider, (_, next) {
      if (!_controller.hasClients) return;
      _controller.animateToPage(
        next,
        duration: context.motion(AppConstants.easeShort),
        curve: Curves.easeOut,
      );
    });

    return Semantics(
      container: true,
      label: 'Offers, ${index + 1} of ${banners.length}',
      child: Listener(
        // Fires before the PageView's own drag recogniser, so a touch pauses
        // the clock even if it turns out not to be a swipe.
        onPointerDown: (_) => _pauseForInteraction(),
        child: SizedBox(
          height: 150.h,
          child: Stack(
            children: [
              Positioned.fill(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (page) => ref
                      .read(bannerControllerProvider.notifier)
                      .setIndex(page),
                  children: [
                    for (final banner in banners) _BannerSlide(banner: banner),
                  ],
                ),
              ),
              Positioned(
                left: 20.w,
                bottom: 14.h,
                child: AppCarouselDots(
                  count: banners.length,
                  activeIndex: index,
                  onDotTapped: _goTo,
                  activeColor: AppColors.textOnBrand,
                  inactiveColor: AppColors.textOnBrand.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerSlide extends StatelessWidget {
  const _BannerSlide({required this.banner});

  final PromoBanner banner;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: banner.gradient,
            ),
            borderRadius: AppRadii.lg,
          ),
          child: Stack(
            children: [
              if (banner.hasImage)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: w * 0.46,
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.transparent, Colors.black, Colors.black],
                      stops: [0.0, 0.32, 1.0],
                    ).createShader(rect),
                    child: Image.asset(
                      'assets/images/doctor-portrait.png',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0.24, -0.6),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(20.w),
                child: SizedBox(
                  width: w * 0.57,
                  // The slide is a fixed 150px band, so the copy has to live
                  // inside it: Flexible + maxLines truncates at a large OS
                  // text scale instead of overflowing the gradient.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          banner.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(
                            size: 19,
                            weight: AppText.bold,
                            color: AppColors.textOnBrand,
                            height: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Flexible(
                        child: Text(
                          banner.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(
                            size: 13,
                            weight: AppText.regular,
                            color: AppColors.textOnBrand.withValues(
                              alpha: 0.92,
                            ),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
