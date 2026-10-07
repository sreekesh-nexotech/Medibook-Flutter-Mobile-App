import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';

/// Booking step 1 department tile, as the design draws it: a `Card` holding a
/// centred column (`gap 12`, content `144` tall) — a `64` square
/// (`--radius-lg`) with the `40` Healthicons mark, then the name (`16/600`,
/// navy, two lines) and the descriptor (`12`, muted, one line).
///
/// Selected: a `2px` brand ring around the card, the square fills brand and
/// the mark turns white. Unselected keeps a transparent ring so nothing
/// shifts. Data is a [DepartmentSummary] (platform list) or a
/// [HospitalDepartment] (one facility), reduced to the three strings here.
class DepartmentCard extends StatelessWidget {
  const DepartmentCard({
    super.key,
    required this.name,
    required this.sub,
    required this.iconName,
    required this.selected,
    this.onTap,
  });

  final String name;

  /// "4 hospitals" / "Heart and vascular care".
  final String sub;
  final String iconName;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$name, $sub',
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.all(2.r),
          decoration: BoxDecoration(
            color: selected ? AppColors.brand : Colors.transparent,
            borderRadius: AppRadii.lg,
          ),
          child: AppCard(
            onTap: onTap,
            child: SizedBox(
              height: 144.h,
              child: Column(
                children: [
                  Container(
                    width: 64.r,
                    height: 64.r,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.brand : AppColors.surfaceTint,
                      borderRadius: AppRadii.lg,
                    ),
                    child: AppIcon(
                      iconName,
                      size: 40,
                      color: selected ? AppColors.textOnBrand : AppColors.brand,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(
                      size: AppFontSize.body,
                      weight: AppText.semibold,
                      color: AppColors.textStrong,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    sub,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(
                      size: AppFontSize.xs,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
