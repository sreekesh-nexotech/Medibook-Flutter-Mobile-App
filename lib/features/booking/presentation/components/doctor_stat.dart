import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';

/// A single cell in the doctor-detail 3-up stat grid (Experience / Patients /
/// Consultation): a bold value over a muted label.
class DoctorStat extends StatelessWidget {
  const DoctorStat({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.poppins(
            size: 16,
            weight: AppText.bold,
            color: AppColors.textStrong,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: AppText.poppins(size: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
