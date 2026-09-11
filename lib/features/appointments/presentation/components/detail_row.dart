import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_icon.dart';

/// A label/value row inside the Appointment Details card. The key is muted; the
/// value defaults to text-primary / medium, with an emphasised
/// (accent-blue / bold) variant used for the Token row.
///
/// [trailing] replaces the plain value text (a status pill, a small tag), and
/// [caption] adds one muted line under it — "Requested 12 Aug 2026" under a
/// refund status, for instance.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    this.value,
    this.valueColor,
    this.valueWeight,
    this.trailing,
    this.caption,
    this.showDivider = true,
  }) : assert(
         value != null || trailing != null,
         'a DetailRow needs a value or a trailing widget',
       );

  final String label;

  /// The plain-text value. Null when [trailing] carries the value instead.
  final String? value;

  final Color? valueColor;
  final FontWeight? valueWeight;

  /// A widget shown in place of [value] (a pill, a tag).
  final Widget? trailing;

  /// One muted line under the value.
  final String? caption;

  /// The hairline under the row — off for the last row in a card.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final text = value;
    final note = caption;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 9.h),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(color: AppColors.borderSubtle, width: 1.w),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.poppins(size: 14, color: AppColors.textMuted),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (trailing != null)
                  trailing!
                else
                  Text(
                    text!,
                    textAlign: TextAlign.right,
                    style: AppText.poppins(
                      size: 14,
                      weight: valueWeight ?? AppText.medium,
                      color: valueColor ?? AppColors.textPrimary,
                    ),
                  ),
                if (note != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    note,
                    textAlign: TextAlign.right,
                    style: AppText.poppins(
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable row that goes somewhere: the receipt, an attached document, the
/// ambulance screen.
///
/// Reads as one of the app's inset rows (`surfaceAlt` fill, `border` hairline)
/// so it is visibly a destination rather than a read-only value, and it carries
/// a [semanticLabel] because the chevron alone says nothing.
class DetailActionRow extends StatelessWidget {
  const DetailActionRow({
    super.key,
    required this.iconName,
    required this.title,
    required this.semanticLabel,
    this.subtitle,
    this.onTap,
    this.trailingLabel,
    this.tone = DetailActionTone.neutral,
    this.margin,
  });

  final String iconName;
  final String title;

  /// One muted line under [title].
  final String? subtitle;

  /// What a screen reader announces for the whole row — always say where it
  /// goes, never just "row".
  final String semanticLabel;

  /// Null disables the row; pass [subtitle] saying why (THE LAW: a control is
  /// either working, disabled with a reason, or declared stubbed).
  final VoidCallback? onTap;

  /// Short right-aligned label before the chevron ("₹1,062", "PDF · 240 KB").
  final String? trailingLabel;

  final DetailActionTone tone;

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final accent = switch (tone) {
      DetailActionTone.neutral => AppColors.brand,
      DetailActionTone.emergency => AppColors.danger,
    };
    final iconColor = enabled ? accent : AppColors.textInactive;
    final titleColor = enabled ? AppColors.textStrong : AppColors.textInactive;
    final note = subtitle;
    final trailing = trailingLabel;

    return Semantics(
      button: enabled,
      enabled: enabled,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Padding(
          padding: margin ?? EdgeInsets.only(top: 10.h),
          child: Material(
            color: AppColors.surfaceAlt,
            borderRadius: AppRadii.md,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadii.md,
              child: Container(
                constraints: BoxConstraints(minHeight: 48.h),
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.x3.w,
                  vertical: 10.h,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.md,
                  border: Border.all(color: AppColors.border, width: 1.w),
                ),
                child: Row(
                  children: [
                    AppIcon(iconName, size: 18, color: iconColor),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: AppText.poppins(
                              size: 13,
                              weight: AppText.semibold,
                              color: titleColor,
                            ),
                          ),
                          if (note != null) ...[
                            SizedBox(height: 2.h),
                            Text(
                              note,
                              style: AppText.poppins(
                                size: 11,
                                color: AppColors.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      SizedBox(width: 8.w),
                      Text(
                        trailing,
                        style: AppText.poppins(
                          size: 12,
                          weight: AppText.medium,
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Accent for a [DetailActionRow] — emergency rows (Call Ambulance) read in the
/// danger tone so they are not one more grey row.
enum DetailActionTone { neutral, emergency }
