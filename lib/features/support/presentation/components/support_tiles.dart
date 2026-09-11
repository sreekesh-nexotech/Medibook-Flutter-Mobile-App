import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon.dart';

/// A contact channel on the support screen: what it is, the address to use,
/// and one action.
///
/// ## Why the action is "Copy" and not "Call" or "Email"
///
/// This build ships no telephony and no URL launcher, and must not gain one.
/// A "Call support" button would therefore have to lie. Copying to the
/// clipboard, on the other hand, genuinely happens — so the honest control here
/// is the one that does something real (THE LAW, option 1), and the address is
/// shown in full so it can also just be read or dictated.
class SupportContactTile extends StatelessWidget {
  const SupportContactTile({
    super.key,
    required this.iconName,
    required this.title,
    required this.value,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.actionSemanticLabel,
  });

  /// A [MedIcon] name.
  final String iconName;

  final String title;

  /// The address itself — selectable text, so it can be copied by hand too.
  final String value;

  /// One line on when to use this channel and how fast it answers.
  final String description;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// What a screen reader announces for the action ("Copy the support email
  /// address"), because "Copy" on its own does not say copy *what*.
  final String? actionSemanticLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.x3.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surfaceTint,
              shape: BoxShape.circle,
            ),
            child: AppIcon(iconName, size: 18, color: AppColors.brand),
          ),
          SizedBox(width: AppSpacing.x3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: AppText.semibold,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 2.h),
                SelectableText(
                  value,
                  style: AppText.inter(
                    size: AppFontSize.sm,
                    weight: AppText.medium,
                    color: AppColors.textLink,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    height: 1.45,
                    color: AppColors.textMuted,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  SizedBox(height: AppSpacing.x2.h),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppButton(
                      label: actionLabel!,
                      variant: AppButtonVariant.soft,
                      size: AppButtonSize.sm,
                      semanticLabel: actionSemanticLabel,
                      onPressed: onAction,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A navigation row inside a support card — an FAQ link, a policy, the
/// ambulance screen.
///
/// The whole row is the tap target (48px minimum), and it carries an explicit
/// semantic label so a screen reader hears the destination rather than just
/// the icon (audit §3.3.1).
class SupportLinkTile extends StatelessWidget {
  const SupportLinkTile({
    super.key,
    required this.iconName,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.semanticLabel,
    this.showDivider = true,
  });

  final String iconName;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final String? semanticLabel;

  /// A hairline under the row; the last row in a card passes false.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: AppButton.minTapHeight.h),
            padding: EdgeInsets.symmetric(vertical: AppSpacing.x3.h),
            decoration: showDivider
                ? BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.borderSubtle,
                        width: 1.w,
                      ),
                    ),
                  )
                : null,
            child: Row(
              children: [
                AppIcon(iconName, size: 20, color: AppColors.brand),
                SizedBox(width: AppSpacing.x3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: AppText.poppins(
                          size: AppFontSize.base,
                          weight: AppText.medium,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          subtitle!,
                          style: AppText.poppins(
                            size: AppFontSize.xs,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.x2.w),
                const _RowChevron(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The trailing chevron. Painted, because the icon set has none — same path as
/// `AppSelect`'s.
class _RowChevron extends StatelessWidget {
  const _RowChevron();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      // A quarter turn anti-clockwise: the down-chevron becomes a right one.
      angle: -math.pi / 2,
      child: CustomPaint(
        size: Size(16.r, 16.r),
        painter: _ChevronPainter(
          color: AppColors.textMutedDecorative,
          strokeWidth: 2.w,
        ),
      ),
    );
  }
}

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

/// A section heading inside a support / profile card.
class SupportCardTitle extends StatelessWidget {
  const SupportCardTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.x2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppText.poppins(
                size: AppFontSize.body,
                weight: AppText.bold,
                color: AppColors.textStrong,
              ),
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 4.h),
            Text(
              subtitle!,
              style: AppText.poppins(
                size: AppFontSize.xs,
                height: 1.45,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A labelled inset row for a read-only fact ("Hours", "Response time").
class SupportFactRow extends StatelessWidget {
  const SupportFactRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: AppSpacing.x2.h),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.x3.w,
        vertical: AppSpacing.x3.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.poppins(
                size: AppFontSize.sm,
                color: AppColors.textMuted,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.x2.w),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.poppins(
                size: AppFontSize.sm,
                weight: AppText.medium,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
