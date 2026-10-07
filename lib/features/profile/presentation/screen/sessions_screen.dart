import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../common/cached/presentation/components/cached_status_bar.dart';
import '../../application/providers/profile_mutations_provider.dart';
import '../../application/providers/profile_provider.dart';
import '../../domain/entities/account.dart';

/// Signed-in devices (`/profile/sessions`) — `GET /patient/auth/sessions`
/// (§4.9), most recently seen first.
///
/// Each other session can be ended on its own (`DELETE …/sessions/{id}`);
/// "Log out everywhere" ends every session including this one
/// (`AuthController.logout(everywhere: true)`), after which the router lands
/// on sign-in.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionsProvider);
    final busy = ref.watch(sessionsControllerProvider.select((s) => s.isBusy));
    Future<void> refresh() =>
        ref.read(sessionsProvider.notifier).refresh(force: true);

    final sessions = state.value ?? const <AccountSession>[];
    final others = sessions.where((s) => !s.isCurrent).toList();

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInnerHeader(
              title: 'Signed-in Devices',
              onBack: () => _leave(context),
              backSemanticLabel: 'Back to profile',
            ),
            Expanded(
              child: state.isLoading
                  ? SingleChildScrollView(
                      child: AppSkeletonList(
                        count: 3,
                        tile: true,
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
                      headline: 'We could not load your devices',
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
                            others.isEmpty
                                ? 'Only this device is signed in.'
                                : others.length == 1
                                ? 'One other device is signed in to your '
                                      'account.'
                                : '${others.length} other devices are signed '
                                      'in to your account.',
                            style: AppText.poppins(
                              size: AppFontSize.xs,
                              height: 1.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          for (final session in sessions)
                            Padding(
                              padding: EdgeInsets.only(bottom: AppSpacing.x3.h),
                              child: _SessionCard(
                                session: session,
                                isBusy: busy,
                                onRevoke: session.isCurrent
                                    ? null
                                    : () => _revoke(context, ref, session),
                              ),
                            ),
                          SizedBox(height: AppSpacing.x2.h),
                          AppButton(
                            label: 'Log Out Everywhere',
                            variant: AppButtonVariant.danger,
                            fullWidth: true,
                            leadingIcon: MedIcon.logout,
                            onPressed: () => _logoutEverywhere(context, ref),
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

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    AccountSession session,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Sign out ${session.deviceLabel}?',
      consequence:
          'That device will be signed out immediately and will need your '
          'password or a code to get back in.',
      confirmLabel: 'Sign Out Device',
      iconName: MedIcon.logout,
    );
    if (confirmed != true || !context.mounted) return;
    final failure = await ref
        .read(sessionsControllerProvider.notifier)
        .revoke(session.id);
    if (!context.mounted) return;
    ref
        .read(toastControllerProvider.notifier)
        .show(failure?.userMessage ?? '${session.deviceLabel} signed out');
  }

  Future<void> _logoutEverywhere(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Log out everywhere?',
      consequence:
          'Every device, including this one, is signed out now. You will '
          'need your password or a code to sign back in.',
      confirmLabel: 'Log Out Everywhere',
      iconName: MedIcon.logout,
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(authProvider.notifier).logout(everywhere: true);
    if (!context.mounted) return;
    context.go(AppRoutes.login);
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.profile);
  }
}

/// One session: device, network, when it was last used, and its Sign out.
class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.isBusy,
    required this.onRevoke,
  });

  final AccountSession session;
  final bool isBusy;

  /// Null on the current session — it is ended by Logout, not here.
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final lastSeen = session.lastSeenAt;
    final created = session.createdAt;
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(PhIcon.buildings, size: 20, color: AppColors.brand),
              SizedBox(width: AppSpacing.x2.w),
              Expanded(
                child: Text(
                  session.deviceLabel,
                  style: AppText.poppins(
                    size: AppFontSize.body,
                    weight: AppText.bold,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
              if (session.isCurrent) ...[
                SizedBox(width: AppSpacing.x2.w),
                const AppBadge(label: 'This device', tone: AppBadgeTone.brand),
              ],
            ],
          ),
          SizedBox(height: AppSpacing.x2.h),
          Text(
            [
              ?session.appVersionLabel,
              if (lastSeen != null)
                'Last used ${AppDates.relativeAgo(lastSeen.toLocal())}',
              if (created != null)
                'signed in ${AppDates.dayMonthYear(created.toLocal())}',
              if (session.ip != null && session.ip!.isNotEmpty)
                'from ${session.ip}',
            ].join(' · '),
            style: AppText.poppins(
              size: AppFontSize.xs,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
          if (onRevoke != null) ...[
            SizedBox(height: AppSpacing.x3.h),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: 'Sign Out Device',
                variant: AppButtonVariant.soft,
                size: AppButtonSize.sm,
                disabled: isBusy,
                semanticLabel: 'Sign out ${session.deviceLabel}',
                onPressed: onRevoke,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
