import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';

/// "Personal Information" card: a titled header with an Edit link, then a
/// key/value row per field (Phone / Date of Birth / Gender / Blood Group), each
/// closed with a subtle bottom hairline.
///
/// Pure presentation — the screen passes the [rows] (from `profileInfoProvider`)
/// and the [onEdit] callback that fires the stub toast.
class ProfileInfoCard extends StatelessWidget {
  const ProfileInfoCard({
    super.key,
    required this.rows,
    required this.onEdit,
  });

  final List<({String key, String value})> rows;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Personal Information',
                  style: AppText.poppins(
                    size: 16,
                    weight: AppText.bold,
                    color: AppColors.textStrong,
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEdit,
                  child: Text(
                    'Edit',
                    style: AppText.poppins(
                      size: 14,
                      weight: AppText.medium,
                      color: AppColors.accentBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final row in rows) _InfoRow(label: row.key, value: row.value),
        ],
      ),
    );
  }
}

/// A single key/value line with a bottom hairline.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1.w),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              style: AppText.poppins(size: 14, color: AppColors.textMuted),
            ),
          ),
          SizedBox(width: 12.w),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.poppins(
                size: 14,
                weight: AppText.medium,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
