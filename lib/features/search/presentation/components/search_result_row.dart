import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';

/// One tappable row inside a Search results card (a department or a doctor).
/// The caller supplies the [leading] visual (tinted icon holder for a
/// department, avatar for a doctor), the two text lines, and the trailing
/// call-to-action label ("Book" / "View").
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;

  /// Trailing accent-blue call to action ("Book" / "View").
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Row(
          children: [
            leading,
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(
                      size: 14,
                      weight: AppText.semibold,
                      color: AppColors.textStrong,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(
                      size: 12,
                      weight: AppText.regular,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              actionLabel,
              style: AppText.poppins(
                size: 12,
                weight: AppText.semibold,
                color: AppColors.accentBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
