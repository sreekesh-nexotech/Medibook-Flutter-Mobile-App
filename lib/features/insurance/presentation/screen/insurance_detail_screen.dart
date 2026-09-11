import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/insurance_policy.dart';
import '../../../../core/mock_data/stores/documents_store.dart';
import '../../../../core/mock_data/stores/insurance_store.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../../../core/widgets/app_stub_notice.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_not_found_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/insurance_fields.dart';
import '../components/insurance_policy_card.dart';

/// One insurance policy (`/insurance/:id`) — CM-37, CM-39.
///
/// What a patient standing at a hospital counter needs, in the order they need
/// it: whether the policy is in force, the number to quote, who it is in, how
/// much cover it carries, and who administers the claim.
///
/// ## An expired policy must look expired
///
/// If the policy has lapsed, that is the first thing on the screen — a red
/// banner saying so and naming the date, above the numbers. The cover amount
/// is then rendered muted and captioned as what the policy *was* for, because
/// a big confident "₹5,00,000" on a lapsed policy is a promise the app cannot
/// keep.
///
/// Reads [insurancePolicyByIdProvider], which returns null for an id that is
/// not on the account — a stale deep link, or a policy removed on another
/// screen — and that renders [AppNotFoundView] rather than a blank card.
class InsuranceDetailScreen extends ConsumerWidget {
  const InsuranceDetailScreen({super.key, this.id});

  /// Overrides the `:id` path parameter. Exists so the router can pass it
  /// explicitly and so the screen is testable without a router.
  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedId =
        id ?? GoRouterState.of(context).pathParameters['id'] ?? '';
    final policy = ref.watch(insurancePolicyByIdProvider(resolvedId));

    if (policy == null) {
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

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInnerHeader(
              title: policy.provider,
              onBack: () => _leave(context),
              backSemanticLabel: 'Back to insurance',
            ),
            Expanded(
              child: ListView(
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
                        InsuranceDetailRow(
                          label: 'Plan',
                          value: policy.planName,
                        ),
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
                          label: 'Valid',
                          value: policy.validityLabel,
                        ),
                        InsuranceDetailRow(
                          label: 'TPA',
                          value:
                              policy.tpaName ??
                              'None — claims go to the '
                                  'insurer directly',
                          isSelectable: policy.tpaName != null,
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.x4.h),

                  _DocumentsCard(policy: policy),
                  SizedBox(height: AppSpacing.x6.h),

                  AppButton(
                    label: 'Remove Policy',
                    variant: AppButtonVariant.danger,
                    fullWidth: true,
                    onPressed: () => _remove(context, ref, policy),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    InsurancePolicy policy,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Remove this policy?',
      consequence:
          '${policy.provider} ${policy.planName} (${policy.policyNumber}) '
          'will be removed from your account, and it will no longer be '
          'offered as a way to pay. Any documents attached to it stay in your '
          'records. You will need the policy paperwork to add it again.',
      confirmLabel: 'Remove Policy',
      iconName: MedIcon.closeCircle,
    );
    if (confirmed != true || !context.mounted) return;

    final removed = ref.read(insuranceStoreProvider.notifier).remove(policy.id);
    if (!context.mounted) return;

    if (!removed) {
      // False means the store had no such policy — never a success message.
      ref
          .read(toastControllerProvider.notifier)
          .show('That policy is no longer on your account');
      return;
    }
    ref
        .read(toastControllerProvider.notifier)
        .show('${policy.provider} policy removed');
    _leave(context);
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.insurance);
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
              // Muted on a lapsed policy: the figure is history, not money
              // that is available.
              color: isExpired ? AppColors.textMuted : AppColors.textStrong,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            isExpired
                ? 'This policy cannot be claimed against.'
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

/// The lapsed-policy banner — the first thing on the screen when cover is gone.
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
          AppIcon(MedIcon.closeCircle, size: 20, color: AppColors.dangerText),
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

/// The 30-day renewal nudge (CM-39) on the detail screen.
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
          AppIcon(MedIcon.clock, size: 20, color: AppColors.textPrimary),
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
                  '${policy.provider} before then to stay covered.',
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

/// The attached documents — CM-38's other half.
///
/// The list is real: it resolves each id through `documentByIdProvider`, so an
/// attachment made anywhere shows here, and an id whose document has been
/// deleted from Records is reported as missing rather than rendered as a file
/// that can be opened. Attaching is the part that cannot be real (no file
/// picker exists and none may be added), so that control declares itself
/// stubbed.
class _DocumentsCard extends ConsumerWidget {
  const _DocumentsCard({required this.policy});

  final InsurancePolicy policy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          if (policy.documents.isEmpty)
            AppInlineEmpty(
              message:
                  'No policy PDF or e-card attached. Keeping one here means '
                  'you have it at the counter without hunting through email.',
              iconName: MedIcon.records,
            )
          else
            for (final documentId in policy.documents)
              _DocumentRow(documentId: documentId),
          SizedBox(height: AppSpacing.x3.h),
          AppButton(
            label: 'Attach Document',
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            stubbed: true,
            onPressed: () =>
                showStubbedToast(context, ref, 'Attaching a policy document'),
          ),
        ],
      ),
    );
  }
}

/// One attached document, resolved from its id.
class _DocumentRow extends ConsumerWidget {
  const _DocumentRow({required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(documentByIdProvider(documentId));

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.x2.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            MedIcon.records,
            size: 18,
            color: document == null ? AppColors.textMuted : AppColors.brand,
          ),
          SizedBox(width: AppSpacing.x3.w),
          Expanded(
            child: document == null
                // The id is on the policy but the document has gone from
                // Records. Saying so beats rendering an openable-looking row
                // for a file that is not there.
                ? Text(
                    'A document attached to this policy is no longer in your '
                    'records.',
                    style: AppText.poppins(
                      size: AppFontSize.xs,
                      height: 1.45,
                      color: AppColors.textMuted,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        document.title,
                        style: AppText.poppins(
                          size: AppFontSize.base,
                          weight: AppText.medium,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${document.type.label} · ${document.fileSizeLabel} · '
                        'added ${document.uploadedLabel}',
                        style: AppText.poppins(
                          size: AppFontSize.xxs,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
          ),
          if (document != null) ...[
            SizedBox(width: AppSpacing.x2.w),
            AppButton(
              label: 'Open',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              semanticLabel: 'Open ${document.title} in your records',
              // Genuinely opens it: the records feature owns the document
              // screen, and this is a real route to a real record.
              onPressed: () =>
                  context.push(AppRoutes.documentPath(document.id)),
            ),
          ],
        ],
      ),
    );
  }
}
