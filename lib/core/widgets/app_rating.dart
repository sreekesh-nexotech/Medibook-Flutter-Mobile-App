import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';
import 'app_icon.dart';

/// A star rating row. Display-only when [onRate] is null; when provided, each
/// star is tappable and reports its 1-based value. Filled stars paint
/// `--warning`, empty stars `--grey-200`, `gap 3`.
class AppRating extends StatelessWidget {
  const AppRating({
    super.key,
    required this.value,
    this.max = 5,
    this.size = 16,
    this.showValue = false,
    this.onRate,
  });

  final double value;
  final int max;
  final double size;
  final bool showValue;

  /// `ValueChanged<int>?` — display-only when null.
  final ValueChanged<int>? onRate;

  @override
  Widget build(BuildContext context) {
    final filledCount = value.round();

    final children = <Widget>[];
    for (var i = 0; i < max; i++) {
      final filled = i < filledCount;
      Widget star = AppIcon(
        filled ? MedIcon.bold(MedIcon.star) : MedIcon.star,
        size: size,
        color: filled ? AppColors.warning : AppColors.grey200,
      );
      if (onRate != null) {
        star = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onRate!(i + 1),
          child: star,
        );
      }
      children.add(star);
      if (i < max - 1) children.add(SizedBox(width: 3.w));
    }

    if (showValue) {
      children
        ..add(SizedBox(width: 6.w))
        ..add(
          Text(
            value.toStringAsFixed(1),
            style: AppText.poppins(
              size: AppFontSize.sm,
              weight: AppText.medium,
              color: AppColors.textBody,
            ),
          ),
        );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
