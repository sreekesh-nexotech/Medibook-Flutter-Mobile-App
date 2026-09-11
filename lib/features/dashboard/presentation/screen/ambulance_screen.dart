import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/support_content.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/mock_data/stores/profile_store.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_stub_notice.dart';
import '../../../../core/widgets/app_tag.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../booking/presentation/components/flow_screen_enter.dart';

/// Call an ambulance (CM-44, CM-45, CM-46). Route: `/ambulance`.
///
/// The audit listed this as a whole missing screen: the app had no emergency
/// path at all. It is reachable from Home's prominent emergency row and from
/// an appointment's detail (the appointments feature owns that entry point).
///
/// **The call itself is stubbed, deliberately.** There is no `url_launcher` in
/// this build and none may be added, so no control here can place a call.
/// Rather than a button that appears to dial and does nothing — or worse, one
/// that reports a dispatched ambulance — each row shows the number in full,
/// large enough to read out or type into the dialler, and the action declares
/// itself with `AppButton(stubbed: true)` + [showStubbedToast] (THE LAW).
///
/// Router wiring:
/// ```dart
/// GoRoute(
///   path: AppRoutes.ambulance,
///   builder: (_, __) => const AmbulanceScreen(),
/// )
/// ```
class AmbulanceScreen extends ConsumerWidget {
  const AmbulanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(ambulanceProvidersProvider);
    final emergencyContact = ref.watch(primaryEmergencyContactProvider);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: FlowScreenEnter(
          child: Column(
            children: [
              AppInnerHeader(
                title: 'Emergency',
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.home),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 28.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _DiallerNotice(),
                      SizedBox(height: AppSpacing.x4.h),
                      Text(
                        'Ambulance services',
                        style: AppText.poppins(
                          size: AppFontSize.body,
                          weight: AppText.semibold,
                          color: AppColors.textStrong,
                        ),
                      ),
                      SizedBox(height: AppSpacing.x3.h),
                      if (providers.isEmpty)
                        AppEmptyView(
                          iconName: MedIcon.hospital,
                          headline: 'No operators listed',
                          body:
                              'We could not load the ambulance directory. '
                              'The national emergency number is 108.',
                          actionLabel: 'Contact support',
                          onAction: () => context.push(AppRoutes.support),
                        )
                      else
                        for (final provider in providers) ...[
                          _AmbulanceRow(provider: provider),
                          SizedBox(height: AppSpacing.x3.h),
                        ],
                      SizedBox(height: AppSpacing.x3.h),
                      _EmergencyContactCard(
                        name: emergencyContact?.name,
                        relation: emergencyContact?.relation,
                        phone: emergencyContact?.phone,
                        onManage: () =>
                            context.push(AppRoutes.profileEmergency),
                      ),
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
}

/// Says plainly that the app cannot dial, before the patient taps anything.
class _DiallerNotice extends StatelessWidget {
  const _DiallerNotice();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(16.w),
      color: AppColors.dangerSoft,
      shadow: AppShadowToken.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(MedIcon.bell, size: 20, color: AppColors.dangerText),
          SizedBox(width: AppSpacing.x3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'In a real emergency, dial from your phone',
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: AppText.semibold,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'This build cannot place calls, so the numbers below are '
                  'shown in full for you to dial. 108 is the national '
                  'emergency line and is free.',
                  style: AppText.poppins(
                    size: AppFontSize.sm,
                    color: AppColors.textPrimary,
                    height: 1.5,
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

/// One operator: name, ETA, area, capability tags and the number itself.
class _AmbulanceRow extends ConsumerWidget {
  const _AmbulanceRow({required this.provider});

  final AmbulanceProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.name,
                      style: AppText.poppins(
                        size: AppFontSize.base,
                        weight: AppText.semibold,
                        color: AppColors.textStrong,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${provider.etaLabel} · ${provider.area}',
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (provider.tags.isNotEmpty)
                Wrap(
                  spacing: AppSpacing.x1.w,
                  children: [
                    for (final tag in provider.tags) AppTag(label: tag),
                  ],
                ),
            ],
          ),
          SizedBox(height: AppSpacing.x3.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 14.w,
              vertical: AppSpacing.x3.h,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md.r),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: AppIcon(
                    MedIcon.bell,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(width: AppSpacing.x2.w),
                Expanded(
                  child: Text(
                    provider.phone,
                    style: AppText.poppins(
                      size: AppFontSize.body,
                      weight: AppText.bold,
                      color: AppColors.textStrong,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.x3.h),
          AppButton(
            label: 'Call now',
            variant: AppButtonVariant.danger,
            fullWidth: true,
            leadingIcon: MedIcon.bell,
            stubbed: true,
            semanticLabel:
                'Call ${provider.name} on ${provider.phone} — dialling is '
                'not available in this build',
            onPressed: () =>
                showStubbedToast(context, ref, 'Calling ${provider.name}'),
          ),
        ],
      ),
    );
  }
}

/// The patient's own emergency contact, so the number they most need is not
/// buried in Profile when it matters (CM-46).
class _EmergencyContactCard extends StatelessWidget {
  const _EmergencyContactCard({
    required this.name,
    required this.relation,
    required this.phone,
    required this.onManage,
  });

  final String? name;
  final String? relation;
  final String? phone;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final name = this.name;
    if (name == null) {
      return AppEmptyView(
        iconName: MedIcon.records,
        headline: 'No emergency contact saved',
        body:
            'Add one so the hospital knows who to call if you cannot speak '
            'for yourself.',
        actionLabel: 'Add an emergency contact',
        onAction: onManage,
        padding: EdgeInsets.symmetric(vertical: AppSpacing.x4.h),
      );
    }

    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your emergency contact',
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            relation == null ? name : '$name · $relation',
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          if (phone != null) ...[
            SizedBox(height: 2.h),
            Text(
              phone!,
              style: AppText.poppins(
                size: AppFontSize.base,
                color: AppColors.textBody,
              ),
            ),
          ],
          SizedBox(height: AppSpacing.x3.h),
          AppButton(
            label: 'Manage contacts',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            onPressed: onManage,
          ),
        ],
      ),
    );
  }
}
