import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';

/// A labelled checkbox. `20x20` box, `radius 6`, 1.5px border (danger / brand /
/// grey300), white check path `M5 12l4.5 4.5L19 7` when checked. The whole row
/// is the tap target.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.error = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    if (error) {
      borderColor = AppColors.danger;
    } else if (value) {
      borderColor = AppColors.brand;
    } else {
      borderColor = AppColors.grey300;
    }

    final box = Container(
      width: 20.w,
      height: 20.w,
      decoration: BoxDecoration(
        color: value ? AppColors.brand : Colors.transparent,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: borderColor, width: 1.5.w),
      ),
      child: value
          ? CustomPaint(
              size: Size(20.w, 20.w),
              painter: _CheckPainter(
                color: AppColors.textOnBrand,
                strokeWidth: 2.w,
              ),
            )
          : null,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          box,
          if (label != null) ...[
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                label!,
                style: AppText.poppins(
                  size: AppFontSize.sm,
                  height: 1.45,
                  color: error ? AppColors.danger : AppColors.textBody,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Paints the checkmark polyline `M5 12l4.5 4.5L19 7`, authored in a 24×24 box.
class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.color, required this.strokeWidth});

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
      ..moveTo(5 * s, 12 * s)
      ..lineTo(9.5 * s, 16.5 * s)
      ..lineTo(19 * s, 7 * s);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
