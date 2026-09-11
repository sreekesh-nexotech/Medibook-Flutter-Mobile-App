import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/router/app_routes.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';

/// The 4-tab bottom navigation bar. Renders the exact custom nav glyphs
/// (`assets/icons/nav_<tab>[_active].svg`, 25×25) recolored `brand` (active) /
/// `textInactive` (inactive). Bar padding `12,8,18`, top border
/// `borderSubtle`, surface bg. The shell wires [onChanged] to tab navigation.
///
/// ## Accessibility (audit §3.3.1, §3.3.7, §3.3.8)
///
/// * **Contrast.** The inactive label used `grey300` (`#999EA3`), which
///   measures **2.70:1** on white — well under the 4.5:1 floor. It now uses
///   [AppColors.textInactive] (`#6A6E72`, 5.14:1). `grey300` was left alone
///   because it is also the checkbox/radio hairline colour, where darkening it
///   would have changed the drawing.
/// * **Semantics.** Each tab is a labelled button that reports whether it is
///   selected, so a screen reader says "Records, tab 3 of 4, selected" instead
///   of reading a bare word.
/// * **Touch target.** Each tab's tap area is at least [_minTapHeight] (48)
///   tall. The glyph and label are unchanged; the tap box simply fills the bar.
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

  /// Platform minimum tap target.
  static const double _minTapHeight = 48;

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
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _NavTab(
                    isActive: _tabs[i] == active,
                    assetKey: _key(_tabs[i]),
                    label: _label(_tabs[i]),
                    position: i + 1,
                    total: _tabs.length,
                    minTapHeight: _minTapHeight,
                    onTap: onChanged == null
                        ? null
                        : () => onChanged!(_tabs[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.isActive,
    required this.assetKey,
    required this.label,
    required this.position,
    required this.total,
    required this.minTapHeight,
    this.onTap,
  });

  final bool isActive;
  final String assetKey;
  final String label;

  /// 1-based position, for the "tab 3 of 4" announcement.
  final int position;
  final int total;

  final double minTapHeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.brand : AppColors.textInactive;
    final asset = 'assets/icons/nav_$assetKey${isActive ? '_active' : ''}.svg';

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      hint: 'Tab $position of $total',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            // Fills the bar's height so the whole column is tappable, not just
            // the 25px glyph.
            constraints: BoxConstraints(minHeight: minTapHeight.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
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
          ),
        ),
      ),
    );
  }
}
