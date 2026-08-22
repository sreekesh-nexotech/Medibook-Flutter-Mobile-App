import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../app/theme/typography.dart';

/// A horizontally-scrolling row of pill tabs (Upcoming/Past, department names).
/// `gap 8`, each `9x18`, `--fs-sm`/medium. Active navy fill/white; else surface
/// + `border` + `textBody`.
class AppSegmentedTabs extends StatelessWidget {
  const AppSegmentedTabs({
    super.key,
    required this.tabs,
    required this.active,
    this.onChanged,
  });

  final List<String> tabs;
  final String active;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) SizedBox(width: 8.w),
            _SegTab(
              label: tabs[i],
              isActive: tabs[i] == active,
              onTap: onChanged == null ? null : () => onChanged!(tabs[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegTab extends StatelessWidget {
  const _SegTab({required this.label, required this.isActive, this.onTap});

  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 9.h, horizontal: 18.w),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brand : AppColors.surface,
          borderRadius: AppRadii.pill,
          border: isActive
              ? null
              : Border.all(color: AppColors.border, width: 1.w),
        ),
        child: Text(
          label,
          style: AppText.poppins(
            size: AppFontSize.sm,
            weight: AppText.medium,
            color: isActive ? AppColors.textOnBrand : AppColors.textBody,
          ),
        ),
      ),
    );
  }
}
