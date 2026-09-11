import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/hospital.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_rating.dart';
import '../../../../core/widgets/app_tag.dart';

/// One facility in the hospital list (CM-10, CM-11).
///
/// The audit's finding was that "the hospital is only a label printed on a
/// doctor card — it cannot be chosen, searched or filtered". This is the row
/// that makes it choosable: photo, name, `area, city`, distance, rating,
/// opening hours, and the departments it actually runs (which is what the
/// filter above the list matches on).
///
/// Up to [maxDepartmentTags] department tags are shown with a `+n` overflow
/// tag, so a five-department hospital does not push the next card off screen.
class HospitalCard extends StatelessWidget {
  const HospitalCard({
    super.key,
    required this.hospital,
    this.onTap,
    this.highlightDepartment,
    this.maxDepartmentTags = 3,
  });

  final Hospital hospital;
  final VoidCallback? onTap;

  /// The department the list is filtered by, pulled to the front of the tags
  /// and marked active — so a filtered list shows *why* each row matched.
  final String? highlightDepartment;

  final int maxDepartmentTags;

  List<String> get _orderedDepartments {
    final highlight = highlightDepartment;
    if (highlight == null || !hospital.offers(highlight)) {
      return hospital.departments;
    }
    return [
      highlight,
      for (final d in hospital.departments)
        if (d != highlight) d,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final departments = _orderedDepartments;
    final shown = departments.take(maxDepartmentTags).toList();
    final hidden = departments.length - shown.length;

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
              _Thumb(imageAsset: hospital.imageAsset),
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
                      iconName: MedIcon.location,
                      text:
                          '${hospital.locationLabel} · '
                          '${hospital.distanceLabel}',
                    ),
                    SizedBox(height: 3.h),
                    _MetaRow(
                      iconName: MedIcon.clock,
                      text: hospital.openingHours,
                    ),
                    SizedBox(height: 5.h),
                    // See the note in doctor_card.dart: the core rating Row
                    // cannot flex, so it is scaled down, never clipped.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: AppRating(
                        value: hospital.rating,
                        showValue: true,
                        size: 13,
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
                  AppTag(label: d, active: d == highlightDepartment),
                if (hidden > 0) AppTag(label: '+$hidden more'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The facility photo. Falls back to a tinted glyph rather than a broken
/// image box when a facility publishes no picture.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageAsset});

  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final asset = imageAsset;
    if (asset == null) {
      return Container(
        width: 64.w,
        height: 64.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceTint,
          borderRadius: BorderRadius.circular(AppRadius.md.r),
        ),
        child: AppIcon(MedIcon.hospital, size: 26, color: AppColors.brand),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md.r),
      child: Image.asset(
        asset,
        width: 64.w,
        height: 64.w,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          width: 64.w,
          height: 64.w,
          alignment: Alignment.center,
          color: AppColors.surfaceTint,
          child: AppIcon(MedIcon.hospital, size: 26, color: AppColors.brand),
        ),
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
