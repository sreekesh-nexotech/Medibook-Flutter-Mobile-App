import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/router/app_routes.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';

/// The 4-tab bottom navigation bar. Renders the exact custom nav glyphs
/// (`assets/icons/nav_<tab>[_active].svg`, 25×25) recolored `brand` (active) /
/// `grey300` (inactive). Bar padding `12,8,18`, top border `borderSubtle`,
/// surface bg. The shell wires [onChanged] to tab navigation.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.active, this.onChanged});

  final AppTab active;
  final ValueChanged<AppTab>? onChanged;

  static const List<AppTab> _tabs = [
    AppTab.home,
    AppTab.appointments,
    AppTab.records,
    AppTab.profile,
  ];

  String _key(AppTab tab) => switch (tab) {
    AppTab.home => 'home',
    AppTab.appointments => 'appointments',
    AppTab.records => 'records',
    AppTab.profile => 'profile',
  };

  String _label(AppTab tab) => switch (tab) {
    AppTab.home => 'Home',
    AppTab.appointments => 'Appointments',
    AppTab.records => 'Records',
    AppTab.profile => 'Profile',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.w),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8.w, 12.h, 8.w, 18.h),
          child: Row(
            children: [
              for (final tab in _tabs)
                Expanded(child: _NavTab(
                  tab: tab,
                  isActive: tab == active,
                  assetKey: _key(tab),
                  label: _label(tab),
                  onTap: onChanged == null ? null : () => onChanged!(tab),
                )),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.tab,
    required this.isActive,
    required this.assetKey,
    required this.label,
    this.onTap,
  });

  final AppTab tab;
  final bool isActive;
  final String assetKey;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.brand : AppColors.grey300;
    final asset =
        'assets/icons/nav_$assetKey${isActive ? '_active' : ''}.svg';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            asset,
            width: 25.r,
            height: 25.r,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.poppins(
              size: 12,
              weight: isActive ? AppText.semibold : AppText.regular,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
