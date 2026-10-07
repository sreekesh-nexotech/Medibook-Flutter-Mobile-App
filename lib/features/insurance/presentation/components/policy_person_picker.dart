import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../common/persons/application/providers/persons_read_provider.dart';
import '../../../common/persons/domain/entities/person_summary.dart';

/// "Who does this policy cover?" — the optional `person_id` on a policy
/// (§6.4), picked from the account's persons. Optional, so "Not tied to
/// one person" is a real choice and an empty account is not a dead end.
class PolicyPersonPicker extends ConsumerWidget {
  const PolicyPersonPicker({
    super.key,
    required this.selectedId,
    required this.onChanged,
    required this.onRetry,
    this.errorText,
  });

  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRetry;
  final String? errorText;

  static const String _none = '__none__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persons = ref.watch(personSummariesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Covers (optional)',
          style: AppText.poppins(
            size: AppFontSize.base,
            weight: AppText.medium,
            color: AppColors.textStrong,
          ),
        ),
        SizedBox(height: 8.h),
        persons.when(
          loading: () => const AppSkeletonLine(height: 52),
          error: (_, _) => _Box(
            label: 'Could not load your family members — tap to retry',
            muted: true,
            hasError: true,
            onTap: onRetry,
          ),
          data: (list) {
            final selected = list.where((p) => p.id == selectedId).firstOrNull;
            return _Box(
              label: selected == null
                  ? 'Not tied to one person'
                  : selected.fullName,
              muted: selected == null,
              hasError: errorText != null,
              onTap: list.isEmpty ? null : () => _pick(context, list),
            );
          },
        ),
        SizedBox(height: 6.h),
        Text(
          errorText ??
              (persons.valueOrNull?.isEmpty ?? false
                  ? 'Add family members on your profile to pick one here.'
                  : 'Which family member this policy is for, if one.'),
          style: AppText.poppins(
            size: AppFontSize.xs,
            color: errorText == null ? AppColors.textMuted : AppColors.danger,
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context, List<PersonSummary> list) async {
    final picked = await showAppSheet<String>(
      context,
      title: 'Who does this policy cover?',
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(
            label: 'Not tied to one person',
            subtitle: 'A family floater, or not sure',
            isSelected: selectedId == null,
            onTap: () => Navigator.of(sheetContext).pop(_none),
          ),
          for (final person in list)
            _Row(
              label: person.fullName,
              subtitle: person.isSelf ? 'You' : 'Family member',
              isSelected: person.id == selectedId,
              onTap: () => Navigator.of(sheetContext).pop(person.id),
            ),
        ],
      ),
    );
    if (picked == null) return;
    onChanged(picked == _none ? null : picked);
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.label,
    required this.muted,
    required this.hasError,
    required this.onTap,
  });

  final String label;
  final bool muted;
  final bool hasError;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: 'Covers: $label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: 52.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: onTap == null ? AppColors.grey100 : AppColors.surfaceAlt,
            borderRadius: AppRadii.md,
            border: Border.all(
              color: hasError ? AppColors.danger : AppColors.border,
              width: 1.w,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppText.poppins(
                    size: AppFontSize.body,
                    color: muted ? AppColors.textMuted : AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              AppIcon(PhIcon.folder, size: 20, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: 48.h),
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceTint : AppColors.surfaceAlt,
            borderRadius: AppRadii.md,
            border: Border.all(
              color: isSelected ? AppColors.brand : AppColors.border,
              width: 1.w,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppText.poppins(
                  size: AppFontSize.base,
                  weight: isSelected ? AppText.semibold : AppText.medium,
                  color: isSelected ? AppColors.brand : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: AppText.poppins(
                  size: AppFontSize.xs,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
