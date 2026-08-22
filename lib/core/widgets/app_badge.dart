import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../app/theme/typography.dart';

/// Semantic tone for an [AppBadge].
enum AppBadgeTone { neutral, brand, success, danger, warning }

/// A soft status pill for record/appointment state ("Completed", "Pending").
/// Pill, padding `6x14`, `--fs-sm`, weight medium.
class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, this.tone = AppBadgeTone.neutral});

  final String label;
  final AppBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (tone) {
      case AppBadgeTone.neutral:
        bg = AppColors.grey100;
        fg = AppColors.textBody;
      case AppBadgeTone.brand:
        bg = AppColors.surfaceTint;
        fg = AppColors.brand;
      case AppBadgeTone.success:
        bg = AppColors.successSoft;
        fg = AppColors.successText;
      case AppBadgeTone.danger:
        bg = AppColors.dangerSoft;
        fg = AppColors.dangerText;
      case AppBadgeTone.warning:
        bg = AppColors.warningSoft;
        fg = AppColors.warning;
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 14.w),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.pill),
      child: Text(
        label,
        style: AppText.poppins(
          size: AppFontSize.sm,
          weight: AppText.medium,
          color: fg,
        ),
      ),
    );
  }
}
