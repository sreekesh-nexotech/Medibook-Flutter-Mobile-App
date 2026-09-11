import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/doctor.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_rating.dart';

/// Booking step 2 doctor row. Avatar + name + `spec · experience` + rating on
/// the left, fee + "per visit" on the right. Tapping opens the doctor detail
/// screen (the actual doctor pick happens from there).
class DoctorCard extends StatelessWidget {
  const DoctorCard({
    super.key,
    required this.doctor,
    this.selected = false,
    this.onTap,
  });

  final Doctor doctor;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(14.w),
      border: Border.all(
        color: selected ? AppColors.brand : Colors.transparent,
        width: 1.5.w,
      ),
      child: Row(
        children: [
          AppAvatar(name: doctor.name, imageAsset: doctor.imageAsset, size: 56),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  doctor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: 15,
                    weight: AppText.semibold,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${doctor.spec} · ${doctor.experience}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(size: 12, color: AppColors.textMuted),
                ),
                SizedBox(height: 4.h),
                // AppRating lays its stars out in a Row that cannot flex
                // (core widget), so at a large OS text scale the value label
                // would push past the card. Scale-down keeps it inside.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: AppRating(
                    value: doctor.rating,
                    showValue: true,
                    size: 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                doctor.fee,
                style: AppText.poppins(
                  size: 13,
                  weight: AppText.bold,
                  color: AppColors.textStrong,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'per visit',
                style: AppText.poppins(size: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
