import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/booked_appointment.dart';
import 'slot_labels.dart';

/// The payment screen's order summary: a doctor header over the Hospital /
/// Patient / Department / Date / Time / Reference / Token rows, from the
/// **booked** appointment (§9.1).
///
/// The booking reference and the token are both on it, labelled for what
/// they are — the reference is the permanent id, the token is the day's
/// queue position — and both came from the backend at booking time. The
/// date and time render in the hospital's zone.
class ConfirmSummary extends StatelessWidget {
  const ConfirmSummary({
    super.key,
    required this.appointment,
    required this.patientName,
    this.timezone,
  });

  final BookedAppointment appointment;
  final String patientName;
  final String? timezone;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final rows =
        <({String label, String value, Color color, FontWeight weight})>[
          (
            label: 'Hospital',
            value: a.hospitalName,
            color: AppColors.textPrimary,
            weight: AppText.medium,
          ),
          (
            label: 'Patient',
            value: patientName,
            color: AppColors.textPrimary,
            weight: AppText.medium,
          ),
          (
            label: 'Department',
            value: a.departmentName,
            color: AppColors.textPrimary,
            weight: AppText.medium,
          ),
          (
            label: 'Date',
            value: SlotLabels.dayLong(a.scheduledDate, timezone: timezone),
            color: AppColors.textPrimary,
            weight: AppText.medium,
          ),
          (
            label: 'Time',
            value:
                '${SlotLabels.time(a.scheduledStartAt, timezone: timezone)} – '
                '${SlotLabels.time(a.scheduledEndAt, timezone: timezone)}',
            color: AppColors.textPrimary,
            weight: AppText.medium,
          ),
          (
            label: 'Booking Reference',
            value: a.bookingRef,
            color: AppColors.textStrong,
            weight: AppText.bold,
          ),
          (
            label: 'Token',
            value: a.tokenLabel ?? 'Assigned by the hospital',
            color: a.tokenLabel == null
                ? AppColors.textMuted
                : AppColors.accentBlue,
            weight: a.tokenLabel == null ? AppText.regular : AppText.bold,
          ),
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
                AppAvatar(name: a.doctorName, size: 52),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        a.doctorName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(
                          size: 16,
                          weight: AppText.semibold,
                          color: AppColors.textStrong,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        [?a.doctorTitle, ?a.doctorSpecialisation].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(
                          size: 12,
                          color: AppColors.textMuted,
                        ),
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
                  Expanded(
                    flex: 4,
                    child: Text(
                      row.label,
                      style: AppText.poppins(
                        size: AppFontSize.base,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.x3.w),
                  Expanded(
                    flex: 6,
                    child: Text(
                      row.value,
                      textAlign: TextAlign.end,
                      style: AppText.poppins(
                        size: AppFontSize.base,
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
