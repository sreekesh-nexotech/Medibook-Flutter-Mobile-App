import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/mock_data/models/patient.dart';
import '../../../../core/mock_data/stores/dependants_store.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/app_tag.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../controllers/list_lifecycle_controller.dart';

/// Family members (`/dependants`) — CM-16, CM-48.
///
/// The audit found "three fixed people can be picked. There is no add, edit or
/// remove control, and no blood group or allergy field." This list is where
/// those controls live, over `dependantsStoreProvider` — **the same store the
/// booking flow's patient picker reads**, so a dependant added here is
/// bookable immediately and there is only ever one copy of the data.
///
/// The account holder's own record is shown first and has no Remove control:
/// `DependantsStore.remove` refuses for `isSelf`, so offering the button would
/// be offering an action that cannot succeed.
class DependantsScreen extends ConsumerWidget {
  const DependantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final self = ref.watch(selfPatientProvider);
    final dependants = ref.watch(dependantsOnlyProvider);
    final lifecycle = ref.watch(
      listLifecycleProvider(ProfileListKeys.dependants),
    );
    final notifier = listLifecycleProvider(ProfileListKeys.dependants).notifier;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInnerHeader(
              title: 'Family Members',
              onBack: () => _leave(context),
              backSemanticLabel: 'Back to profile',
            ),
            Expanded(
              child: lifecycle.isLoading
                  ? SingleChildScrollView(
                      child: AppSkeletonList(
                        count: 3,
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.x5.w,
                          AppSpacing.x4.h,
                          AppSpacing.x5.w,
                          AppSpacing.x6.h,
                        ),
                      ),
                    )
                  : lifecycle.failure != null && dependants.isEmpty
                  ? AppErrorView(
                      failure: lifecycle.failure!,
                      headline: 'We could not load your family members',
                      onRetry: () => ref.read(notifier).retry(),
                    )
                  : AppRefreshIndicator(
                      onRefresh: () => ref.read(notifier).refresh(),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.x5.w,
                          AppSpacing.x4.h,
                          AppSpacing.x5.w,
                          AppSpacing.x8.h,
                        ),
                        children: [
                          if (lifecycle.failure != null) ...[
                            AppErrorBanner(
                              message: lifecycle.failure!.userMessage,
                              onTap: () => ref.read(notifier).refresh(),
                            ),
                            SizedBox(height: AppSpacing.x4.h),
                          ],
                          Text(
                            'Anyone here can be chosen as the patient when you '
                            'book an appointment.',
                            style: AppText.poppins(
                              size: AppFontSize.xs,
                              height: 1.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          _PatientCard(
                            patient: self,
                            // The account holder's identity is edited in
                            // Profile, which is also where the email and
                            // mobile number live.
                            onEdit: () => context.push(AppRoutes.profileEdit),
                            editLabel: 'Edit in Profile',
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          Semantics(
                            header: true,
                            child: Text(
                              dependants.length == 1
                                  ? 'One dependant'
                                  : '${dependants.length} dependants',
                              style: AppText.poppins(
                                size: AppFontSize.body,
                                weight: AppText.bold,
                                color: AppColors.textStrong,
                              ),
                            ),
                          ),
                          SizedBox(height: AppSpacing.x3.h),
                          if (dependants.isEmpty)
                            AppInlineEmpty(
                              message:
                                  'No dependants yet. Add a family member to '
                                  'book for them and keep their records here.',
                              iconName: MedIcon.records,
                              actionLabel: 'Add Family Member',
                              onAction: () =>
                                  context.push(AppRoutes.dependantEditPath()),
                            )
                          else
                            for (final patient in dependants)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: AppSpacing.x3.h,
                                ),
                                child: _PatientCard(
                                  patient: patient,
                                  onEdit: () => context.push(
                                    AppRoutes.dependantEditPath(patient.id),
                                  ),
                                ),
                              ),
                          SizedBox(height: AppSpacing.x2.h),
                          AppButton(
                            label: 'Add Family Member',
                            variant: AppButtonVariant.secondary,
                            fullWidth: true,
                            leadingIcon: MedIcon.records,
                            onPressed: () =>
                                context.push(AppRoutes.dependantEditPath()),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.profile);
  }
}

/// One patient: who they are, the details a clinician needs, and Edit.
///
/// Removal lives on the edit screen rather than here: deleting a person's
/// record is destructive, and putting it behind opening the record makes it
/// much harder to hit by accident in a list.
class _PatientCard extends StatelessWidget {
  const _PatientCard({
    required this.patient,
    required this.onEdit,
    this.editLabel = 'Edit',
  });

  final Patient patient;
  final VoidCallback onEdit;
  final String editLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(name: patient.name, size: 44),
              SizedBox(width: AppSpacing.x3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      patient.name,
                      style: AppText.poppins(
                        size: AppFontSize.body,
                        weight: AppText.bold,
                        color: AppColors.textStrong,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      // Derived from the stored date of birth, so a birthday
                      // moves it without anyone editing a string.
                      '${patient.relation} · ${patient.meta}',
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.x2.w),
              if (patient.isSelf)
                const AppBadge(label: 'You', tone: AppBadgeTone.brand)
              else if (patient.isMinor)
                const AppBadge(label: 'Minor', tone: AppBadgeTone.neutral),
            ],
          ),
          SizedBox(height: AppSpacing.x3.h),
          _DetailRow(label: 'Date of birth', value: patient.dateOfBirthLabel),
          _DetailRow(
            label: 'Blood group',
            value: patient.bloodGroup ?? 'Not recorded',
            isMissing: patient.bloodGroup == null,
          ),
          if (patient.phone != null)
            _DetailRow(label: 'Mobile', value: patient.phone!),
          SizedBox(height: AppSpacing.x2.h),
          Text(
            'Allergies',
            style: AppText.poppins(
              size: AppFontSize.xs,
              weight: AppText.medium,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 6.h),
          if (patient.hasAllergies)
            Wrap(
              spacing: AppSpacing.x2.w,
              runSpacing: AppSpacing.x2.h,
              children: [
                for (final allergy in patient.allergies) AppTag(label: allergy),
              ],
            )
          else
            Text(
              'None recorded',
              style: AppText.poppins(
                size: AppFontSize.sm,
                color: AppColors.textMuted,
              ),
            ),
          SizedBox(height: AppSpacing.x3.h),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: editLabel,
              variant: AppButtonVariant.soft,
              size: AppButtonSize.sm,
              leadingIcon: MedIcon.edit,
              semanticLabel: '$editLabel ${patient.name}',
              onPressed: onEdit,
            ),
          ),
        ],
      ),
    );
  }
}

/// A label/value line inside a patient card.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isMissing = false,
  });

  final String label;
  final String value;

  /// Renders the value in the muted tone — "Not recorded" is not a value.
  final bool isMissing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.poppins(
                size: AppFontSize.xs,
                color: AppColors.textMuted,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.x3.w),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.poppins(
                size: AppFontSize.sm,
                weight: isMissing ? AppText.regular : AppText.medium,
                color: isMissing ? AppColors.textMuted : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
