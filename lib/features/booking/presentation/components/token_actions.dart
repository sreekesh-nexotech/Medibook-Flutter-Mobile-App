import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_stub_notice.dart';

/// The token card a patient shows at the desk, and the two controls around
/// it (CM-15, CM-27).
///
/// Every value is a string the backend issued (§10.4) — the booking
/// reference, the token label, the hospital-local date and time. The QR
/// payload is shown as text: no QR or image-saving package is in this build,
/// so "Save token card" stays honestly stubbed rather than flashing a success
/// for a file that was never written. "Add to calendar" is the caller's
/// [onAddToCalendar] (the backend's `calendar.ics`, §10.10); without one the
/// control is not shown.
class TokenActionsCard extends ConsumerWidget {
  const TokenActionsCard({
    super.key,
    required this.token,
    required this.bookingRef,
    required this.dateLabel,
    required this.whenLabel,
    required this.doctorName,
    required this.hospitalName,
    this.patientName,
    this.qrPayload,
    this.onAddToCalendar,
    this.calendarBusy = false,
    this.onViewQueue,
  });

  /// `T-026` — the day's queue position, as issued.
  final String token;

  /// `MB-2026-000125` — the permanent identifier.
  final String bookingRef;

  /// The date chip ("2026-10-01" as the backend states it).
  final String dateLabel;

  /// "2026-10-01 · 09:00 – 09:15 · Morning".
  final String whenLabel;
  final String doctorName;
  final String hospitalName;
  final String? patientName;

  /// The string a QR would encode (§10.4 `qr_payload`).
  final String? qrPayload;

  /// Downloads the appointment's `.ics` and hands it to the calendar app
  /// (§10.10). Null hides the control.
  final VoidCallback? onAddToCalendar;

  /// True while the `.ics` is being fetched.
  final bool calendarBusy;

  /// Opens live token progress (CM-09/CM-24). Null hides the control.
  final VoidCallback? onViewQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Your token',
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      token,
                      style: AppText.poppins(
                        size: AppFontSize.h2,
                        weight: AppText.bold,
                        color: AppColors.accentBlue,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: AppSpacing.x2.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceTint,
                  borderRadius: AppRadii.pill,
                ),
                child: Text(
                  dateLabel,
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    weight: AppText.semibold,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.x3.h),
          Container(height: 1.h, color: AppColors.borderSubtle),
          SizedBox(height: AppSpacing.x3.h),
          _Row(label: 'Booking reference', value: bookingRef, strong: true),
          if (patientName != null && patientName!.isNotEmpty)
            _Row(label: 'Patient', value: patientName!),
          _Row(label: 'Doctor', value: doctorName),
          _Row(label: 'Where', value: hospitalName),
          _Row(label: 'When', value: whenLabel),
          if (qrPayload != null && qrPayload!.isNotEmpty)
            _Row(label: 'Desk code', value: qrPayload!),
          SizedBox(height: AppSpacing.x2.h),
          Text(
            'Quote the booking reference to support — the token is only '
            "today's queue position at the desk.",
            style: AppText.poppins(
              size: AppFontSize.xxs,
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
          SizedBox(height: AppSpacing.x4.h),
          Wrap(
            spacing: AppSpacing.x2.w,
            runSpacing: AppSpacing.x2.h,
            children: [
              AppButton(
                label: 'Save token card',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                leadingIcon: MedIcon.download,
                stubbed: true,
                semanticLabel: 'Save the token card for $bookingRef',
                onPressed: () =>
                    showStubbedToast(context, ref, 'Saving the token card'),
              ),
              if (onAddToCalendar != null)
                AppButton(
                  label: 'Add to calendar',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  leadingIcon: MedIcon.calendar,
                  loading: calendarBusy,
                  semanticLabel: 'Add this appointment to your calendar',
                  onPressed: onAddToCalendar,
                ),
              if (onViewQueue != null)
                AppButton(
                  label: 'Live queue',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  leadingIcon: MedIcon.clock,
                  semanticLabel: 'See the live queue for $doctorName',
                  onPressed: onViewQueue,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: AppText.poppins(
                size: AppFontSize.xs,
                color: AppColors.textMuted,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.x3.w),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppText.poppins(
                size: AppFontSize.sm,
                weight: strong ? AppText.bold : AppText.medium,
                color: strong ? AppColors.textStrong : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
