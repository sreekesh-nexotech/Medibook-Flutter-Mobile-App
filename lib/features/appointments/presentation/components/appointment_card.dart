import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/appointment.dart';
import '../../../../core/mock_data/models/doctor.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/status_style.dart';
import '../../domain/entities/appointment_status_view.dart';
import '../../domain/entities/appointment_token.dart';
import 'status_view_pill.dart';

/// A single appointment row on the Appointments list and in search results.
///
/// Top row: 48px avatar, doctor name, `spec · patient first name`, the
/// canonical status pill. Hairline. Bottom row: calendar + date, clock + time,
/// and the token pill.
///
/// [status] is passed in rather than read off `appointment.status`: the stored
/// field only knows three states, and the list must show all five
/// (`CANONICAL_MASTER_DATA` §4). The caller resolves it once — see
/// `AppointmentRow`.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.doctor,
    required this.status,
    required this.onTap,
    this.hospitalName,
  });

  final Appointment appointment;
  final Doctor doctor;

  /// The canonical status (Scheduled / In Queue / Completed / Cancelled /
  /// No-show).
  final AppointmentStatusView status;

  /// Shown under the doctor when given — search results span hospitals, so the
  /// facility is part of telling two rows apart.
  final String? hospitalName;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final patientFirst = appointment.patient.split(' ').first;
    final facility = hospitalName;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                name: doctor.name,
                imageAsset: doctor.imageAsset,
                size: 48,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    SizedBox(height: 1.h),
                    Text(
                      '${doctor.spec} · $patientFirst',
                      // Lets this wrap (2 lines for the longest spec) rather
                      // than ellipsize, so it survives 1.3x text scaling.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (facility != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        facility,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(
                          size: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              AppointmentStatusViewPill(status: status),
            ],
          ),
          Container(
            margin: EdgeInsets.only(top: 12.h),
            padding: EdgeInsets.only(top: 12.h),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderSubtle, width: 1.w),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Wrap(
                    spacing: 14.w,
                    runSpacing: 4.h,
                    children: [
                      _MetaItem(
                        icon: MedIcon.calendar,
                        label: appointment.date,
                      ),
                      _MetaItem(icon: MedIcon.clock, label: appointment.time),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                _TokenPill(
                  label: AppointmentToken.normalize(appointment.token),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon + short meta label (calendar+date, clock+time) on the card footer.
class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 15, color: AppColors.textBody),
        SizedBox(width: 5.w),
        Text(
          label,
          style: AppText.poppins(size: 12, color: AppColors.textBody),
        ),
      ],
    );
  }
}

/// The token pill on the card footer: navy-on-tint, fs12 / bold (heavier than
/// the status pill), using [AppStatusStyle.token].
class _TokenPill extends StatelessWidget {
  const _TokenPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const colors = AppStatusStyle.token;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadii.pill,
      ),
      child: Text(
        label,
        style: AppText.poppins(
          size: 12,
          weight: AppText.bold,
          color: colors.foreground,
        ),
      ),
    );
  }
}
