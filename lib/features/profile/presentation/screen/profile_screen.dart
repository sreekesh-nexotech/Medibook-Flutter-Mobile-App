import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/medibook_seed.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_switch.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/profile_info_card.dart';
import '../controllers/donation_controller.dart';

/// Profile tab (`/profile`). Lives in the bottom-nav shell (no nav bar here).
///
/// Reads the current user's identity + personal-info rows, a local donation
/// toggle, and drives the logout / delete confirmation sheets. Every action here
/// is either a stub toast or a navigation; nothing hits a backend.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(profileInfoProvider);
    final available = ref.watch(donationProvider);

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
              const AppTabHeader(title: 'Profile'),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 24.h),
                  children: [
                    _IdentityCard(
                      onEdit: () => _showEditStub(ref),
                    ),
                    SizedBox(height: 16.h),
                    ProfileInfoCard(
                      rows: info,
                      onEdit: () => _showEditStub(ref),
                    ),
                    SizedBox(height: 16.h),
                    _DonationCard(
                      available: available,
                      onChanged: (next) {
                        ref.read(donationProvider.notifier).state = next;
                        ref.read(toastControllerProvider.notifier).show(
                              next
                                  ? 'You are now available for donation'
                                  : 'Donation availability turned off',
                            );
                      },
                    ),
                    SizedBox(height: 16.h),
                    _AccountActionsCard(
                      onLogout: () => _confirmLogout(context),
                      onDelete: () => _confirmDelete(context, ref),
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

  void _showEditStub(WidgetRef ref) {
    ref
        .read(toastControllerProvider.notifier)
        .show('Profile editing is stubbed in this demo');
  }

  void _confirmLogout(BuildContext context) {
    showMedibookSheet(
      context,
      title: 'Logout',
      message: 'Are you sure you want to log out?',
      confirmLabel: 'Yes, Logout',
      confirmVariant: AppButtonVariant.primary,
      onConfirm: () => context.go(AppRoutes.login),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showMedibookSheet(
      context,
      title: 'Delete Account',
      message: 'This will permanently remove your records and appointments.',
      confirmLabel: 'Yes, Delete',
      confirmVariant: AppButtonVariant.danger,
      // Stub: stay on Profile, just confirm with a toast.
      onConfirm: () => ref
          .read(toastControllerProvider.notifier)
          .show('Account deletion is stubbed in this demo'),
    );
  }
}

/// Avatar + name + email, with an Edit icon button.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AppAvatar(name: MedibookSeed.userName, size: 56),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  MedibookSeed.userName,
                  style: AppText.poppins(
                    size: 17,
                    weight: AppText.bold,
                    color: AppColors.textStrong,
                  ),
                ),
                Text(
                  MedibookSeed.userEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 14.w),
          AppIconButton(
            icon: MedIcon.edit,
            variant: AppIconButtonVariant.tint,
            size: 38,
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
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 220.w),
                  child: Text(
                    'Hospitals can contact you for rare blood needs.',
                    style: AppText.poppins(
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          AppSwitch(value: available, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Logout + Delete account rows sharing one thin card.
class _AccountActionsCard extends StatelessWidget {
  const _AccountActionsCard({required this.onLogout, required this.onDelete});

  final VoidCallback onLogout;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(6.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ActionRow(
            icon: MedIcon.logout,
            label: 'Logout',
            color: AppColors.textPrimary,
            onTap: onLogout,
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 14.w),
            height: 1.h,
            color: AppColors.borderSubtle,
          ),
          _ActionRow(
            icon: MedIcon.closeCircle,
            label: 'Delete account',
            color: AppColors.danger,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

/// A tappable icon + label row inside the account-actions card.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppIcon(icon, size: 20, color: color),
            SizedBox(width: 12.w),
            Text(
              label,
              style: AppText.poppins(
                size: 15,
                weight: AppText.medium,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
