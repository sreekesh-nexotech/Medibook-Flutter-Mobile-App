import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/external_url.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/route_arrival.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../../core/widgets/states/app_not_found_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../common/attachments/application/providers/attachments_provider.dart';
import '../../../common/attachments/application/states/attachment_upload_state.dart';
import '../../../common/attachments/domain/entities/stored_file.dart';
import '../../../common/attachments/presentation/components/attachment_upload_tile.dart';
import '../../../common/persons/application/providers/persons_read_provider.dart';
import '../../application/providers/insurance_provider.dart';
import '../../domain/entities/insurance_policy.dart';
import '../components/insurance_fields.dart';
import '../components/insurance_policy_card.dart';
import '../components/policy_labels.dart';

/// One insurance policy (`/insurance/:id`) — CM-37, CM-39, §6.4.
///
/// `GET /patient/me/insurance-policies/{id}` with its documents. Attach a
/// file through the shared slot (purpose `insurance`): when the scan comes
/// back clean the file is attached with `POST /{id}/documents`; each
/// attached file opens through `GET /shared/files/{id}/url` and can be
/// detached. An expired policy is announced before the numbers.
class InsuranceDetailScreen extends ConsumerWidget {
  const InsuranceDetailScreen({super.key, this.id});

  /// Overrides the `:id` path parameter, so the screen is testable without
  /// a router.
  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedId =
        id ?? GoRouterState.of(context).pathParameters['id'] ?? '';
    final policy = ref.watch(insurancePolicyProvider(resolvedId));

    return RouteArrival(
      onArrive: () => ref.invalidate(insurancePolicyProvider(resolvedId)),
      child: policy.when(
        loading: () => _Frame(
          title: 'Policy',
          onBack: () => _leave(context),
          child: SingleChildScrollView(
            child: AppSkeletonList(
              count: 2,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.x5.w,
                AppSpacing.x3.h,
                AppSpacing.x5.w,
                AppSpacing.x6.h,
              ),
            ),
          ),
        ),
        error: (error, _) {
          if (error is NotFoundFailure) {
            return AppNotFoundView(
              headline: 'Policy not found',
              body:
                  'This policy is no longer on your account. It may have been '
                  'removed, or the link may be out of date.',
              attemptedPath: AppRoutes.insurancePath(resolvedId),
              onGoHome: () => context.go(AppRoutes.home),
              onGoBack: context.canPop() ? () => context.pop() : null,
            );
          }
          return _Frame(
            title: 'Policy',
            onBack: () => _leave(context),
            child: AppErrorView(
              failure: error is Failure ? error : error.asFailure(),
              headline: 'We could not load this policy',
              onRetry: () =>
                  ref.invalidate(insurancePolicyProvider(resolvedId)),
            ),
          );
        },
        data: (value) => _Frame(
          title: value.providerName,
          onBack: () => _leave(context),
          child: _Body(policy: value),
        ),
      ),
    );
  }

  static void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.insurance);
  }
}

class _Frame extends StatelessWidget {
  const _Frame({
    required this.title,
    required this.onBack,
    required this.child,
  });

