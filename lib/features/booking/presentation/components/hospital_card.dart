import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_rating.dart';
import '../../../../core/widgets/app_tag.dart';
import '../../domain/entities/hospital.dart';
import 'file_image.dart';
import 'slot_labels.dart';

/// One facility in the hospital list (CM-10, CM-11): logo, name,
/// `area, city`, distance when the query carried coordinates, the next open
/// slot, rating, and the departments it runs (which is what the filter above
/// the list matches on).
///
/// Up to [maxDepartmentTags] department tags are shown with a `+n` overflow
/// tag, so a five-department hospital does not push the next card off screen.
class HospitalListCard extends StatelessWidget {
  const HospitalListCard({
    super.key,
    required this.hospital,
    this.onTap,
    this.highlightDepartment,
    this.maxDepartmentTags = 3,
  });

  final HospitalCard hospital;
  final VoidCallback? onTap;

  /// The department **code** the list is filtered by, pulled to the front of
  /// the tags and marked active — so a filtered list shows *why* each row
  /// matched.
  final String? highlightDepartment;

  final int maxDepartmentTags;

  List<({String code, String name})> get _orderedDepartments {
    final all = [
      for (final d in hospital.departments) (code: d.code, name: d.name),
    ];
    final highlight = highlightDepartment;
    if (highlight == null || !hospital.offers(highlight)) return all;
    return [
      ...all.where((d) => d.code == highlight),
      ...all.where((d) => d.code != highlight),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final departments = _orderedDepartments;
    final shown = departments.take(maxDepartmentTags).toList();
    final hidden = departments.length - shown.length;
    final distance = hospital.distanceKm;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(14.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(fileId: hospital.logoFileId ?? hospital.coverFileId),
              SizedBox(width: AppSpacing.x3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hospital.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(
                        size: AppFontSize.base,
                        weight: AppText.semibold,
                        color: AppColors.textStrong,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    _MetaRow(
                      iconName: PhIcon.mapPin,
                      text: distance == null
                          ? hospital.locationLabel
                          : '${hospital.locationLabel} · '
                                '${distance.toStringAsFixed(1)} km away',
                    ),
                    SizedBox(height: 3.h),
                    _MetaRow(
                      iconName: PhIcon.clock,
                      text: hospital.onlineBookingEnabled
                          ? SlotLabels.nextAvailable(hospital.nextAvailableAt)
                          : 'Online booking not available',
                    ),
                    SizedBox(height: 5.h),
                    if (hospital.hasRating)
                      // The core rating Row cannot flex, so it is scaled
                      // down, never clipped.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: AppRating(
                          value: hospital.ratingValue,
                          showValue: true,
                          size: 13,
                        ),
                      )
                    else
                      Text(
                        'Not yet rated',
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
          if (shown.isNotEmpty) ...[
            SizedBox(height: AppSpacing.x3.h),
            Wrap(
              spacing: AppSpacing.x2.w,
              runSpacing: AppSpacing.x1.h,
              children: [
                for (final d in shown)
                  AppTag(label: d.name, active: d.code == highlightDepartment),
                if (hidden > 0) AppTag(label: '+$hidden more'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The facility logo. Falls back to a tinted glyph rather than a broken
/// image box when a facility publishes no picture or the viewer is signed
/// out (§11.4).
class _Thumb extends StatelessWidget {
  const _Thumb({required this.fileId});

  final String? fileId;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 64.w,
      height: 64.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
      ),
      child: AppIcon(PhIcon.firstAid, size: 26, color: AppColors.brand),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md.r),
      child: SizedBox(
        width: 64.w,
        height: 64.w,
        child: AppFileImage(fileId: fileId, fallback: fallback),
      ),
    );
  }
}

/// A glyph + one line of muted meta. The glyph is decorative — the line next
/// to it carries the meaning — so it is excluded from semantics.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.iconName, required this.text});

  final String iconName;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: AppIcon(
              iconName,
              size: 13,
              color: AppColors.textMutedDecorative,
            ),
          ),
        ),
        SizedBox(width: 5.w),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
