import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../app/theme/typography.dart';

/// A typed option for [AppSelect].
class AppSelectOption<T> {
  const AppSelectOption(this.value, this.label);

  final T value;
  final String label;
}

/// A dropdown styled to match [AppTextField]. Custom chevron `M6 9l6 6 6-6`.
/// (Part of the DS for completeness; not used by the current 15 screens.)
class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    this.label,
    this.value,
    this.placeholder = 'Select',
    required this.options,
    this.onChanged,
  });

  final String? label;
  final T? value;
  final String placeholder;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.medium,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 8.h),
        ],
        Container(
          height: 52.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: AppRadii.md,
            border: Border.all(color: AppColors.border, width: 1.w),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              onChanged: onChanged,
              dropdownColor: AppColors.surface,
              borderRadius: AppRadii.md,
              icon: _ChevronDown(),
              hint: Text(
                placeholder,
                style: AppText.poppins(
                  size: AppFontSize.body,
                  color: AppColors.textMuted,
                ),
              ),
              style: AppText.poppins(
                size: AppFontSize.body,
                color: AppColors.textPrimary,
              ),
              items: [
                for (final option in options)
                  DropdownMenuItem<T>(
                    value: option.value,
                    child: Text(
                      option.label,
                      style: AppText.poppins(
                        size: AppFontSize.body,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The chevron glyph `M6 9l6 6 6-6` (authored in a 24×24 box).
class _ChevronDown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(20.r, 20.r),
      painter: _ChevronPainter(color: AppColors.textMuted, strokeWidth: 2.w),
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
