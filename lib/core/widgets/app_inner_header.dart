import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';
import 'app_icon.dart';
import 'app_icon_button.dart';

/// The repeated inner-screen header: a 38px back button, a centered title, and
/// an optional trailing slot (kept symmetric with a spacer so the title stays
/// centered). Top padding `12.h`, horizontal `18.w`, bottom `14.h`, `bgApp`.
class AppInnerHeader extends StatelessWidget {
  const AppInnerHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;

  /// Null → no back button (renders a spacer to keep the title centered).
  final VoidCallback? onBack;

  /// Optional right-side widget (e.g. a bell button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgApp,
      padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 14.h),
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
