import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/doctor.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';

/// Booking step 4 confirmation card: a doctor header over the
/// Hospital / Patient / Department / Date / Time / Reference / Token rows.
///
/// ## What the audit changed here
///
/// * **CM-14.** A token was the only identifier on screen. The **booking
///   reference** ([bookingRef]) now has its own row, above the token, because
///   they are different things: the token is today's queue position at one
///   desk (`T-026`, reused tomorrow), the reference is the permanent id
///   (`MB-2026-000125`) and is what support and appointment search match on.
/// * **CM-11.** The hospital has a row, so a patient who picked a facility can
///   confirm they are booking at it.
/// * **§3.8.3.** [scheduledAt] is a real instant. The date and the slot range
///   are rendered from it here, at the edge, instead of being carried around as
///   display strings.
/// * **CM-13.** The consultation-fee row has moved out to
///   [FeeBreakdownCard] — a single fee row was the finding, and a card of one
///   row plus a total is not a breakdown.
class ConfirmSummary extends StatelessWidget {
  const ConfirmSummary({
    super.key,
    required this.doctor,
    required this.patientName,
    required this.departmentName,
    required this.hospitalName,
    required this.scheduledAt,
    required this.slotRangeLabel,
    required this.bookingRef,
    required this.token,
  });

  final Doctor doctor;
  final String patientName;
  final String departmentName;
  final String hospitalName;

  /// The booked instant.
  final DateTime scheduledAt;

  /// "10:30 AM – 10:45 AM".
  final String slotRangeLabel;

  /// `MB-2026-000125` (CM-14).
  final String bookingRef;

  /// `T-026` — the day's queue position.
  final String token;

  @override
  Widget build(BuildContext context) {
    final rows =
        <({String label, String value, Color color, FontWeight weight})>[
          (
            label: 'Hospital',
            value: hospitalName,
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
            value: departmentName,
            color: AppColors.textPrimary,
            weight: AppText.medium,
          ),
          (
            label: 'Date',
            value:
                '${AppDates.relativeDay(scheduledAt)} · '
                '${AppDates.weekdayLong(scheduledAt)}',
            color: AppColors.textPrimary,
            weight: AppText.medium,
          ),
          (
            label: 'Time',
            value: slotRangeLabel,
            color: AppColors.textPrimary,
            weight: AppText.medium,
          ),
          (
            label: 'Booking Reference',
            value: bookingRef,
            color: AppColors.textStrong,
            weight: AppText.bold,
          ),
          (
            label: 'Token',
            value: token,
            color: AppColors.accentBlue,
            weight: AppText.bold,
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
                        doctor.title,
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
