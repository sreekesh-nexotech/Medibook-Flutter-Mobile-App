import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/medical_record.dart';
import '../../../../core/widgets/app_icon.dart';
import '../controllers/documents_filter_controller.dart';

/// The active-filter chip row above the documents list (CM-34).
///
/// Each chip removes exactly the facet it names — it carries its
/// [DocumentFilterField] and, for a type chip, the one [DocumentType] to drop —
/// so clearing "Lab Report" leaves the patient and date range in place.
/// "Clear all" is always present while anything is active: a library that
/// silently hides most of a patient's documents with no visible way back reads
/// as data loss.
///
/// Renders nothing when no filter is active, so the default state pays no
/// vertical cost.
class DocumentFilterChipsRow extends StatelessWidget {
  const DocumentFilterChipsRow({
    super.key,
    required this.chips,
    required this.onRemove,
    required this.onClearAll,
    this.padding,
  });

  final List<DocumentFilterChip> chips;

  /// Drop one facet. `type` is non-null only for a type chip.
  final void Function(DocumentFilterField field, {DocumentType? type}) onRemove;

  final VoidCallback onClearAll;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding:
          padding ??
          EdgeInsets.fromLTRB(AppSpacing.x5.w, 0, AppSpacing.x5.w, 8.h),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final chip in chips)
            _RemovableChip(
              label: '${chip.field.label}: ${chip.label}',
              semanticLabel: 'Remove filter ${chip.field.label} ${chip.label}',
              onRemove: () => onRemove(chip.field, type: chip.type),
            ),
          _ClearAllChip(onTap: onClearAll),
        ],
      ),
    );
  }
}

/// One active facet: its label plus a remove target that stays reachable.
class _RemovableChip extends StatelessWidget {
  const _RemovableChip({
    required this.label,
    required this.semanticLabel,
    required this.onRemove,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Material(
          color: AppColors.surfaceTint,
          borderRadius: AppRadii.pill,
          child: InkWell(
            onTap: onRemove,
            borderRadius: AppRadii.pill,
            child: Container(
              // Minimum, not fixed: the chip grows with the OS text scale
              // instead of clipping its label at 1.3x.
              constraints: BoxConstraints(minHeight: 34.h),
              padding: EdgeInsets.fromLTRB(12.w, 6.h, 8.w, 6.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 210.w),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        weight: AppText.medium,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  AppIcon(MedIcon.close, size: 12, color: AppColors.brand),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The always-present way back to the whole library.
class _ClearAllChip extends StatelessWidget {
  const _ClearAllChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Clear all document filters',
      child: ExcludeSemantics(
        child: Material(
          color: AppColors.surface,
          borderRadius: AppRadii.pill,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.pill,
            child: Container(
              constraints: BoxConstraints(minHeight: 34.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                borderRadius: AppRadii.pill,
                border: Border.all(color: AppColors.border, width: 1.w),
              ),
              child: Text(
                'Clear all',
                style: AppText.poppins(
                  size: AppFontSize.xs,
                  weight: AppText.medium,
                  color: AppColors.textBody,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
