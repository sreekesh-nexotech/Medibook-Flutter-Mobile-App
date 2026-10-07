import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/utils/date_utils.dart';
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
import '../../../auth/application/providers/auth_provider.dart';
import '../../../booking/presentation/components/file_image.dart';
import '../../../common/cached/presentation/components/cached_status_bar.dart';
import '../../application/providers/profile_provider.dart';
import '../../domain/entities/person.dart';

/// Family members (`/dependants`) — CM-16, CM-48, over
/// `GET /patient/me/persons` (§6.1) through the cache.
///
/// The account holder's own record (`is_self`) is shown first when the
/// account has one. The test account has **none** (INTEGRATION-CORE §3), and
/// the API refuses to create one, so that case is stated plainly: booking
/// "for myself" is unavailable until the record exists, and dependants can
/// still be added and booked for.
///
/// This list is what the booking flow's patient picker reads too, so a
/// dependant added here is bookable immediately.
class DependantsScreen extends ConsumerWidget {
  const DependantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(personsProvider);
    final self = ref.watch(selfPersonProvider);
    final dependants = ref.watch(dependantsProvider);
    // The account's photo belongs to the account holder's own card.
    final avatarFileId = ref.watch(
      currentUserProvider.select((u) => u?.avatarFileId),
    );
    Future<void> refresh() =>
        ref.read(personsProvider.notifier).refresh(force: true);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInnerHeader(
              title: 'Family Members',
              onBack: () => _leave(context),
              // Back goes where the screen was opened from (Home's Family
              // card, Profile, booking); only with nothing underneath is it
              // Profile.
              backSemanticLabel: (GoRouter.maybeOf(context)?.canPop() ?? false)
                  ? 'Back'
                  : 'Back to profile',
            ),
            Expanded(
              child: state.isLoading
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
                  : state.isError
                  ? AppErrorView(
                      failure: state.failure!,
                      headline: 'We could not load your family members',
                      onRetry: refresh,
                    )
                  : AppRefreshIndicator(
                      onRefresh: refresh,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.x5.w,
                          AppSpacing.x4.h,
                          AppSpacing.x5.w,
                          AppSpacing.x8.h,
                        ),
                        children: [
                          CachedStatusBar(state: state, onRefresh: refresh),
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
                          if (self != null)
                            _PersonCard(
                              person: self,
                              avatarFileId: avatarFileId,
                              // The account holder's identity is edited in
                              // Profile, where the email and mobile live.
                              onEdit: () => context.push(AppRoutes.profileEdit),
                              editLabel: 'Edit in Profile',
                            )
                          else
                            const _NoSelfRecordCard(),
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
                              iconName: PhIcon.folder,
                              actionLabel: 'Add Family Member',
                              onAction: () =>
                                  context.push(AppRoutes.dependantEditPath()),
                            )
                          else
                            for (final person in dependants)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: AppSpacing.x3.h,
                                ),
                                child: _PersonCard(
                                  person: person,
                                  onEdit: () => context.push(
                                    AppRoutes.dependantEditPath(person.id),
                                  ),
                                ),
                              ),
                          SizedBox(height: AppSpacing.x2.h),
                          AppButton(
                            label: 'Add Family Member',
                            variant: AppButtonVariant.secondary,
                            fullWidth: true,
                            leadingIcon: PhIcon.plus,
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

/// The honest state for an account with no `is_self` person: the API cannot
/// create one from the app (§6.1 refuses `relation: self`).
class _NoSelfRecordCard extends StatelessWidget {
  const _NoSelfRecordCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: AppRadii.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No patient record for you yet',
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'This account has no "self" record, so booking for yourself is '
            'not available until one is created by support. You can still '
            'add family members and book for them.',
            style: AppText.poppins(
              size: AppFontSize.xs,
              height: 1.5,
              color: AppColors.textBody,
            ),
          ),
        ],
      ),
    );
  }
}

/// One person: who they are, the details a clinician needs, and Edit.
///
/// Removal and release live on the edit screen: both are destructive, and
/// putting them behind opening the record makes them hard to hit by
/// accident in a list.
class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.onEdit,
    this.editLabel = 'Edit',
    this.avatarFileId,
  });

  final Person person;
  final VoidCallback onEdit;
  final String editLabel;

  /// The account's photo (`profile.avatar_file_id`) — only the account
  /// holder's card has one; everyone else shows initials.
  final String? avatarFileId;

  @override
  Widget build(BuildContext context) {
    final age = person.ageInYears();
    final guardianNote = person.guardianNote?.trim();
    final meta = [
      person.relationLabel,
      if (age != null) '$age years',
      if (person.gender != null) person.gender!.label,
    ].join(' · ');

    return AppCard(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: SizedBox.square(
                  dimension: 44.w,
                  child: AppFileImage(
                    fileId: avatarFileId,
                    fallback: AppAvatar(name: person.name, size: 44),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.x3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      person.name,
                      style: AppText.poppins(
                        size: AppFontSize.body,
                        weight: AppText.bold,
                        color: AppColors.textStrong,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      meta,
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.x2.w),
              if (person.isSelf)
                const AppBadge(label: 'You', tone: AppBadgeTone.brand)
              else if (person.isMinor)
                const AppBadge(label: 'Minor', tone: AppBadgeTone.neutral),
            ],
          ),
          SizedBox(height: AppSpacing.x3.h),
          _DetailRow(
            label: 'Date of birth',
            value: person.dateOfBirth == null
                ? 'Not recorded'
                : AppDates.dayMonthYear(person.dateOfBirth!),
            isMissing: person.dateOfBirth == null,
          ),
          _DetailRow(
            label: 'Blood group',
            value: person.bloodGroup ?? 'Not recorded',
            isMissing: person.bloodGroup == null,
          ),
          if (person.phoneE164 != null)
            _DetailRow(label: 'Mobile', value: person.phoneE164!),
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
          if (person.hasAllergies)
            Wrap(
              spacing: AppSpacing.x2.w,
              runSpacing: AppSpacing.x2.h,
              children: [
                for (final allergy in person.allergies) AppTag(label: allergy),
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
          if (guardianNote != null && guardianNote.isNotEmpty) ...[
            SizedBox(height: AppSpacing.x3.h),
            Text(
              'Guardian note',
              style: AppText.poppins(
                size: AppFontSize.xs,
                weight: AppText.medium,
                color: AppColors.textMuted,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              guardianNote,
              style: AppText.poppins(
                size: AppFontSize.sm,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          SizedBox(height: AppSpacing.x3.h),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: editLabel,
              variant: AppButtonVariant.soft,
              size: AppButtonSize.sm,
              leadingIcon: MedIcon.edit,
              semanticLabel: '$editLabel ${person.name}',
              onPressed: onEdit,
            ),
          ),
        ],
      ),
    );
  }
}

/// A label/value line inside a person card.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isMissing = false,
  });

  final String label;
  final String value;
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
