import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';
import 'app_icon.dart';
import 'app_icon_button.dart';

/// The repeated inner-screen header: a 38px back button, a centered title, and
/// an optional trailing slot (kept symmetric with a spacer so the title stays
/// centered). Top padding `12.h` (design 56 − 44 status bar), horizontal `18.w`,
/// `bgApp`. Bottom padding defaults to `14` but the prototype varies it per
/// screen (8 on the auth sub-screens, 10 on Search), so it is a parameter.
class AppInnerHeader extends StatelessWidget {
  const AppInnerHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.bottomGap = 14,
    this.background,
  });

  final String title;

  /// Null → no back button (renders a spacer to keep the title centered).
  final VoidCallback? onBack;

  /// Optional right-side widget (e.g. a bell button).
  final Widget? trailing;

  /// Bottom padding under the title (design px). Prototype: 8 on Sign Up /
  /// Forgot / Verify / New Password, 10 on Search, 14 elsewhere.
  final double bottomGap;

  /// Header band color. Defaults to `bgApp`; the all-white auth sub-screens
  /// pass `AppColors.surface` (their whole page is surface in the design).
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background ?? AppColors.bgApp,
      padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, bottomGap.h),
      child: Row(
        children: [
          SizedBox(
            width: 38.w,
            height: 38.w,
            child: onBack == null
                ? null
                : AppIconButton(
                    icon: MedIcon.back,
                    size: 38,
                    onPressed: onBack,
                  ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.poppins(
                size: AppFontSize.h3,
                weight: AppText.bold,
                color: AppColors.textStrong,
              ),
            ),
          ),
          SizedBox(
            width: 38.w,
            height: 38.w,
            child: trailing == null
                ? null
                : Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
  }
}
