import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../notifications/presentation/components/notification_bell.dart';

/// The Home navy header, as the design draws it: greeting on the left, the
/// bell (with its unread dot) on the right, and a white pill search bar
/// beneath. Pure presentation — the screen supplies the user's [name] and the
/// two tap callbacks.
///
/// Design: `padding 56px 20px 20px` (the 56 includes the 46px status zone,
/// so the content sits 10px below the OS inset), bottom corners
/// `--radius-xl`, greeting `16/400`, name `22/700` at `lh-tight`, bell
/// `38` with a `24` glyph, search pill `52` tall with `20` side padding.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.name,
    required this.onBell,
    required this.onSearchTap,
  });

  /// Full display name ("Alexandra Johnson"); the greeting shows the first word.
  final String name;
  final VoidCallback onBell;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final firstName = name.trim().split(' ').first;
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, topInset + 10.h, 20.w, 20.h),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24.r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // With no first name on the account the greeting is one
                    // line — never a stray "!" or a placeholder name.
                    if (firstName.isEmpty)
                      Text(
                        'Welcome back!',
                        style: AppText.poppins(
                          size: 22,
                          weight: AppText.bold,
                          color: AppColors.textOnBrand,
                          height: 1.2,
                        ),
                      )
                    else ...[
                      Text(
                        'Welcome back,',
                        style: AppText.poppins(
                          size: 16,
                          weight: AppText.regular,
                          color: AppColors.textOnBrand,
                        ),
                      ),
                      Text(
                        '$firstName!',
                        style: AppText.poppins(
                          size: 22,
                          weight: AppText.bold,
                          color: AppColors.textOnBrand,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // The design pads the bell 4px off the baseline row.
              Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: NotificationBellButton(
                  onPressed: onBell,
                  variant: AppIconButtonVariant.onBrand,
                  size: 38,
                  iconSize: 24,
                  dot: true,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Semantics(
            button: true,
            label: 'Search',
            child: ExcludeSemantics(
              child: GestureDetector(
                onTap: onSearchTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 52.h,
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.pill,
                  ),
                  child: Row(
                    children: [
                      AppIcon(
                        PhIcon.magnifyingGlass,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'Search here...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(
                            size: 14,
                            weight: AppText.regular,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
