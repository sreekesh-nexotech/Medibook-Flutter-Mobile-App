import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../notifications/presentation/components/notification_bell.dart';

/// The Home navy header: greeting + bell + ringed avatar, with a white pill
/// search bar beneath. Pure presentation — the screen supplies the user's
/// [name] and the three tap callbacks. Top padding is `14.h` (design 58px minus
/// the 44px faux status bar; the screen is wrapped in `SafeArea`).
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.name,
    required this.onBell,
    required this.onAvatar,
    required this.onSearchTap,
  });

  /// Full display name ("Alexandra Johnson"); the greeting shows the first word.
  final String name;
  final VoidCallback onBell;
  final VoidCallback onAvatar;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final firstName = name.split(' ').first;
    // The navy block owns the status zone: OS inset + the design's 14px
    // (design 58 = 44 status + 14 content).
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, topInset + 14.h, 20.w, 22.h),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26.r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: AppText.poppins(
                        size: 16,
                        weight: AppText.regular,
                        color: AppColors.textOnBrand.withValues(alpha: 0.9),
                      ),
                    ),
                    Text(
                      '$firstName!',
                      style: AppText.poppins(
                        size: 26,
                        weight: AppText.bold,
                        color: AppColors.textOnBrand,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              // The bell carries the unread count (CM-41) and its own
              // semantics label; it reads the store itself, so the header
              // stays a plain widget.
              NotificationBellButton(
                onPressed: onBell,
                variant: AppIconButtonVariant.onBrand,
                size: 40,
              ),
              SizedBox(width: 14.w),
              GestureDetector(
                onTap: onAvatar,
                behavior: HitTestBehavior.opaque,
                child: AppAvatar(name: name, size: 42, ring: true),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          GestureDetector(
            onTap: onSearchTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 52.h,
              padding: EdgeInsets.symmetric(horizontal: 18.w),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.pill,
              ),
              child: Row(
                children: [
                  AppIcon(MedIcon.search, size: 20, color: AppColors.textMuted),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Search doctors or departments...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(
                        size: 15,
                        weight: AppText.regular,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
