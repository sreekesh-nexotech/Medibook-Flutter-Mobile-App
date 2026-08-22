import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/doctor.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';

/// Booking step 4 confirmation card: a doctor header over the Patient /
/// Department / Date / Time / Token / Consultation Fee rows. Token renders in
/// accent blue (700) and the fee in navy (700); every other value is primary
/// text (500).
class ConfirmSummary extends StatelessWidget {
  const ConfirmSummary({
    super.key,
    required this.doctor,
    required this.patientName,
    required this.departmentName,
    required this.dateFull,
    required this.time,
    required this.token,
  });

  final Doctor doctor;
  final String patientName;
  final String departmentName;
  final String dateFull;
  final String time;
  final String token;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value, Color color, FontWeight weight})>[
      (label: 'Patient', value: patientName, color: AppColors.textPrimary, weight: AppText.medium),
      (label: 'Department', value: departmentName, color: AppColors.textPrimary, weight: AppText.medium),
      (label: 'Date', value: dateFull, color: AppColors.textPrimary, weight: AppText.medium),
      (label: 'Time', value: time, color: AppColors.textPrimary, weight: AppText.medium),
      (label: 'Token', value: token, color: AppColors.accentBlue, weight: AppText.bold),
      (label: 'Consultation Fee', value: doctor.fee, color: AppColors.textStrong, weight: AppText.bold),
    ];

    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.only(bottom: 14.h),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.borderSubtle, width: 1.w),
              ),
            ),
            child: Row(
              children: [
                AppAvatar(
                  name: doctor.name,
                  imageAsset: doctor.imageAsset,
                  size: 52,
                ),
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
                          size: 16,
                          weight: AppText.semibold,
                          color: AppColors.textStrong,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        doctor.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(size: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final row in rows)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 9.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.label,
                    style: AppText.poppins(size: 14, color: AppColors.textMuted),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.end,
                      style: AppText.poppins(
                        size: 14,
                        weight: row.weight,
                        color: row.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
