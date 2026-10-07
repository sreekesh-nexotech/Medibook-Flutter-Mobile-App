import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../domain/entities/doctor.dart';
import 'file_image.dart';
import 'slot_labels.dart';

/// Booking step 2 doctor card, as the design draws it: a `76` square photo
/// (`--radius-md`) beside the name (`18/700`), speciality (`14/500`, body),
/// hospital and experience (`12`, muted); then a `map-pin` hospital line
/// (`13`, body) and a `clock` "Next free …" line (`13/500`, success); then
/// "View Details" (secondary pill) over "Book Appointment" (primary pill).
///
/// A `1.5px` brand ring marks the chosen doctor; unselected keeps a
/// transparent ring so nothing shifts. A doctor who is not bookable online
/// says so in place of the book button rather than offering a dead control.
class BookingDoctorCard extends StatelessWidget {
  const BookingDoctorCard({
    super.key,
    required this.doctor,
    required this.selected,
    required this.onView,
    required this.onBook,
    this.timezone,
    this.hospitalPhone,
  });

  final DoctorCard doctor;
  final bool selected;
  final VoidCallback onView;
  final VoidCallback onBook;
  final String? timezone;

  /// The hospital's number from its detail, for a doctor not booked online.
  final String? hospitalPhone;

  @override
  Widget build(BuildContext context) {
    final experience = doctor.experienceLabel;
    return Container(
      padding: EdgeInsets.all(1.5.r),
      decoration: BoxDecoration(
        color: selected ? AppColors.brand : Colors.transparent,
        borderRadius: AppRadii.lg,
      ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: AppRadii.md,
                  child: SizedBox(
                    width: 76.w,
                    height: 76.w,
                    child: AppFileImage(
                      fileId: doctor.photoFileId,
                      fallback: _Initials(name: doctor.name),
                      alignment: const Alignment(0, -0.6),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
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
                          size: AppFontSize.title,
                          weight: AppText.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        doctor.specialityLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(
                          size: AppFontSize.base,
                          weight: AppText.medium,
                          color: AppColors.textBody,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        doctor.qualification ?? doctor.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(
                          size: AppFontSize.xs,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (experience != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          '$experience experience',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(
                            size: AppFontSize.xs,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _Line(
              icon: PhIcon.mapPin,
              iconColor: AppColors.grey300,
              text: doctor.hospital.label,
              style: AppText.poppins(
                size: AppFontSize.sm,
                color: AppColors.textBody,
              ),
            ),
            SizedBox(height: 8.h),
            _Line(
              icon: PhIcon.clock,
              iconColor: doctor.nextAvailableAt == null
                  ? AppColors.textMuted
                  : AppColors.successText,
              text: SlotLabels.nextAvailable(
                doctor.nextAvailableAt,
                timezone: timezone,
              ),
              style: AppText.poppins(
                size: AppFontSize.sm,
                weight: AppText.medium,
                color: doctor.nextAvailableAt == null
                    ? AppColors.textMuted
                    : AppColors.successText,
              ),
            ),
            SizedBox(height: 16.h),
            AppButton(
              label: 'View Details',
              variant: AppButtonVariant.secondary,
              pill: true,
              fullWidth: true,
              semanticLabel: 'View details for ${doctor.name}',
              onPressed: onView,
            ),
            SizedBox(height: 12.h),
            if (doctor.canBook)
              AppButton(
                label: 'Book Appointment',
                pill: true,
                fullWidth: true,
                semanticLabel: 'Book an appointment with ${doctor.name}',
                onPressed: onBook,
              )
            else
              Text(
                doctor.status == DoctorStatus.onLeave
                    ? 'On leave — not taking bookings right now.'
                    // "Call the hospital" with the number to call.
                    : 'Not bookable online. Call the hospital'
                          '${hospitalPhone == null ? '' : ' on $hospitalPhone'}'
                          ' to book.',
                textAlign: TextAlign.center,
                style: AppText.poppins(
                  size: AppFontSize.xs,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tinted initials — the honest fallback when a photo cannot be shown.
class _Initials extends StatelessWidget {
  const _Initials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final words = name
        .replaceAll(RegExp(r'^Dr\.?\s+'), '')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2);
    return ColoredBox(
      color: AppColors.surfaceTint,
      child: Center(
        child: Text(
          words.map((w) => w[0].toUpperCase()).join(),
          style: AppText.poppins(
            size: AppFontSize.h3,
            weight: AppText.bold,
            color: AppColors.brand,
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.style,
  });

  final String icon;
  final Color iconColor;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIcon(icon, size: 16, color: iconColor),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
