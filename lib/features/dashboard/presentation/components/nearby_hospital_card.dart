import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../booking/domain/entities/hospital.dart';
import '../../../booking/presentation/components/file_image.dart';
import '../../../booking/presentation/components/slot_labels.dart';

/// One "Hospitals Near You" row on Home, as the design draws it: a `72`
/// square logo (`--radius-md`; tinted initials when there is none) beside
/// the name (`16/700` text-strong), the area (`map-pin` + `13` text-body),
/// and a `gap 16` row of the next open slot (`clock`) and rating
/// (`star-fill` in `--warning`). Distance shows only when the query carried
/// coordinates.
class NearbyHospitalCard extends StatelessWidget {
  const NearbyHospitalCard({
    super.key,
    required this.hospital,
    required this.onTap,
  });

  final HospitalCard hospital;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // "4.5 · 25 ratings": the score and how many gave it (rating_count).
    final rating = hospital.hasRating
        ? '${hospital.ratingValue.toStringAsFixed(1)} · ${hospital.ratingCount} '
              '${hospital.ratingCount == 1 ? 'rating' : 'ratings'}'
        : 'Unrated';
    final ratingSpoken = hospital.hasRating
        ? '${hospital.ratingValue.toStringAsFixed(1)} from '
              '${hospital.ratingCount} '
              '${hospital.ratingCount == 1 ? 'rating' : 'ratings'}'
        : 'unrated';
    final distance = hospital.distanceKm;
    final place = distance == null
        ? hospital.locationLabel
        : '${hospital.locationLabel} · ${distance.toStringAsFixed(1)} km';
    final next = SlotLabels.nextAvailable(hospital.nextAvailableAt);
    final nextShort = SlotLabels.nextAvailableShort(hospital.nextAvailableAt);
    return Semantics(
      button: true,
      label: '${hospital.name}, $place, $next, rated $ratingSpoken',
      child: ExcludeSemantics(
        child: AppCard(
          onTap: onTap,
          child: Row(
            children: [
              _Photo(hospital: hospital),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hospital.name,
                      // Two lines: "Lakeshore Multispeciality Hospital" is
                      // the server's name, not something to cut short.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(
                        size: AppFontSize.body,
                        weight: AppText.bold,
                        color: AppColors.textStrong,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    // One fact per line, so none of the server's values is
                    // cut short (HOME audit 6 Oct): area (with the distance
                    // the server worked out when the position is known,
                    // DISC-015), the next free slot day first, the rating.
                    _Meta(icon: PhIcon.mapPin, text: place),
                    SizedBox(height: 6.h),
                    _Meta(icon: PhIcon.clock, text: nextShort),
                    SizedBox(height: 6.h),
                    _Meta(
                      icon: PhIcon.starFill,
                      iconColor: AppColors.warning,
                      text: rating,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.hospital});

  final HospitalCard hospital;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.md,
      child: SizedBox(
        width: 72.w,
        height: 72.w,
        child: AppFileImage(
          fileId: hospital.logoFileId ?? hospital.coverFileId,
          alignment: const Alignment(-0.1, 0),
          fallback: ColoredBox(
            color: AppColors.surfaceTint,
            child: Center(
              child: Text(
                _initials(hospital.name),
                style: AppText.poppins(
                  size: 20,
                  weight: AppText.bold,
                  color: AppColors.brand,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "Green Leaf Family Clinic" → "GL".
  static String _initials(String name) {
    final words = name.split(' ').where((w) => w.isNotEmpty).take(2);
    return words.map((w) => w[0].toUpperCase()).join();
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.iconColor});

  final String icon;
  final String text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 16, color: iconColor ?? AppColors.grey300),
        SizedBox(width: 8.w),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.poppins(
              size: AppFontSize.sm,
              color: AppColors.textBody,
            ),
          ),
        ),
      ],
    );
  }
}
