import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/date_utils.dart';

/// Booking / reschedule "Select date" chip. Two stacked labels (day-of-week over
/// day-of-month) built from a [DateChip] model. Selected → brand fill + white
/// text; else white surface with a hairline border + body text.
///
/// Named `DateChipTile` to avoid clashing with the [DateChip] data model in
/// `core/utils/date_utils.dart`.
class DateChipTile extends StatelessWidget {
  const DateChipTile({
    super.key,
    required this.data,
    required this.selected,
    this.onTap,
  });

  final DateChip data;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.textOnBrand : AppColors.textBody;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              data.dow,
              style: AppText.poppins(
                size: 11,
                weight: AppText.medium,
                color: fg.withValues(alpha: 0.85),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              data.day,
              style: AppText.poppins(
                size: 15,
                weight: AppText.semibold,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
