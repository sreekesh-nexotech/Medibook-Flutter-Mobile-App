import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../domain/entities/appointment_filter.dart';
import '../../domain/entities/appointment_status_view.dart';

/// The active-filter chip row shown above the appointments list (CM-28).
///
/// Every chip removes exactly the facet it shows — the chip carries its
/// [AppointmentFilterField] (and, for a status chip, the single status), so
/// dropping "Dr. Anya Sharma" leaves the date range alone. "Clear all" is
/// always present when anything is active, because the audit's complaint about
/// dead ends applies to filters too: a patient who cannot see how to get all
/// their appointments back thinks the app has lost them.
///
/// Renders nothing at all when no filter is active, so it costs no vertical
/// space in the default state.
class AppointmentFilterChipsRow extends StatelessWidget {
  const AppointmentFilterChipsRow({
    super.key,
    required this.chips,
    required this.onRemove,
    required this.onClearAll,
    this.padding,
  });

  final List<AppointmentFilterChip> chips;

  /// Remove one facet. For a status chip, `status` is the one status to drop.
  final void Function(
    AppointmentFilterField field, {
    AppointmentStatusView? status,
  })
  onRemove;

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
              onRemove: () => onRemove(chip.field, status: chip.status),
            ),
          _ClearAllChip(onTap: onClearAll),
        ],
      ),
    );
  }
}

/// One active facet: its label plus a 48px-reachable remove target.
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
                        size: 12,
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

/// The always-present way out of a filtered list.
class _ClearAllChip extends StatelessWidget {
  const _ClearAllChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Clear all appointment filters',
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
                  size: 12,
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
