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
import '../../../../core/mock_data/models/insurance_policy.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../components/insurance_policy_card.dart';
import '../controllers/insurance_list_controller.dart';

/// The insurance locker (`/insurance`) — CM-37, CM-39.
///
/// The audit's finding was "nothing exists". This is the list: every policy on
/// the account, filterable by in-force / expired, each card showing its status
/// in words as well as colour, with the renewal nudge for anything inside 30
/// days of expiry (CM-39) pinned above the list.
///
/// All four list states are here — skeletons on first load, [AppErrorView]
/// with a retry, an empty state that offers the add form (a fresh account has
/// no policies, so it is the first thing a real user sees), and the content
/// list, refreshable by pulling.
class InsuranceScreen extends ConsumerWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(insuranceListControllerProvider);
    final policies = ref.watch(visibleInsurancePoliciesProvider);
    final counts = ref.watch(insuranceFilterCountsProvider);
    final expiringSoon = ref.watch(expiringSoonPoliciesProvider);
    final controller = ref.read(insuranceListControllerProvider.notifier);

    final hasAnyPolicy = (counts[InsuranceFilter.all] ?? 0) > 0;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInnerHeader(
              title: 'Insurance',
              onBack: () => _leave(context),
              backSemanticLabel: 'Back to profile',
              bottomGap: 10,
            ),
            if (hasAnyPolicy && !state.isLoading)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.x5.w,
                  0,
                  AppSpacing.x5.w,
                  AppSpacing.x3.h,
                ),
                child: AppSegmentedTabs(
                  tabs: [
                    for (final filter in InsuranceFilter.values)
                      _tabLabel(filter, counts[filter] ?? 0),
                  ],
                  active: _tabLabel(state.filter, counts[state.filter] ?? 0),
                  onChanged: (label) {
                    for (final filter in InsuranceFilter.values) {
                      if (_tabLabel(filter, counts[filter] ?? 0) == label) {
                        controller.setFilter(filter);
                        return;
                      }
                    }
                  },
                ),
              ),
            Expanded(
              child: _body(
                context,
                ref,
                state: state,
                policies: policies,
                expiringSoon: expiringSoon,
                hasAnyPolicy: hasAnyPolicy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Active 2" — the count belongs in the tab so the filter answers "is there
  /// anything in there" before it is tapped.
  String _tabLabel(InsuranceFilter filter, int count) =>
      count == 0 ? filter.label : '${filter.label} $count';

  Widget _body(
    BuildContext context,
    WidgetRef ref, {
    required InsuranceListState state,
    required List<InsurancePolicy> policies,
    required List<InsurancePolicy> expiringSoon,
    required bool hasAnyPolicy,
  }) {
    final controller = ref.read(insuranceListControllerProvider.notifier);

    if (state.isLoading) {
      return SingleChildScrollView(
        child: AppSkeletonList(
          count: 3,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.x5.w,
            AppSpacing.x3.h,
            AppSpacing.x5.w,
            AppSpacing.x6.h,
          ),
        ),
      );
    }

    if (state.failure != null && policies.isEmpty) {
      return AppErrorView(
        failure: state.failure!,
        headline: 'We could not load your policies',
        onRetry: controller.retry,
        secondaryLabel: 'Add a Policy',
        onSecondary: () => context.push(AppRoutes.insuranceAdd),
      );
    }

    return AppRefreshIndicator(
      onRefresh: controller.refresh,
      child: policies.isEmpty
          ? ListView(
              children: [
                hasAnyPolicy
                    // A filter matched nothing — the way out is the filter,
                    // not the add form.
                    ? AppEmptyView(
                        iconName: MedIcon.hospital,
                        headline: state.filter == InsuranceFilter.expired
                            ? 'No expired policies'
                            : 'No policies in force',
                        body: state.filter == InsuranceFilter.expired
                            ? 'Nothing on your account has lapsed. That is '
                                  'the good news.'
                            : 'Every policy on your account has expired. Add '
                                  'a current one so a hospital can bill your '
                                  'insurer directly.',
                        actionLabel: 'Show All Policies',
                        onAction: () =>
                            controller.setFilter(InsuranceFilter.all),
                        secondaryLabel: 'Add a Policy',
                        onSecondary: () => context.push(AppRoutes.insuranceAdd),
                      )
                    : AppEmptyView(
                        iconName: MedIcon.hospital,
                        headline: 'No insurance saved',
                        body:
                            'Save your health policy here and it is to hand '
                            'at the hospital counter — the policy number, the '
                            'cover left, and who to call.',
                        actionLabel: 'Add a Policy',
                        onAction: () => context.push(AppRoutes.insuranceAdd),
                      ),
              ],
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.x5.w,
                AppSpacing.x3.h,
                AppSpacing.x5.w,
                AppSpacing.x8.h,
              ),
              children: [
                if (state.failure != null) ...[
                  AppErrorBanner(
                    message: state.failure!.userMessage,
                    onTap: controller.refresh,
                  ),
                  SizedBox(height: AppSpacing.x4.h),
                ],
                // CM-39: a policy about to lapse is the one thing on this
                // screen worth interrupting for.
                if (expiringSoon.isNotEmpty) ...[
                  _RenewalNudge(policies: expiringSoon),
                  SizedBox(height: AppSpacing.x4.h),
                ],
                for (final policy in policies)
                  Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.x3.h),
                    child: InsurancePolicyCard(
                      policy: policy,
                      onTap: () =>
                          context.push(AppRoutes.insurancePath(policy.id)),
                    ),
                  ),
                SizedBox(height: AppSpacing.x2.h),
                AppButton(
                  label: 'Add Policy',
                  variant: AppButtonVariant.secondary,
                  fullWidth: true,
                  onPressed: () => context.push(AppRoutes.insuranceAdd),
                ),
              ],
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

/// The renewal nudge (CM-39): which policies lapse soon, and when.
///
/// It does not offer to renew — Medibook cannot renew an insurance policy, and
/// a "Renew now" button that goes nowhere would be exactly the fake control
/// this app is being audited for. It says what is happening and when.
class _RenewalNudge extends StatelessWidget {
  const _RenewalNudge({required this.policies});

  final List<InsurancePolicy> policies;

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
                  policies.length == 1
                      ? 'A policy is about to expire'
                      : '${policies.length} policies are about to expire',
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: AppText.semibold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                for (final policy in policies)
                  Padding(
                    padding: EdgeInsets.only(top: 2.h),
                    child: Text(
                      '${policy.provider} · ${policy.statusLabel.toLowerCase()}',
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        height: 1.45,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                SizedBox(height: 6.h),
                Text(
                  'Renew with your insurer directly, then update the dates '
                  'here.',
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    height: 1.45,
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
