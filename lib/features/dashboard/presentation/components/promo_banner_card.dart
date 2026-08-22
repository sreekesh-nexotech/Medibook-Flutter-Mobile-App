import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/promo_banner.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../controllers/banner_controller.dart';

/// The 150px rotating promo banner. A [PageView] (swipe disabled — the design
/// advances on tap) synced to [bannerControllerProvider]: the controller
/// drives the visible page (auto-rotate + manual `next()`), and this widget
/// animates the page whenever that index changes. Tapping anywhere advances.
class PromoBannerCard extends ConsumerStatefulWidget {
  const PromoBannerCard({super.key});

  @override
  ConsumerState<PromoBannerCard> createState() => _PromoBannerCardState();
}

class _PromoBannerCardState extends ConsumerState<PromoBannerCard> {
  // The banner controller starts at index 0 (autoDispose → fresh on entry), so
  // the initial page aligns without reading the provider here.
  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(promoBannersProvider);
    final index = ref.watch(bannerControllerProvider);

    // Keep the page in step with the controller's index (auto-rotate / tap).
    ref.listen<int>(bannerControllerProvider, (_, next) {
      if (!_controller.hasClients) return;
      _controller.animateToPage(
        next,
        duration: AppConstants.easeShort,
        curve: Curves.easeOut,
      );
    });

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(bannerControllerProvider.notifier).next(),
      child: SizedBox(
        height: 150.h,
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final banner in banners) _BannerSlide(banner: banner),
                ],
              ),
            ),
            Positioned(
              left: 20.w,
              bottom: 14.h,
              child: Row(
                children: [
                  for (var i = 0; i < banners.length; i++) ...[
                    if (i > 0) SizedBox(width: 5.w),
                    _Dot(active: i == index),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 18.w : 7.w,
      height: 7.h,
      decoration: BoxDecoration(
        color: active
            ? AppColors.textOnBrand
            : AppColors.textOnBrand.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4.r),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        banner.title,
                        style: AppText.poppins(
                          size: 19,
                          weight: AppText.bold,
                          color: AppColors.textOnBrand,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        banner.body,
                        style: AppText.poppins(
                          size: 13,
                          weight: AppText.regular,
                          color: AppColors.textOnBrand.withValues(alpha: 0.92),
                          height: 1.45,
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