  final String title;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInnerHeader(
              title: title,
              onBack: onBack,
              backSemanticLabel: 'Back to insurance',
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.policy});

  final InsurancePolicy policy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(policyActionsProvider(policy.id));
    // Names the covered person; only read when the policy names one.
    final persons = policy.personId == null
        ? null
        : ref.watch(personSummariesProvider).valueOrNull;

    // When the slot's scan comes back clean, attach the file to this
    // policy; the slot is then released so it does not delete the file.
    ref.listen(attachmentUploadProvider(FileUploadPurpose.insurance), (
      previous,
      next,
    ) {
      if (next.status != AttachmentStatus.ready ||
          previous?.status == AttachmentStatus.ready) {
        return;
      }
      final fileId = next.readyFileId;
      if (fileId != null) _attach(context, ref, fileId);
    });

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x5.w,
        AppSpacing.x1.h,
        AppSpacing.x5.w,
        AppSpacing.x8.h,
      ),
      children: [
        if (policy.isExpired) ...[
          _ExpiredBanner(policy: policy),
          SizedBox(height: AppSpacing.x4.h),
        ] else if (policy.isExpiringSoon) ...[
          _ExpiringBanner(policy: policy),
          SizedBox(height: AppSpacing.x4.h),
        ],

        _CoverCard(policy: policy),
        SizedBox(height: AppSpacing.x4.h),

        AppCard(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.x4.w,
            AppSpacing.x2.h,
            AppSpacing.x4.w,
            AppSpacing.x2.h,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InsuranceDetailRow(label: 'Plan', value: policy.planLabel),
              InsuranceDetailRow(
                label: 'Policy number',
                value: policy.policyNumber,
                isSelectable: true,
                isMono: true,
              ),
              InsuranceDetailRow(
                label: 'Policy holder',
                value: policy.holderName,
              ),
              InsuranceDetailRow(
                label: 'Covers',
                value: policy.coversLabel(persons),
              ),
              InsuranceDetailRow(label: 'Valid', value: policy.validityLabel),
              InsuranceDetailRow(
                label: 'TPA',
                value:
                    policy.tpaName ??
                    'None — claims go to the insurer directly',
                isSelectable: policy.tpaName != null,
                showDivider: policy.notes != null,
              ),
              if (policy.notes != null && policy.notes!.trim().isNotEmpty)
                InsuranceDetailRow(
                  label: 'Notes',
                  value: policy.notes!,
                  showDivider: false,
                ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.x4.h),

        if (actions.failure != null) ...[
          AppInlineError(
            failure: actions.failure!,
            onRetry: ref
                .read(policyActionsProvider(policy.id).notifier)
                .clearFailure,
            retryLabel: 'Dismiss',
          ),
          SizedBox(height: AppSpacing.x4.h),
        ],

        _DocumentsCard(policy: policy),
        SizedBox(height: AppSpacing.x6.h),

        // The renewal banner asks the patient to "update the dates here":
        // this is where (BL-INS-006).
        AppButton(
          label: 'Edit Policy',
          variant: AppButtonVariant.secondary,
          fullWidth: true,
          leadingIcon: PhIcon.pencilSimple,
          disabled: actions.isBusy,
          onPressed: actions.isBusy
              ? null
              : () => context.push(AppRoutes.insuranceEditPath(policy.id)),
        ),
        SizedBox(height: AppSpacing.x3.h),
        AppButton(
          label: 'Remove Policy',
          variant: AppButtonVariant.danger,
          fullWidth: true,
          loading: actions.isDeleting,
          disabled: actions.isBusy && !actions.isDeleting,
          onPressed: actions.isBusy ? null : () => _remove(context, ref),
        ),
      ],
    );
  }

  Future<void> _attach(
    BuildContext context,
    WidgetRef ref,
    String fileId,
  ) async {
    final attached = await ref
        .read(policyActionsProvider(policy.id).notifier)
        .attach(policy.id, fileId);
    if (!context.mounted) return;
    if (attached != null) {
      ref
          .read(attachmentUploadProvider(FileUploadPurpose.insurance).notifier)
          .detachOwnership();
      ref.invalidate(insurancePolicyProvider(policy.id));
      ref.read(toastControllerProvider.notifier).show('Document attached');
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Remove this policy?',
      consequence:
          '${policy.providerName} ${policy.planLabel} (${policy.policyNumber}) '
          'will be removed from your account. Files attached to it are kept '
          'in your uploads. You will need the policy paperwork to add it '
          'again.',
      confirmLabel: 'Remove Policy',
      iconName: PhIcon.xCircle,
    );
    if (confirmed != true || !context.mounted) return;

    final failure = await ref
        .read(policyActionsProvider(policy.id).notifier)
        .delete(policy.id);
    if (!context.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    if (failure != null && failure is! NotFoundFailure) {
      toast.show(failure.userMessage);
      return;
    }
    toast.show(
      failure == null
          ? '${policy.providerName} policy removed'
          : 'That policy is no longer on your account',
    );
    ref.invalidate(insuranceListProvider);
    ref.invalidate(insurancePolicyCountProvider);
    InsuranceDetailScreen._leave(context);
  }
}

/// The headline cover figure, with its status pill.
class _CoverCard extends StatelessWidget {
  const _CoverCard({required this.policy});

  final InsurancePolicy policy;

