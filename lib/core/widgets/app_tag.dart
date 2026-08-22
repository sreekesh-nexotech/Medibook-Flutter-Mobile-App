import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../app/theme/typography.dart';

/// A small relation/label chip ("Self", "Husband"). Pill `4x12`, `--fs-xs`,
/// weight medium. [active] → brand fill / white; else tint / brand.
class AppTag extends StatelessWidget {
  const AppTag({super.key, required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: active ? AppColors.brand : AppColors.surfaceTint,
        borderRadius: AppRadii.pill,
      ),
      child: Text(
        label,
        style: AppText.poppins(
          size: AppFontSize.xs,
          weight: AppText.medium,
          color: active ? AppColors.textOnBrand : AppColors.brand,
        ),
      ),
    );
  }
}
