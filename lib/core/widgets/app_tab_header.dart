import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';

/// The large, left-aligned title used at the top of the Appointments / Records
/// / Profile tabs, with an optional trailing action (e.g. a bell button).
/// Title `fs 22`/bold/`textStrong`. Padding top `12.h`, horizontal `20.w`,
/// bottom `14.h`.
class AppTabHeader extends StatelessWidget {
  const AppTabHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.poppins(
                size: AppFontSize.h2,
                weight: AppText.bold,
                color: AppColors.textStrong,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
