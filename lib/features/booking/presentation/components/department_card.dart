import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/department.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';

/// Booking step 1 department tile. A tinted glyph square over the department
/// name + descriptor. When [selected] the card gains a 1.5px brand border
/// (unselected keeps a transparent 1.5px border so the layout never shifts).
class DepartmentCard extends StatelessWidget {
  const DepartmentCard({
    super.key,
    required this.department,
    required this.selected,
    this.onTap,
  });

  final Department department;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      border: Border.all(
        color: selected ? AppColors.brand : Colors.transparent,
        width: 1.5.w,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: AppColors.surfaceTint,
              borderRadius: BorderRadius.circular(AppRadius.md.r),
            ),
            alignment: Alignment.center,
            child: AppIcon(
              department.iconName,
              size: 24,
              color: AppColors.brand,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            department.name,
            style: AppText.poppins(
              size: 15,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            department.sub,
            style: AppText.poppins(size: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
