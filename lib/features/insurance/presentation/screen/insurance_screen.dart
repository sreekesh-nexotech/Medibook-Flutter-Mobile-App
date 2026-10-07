import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/network/connectivity/connectivity_monitor.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../application/providers/insurance_provider.dart';
import '../../application/states/insurance_list_state.dart';
import '../../domain/entities/insurance_policy.dart';
import '../components/insurance_policy_card.dart';
import '../components/policy_labels.dart';

/// The insurance locker (`/insurance`) — CM-37, CM-39.
///
/// `GET /patient/me/insurance-policies` through the three-layer cache, with
/// every state real: skeletons on a cold start, [AppErrorView] with retry,
/// the empty state that offers the add form, the content list with the
/// in-force / expired tabs (derived from `valid_to`, §6.4), pull-to-refresh,
/// "updating…", the stale bar and the offline note.
class InsuranceScreen extends ConsumerWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(insuranceEnabledProvider)) {
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
              ),
              const Expanded(
                child: AppEmptyView(
                  iconName: PhIcon.firstAid,
                  headline: 'Insurance is not available right now',
                  body:
                      'This part of the app is switched off at the moment. '
                      'Check back later.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final state = ref.watch(insuranceListProvider);
    final policies = ref.watch(visibleInsurancePoliciesProvider);
    final counts = ref.watch(insuranceFilterCountsProvider);
    final expiringSoon = ref.watch(expiringSoonPoliciesProvider);
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final controller = ref.read(insuranceListProvider.notifier);

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
                isOnline: isOnline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tabLabel(InsuranceFilter filter, int count) =>
      count == 0 ? filter.label : '${filter.label} $count';

  Widget _body(
    BuildContext context,
    WidgetRef ref, {
    required InsuranceListState state,
    required List<InsurancePolicy> policies,
    required List<InsurancePolicy> expiringSoon,
    required bool hasAnyPolicy,
    required bool isOnline,
  }) {
    final controller = ref.read(insuranceListProvider.notifier);

    if (state.isLoading && !state.hasData) {
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

    if (state.failure != null && !state.hasData) {
      return AppErrorView(
        failure: state.failure!,
        headline: 'We could not load your policies',
        onRetry: controller.retry,
        secondaryLabel: 'Add a Policy',
        onSecondary: () => context.push(AppRoutes.insuranceAdd),
      );
    }

    final cachedAt = state.cachedAt;
    final banners = <Widget>[
      // Offline is said once, by the app-wide OfflineBar (offline audit).
      if (isOnline && state.isStale && cachedAt != null)
        AppErrorBanner(
          message:
              'Data from ${AppDates.relativeAgo(cachedAt)} • Tap to refresh',
          onTap: controller.refresh,
        ),
      if (state.failure != null)
        AppErrorBanner(
          message: state.failure!.userMessage,
          tone: AppBannerTone.danger,
          iconName: PhIcon.xCircle,
          onTap: controller.retry,
        ),
      if (state.revalidating)
        Row(
          children: [
            const AppInlineLoader(size: 14),
            SizedBox(width: 8.w),
            Text(
              'Updating…',
              style: AppText.poppins(
                size: AppFontSize.xs,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
    ];

    return AppRefreshIndicator(
      onRefresh: controller.refresh,
      child: policies.isEmpty
          ? ListView(
              children: [
                for (final banner in banners)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.x5.w,
                      AppSpacing.x3.h,
                      AppSpacing.x5.w,
                      0,
                    ),
                    child: banner,
                  ),
                hasAnyPolicy
                    ? AppEmptyView(
                        iconName: PhIcon.firstAid,
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
                        iconName: PhIcon.firstAid,
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
                for (final banner in banners) ...[
                  banner,
                  SizedBox(height: AppSpacing.x4.h),
                ],
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

/// The renewal nudge (CM-39): which policies lapse soon, and when. It does
/// not offer to renew — Medibook cannot renew a policy.
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
          AppIcon(PhIcon.clock, size: 20, color: AppColors.textPrimary),
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
                      '${policy.providerName} · '
                      '${policy.statusLabel.toLowerCase()}',
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
