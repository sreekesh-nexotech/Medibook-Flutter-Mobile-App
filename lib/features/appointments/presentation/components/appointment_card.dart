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
import '../../../../core/widgets/app_status_pill.dart';
import '../../../../core/widgets/status_style.dart';

/// A single appointment row on the Appointments list. Pure data + callback →
/// [StatelessWidget]. Top row: 48px avatar, doctor name, `spec · patient first
/// name`, status pill. Hairline. Bottom row: calendar + date, clock + time, and
/// the token pill.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.doctor,
    required this.onTap,
  });

  final Appointment appointment;
  final Doctor doctor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final patientFirst = appointment.patient.split(' ').first;
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              AppStatusPill(
                label: appointment.status.label,
                colors: AppStatusStyle.appointment(appointment.status),
              ),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MetaItem(icon: MedIcon.calendar, label: appointment.date),
                    SizedBox(width: 14.w),
                    _MetaItem(icon: MedIcon.clock, label: appointment.time),
                  ],
                ),
                _TokenPill(label: appointment.token),
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
