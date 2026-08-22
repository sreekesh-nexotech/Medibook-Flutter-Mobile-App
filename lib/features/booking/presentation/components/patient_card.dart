import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/patient.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_tag.dart';

/// Booking step 3 patient row. Avatar + name + age/gender meta, with a relation
/// [AppTag] on the right that turns active when this patient is selected.
class PatientCard extends StatelessWidget {
  const PatientCard({
    super.key,
    required this.patient,
    required this.selected,
    this.onTap,
  });

  final Patient patient;
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
          AppAvatar(name: patient.name, size: 42),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  patient.name,
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
                  patient.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(size: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          AppTag(label: patient.relation, active: selected),
        ],
      ),
    );
  }
}
