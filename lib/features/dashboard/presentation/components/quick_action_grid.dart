import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';

/// One tile in a [QuickActionGrid]: an icon glyph over a label, tappable.
class QuickAction {
  const QuickAction({
    required this.iconName,
    required this.label,
    required this.onTap,
  });

  /// [MedIcon] name for the tile glyph.
  final String iconName;
  final String label;
  final VoidCallback onTap;
}

/// A row of three icon tiles — reused by both "Quick Booking" and "Available
/// Services" on Home. Each tile is an [AppCard] (press feedback baked in) with
/// a tinted rounded icon holder over a centered label.
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key, required this.actions});

  /// Exactly three actions (left → right).
  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) SizedBox(width: 12.w),
          Expanded(child: _Tile(action: actions[i])),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: action.onTap,
      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 8.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46.r,
            height: 46.r,
            decoration: BoxDecoration(
              color: AppColors.surfaceTint,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Center(
              child: AppIcon(action.iconName, size: 26, color: AppColors.brand),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            action.label,
            textAlign: TextAlign.center,
            style: AppText.poppins(
              size: 13,
              weight: AppText.medium,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
