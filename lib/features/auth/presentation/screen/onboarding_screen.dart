import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/utils/motion.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_carousel_dots.dart';
import '../components/onboarding_slide.dart';
import '../components/screen_fade_rise.dart';
import '../../application/providers/onboarding_slides_controller.dart';

/// The first-run intro (`/onboarding`) — two slides, then the consent screen.
///
/// Shown once per device: the router sends a signed-out visitor here until
/// `onboardingProvider` records the consent, and to `/login` afterwards.
///
/// The slide index lives in [onboardingSlidesProvider]; this screen owns the
/// `PageController` and keeps it in step, so swiping, the dots and the button
/// all move the same state.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // The slides controller starts at 0 (autoDispose → fresh on entry), so the
  // initial page aligns without reading the provider here.
  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  OnboardingSlidesController get _slides =>
      ref.read(onboardingSlidesProvider(OnboardingSlides.all.length).notifier);

  void _advance() {
    if (_slides.isLast) {
      context.push(AppRoutes.onboardingConsent);
      return;
    }
    _slides.next();
  }

  @override
  Widget build(BuildContext context) {
    const slides = OnboardingSlides.all;
    final index = ref.watch(
      onboardingSlidesProvider(OnboardingSlides.all.length),
    );
    final isLast = index >= slides.length - 1;

    // Keep the page in step with the controller's index (dots / button).
    ref.listen<int>(onboardingSlidesProvider(OnboardingSlides.all.length), (
      _,
      next,
    ) {
      if (!_controller.hasClients) return;
      _controller.animateToPage(
        next,
        duration: context.motion(AppConstants.easeShort),
        curve: Curves.easeOut,
      );
    });

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: ScreenFadeRise(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  label: 'Introduction, slide ${index + 1} of ${slides.length}',
                  child: PageView(
                    controller: _controller,
                    onPageChanged: _slides.setIndex,
                    children: [
                      for (final slide in slides)
                        OnboardingSlideView(slide: slide),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 32.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 8.h, bottom: 20.h),
                      child: Center(
                        child: AppCarouselDots(
                          count: slides.length,
                          activeIndex: index,
                          onDotTapped: _slides.setIndex,
                          dotSize: 8,
                          activeWidth: 28,
                          tapTargetWidth: 44,
                          gap: 4,
                        ),
                      ),
                    ),
                    AppButton(
                      label: isLast ? 'Get Started' : 'Continue',
                      size: AppButtonSize.lg,
                      pill: true,
                      fullWidth: true,
                      onPressed: _advance,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
