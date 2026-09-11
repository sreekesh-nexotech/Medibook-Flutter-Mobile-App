import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/mock_data/stores/dependants_store.dart';
import '../../../../core/mock_data/stores/insurance_store.dart';
import '../../../../core/mock_data/stores/profile_store.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_stub_notice.dart';
import '../../../../core/widgets/app_switch.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../components/profile_info_card.dart';
import '../components/profile_menu_card.dart';
import '../controllers/donation_controller.dart';
import '../controllers/profile_edit_controller.dart';

/// Profile tab (`/profile`). Lives in the bottom-nav shell (no nav bar here).
///
/// ## What changed here, and why
///
/// The audit found this screen was a dead end. Both edit controls showed
/// "Profile editing is stubbed in this demo" (CM-47); emergency contacts,
/// addresses, family-member management and the insurance locker did not exist
/// anywhere (CM-49, CM-50, CM-48, CM-37); no help, FAQ, support or legal
/// screen was reachable from anywhere in the app (CM-52); there was no way to
/// change a password (CM-51); and logout only navigated, leaving the session
/// intact behind the sign-in screen (CM-53).
///
/// So this screen is now the app's account hub: it reads the **live** identity
/// (`profileIdentityProvider`, not the fixed seed, so a saved edit is visible
/// here immediately) and links every one of those screens.
///
/// Logout really signs out — `authProvider.logout()` clears all session state
/// — and is confirmed first with what is lost named. Account deletion cannot
/// be performed by this build, so it says so rather than confirming a deletion
/// that will not happen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(profileIdentityProvider);
    final available = ref.watch(donationProvider);
    final dependants = ref.watch(dependantsOnlyProvider);
    final policies = ref.watch(insuranceStoreProvider);
    final activePolicies = ref.watch(activeInsurancePoliciesProvider);
    final contacts = ref.watch(emergencyContactsStoreProvider);
    final addresses = ref.watch(addressesStoreProvider);
    final documents = ref.watch(legalDocumentsProvider);

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
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 24.h),
                  children: [
                    _IdentityCard(
                      name: identity.name,
                      email: identity.email,
                      onEdit: () => context.push(AppRoutes.profileEdit),
                    ),
                    SizedBox(height: 16.h),
                    ProfileInfoCard(
                      rows: identity.infoRows,
                      onEdit: () => context.push(AppRoutes.profileEdit),
                    ),
                    SizedBox(height: 16.h),

                    ProfileMenuCard(
                      title: 'Your people and cover',
                      rows: [
                        ProfileMenuRow(
                          iconName: MedIcon.records,
                          label: 'Family members',
                          subtitle: dependants.isEmpty
                              ? 'Add the people you book for'
                              : 'Book for them and keep their records',
                          trailingText: dependants.isEmpty
                              ? 'None'
                              : '${dependants.length}',
                          semanticLabel:
                              'Family members, ${dependants.length} saved',
                          onTap: () => context.push(AppRoutes.dependants),
                        ),
                        ProfileMenuRow(
                          iconName: MedIcon.hospital,
                          label: 'Insurance',
                          subtitle: policies.isEmpty
                              ? 'No policy saved yet'
                              : '${activePolicies.length} of '
                                    '${policies.length} in force',
                          trailingText: policies.isEmpty
                              ? 'None'
                              : '${policies.length}',
                          semanticLabel: 'Insurance policies',
                          onTap: () => context.push(AppRoutes.insurance),
                        ),
                        ProfileMenuRow(
                          iconName: MedIcon.bell,
                          label: 'Emergency contacts',
                          subtitle: contacts.isEmpty
                              ? 'No one to call yet'
                              : 'Who the hospital calls first',
                          trailingText: contacts.isEmpty
                              ? 'None'
                              : '${contacts.length}',
                          onTap: () => context.push(AppRoutes.profileEmergency),
                        ),
                        ProfileMenuRow(
                          iconName: MedIcon.location,
                          label: 'Saved addresses',
                          subtitle: addresses.isEmpty
                              ? 'None saved for home visits yet'
                              : 'Used for home visits and invoices',
                          trailingText: addresses.isEmpty
                              ? 'None'
                              : '${addresses.length}',
                          onTap: () => context.push(AppRoutes.profileAddress),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    _DonationCard(
                      available: available,
                      onChanged: (next) {
                        ref.read(donationProvider.notifier).state = next;
                        ref
                            .read(toastControllerProvider.notifier)
                            .show(
                              next
                                  ? 'You are now available for donation'
                                  : 'Donation availability turned off',
                            );
                      },
                    ),
                    SizedBox(height: 16.h),

                    ProfileMenuCard(
                      title: 'Help',
                      rows: [
                        ProfileMenuRow(
                          iconName: MedIcon.hospital,
                          label: 'Help & Support',
                          subtitle: 'Contact us or raise a request',
                          onTap: () => context.push(AppRoutes.support),
                        ),
                        ProfileMenuRow(
                          iconName: MedIcon.search,
                          label: 'FAQs',
                          subtitle: 'Booking, payments, records and account',
                          semanticLabel: 'Frequently asked questions',
                          onTap: () => context.push(AppRoutes.faq),
                        ),
                        // Straight from `legalDocumentsProvider`, so these
                        // slugs cannot drift from AppRoutes.legalSlugs or from
                        // the sign-up consent links (CM-02).
                        for (final document in documents)
                          ProfileMenuRow(
                            iconName: MedIcon.records,
                            label: document.title,
                            subtitle: 'Version ${document.version}',
                            semanticLabel: 'Read the ${document.title}',
                            onTap: () => context.push(
                              AppRoutes.legalPath(document.slug),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    ProfileMenuCard(
                      title: 'Account',
                      rows: [
                        ProfileMenuRow(
                          iconName: MedIcon.eye,
                          label: 'Change password',
                          subtitle: 'You will need your current password',
                          onTap: () => context.push(AppRoutes.changePassword),
                        ),
                        ProfileMenuRow(
                          iconName: MedIcon.logout,
                          label: 'Logout',
                          subtitle: 'Sign out on this device',
                          isDestructive: true,
                          onTap: () => _confirmLogout(context, ref),
                        ),
                        ProfileMenuRow(
                          iconName: MedIcon.closeCircle,
                          label: 'Delete account',
                          subtitle: 'Permanently erase your data',
                          isDestructive: true,
                          onTap: () => _openDeleteAccount(context, ref),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// CM-53. Confirms with what is lost named, then really signs out:
  /// `logout()` clears the session, the tokens and the cached user, so the
  /// next screen is the sign-in screen with nothing behind it.
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

    await ref.read(authProvider.notifier).logout();
    if (!context.mounted) return;
    // The router's guard sends an unauthenticated session to sign-in on its
    // own; going there explicitly means the tab shell is left immediately
    // rather than after the next redirect.
    context.go(AppRoutes.login);
  }

  /// CM-53's other half. There is no delete-account call in this build, so the
  /// sheet states the consequence, offers the channel that *can* action it,
  /// and marks the button stubbed rather than confirming a deletion that will
  /// not happen.
  void _openDeleteAccount(BuildContext context, WidgetRef ref) {
    showAppSheet<void>(
      context,
      title: 'Delete account',
      builder: (sheetContext) => _DeleteAccountBody(
        onRequestByEmail: () {
          Navigator.of(sheetContext).pop();
          context.push(AppRoutes.support);
        },
        onDelete: () => showStubbedToast(sheetContext, ref, 'Account deletion'),
      ),
    );
  }
}

/// Avatar + name + email, with an Edit control that now opens the real form.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.email,
    required this.onEdit,
  });

  final String name;
  final String email;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppAvatar(name: name, size: 56),
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
            icon: MedIcon.edit,
            variant: AppIconButtonVariant.tint,
            size: 38,
            // Audit §3.3.1 names this pencil specifically: an icon-only
            // control has to say what it edits.
            semanticLabel: 'Edit your profile details',
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

/// "Available for Donation" card with helper copy and the toggle switch.
class _DonationCard extends StatelessWidget {
  const _DonationCard({required this.available, required this.onChanged});

  final bool available;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available for Donation',
                  style: AppText.poppins(
                    size: 15,
                    weight: AppText.semibold,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Hospitals can contact you for rare blood needs.',
                  style: AppText.poppins(size: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Semantics(
            label: 'Make yourself available for blood donation',
            child: AppSwitch(value: available, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

/// The delete-account sheet: the consequence, the route that can actually do
/// it, and an honestly stubbed button.
class _DeleteAccountBody extends StatelessWidget {
  const _DeleteAccountBody({
    required this.onRequestByEmail,
    required this.onDelete,
  });

  final VoidCallback onRequestByEmail;
  final VoidCallback onDelete;

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
                'This cannot be undone',
                style: AppText.poppins(
                  size: AppFontSize.base,
                  weight: AppText.bold,
                  color: AppColors.dangerText,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Deleting your account permanently erases your appointment '
                'history, every uploaded report and prescription, your saved '
                'family members, addresses and insurance policies. Receipts '
                'we are required to keep for tax are retained without your '
                'name. Nothing can be restored afterwards.',
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
        AppStubBanner(
          title: 'Not wired up in this build',
          body:
              'This app cannot delete an account yet, so the button below does '
              'nothing but say so. Our support team can action the deletion '
              'for you in the meantime.',
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppButton(
          label: 'Contact Support to Delete',
          fullWidth: true,
          onPressed: onRequestByEmail,
        ),
        SizedBox(height: AppSpacing.x3.h),
        AppButton(
          label: 'Delete Account',
          variant: AppButtonVariant.danger,
          fullWidth: true,
          stubbed: true,
          onPressed: onDelete,
        ),
      ],
    );
  }
}
