import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/support_content.dart';
import '../../../../core/utils/motion.dart';
import '../../../../core/widgets/app_card.dart';

/// One expandable question-and-answer row on the FAQ screen (CM-52).
///
/// The whole card is the tap target (so there is no small icon-only control to
/// mis-hit), and it announces itself to a screen reader as an expandable
/// button with its current state. The open/close animation runs through
/// [MotionContext.motion], so a viewer with "reduce motion" on gets an instant
/// change instead of a height animation.
///
/// Pure presentation: [isExpanded] and [onToggle] are owned by
/// `faqControllerProvider`, so expansion survives a rebuild and a search.
class FaqEntryTile extends StatelessWidget {
  const FaqEntryTile({
    super.key,
    required this.entry,
    required this.isExpanded,
    required this.onToggle,
  });

  final FaqEntry entry;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: isExpanded,
      label: entry.question,
      hint: isExpanded ? 'Collapse answer' : 'Expand answer',
      child: ExcludeSemantics(
        child: AppCard(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.x4.w,
            vertical: AppSpacing.x4.h,
          ),
          onTap: onToggle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.question,
                      style: AppText.poppins(
                        size: AppFontSize.base,
                        weight: AppText.semibold,
                        color: AppColors.textStrong,
                        height: 1.4,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.x3.w),
                  _Chevron(isExpanded: isExpanded),
                ],
              ),
              AnimatedSize(
                duration: context.motion(AppConstants.easeShort),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: isExpanded
                    ? Padding(
                        padding: EdgeInsets.only(top: AppSpacing.x3.h),
                        child: Text(
                          entry.answer,
                          style: AppText.poppins(
                            size: AppFontSize.base,
                            color: AppColors.textBody,
                            height: 1.6,
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The open/close indicator. Drawn rather than an [AppIcon] because the icon
/// set has no chevron — `AppSelect` paints the same glyph the same way.
class _Chevron extends StatelessWidget {
  const _Chevron({required this.isExpanded});

  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: isExpanded ? 0.5 : 0,
      duration: context.motion(AppConstants.easeShort),
      curve: Curves.easeOut,
      child: CustomPaint(
        size: Size(18.r, 18.r),
        painter: _ChevronPainter(color: AppColors.brand, strokeWidth: 2.w),
      ),
    );
  }
}

/// `M6 9l6 6 6-6`, authored in a 24x24 box (the design system's chevron).
class _ChevronPainter extends CustomPainter {
  _ChevronPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(6 * s, 9 * s)
      ..lineTo(12 * s, 15 * s)
      ..lineTo(18 * s, 9 * s);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
