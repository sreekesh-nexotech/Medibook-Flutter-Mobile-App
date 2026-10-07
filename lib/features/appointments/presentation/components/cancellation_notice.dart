import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../application/usecases/hospital_time.dart';
import '../../domain/entities/cancellation_preview.dart';

/// The cancellation policy panel (CM-25), rendered from the backend's
/// `cancellation-preview` (§10.6) — the hospital's cut-off, which side of it
/// the patient is on, and exactly what they get back. Nothing here is a rule
/// the app applies; every value comes off the [CancellationPreview].
///
/// Tone follows the verdict: refundable → neutral tint, past the cut-off →
/// warning, blocked → danger.
class CancellationNotice extends StatelessWidget {
  const CancellationNotice({
    super.key,
    required this.preview,
    this.timezone,
    this.margin,
  });

  final CancellationPreview preview;

  /// The hospital's zone — the cut-off is shown in it.
  final String? timezone;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color accent, Color border) = !preview.allowed
        ? (AppColors.dangerSoft, AppColors.dangerText, AppColors.danger)
        : preview.beforeCutoff
        ? (AppColors.surfaceTint, AppColors.brand, AppColors.primary200)
        : (AppColors.warningSoft, AppColors.grey600, AppColors.warning);

    final cutoff = preview.cutoffAt;
    return Container(
      margin: margin ?? EdgeInsets.only(top: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.md,
        border: Border.all(color: border, width: 1.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(PhIcon.clock, size: 18, color: accent),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Cancellation policy · ${windowLabel(preview)}',
                  style: AppText.poppins(
                    size: 13,
                    weight: AppText.semibold,
                    color: accent,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          if (cutoff != null) ...[
            _line(
              'Cut-off',
              HospitalTime.dateAndTime(cutoff, timezone: timezone),
            ),
            SizedBox(height: 4.h),
          ],
          _line(
            'Refund',
            '${preview.refundPercentLabel} · ${preview.refund.format()}',
          ),
          SizedBox(height: 8.h),
          Text(
            consequence(preview),
            style: AppText.poppins(
              size: 12,
              color: AppColors.textBody,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.poppins(size: 12, color: AppColors.textMuted),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppText.poppins(
              size: 12,
              weight: AppText.medium,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// "Before the cut-off" / "Past the cut-off" / "Not possible".
  static String windowLabel(CancellationPreview preview) {
    if (!preview.allowed) return 'Not possible';
    return preview.beforeCutoff ? 'Before the cut-off' : 'Past the cut-off';
  }

  /// The one sentence the confirm dialog shows — the money consequence, in
  /// plain words, from the backend's numbers.
  static String consequence(CancellationPreview preview) {
    if (!preview.allowed) {
      return switch (preview.reason) {
        'TOKEN_ALREADY_CALLED' =>
          'Your token has already been called, so only the hospital can '
              'cancel this appointment now.',
        'TOKEN_CANCEL_WINDOW_CLOSED' =>
          'The cancellation window for this token has closed.',
        _ => 'This appointment can no longer be cancelled.',
      };
    }
    if (preview.refund.isZero && preview.nonRefundable.isZero) {
      return 'Nothing has been paid on this booking, so there is nothing to '
          'refund. Cancelling releases the slot and the token.';
    }
    if (preview.refund.isZero) {
      return 'You are past the hospital\'s cut-off, so the '
          '${preview.nonRefundable.format()} paid is not refundable.';
    }
    final fee = preview.includesConvenienceFee
        ? ' including the convenience fee'
        : preview.nonRefundable.isZero
        ? ''
        : '; ${preview.nonRefundable.format()} is not refundable';
    return '${preview.refund.format()} (${preview.refundPercentLabel}) goes '
        'back to the original payment method$fee. Refunds usually take '
        '5–7 working days.';
  }
}
