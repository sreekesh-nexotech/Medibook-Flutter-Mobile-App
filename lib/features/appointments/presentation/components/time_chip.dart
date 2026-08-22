import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';

/// A selectable time-slot chip for the Reschedule time grid.
///
/// Appointments-local (see [ApptDateChip]); not shared with the booking feature.
class ApptTimeChip extends StatelessWidget {
  const ApptTimeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
