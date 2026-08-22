import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';

/// A selectable day chip for the Reschedule date row.
///
/// Appointments-local by design: the booking feature keeps its own copy — chips
/// are duplicated per feature rather than imported across features.
class ApptDateChip extends StatelessWidget {
  const ApptDateChip({
    super.key,
    required this.dow,
    required this.day,
    required this.selected,
    required this.onTap,
  });

  /// Day-of-week label ("Today", "Mon"…).
  final String dow;

  /// Day-of-month number ("22").
  final String day;
  final bool selected;
  final VoidCallback onTap;

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
          borderRadius: AppRadii.md,
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.border,
            width: 1.w,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.85,
              child: Text(
                dow,
                style: AppText.poppins(
                  size: 11,
                  weight: AppText.medium,
                  color: fg,
                ),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              day,
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
