import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/queue_status.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../booking/domain/booking_identifiers.dart';

/// Home's "Your Token" card (CM-09, CM-14, CM-24).
///
/// ## What the audit changed here
///
/// * **CM-09/CM-24.** The card used to show the patient's own number and
///   nothing else — *"Current token being served, last called number,
///   estimated wait and a refresh indicator have no place on screen."* When
///   the desk publishes a [QueueStatus] the card now leads with **who is being
///   seen**, how far ahead of the patient that is, and the estimated wait,
///   with the patient's own number beside it. [onViewQueue] opens the full
///   `/queue/:doctorId` screen.
/// * **CM-14.** The booking reference is shown under the token when there is
///   one, labelled, because they are different identifiers and support matches
///   on the reference.
/// * **CANONICAL_MASTER_DATA §5.** Both numbers render through
///   [AppTokens.normalize], so a seeded `A-25` shows as `T-025` like every
///   other token in the app.
class TokenCard extends StatelessWidget {
  const TokenCard({
    super.key,
    required this.token,
    this.bookingRef,
    this.queue,
    this.onTap,
    this.onViewQueue,
  });

  /// The patient's token, in any notation — normalised for display.
  final String token;

  /// `MB-2026-000124`, when the appointment carries one.
  final String? bookingRef;

  /// The desk's published progress, or null when it publishes none.
  final QueueStatus? queue;

  /// Opens the appointment.
  final VoidCallback? onTap;

  /// Opens live token progress. Null hides the row.
  final VoidCallback? onViewQueue;

  @override
  Widget build(BuildContext context) {
    final mine = AppTokens.normalize(token);
    final queue = this.queue;
    final ahead = queue?.positionsAhead(token);

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Your Token',
                      style: AppText.poppins(
                        size: AppFontSize.title,
                        weight: AppText.bold,
                        color: AppColors.accentBlue,
                      ),
                    ),
                    if (bookingRef != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        'Ref ${bookingRef!}',
                        style: AppText.poppins(
                          size: AppFontSize.xxs,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.x2.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: AppRadii.pill,
                ),
                child: Text(
                  mine,
                  style: AppText.poppins(
                    size: AppFontSize.body,
                    weight: AppText.bold,
                    color: AppColors.textOnBrand,
                  ),
                ),
              ),
            ],
          ),
          if (queue != null) ...[
            SizedBox(height: AppSpacing.x3.h),
            Container(height: 1.h, color: AppColors.borderSubtle),
            SizedBox(height: AppSpacing.x3.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Stat(
                    label: queue.isPaused ? 'Queue paused' : 'Now seeing',
                    value: AppTokens.normalize(queue.currentToken),
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Ahead of you',
                    value: ahead == null
                        ? '—'
                        : (ahead == 0 ? "You're next" : '$ahead'),
                  ),
                ),
                Expanded(
                  child: _Stat(label: 'Wait', value: queue.waitLabel),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.x3.h),
            Row(
              children: [
                ExcludeSemantics(
                  child: AppIcon(
                    MedIcon.clock,
                    size: 12,
                    color: AppColors.textMutedDecorative,
                  ),
                ),
                SizedBox(width: 5.w),
                Expanded(
                  child: Text(
                    queue.updatedLabel,
                    style: AppText.poppins(
                      size: AppFontSize.xxs,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                if (onViewQueue != null)
                  Semantics(
                    button: true,
                    label: 'Open the live queue',
                    child: ExcludeSemantics(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onViewQueue,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.x2.w,
                            vertical: AppSpacing.x2.h,
                          ),
                          child: Text(
                            'Live queue',
                            style: AppText.poppins(
                              size: AppFontSize.xs,
                              weight: AppText.medium,
                              color: AppColors.textLink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One of the three queue figures. Label above, value below, both wrapping so
/// the row survives text scaling to 1.3x.
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppText.poppins(
            size: AppFontSize.xxs,
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: AppText.poppins(
            size: AppFontSize.sm,
            weight: AppText.semibold,
            color: AppColors.textStrong,
          ),
        ),
      ],
    );
  }
}
