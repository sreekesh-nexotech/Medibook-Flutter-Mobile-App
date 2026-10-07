import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_icon.dart';

/// One intro slide: the hero photograph with its pill tag, then the promise.
///
/// Presentation view-model — immutable, no logic.
@immutable
class OnboardingSlide {
  const OnboardingSlide({
    required this.tag,
    required this.title,
    required this.body,
    required this.image,
    required this.icon,
    this.focus = Alignment.center,
  });

  /// The pill over the photo ("Book in seconds").
  final String tag;

  /// [MedIcon] name inside the pill.
  final String icon;

  final String title;
  final String body;

  /// Asset path of the hero photograph.
  final String image;

  /// Which part of the photograph stays in frame when it is cropped to cover
  /// the hero (CSS `background-position`, mapped onto [Alignment]).
  final Alignment focus;
}

/// The two slides — the promise, then the proof. Anything else is
/// discoverable in-app.
abstract final class OnboardingSlides {
  OnboardingSlides._();

  static const List<OnboardingSlide> all = [
    OnboardingSlide(
      tag: 'Book in seconds',
      icon: PhIcon.calendarBlank,
      title: 'See a doctor without the wait',
      body:
          'Pick a department, compare doctors near you and book a real slot '
          '— most people are done in under a minute.',
      image: 'assets/images/doctor-portrait.png',
      // Design: `background-position: 58% 20%`.
      focus: Alignment(0.16, -0.6),
    ),
    OnboardingSlide(
      tag: 'Pay upfront',
      icon: PhIcon.clock,
      title: 'Arrive on time, skip the queue',
      body:
          'Your token is held the moment you pay. Walk in at your slot '
          'instead of waiting your turn — for you or anyone in your family.',
      image: 'assets/images/hospital.jpg',
    ),
  ];
}

/// One page of the intro `PageView`: the 340px hero, then the title and body.
///
/// Scrolls only if it has to — at the 1.3x text-scale cap on a short phone
/// the copy can outgrow the slide, and clipping a sentence is worse than a
/// scroll nobody will notice.
class OnboardingSlideView extends StatelessWidget {
  const OnboardingSlideView({super.key, required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24.w, 18.h, 24.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(slide: slide),
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 32.h, 4.w, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    slide.title,
                    style: AppText.poppins(
                      size: AppFontSize.h1,
                      weight: AppText.bold,
                      height: 1.25,
                      color: AppColors.textStrong,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  slide.body,
                  style: AppText.poppins(
                    size: AppFontSize.body,
                    height: 1.5,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The photograph, cropped to cover, with the navy fade at the foot and the
/// white pill tag in the bottom-left corner.
class _Hero extends StatelessWidget {
  const _Hero({required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.xl,
      child: SizedBox(
        height: 340.h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The tint shows for the frame or two before the asset decodes.
            const ColoredBox(color: AppColors.surfaceTint),
            Image.asset(
              slide.image,
              fit: BoxFit.cover,
              alignment: slide.focus,
              excludeFromSemantics: true,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.45, 1.0],
                  colors: [
                    AppColors.brand.withValues(alpha: 0),
                    AppColors.brand.withValues(alpha: 0.74),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20.w,
              bottom: 20.h,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.94),
                  borderRadius: AppRadii.pill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(slide.icon, size: 18, color: AppColors.brand),
                    SizedBox(width: 8.w),
                    Text(
                      slide.tag,
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        weight: AppText.semibold,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
