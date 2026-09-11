import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';

/// A titled group of navigation rows on the Profile tab.
///
/// The audit's §2.1 finding was that Profile is a dead end: "no help, FAQ,
/// support or legal screen is reachable from anywhere in the app", and neither
/// were emergency contacts, addresses, insurance or a password change. This
/// card is the fix — it is how every one of those screens becomes reachable.
class ProfileMenuCard extends StatelessWidget {
  const ProfileMenuCard({super.key, required this.title, required this.rows});

  final String title;

  /// The rows, in order. The last one's divider is dropped automatically, so
  /// callers do not have to track which is last.
  final List<ProfileMenuRow> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x4.w,
        AppSpacing.x4.h,
        AppSpacing.x4.w,
        AppSpacing.x2.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          SizedBox(height: AppSpacing.x1.h),
          for (var i = 0; i < rows.length; i++)
            _MenuRowView(row: rows[i], showDivider: i < rows.length - 1),
        ],
      ),
    );
  }
}

/// One row's data. A value type so [ProfileMenuCard] can decide which row is
/// last, and so a screen can build its rows in a list comprehension.
@immutable
class ProfileMenuRow {
  const ProfileMenuRow({
    required this.iconName,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.trailingText,
    this.semanticLabel,
    this.isDestructive = false,
  });

  /// A [MedIcon] name.
  final String iconName;

  final String label;

  /// One quiet line saying what is behind the row — or, when a list is empty,
  /// that it is ("None saved yet").
  final String? subtitle;

  /// A short value on the right ("2 saved", "O+"), so the row answers the
  /// question without being opened.
  final String? trailingText;

  final VoidCallback onTap;

  /// What a screen reader announces. Defaults to [label]; pass one whenever
  /// the label alone is ambiguous out of context.
  final String? semanticLabel;

  /// Paints the row in the danger colour — logout and delete account.
  final bool isDestructive;
}

class _MenuRowView extends StatelessWidget {
  const _MenuRowView({required this.row, required this.showDivider});

  final ProfileMenuRow row;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tint = row.isDestructive ? AppColors.danger : AppColors.brand;

    return Semantics(
      button: true,
      label: row.semanticLabel ?? row.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: row.onTap,
          child: Container(
            // Minimum height, so the row grows with the text scale.
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
                AppIcon(row.iconName, size: 20, color: tint),
                SizedBox(width: AppSpacing.x3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        row.label,
                        style: AppText.poppins(
                          size: AppFontSize.base,
                          weight: AppText.medium,
                          color: row.isDestructive
                              ? AppColors.danger
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (row.subtitle != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          row.subtitle!,
                          style: AppText.poppins(
                            size: AppFontSize.xs,
                            height: 1.4,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (row.trailingText != null) ...[
                  SizedBox(width: AppSpacing.x2.w),
                  Text(
                    row.trailingText!,
                    style: AppText.poppins(
                      size: AppFontSize.xs,
                      weight: AppText.medium,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                SizedBox(width: AppSpacing.x2.w),
                const ProfileRowChevron(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The trailing "opens a screen" chevron. Painted, because the icon set has no
/// chevron glyph — `AppSelect` paints the same path the same way.
class ProfileRowChevron extends StatelessWidget {
  const ProfileRowChevron({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      // A quarter turn anti-clockwise turns the down-chevron into a right one.
      angle: -math.pi / 2,
      child: CustomPaint(
        size: Size(16.r, 16.r),
        painter: _ChevronPainter(
          color: color ?? AppColors.textMutedDecorative,
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