  @override
  Widget build(BuildContext context) {
    final isExpired = policy.isExpired;

    return AppCard(
      padding: EdgeInsets.all(AppSpacing.x5.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isExpired ? 'Cover when this policy was active' : 'Cover',
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.x2.w),
              AppStatusPill(
                label: policy.statusLabel,
                colors: InsuranceStatusStyle.of(policy),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.x2.h),
          Text(
            policy.sumInsuredLabel,
            style: AppText.inter(
              size: AppFontSize.h1,
              weight: AppText.bold,
              color: isExpired ? AppColors.textMuted : AppColors.textStrong,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            isExpired
                ? 'This policy cannot be claimed against.'
                : policy.status == PolicyStatus.notYetActive
                ? 'Cover has not started yet.'
                : '${policy.daysUntilExpiry} days of cover left',
            style: AppText.poppins(
              size: AppFontSize.xs,
              height: 1.45,
              color: isExpired ? AppColors.dangerText : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiredBanner extends StatelessWidget {
  const _ExpiredBanner({required this.policy});

  final InsurancePolicy policy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: AppRadii.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(PhIcon.xCircle, size: 20, color: AppColors.dangerText),
          SizedBox(width: AppSpacing.x3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This policy has expired',
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: AppText.bold,
                    color: AppColors.dangerText,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Cover ended on '
                  '${AppDates.dayMonthYear(policy.validTo)}. A hospital will '
                  'not be able to bill this insurer, so treatment would be '
                  'paid for out of pocket. Renew with the insurer, then add '
                  'the new policy here.',
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    height: 1.5,
                    color: AppColors.dangerText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiringBanner extends StatelessWidget {
  const _ExpiringBanner({required this.policy});

  final InsurancePolicy policy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: AppRadii.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(PhIcon.clock, size: 20, color: AppColors.textPrimary),
          SizedBox(width: AppSpacing.x3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  policy.statusLabel,
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: AppText.semibold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Cover ends on '
                  '${AppDates.dayMonthYear(policy.validTo)}. Renew with '
                  '${policy.providerName} before then to stay covered.',
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    height: 1.5,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The attached documents (§6.4 `documents[]`) plus the attach slot.
class _DocumentsCard extends ConsumerWidget {
  const _DocumentsCard({required this.policy});

  final InsurancePolicy policy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = policy.documents ?? const <PolicyDocument>[];
    final actions = ref.watch(policyActionsProvider(policy.id));

    return AppCard(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Policy documents',
              style: AppText.poppins(
                size: AppFontSize.body,
                weight: AppText.bold,
                color: AppColors.textStrong,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.x2.h),
          if (documents.isEmpty)
            const AppInlineEmpty(
              message:
                  'No policy PDF or e-card attached. Keeping one here means '
                  'you have it at the counter without hunting through email.',
              iconName: PhIcon.folder,
            )
          else
            for (final document in documents)
              _DocumentRow(
                policyId: policy.id,
                document: document,
                isOpening: actions.openingFileId == document.fileId,
                isDetaching: actions.detachingFileId == document.fileId,
                disabled: actions.isBusy,
              ),
          SizedBox(height: AppSpacing.x3.h),
          if (actions.isAttaching)
            Row(
              children: [
                const AppInlineLoader(size: 14),
                SizedBox(width: 8.w),
                Text(
                  'Attaching to this policy…',
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            )
          else
            AttachmentUploadTile(
              purpose: FileUploadPurpose.insurance,
              title: 'Attach a document',
              helper: 'A PDF or a photo of the policy or e-card',
              enabled: !actions.isBusy,
            ),
        ],
      ),
    );
  }
}

/// One attached file: name, size, scan state; Open and Detach.
class _DocumentRow extends ConsumerWidget {
  const _DocumentRow({
    required this.policyId,
    required this.document,
    required this.isOpening,
    required this.isDetaching,
    required this.disabled,
  });

  final String policyId;
  final PolicyDocument document;
  final bool isOpening;
  final bool isDetaching;
  final bool disabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = document.status == FileStatus.clean;
    final name = document.originalName.isEmpty
        ? 'Attached file'
        : document.originalName;
    final attachedAt = document.attachedAt;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.x2.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIcon(
            PhIcon.folder,
            size: 18,
            color: ready ? AppColors.brand : AppColors.textMuted,
          ),
          SizedBox(width: AppSpacing.x3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: AppText.medium,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${formatFileSize(document.sizeBytes)}'
                  '${attachedAt == null ? '' : ' · added ${AppDates.dayMonthYear(attachedAt.toLocal())}'}'
                  '${ready ? '' : ' · ${document.status.wire}'}',
                  style: AppText.poppins(
                    size: AppFontSize.xxs,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.x2.w),
          AppButton(
            label: 'Open',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            loading: isOpening,
            disabled: !ready || (disabled && !isOpening),
            semanticLabel: ready
                ? 'Open $name'
                : 'Open unavailable — the file is not ready',
            onPressed: ready && !disabled ? () => _open(context, ref) : null,
          ),
          AppButton(
            label: 'Detach',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            loading: isDetaching,
            disabled: disabled && !isDetaching,
            semanticLabel: 'Detach $name from this policy',
            onPressed: disabled ? null : () => _detach(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final signed = await ref
        .read(policyActionsProvider(policyId).notifier)
        .fileUrl(document.fileId);
    if (signed == null || !context.mounted) return;
    final launched = await openExternalUrl(signed.url);
    if (!launched && context.mounted) {
      ref
          .read(toastControllerProvider.notifier)
          .show('No app on this device could open the file');
    }
  }

  Future<void> _detach(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Detach this file?',
      consequence:
          'It will no longer be listed under this policy. The file itself '
          'is kept.',
      confirmLabel: 'Detach',
      iconName: PhIcon.xCircle,
    );
    if (confirmed != true || !context.mounted) return;
    final failure = await ref
        .read(policyActionsProvider(policyId).notifier)
        .detach(policyId, document.fileId);
    if (!context.mounted) return;
    if (failure == null) {
      ref.invalidate(insurancePolicyProvider(policyId));
      ref.read(toastControllerProvider.notifier).show('Document detached');
    }
  }
}
