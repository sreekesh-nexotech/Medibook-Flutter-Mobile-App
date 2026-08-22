import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';

/// Booking / reschedule "Select time" chip. Selected → brand fill + white text;
/// else white surface with a hairline border + body text. Named `TimeChipTile`
/// for symmetry with [DateChipTile].
class TimeChipTile extends StatelessWidget {
  const TimeChipTile({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.border,
            width: 1.w,
          ),
        ),
        child: Text(
          label,
          style: AppText.poppins(
            size: 13,
            weight: AppText.medium,
            color: selected ? AppColors.textOnBrand : AppColors.textBody,
          ),
        ),
      ),
    );
  }
}
