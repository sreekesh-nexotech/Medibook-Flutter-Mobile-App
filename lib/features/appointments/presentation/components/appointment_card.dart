import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/utils/money.dart';
import '../../application/usecases/hospital_time.dart';
import '../../domain/entities/appointment.dart';
import 'status_pill.dart';

/// A single appointment card on the Appointments list, as the design draws
/// it — the *when* is the hero, everything else is one supporting line:
///
/// 1. `clock` (20, brand) + "Today, 10:30 AM" (18/700, navy) … status pill.
/// 2. 44px avatar · doctor (16/600) over "specialisation · hospital" (12).
/// 3. Hairline, then "Token T-025  ·  For Aarav (Son)" (12, muted).
/// 4. The actions for the state: Cancel + View (upcoming), Book again
///    (closed), or a note + Book again (cancelled / no-show).
///
/// Times are rendered in the hospital's zone ([HospitalTime]); the token is
/// the backend's `token_label` verbatim (§1.11 — opaque text).
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
    this.forLabel,
    this.onCancel,
    this.onBookAgain,
    this.busy = false,
  });

  final Appointment appointment;

  /// Who the visit is for — "Aarav (Son)". Null while the persons list has
  /// not resolved, in which case the line shows the token alone.
  final String? forLabel;

  final VoidCallback onTap;

  /// Null hides the Cancel button (the backend's `actions.can_cancel` is
  /// only known on the detail, so the list offers Cancel through "View").
  final VoidCallback? onCancel;
  final VoidCallback? onBookAgain;

  /// True while an action is in flight, so the buttons cannot double-fire.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final doctor = appointment.doctor;
    final status = appointment.status;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(PhIcon.clock, size: 20, color: AppColors.brand),
              SizedBox(width: 8.w),
              Expanded(
                // Two lines: next to a wide pill ("Payment pending") one line
                // cut the time off as "Tomorrow, …" (BL-APPT-006).
                child: Text(
                  _when,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: AppFontSize.title,
                    weight: AppText.bold,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              AppointmentStatusPill(status: status),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              AppAvatar(name: doctor.name, size: 44),
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
                        size: AppFontSize.body,
                        weight: AppText.semibold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    // Specialisation and department, then the hospital on
                    // its own line, so neither is cut off (Appointments
                    // audit 6 Oct).
                    Text(
                      _speciality,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      appointment.hospital.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            margin: EdgeInsets.only(top: 12.h),
            padding: EdgeInsets.only(top: 12.h),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderSubtle, width: 1.h),
              ),
            ),
            child: Text(
              _metaLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.poppins(
                size: AppFontSize.xs,
                color: AppColors.textMuted,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          _actions(),
        ],
      ),
    );
  }

  /// "Today, 10:30 AM" — a current-year date drops the year so the hero line
  /// never truncates, as the design does.
  String get _when {
    final start = appointment.scheduledStartAt;
    final zone = appointment.hospital.timezone;
    final day = HospitalTime.day(start, timezone: zone);
    final year = ' ${HospitalTime.now(timezone: zone).year}';
    final date = day.endsWith(year)
        ? day.substring(0, day.length - year.length)
        : day;
    return '$date, ${HospitalTime.time(start, timezone: zone)}';
  }

  /// "Interventional · Cardiology"; one of them when they are the same or
  /// the doctor has no specialisation.
  String get _speciality {
    final specialisation = appointment.doctor.specialisation?.trim() ?? '';
    final department = appointment.department.name;
    if (specialisation.isEmpty ||
        specialisation.toLowerCase() == department.toLowerCase()) {
      return department;
    }
    return '$specialisation · $department';
  }

  /// "Token A001 · Ref LKSB-2609-00097 · Follow-up · Room OPD-05 · For
  /// Tara". The reference is always there — it is what search finds and what
  /// the hospital desk asks for. A cancelled or missed visit's token no
  /// longer means anything, so it is left out; the room only matters for a
  /// visit still to come.
  String get _metaLine {
    final status = appointment.status;
    final token = appointment.tokenLabel?.trim() ?? '';
    final live = status.isUpcoming;
    final room = appointment.doctor.room?.trim() ?? '';
    final parts = <String>[
      if (token.isNotEmpty &&
          status != AppointmentStatus.cancelled &&
          status != AppointmentStatus.noShow)
        'Token $token',
      'Ref ${appointment.bookingRef}',
      if (appointment.isFollowUp) 'Follow-up',
      if (live && room.isNotEmpty) 'Room $room',
      if (forLabel != null) 'For $forLabel',
    ];
    return parts.join('  ·  ');
  }

  /// "Pay ₹524 by 2:41 PM to confirm" from the server's total and hold
  /// deadline, in the hospital's zone.
  String get _payLine {
    final amount = Money.inr(appointment.total.paise);
    final deadline = appointment.bookingDeadlineAt;
    if (deadline == null) return 'Pay $amount to confirm this booking';
    final by = HospitalTime.time(
      deadline,
      timezone: appointment.hospital.timezone,
    );
    return 'Pay $amount by $by to confirm';
  }

  Widget _actions() {
    final status = appointment.status;
    if (status == AppointmentStatus.pendingPayment) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _payLine,
            style: AppText.poppins(
              size: AppFontSize.sm,
              weight: AppText.medium,
              color: AppColors.dangerText,
            ),
          ),
          SizedBox(height: 10.h),
          _upcomingButtons(status),
        ],
      );
    }
    if (status.isUpcoming) return _upcomingButtons(status);
    return _pastActions(status);
  }

  Widget _upcomingButtons(AppointmentStatus status) {
    return Row(
      children: [
        if (onCancel != null) ...[
          Expanded(
            child: AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.secondary,
              pill: true,
              fullWidth: true,
              loading: busy,
              semanticLabel: 'Cancel this appointment',
              onPressed: onCancel,
            ),
          ),
          SizedBox(width: 12.w),
        ],
        Expanded(
          child: AppButton(
            label: status == AppointmentStatus.pendingPayment
                ? 'Complete payment'
                : 'View details',
            pill: true,
            fullWidth: true,
            disabled: busy,
            semanticLabel: 'Open this appointment',
            onPressed: onTap,
          ),
        ),
      ],
    );
  }

  Widget _pastActions(AppointmentStatus status) {
    if (status == AppointmentStatus.completed) {
      return Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'View details',
              variant: AppButtonVariant.secondary,
              pill: true,
              fullWidth: true,
              onPressed: onTap,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: AppButton(
              label: 'Book Again',
              pill: true,
              fullWidth: true,
              onPressed: onBookAgain,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            AppointmentStatusStyle.hint(appointment),
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        AppButton(label: 'Book Again', pill: true, onPressed: onBookAgain),
      ],
    );
  }
}
