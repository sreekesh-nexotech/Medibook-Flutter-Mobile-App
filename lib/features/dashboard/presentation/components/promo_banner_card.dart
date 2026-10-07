import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/motion.dart';
import '../../../booking/domain/entities/promo_banner.dart';
import '../../../booking/presentation/components/file_image.dart';

/// Home's promo banners, as the design draws them: a horizontal strip of
/// `320 × 150` cards (`gap 16`, `20` lead/trail). Each card carries its own
/// position dots along the bottom.
///
/// The strip moves on to the next card every [interval] and wraps to the
/// first after the last (owner decision 6 Oct 2026, CL HOME-006). It stays
/// still when the phone asks for reduced motion (WCAG 2.2.2), while the
/// patient's finger is on it (and for one interval after), when Home is
/// covered by another screen, and when there is only one card.
///
/// The banners are the visible hospitals' (§7.4): title, body and, when the
/// banner has one, its image (`image_file_id`) in the right `46%` under a
/// navy overlay. Copy sits in the left `62%`. The design's gradient is
/// alternated per card since the backend carries no colour.
class PromoBannerCard extends StatefulWidget {
  const PromoBannerCard({
    super.key,
    required this.banners,
    required this.onTap,
    this.interval = const Duration(seconds: 4),
  });

  final List<HospitalBanner> banners;

  /// Opens the banner's hospital.
  final ValueChanged<HospitalBanner> onTap;

  /// How long each card stays before the next one slides in.
  final Duration interval;

  @override
  State<PromoBannerCard> createState() => _PromoBannerCardState();
}

class _PromoBannerCardState extends State<PromoBannerCard> {
  final ScrollController _scroll = ScrollController();
  Timer? _timer;
  bool _touching = false;
  DateTime _lastTouch = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartTimer();
  }

  @override
  void didUpdateWidget(PromoBannerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interval != widget.interval ||
        oldWidget.banners.length != widget.banners.length) {
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    final interval = autoAdvanceInterval(context, widget.interval);
    if (interval == null || widget.banners.length < 2) return;
    _timer = Timer.periodic(interval, (_) => _advance());
  }

  double get _step => 320.w + 16.w;

  void _advance() {
    if (!mounted || !_scroll.hasClients || _touching) return;
    if (DateTime.now().difference(_lastTouch) < widget.interval) return;
    // Only while Home is the screen on top.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final position = _scroll.position;
    final current = (position.pixels / _step).round();
    final atEnd = position.pixels >= position.maxScrollExtent - 1;
    final next = atEnd ? 0 : current + 1;
    final target = (next * _step).clamp(0.0, position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  void _touch(bool down) {
    _touching = down;
    _lastTouch = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    if (banners.isEmpty) return const SizedBox.shrink();

    return Semantics(
      container: true,
      label: 'Offers',
      child: Listener(
        onPointerDown: (_) => _touch(true),
        onPointerUp: (_) => _touch(false),
        onPointerCancel: (_) => _touch(false),
        child: SizedBox(
          height: 150.h,
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            itemCount: banners.length,
            separatorBuilder: (_, _) => SizedBox(width: 16.w),
            itemBuilder: (context, index) => _BannerSlide(
              banner: banners[index],
              index: index,
              count: banners.length,
              onTap: () => widget.onTap(banners[index]),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerSlide extends StatelessWidget {
  const _BannerSlide({
    required this.banner,
    required this.index,
    required this.count,
    required this.onTap,
  });

  final HospitalBanner banner;
  final int index;
  final int count;
  final VoidCallback onTap;

  static const List<List<Color>> _gradients = [
    [Color(0xFF1D3557), Color(0xFF2E6F95)],
    [Color(0xFF0F766E), Color(0xFF14B8A6)],
    [Color(0xFF7C3AED), Color(0xFFA78BFA)],
  ];

  @override
  Widget build(BuildContext context) {
    const width = 320.0;
    final gradient = _gradients[index % _gradients.length];
    final cta = banner.ctaLabel?.trim().isEmpty ?? true
        ? null
        : banner.ctaLabel!.trim();
    return Semantics(
      button: true,
      label: [banner.title, ?banner.body, ?cta].join('. '),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: width.w,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: AppRadii.lg,
            ),
            child: Stack(
              children: [
                if (banner.imageFileId != null) ...[
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: width.w * 0.46,
                    child: AppFileImage(
                      fileId: banner.imageFileId,
                      fallback: const SizedBox.shrink(),
                      alignment: const Alignment(0.2, -0.6),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xF01D3557),
                            Color(0xCC1D3557),
                            Color(0x1A1D3557),
                          ],
                          stops: [0.0, 0.52, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          // Beside an image the copy keeps the left 62%;
                          // without one it may use the whole card, so the
                          // server's full title has room (HOME audit 6 Oct).
                          width: banner.imageFileId == null
                              ? (width - 40).w
                              : ((width - 40) * 0.62).w,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  banner.title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.poppins(
                                    size: AppFontSize.body,
                                    weight: AppText.bold,
                                    color: AppColors.textOnBrand,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              if (banner.body != null) ...[
                                SizedBox(height: 4.h),
                                Text(
                                  banner.body!,
                                  maxLines: cta == null ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.poppins(
                                    size: AppFontSize.sm,
                                    color: AppColors.textOnBrand,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                              if (cta != null) ...[
                                SizedBox(height: 8.h),
                                // The banner's own call to action
                                // (`cta_label`); the tap goes to its
                                // `cta_target`.
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.textOnBrand,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    cta,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.poppins(
                                      size: AppFontSize.xs,
                                      weight: AppText.semibold,
                                      color: gradient.first,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      _Dots(count: count, active: index),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The card's own position marker, centred along its bottom edge.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) SizedBox(width: 4.w),
          Container(
            height: 6.h,
            width: (i == active ? 18 : 6).w,
            decoration: BoxDecoration(
              color: i == active
                  ? AppColors.textOnBrand
                  : AppColors.textOnBrand.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(3.r),
            ),
          ),
        ],
      ],
    );
  }
}
