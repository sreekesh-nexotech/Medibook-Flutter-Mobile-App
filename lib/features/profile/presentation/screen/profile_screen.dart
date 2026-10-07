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
import '../../../../core/error/failure.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../booking/presentation/components/file_image.dart';
import '../../../insurance/application/providers/insurance_provider.dart';
import '../../../notifications/application/providers/notifications_provider.dart';
import '../../../support/application/providers/app_config_provider.dart';
import '../../../support/application/providers/faq_controller.dart';
import '../../../support/application/providers/support_provider.dart';
import '../../application/providers/account_deletion_provider.dart';
import '../../application/providers/profile_mutations_provider.dart';
import '../../application/providers/profile_provider.dart';
import '../../domain/entities/account.dart';
import '../components/profile_info_card.dart';
import '../components/profile_menu_card.dart';
import '../../application/providers/profile_edit_controller.dart';

/// Profile tab (`/profile`). Lives in the bottom-nav shell (no nav bar here).
///
/// The account hub, over the live session user (`currentUserProvider`, kept
/// fresh by `GET /patient/me`) and the account's cached lists (persons,
/// addresses, emergency contacts, consents, deletion requests). Pull to
/// refresh re-reads `/me` and every list.
///
/// * **Re-consent** — when `app-config.legal_versions` is newer than what
///   was accepted (§5.9), a card asks for it and posts each acceptance.
/// * **Delete account** — a real deletion request (§5.6) with a reason,
///   confirmed with the 30-day consequence named. While the account is
///   `pending_deletion` the card shows the cooling-off end date with
///   Withdraw and Reactivate.
/// * **Logout** really signs out (`authProvider.logout()`); "log out
///   everywhere" lives on the sessions screen.
/// * The old "Available for Donation" toggle is gone: the backend has no such
///   field (§18), and a switch that persists nothing is a fake success.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final identity = ref.watch(profileIdentityProvider);
    final dependants = ref.watch(dependantsProvider);
    final persons = ref.watch(personsProvider);
    final contacts = ref.watch(
      emergencyContactsProvider.select((s) => s.value),
    );
    final addresses = ref.watch(addressesProvider.select((s) => s.value));
    final pending = ref.watch(pendingConsentsProvider);
    final consentBusy = ref.watch(
      consentControllerProvider.select((s) => s.isBusy),
    );
    final openDeletion = ref.watch(openDeletionRequestProvider);
    final deletion = ref.watch(accountDeletionControllerProvider);
    final coolingOffDays = ref.watch(deletionCoolingOffDaysProvider);
    final faqTopics = ref.watch(faqTopicsProvider);
    final insuranceEnabled = ref.watch(insuranceEnabledProvider);
    // Only counted while the feature is on: a switched-off locker is not
    // read at all.
    final policyCount = insuranceEnabled
        ? ref.watch(insurancePolicyCountProvider)
        : null;

    // App config too: a new policy version, support number or feature switch
    // must show on pull-to-refresh, not only after a restart.
    Future<void> refreshAll() => Future.wait([
      ref.read(authProvider.notifier).refreshMe(),
      ref.read(personsProvider.notifier).refresh(force: true),
      ref.read(emergencyContactsProvider.notifier).refresh(force: true),
      ref.read(addressesProvider.notifier).refresh(force: true),
      ref.read(consentsProvider.notifier).refresh(force: true),
      ref.read(deletionRequestsProvider.notifier).refresh(force: true),
      ref.read(appConfigProvider.notifier).refresh(force: true),
      ref.read(supportFaqsProvider.notifier).refresh(force: true),
      if (insuranceEnabled)
        ref.read(insurancePolicyCountProvider.notifier).refresh(force: true),
    ]);

    return ColoredBox(
      color: AppColors.bgApp,
      child: SafeArea(
        bottom: false,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: AppConstants.fadeIn,
          curve: Curves.easeOut,
          builder: (context, value, child) =>
              Opacity(opacity: value, child: child),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTabHeader(title: 'Profile'),
              Expanded(
                child: AppRefreshIndicator(
                  onRefresh: refreshAll,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 24.h),
                    children: [
                      if (identity == null)
                        AppErrorView(
                          failure: const UnauthorizedFailure(
                            userMessage: 'Sign in to see your profile.',
                          ),
                          headline: 'Not signed in',
                          secondaryLabel: 'Sign In',
                          onSecondary: () => context.go(AppRoutes.login),
                        )
                      else ...[
                        _IdentityCard(
                          name: identity.name,
                          email: identity.email ?? 'No email on file',
                          avatarFileId: identity.avatarFileId,
                          onEdit: () => context.push(AppRoutes.profileEdit),
                        ),
                        SizedBox(height: 16.h),

                        if (user != null && user.isPendingDeletion) ...[
                          _CoolingOffCard(
                            request: openDeletion,
                            isBusy: deletion.isBusy,
                            onWithdraw: openDeletion == null
                                ? null
                                : () => _withdraw(context, ref, openDeletion),
                            onReactivate: () => _reactivate(context, ref),
                          ),
                          SizedBox(height: 16.h),
                        ],

                        if (pending.isNotEmpty) ...[
                          _ReconsentCard(
                            pending: pending,
                            isBusy: consentBusy,
                            onRead: (slug) =>
                                context.push(AppRoutes.legalPath(slug)),
                            onAccept: () =>
                                _acceptConsents(context, ref, pending),
                          ),
                          SizedBox(height: 16.h),
                        ],

                        ProfileInfoCard(
                          rows: identity.infoRows,
                          onEdit: () => context.push(AppRoutes.profileEdit),
                        ),
                        SizedBox(height: 16.h),

                        ProfileMenuCard(
                          title: 'Your people and cover',
                          rows: [
                            ProfileMenuRow(
                              iconName: PhIcon.folder,
                              label: 'Family members',
                              subtitle: persons.isLoading
                                  ? 'Loading…'
                                  : dependants.isEmpty
                                  ? 'Add the people you book for'
                                  : 'Book for them and keep their records',
                              trailingText: persons.isLoading
                                  ? null
                                  : dependants.isEmpty
                                  ? 'None'
                                  : '${dependants.length}',
                              semanticLabel:
                                  'Family members, ${dependants.length} saved',
                              onTap: () => context.push(AppRoutes.dependants),
                            ),
                            ProfileMenuRow(
                              iconName: PhIcon.firstAid,
                              label: 'Insurance',
                              subtitle: !insuranceEnabled
                                  ? 'Not available right now'
                                  : policyCount == 0
                                  ? 'No policy saved yet'
                                  : 'Your policies and documents',
                              trailingText: policyCount == null
                                  ? null
                                  : policyCount == 0
                                  ? 'None'
                                  : '$policyCount',
                              semanticLabel: policyCount == null
                                  ? 'Insurance policies'
                                  : 'Insurance policies, $policyCount saved',
                              onTap: () => context.push(AppRoutes.insurance),
                            ),
                            ProfileMenuRow(
                              iconName: PhIcon.bell,
                              label: 'Emergency contacts',
                              subtitle: contacts == null
                                  ? 'Who the hospital calls first'
                                  : contacts.isEmpty
                                  ? 'No one to call yet'
                                  : 'Who the hospital calls first',
                              trailingText: contacts == null
                                  ? null
                                  : contacts.isEmpty
                                  ? 'None'
                                  : '${contacts.length}',
                              onTap: () =>
                                  context.push(AppRoutes.profileEmergency),
                            ),
                            ProfileMenuRow(
                              iconName: PhIcon.mapPin,
                              label: 'Saved addresses',
                              subtitle: addresses == null
                                  ? 'Used for home visits and invoices'
                                  : addresses.isEmpty
                                  ? 'None saved for home visits yet'
                                  : 'Used for home visits and invoices',
                              trailingText: addresses == null
                                  ? null
                                  : addresses.isEmpty
                                  ? 'None'
                                  : '${addresses.length}',
                              onTap: () =>
                                  context.push(AppRoutes.profileAddress),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),

                        ProfileMenuCard(
                          title: 'Help',
                          rows: [
                            ProfileMenuRow(
                              iconName: PhIcon.firstAid,
                              label: 'Help & Support',
                              subtitle: 'Raise a request or find a number',
                              onTap: () => context.push(AppRoutes.support),
                            ),
                            ProfileMenuRow(
                              iconName: PhIcon.magnifyingGlass,
                              label: 'FAQs',
                              // The live categories, not a list of topics
                              // the server may not have.
                              subtitle:
                                  faqTopics ?? 'Common questions, answered',
                              semanticLabel: 'Frequently asked questions',
                              onTap: () => context.push(AppRoutes.faq),
                            ),
                            for (final policy in _policies)
                              ProfileMenuRow(
                                iconName: PhIcon.folder,
                                label: policy.title,
                                semanticLabel: 'Read the ${policy.title}',
                                onTap: () => context.push(
                                  AppRoutes.legalPath(policy.slug),
                                ),
                              ),
                            // The licences of the bundled packages and fonts
                            // (CL REL-026), from Flutter's own registry.
                            ProfileMenuRow(
                              iconName: PhIcon.folder,
                              label: 'Open-source licences',
                              onTap: () => showLicensePage(
                                context: context,
                                applicationName: 'Medibook',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),

                        ProfileMenuCard(
                          title: 'Account',
                          rows: [
                            ProfileMenuRow(
                              iconName: PhIcon.eye,
                              label: user?.hasPassword ?? true
                                  ? 'Change password'
                                  : 'Set a password',
                              subtitle: user?.hasPassword ?? true
                                  ? 'You will need your current password'
                                  : 'Sign in with a password as well as a code',
                              onTap: () =>
                                  context.push(AppRoutes.changePassword),
                            ),
                            ProfileMenuRow(
                              iconName: PhIcon.buildings,
                              label: 'Signed-in devices',
                              subtitle: 'See and end other sessions',
                              onTap: () =>
                                  context.push(AppRoutes.profileSessions),
                            ),
                            ProfileMenuRow(
                              iconName: PhIcon.downloadSimple,
                              label: 'Download my data',
                              subtitle: 'Ask for a copy of what we hold',
                              onTap: () =>
                                  context.push(AppRoutes.profileDataExport),
                            ),
                            ProfileMenuRow(
                              iconName: MedIcon.logout,
                              label: 'Logout',
                              subtitle: 'Sign out on this device',
                              isDestructive: true,
                              onTap: () => _confirmLogout(context, ref),
                            ),
                            if (user == null || !user.isPendingDeletion)
                              ProfileMenuRow(
                                iconName: PhIcon.xCircle,
                                label: 'Delete account',
                                subtitle:
                                    '$coolingOffDays-day cooling off, then '
                                    'erased',
                                isDestructive: true,
                                onTap: () => _openDeleteAccount(context, ref),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<({String slug, String title})> _policies = [
    (slug: AppRoutes.legalTerms, title: 'Terms of Service'),
    (slug: AppRoutes.legalPrivacy, title: 'Privacy Policy'),
    (slug: AppRoutes.legalGuidelines, title: 'Community Guidelines'),
  ];

  /// CM-53. Confirms with what is lost named, then really signs out.
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Log out of Medibook?',
      consequence:
          'Your appointments, records and saved details stay on your account, '
          'but this device will be signed out and you will need your password '
          'or a code to get back in.',
      confirmLabel: 'Log Out',
      iconName: MedIcon.logout,
    );
    if (confirmed != true || !context.mounted) return;

    // Drop this install's push registration while the token is still valid
    // (§16.1: `DELETE /patient/devices/{id}` needs the session), then end it.
    await ref.read(pushDeviceProvider.notifier).unregister();
    await ref.read(authProvider.notifier).logout();
    if (!context.mounted) return;
    context.go(AppRoutes.login);
  }

  Future<void> _acceptConsents(
    BuildContext context,
    WidgetRef ref,
    List<PendingConsent> pending,
  ) async {
    final failure = await ref
        .read(consentControllerProvider.notifier)
        .acceptAll(pending);
    if (!context.mounted) return;
    ref
        .read(toastControllerProvider.notifier)
        .show(failure?.userMessage ?? 'Thanks — your acceptance is recorded');
  }

  /// §5.6: collects an optional reason, confirms the consequence, then opens
  /// the deletion request. The cooling-off length is the platform's setting
  /// (`dsr_cooling_off_days`), not a number written into the app.
  Future<void> _openDeleteAccount(BuildContext context, WidgetRef ref) async {
    final days = ref.read(deletionCoolingOffDaysProvider);
    final reason = await showAppSheet<String>(
      context,
      title: 'Delete account',
      builder: (sheetContext) => _DeleteAccountBody(
        days: days,
        onContinue: (reason) => Navigator.of(sheetContext).pop(reason),
      ),
    );
    if (reason == null || !context.mounted) return;

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Request deletion?',
      consequence:
          'Your account is frozen for $days days, during which you can sign '
          'in and reactivate it. After that everything is erased and cannot '
          'be restored. Every other signed-in device is logged out now.',
      confirmLabel: 'Request Deletion',
      iconName: PhIcon.xCircle,
    );
    if (confirmed != true || !context.mounted) return;

    final failure = await ref
        .read(accountDeletionControllerProvider.notifier)
        .request(reason: reason.trim().isEmpty ? null : reason.trim());
    if (!context.mounted) return;
    final created = ref.read(accountDeletionControllerProvider).lastRequest;
    ref
        .read(toastControllerProvider.notifier)
        .show(
          failure?.userMessage ??
              'Deletion requested${created == null ? '' : ' (${created.requestNo})'}',
        );
  }

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    DeletionRequest request,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Keep your account?',
      consequence:
          'Request ${request.requestNo} will be withdrawn and nothing will '
          'be deleted.',
      confirmLabel: 'Withdraw Request',
      isDestructive: false,
      iconName: PhIcon.checkBold,
    );
    if (confirmed != true || !context.mounted) return;
    final failure = await ref
        .read(accountDeletionControllerProvider.notifier)
        .withdraw(request.requestNo);
    if (!context.mounted) return;
    ref
        .read(toastControllerProvider.notifier)
        .show(failure?.userMessage ?? 'Deletion request withdrawn');
  }

  Future<void> _reactivate(BuildContext context, WidgetRef ref) async {
    final failure = await ref
        .read(accountDeletionControllerProvider.notifier)
        .reactivate();
    if (!context.mounted) return;
    ref
        .read(toastControllerProvider.notifier)
        .show(failure?.userMessage ?? 'Your account is active again');
  }
}

/// Avatar + name + email, with an Edit control.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.email,
    required this.onEdit,
    this.avatarFileId,
  });

  final String name;
  final String email;
  final VoidCallback onEdit;

  /// `profile.avatar_file_id`; the initials show until (and unless) it loads.
  final String? avatarFileId;

  @override
  Widget build(BuildContext context) {
    final initials = AppAvatar(name: name, size: 56);
    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipOval(
            child: SizedBox.square(
              dimension: 56.w,
              child: AppFileImage(fileId: avatarFileId, fallback: initials),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppText.poppins(
                    size: 17,
                    weight: AppText.bold,
                    color: AppColors.textStrong,
                  ),
                ),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(size: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          SizedBox(width: 14.w),
          AppIconButton(
            icon: PhIcon.pencilSimple,
            variant: AppIconButtonVariant.tint,
            size: 38,
            semanticLabel: 'Edit your profile details',
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

/// "We've updated our terms" — the re-consent prompt (§3.1 + §5.9).
class _ReconsentCard extends StatelessWidget {
  const _ReconsentCard({
    required this.pending,
    required this.isBusy,
    required this.onRead,
    required this.onAccept,
  });

  final List<PendingConsent> pending;
  final bool isBusy;
  final ValueChanged<String> onRead;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final names = [for (final p in pending) _titleFor(p.slug)];
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      color: AppColors.warningSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            pending.any((p) => p.isFirstAcceptance)
                ? 'Please accept our policies'
                : 'Our policies have changed',
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.bold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Please read and accept the current ${names.join(', ')}.',
            style: AppText.poppins(
              size: AppFontSize.xs,
              height: 1.5,
              color: AppColors.textBody,
            ),
          ),
          SizedBox(height: AppSpacing.x3.h),
          Wrap(
            spacing: AppSpacing.x2.w,
            runSpacing: AppSpacing.x2.h,
            children: [
              for (final p in pending)
                AppButton(
                  label: 'Read ${_titleFor(p.slug)}',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  onPressed: () => onRead(p.slug),
                ),
              AppButton(
                label: 'Accept',
                size: AppButtonSize.sm,
                loading: isBusy,
                onPressed: onAccept,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _titleFor(String slug) => switch (slug) {
    AppRoutes.legalTerms => 'Terms of Service',
    AppRoutes.legalPrivacy => 'Privacy Policy',
    AppRoutes.legalGuidelines => 'Community Guidelines',
    _ => slug,
  };
}

/// The account is `pending_deletion`: what happens when, and the two ways
/// back.
class _CoolingOffCard extends StatelessWidget {
  const _CoolingOffCard({
    required this.request,
    required this.isBusy,
    required this.onWithdraw,
    required this.onReactivate,
  });

  final DeletionRequest? request;
  final bool isBusy;
  final VoidCallback? onWithdraw;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final ends = request?.coolingOffEndsAt;
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      color: AppColors.dangerSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Deletion requested',
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.bold,
              color: AppColors.dangerText,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            request == null
                ? 'Your account is in its cooling-off period. Reactivate it '
                      'to keep it.'
                : ends == null
                ? 'Request ${request!.requestNo} · ${request!.status.label}. '
                      'Reactivate to keep your account.'
                : 'Request ${request!.requestNo} · your account and data are '
                      'erased on ${AppDates.dayMonthLongYear(ends.toLocal())} '
                      'unless you reactivate before then.',
            style: AppText.poppins(
              size: AppFontSize.xs,
              height: 1.5,
              color: AppColors.dangerText,
            ),
          ),
          SizedBox(height: AppSpacing.x3.h),
          Wrap(
            spacing: AppSpacing.x2.w,
            runSpacing: AppSpacing.x2.h,
            children: [
              AppButton(
                label: 'Reactivate Account',
                size: AppButtonSize.sm,
                loading: isBusy,
                onPressed: onReactivate,
              ),
              if (onWithdraw != null)
                AppButton(
                  label: 'Withdraw Request',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  disabled: isBusy,
                  onPressed: onWithdraw,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The delete-account sheet: the consequence and an optional reason.
class _DeleteAccountBody extends StatefulWidget {
  const _DeleteAccountBody({required this.days, required this.onContinue});

  /// The cooling-off period, in days.
  final int days;
  final ValueChanged<String> onContinue;

  @override
  State<_DeleteAccountBody> createState() => _DeleteAccountBodyState();
}

class _DeleteAccountBodyState extends State<_DeleteAccountBody> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(AppSpacing.x4.w),
          decoration: BoxDecoration(
            color: AppColors.dangerSoft,
            borderRadius: AppRadii.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.days} days to change your mind',
                style: AppText.poppins(
                  size: AppFontSize.base,
                  weight: AppText.bold,
                  color: AppColors.dangerText,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Your account is frozen and every other device is signed '
                'out. Sign in and reactivate within ${widget.days} days to '
                'keep it. After that, your appointment history, uploaded '
                'reports, family members, addresses and policies are '
                'permanently erased. Receipts we must keep for tax are '
                'retained without your name.',
                style: AppText.poppins(
                  size: AppFontSize.xs,
                  height: 1.55,
                  color: AppColors.dangerText,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppTextField(
          label: 'Why are you leaving? (optional)',
          controller: _reason,
          hintText: 'Anything that would help us improve',
          maxLines: 3,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppButton(
          label: 'Continue',
          variant: AppButtonVariant.danger,
          fullWidth: true,
          onPressed: () => widget.onContinue(_reason.text),
        ),
      ],
    );
  }
}
