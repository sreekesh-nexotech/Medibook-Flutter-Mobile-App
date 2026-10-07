import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/route_arrival.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../booking/presentation/components/flow_screen_enter.dart';
import '../../../common/cached/presentation/components/cached_status_bar.dart';
import '../../../profile/application/providers/profile_provider.dart';
import '../../../support/application/providers/support_provider.dart';
import '../../../support/domain/entities/ambulance_provider.dart';

/// Call an ambulance (CM-44, CM-45, CM-46). Route: `/ambulance`.
///
/// Reachable from Home's prominent emergency row and from an appointment's
/// detail (the appointments feature owns that entry point). The operator
/// directory is `GET /patient/ambulance/providers` (§14) through the support
/// feature's cached controller — unfiltered, because the account carries no
/// home city; the emergency contact is the profile feature's primary one.
///
/// **"Call now" opens the phone's dialler** with the operator's number
/// (`tel:` through `url_launcher`); the patient places the call. This is a
/// directory to call from — there is no ambulance request endpoint (§18), so
/// nothing here claims a dispatch. Each row also shows the number in full,
/// large enough to read out, and a device with no dialler is told to dial it
/// by hand rather than left with a button that does nothing.
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
    final directory = ref.watch(
      ambulanceProvidersProvider(AmbulanceFilter.none),
    );
    final providers = directory.value ?? const <AmbulanceProvider>[];
    final emergencyContact = ref.watch(primaryEmergencyContactProvider);

    return RouteArrival(
      onArrive: () {
        ref.invalidate(ambulanceProvidersProvider);
        ref.invalidate(primaryEmergencyContactProvider);
      },
      child: Scaffold(
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
                        CachedStatusBar(
                          state: directory,
                          onRefresh: () => ref
                              .read(
                                ambulanceProvidersProvider(
                                  AmbulanceFilter.none,
                                ).notifier,
                              )
                              .refresh(force: true),
                        ),
                        if (directory.isLoading)
                          const AppLoadingView(label: 'Loading operators…')
                        else if (providers.isEmpty)
                          AppEmptyView(
                            iconName: PhIcon.firstAid,
                            headline: 'No operators listed',
                            body:
                                'We could not load the ambulance directory. '
                                'The national emergency number is 108.',
                            // A failed load can be tried again here, not
                            // only from the bar above (BL-SUP-020).
                            actionLabel: directory.failure != null
                                ? 'Try again'
                                : 'Contact support',
                            onAction: directory.failure != null
                                ? () => ref
                                      .read(
                                        ambulanceProvidersProvider(
                                          AmbulanceFilter.none,
                                        ).notifier,
                                      )
                                      .refresh(force: true)
                                : () => context.push(AppRoutes.support),
                            secondaryLabel: directory.failure != null
                                ? 'Contact support'
                                : null,
                            onSecondary: directory.failure != null
                                ? () => context.push(AppRoutes.support)
                                : null,
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
                          phone: emergencyContact?.phoneE164,
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
          AppIcon(PhIcon.bell, size: 20, color: AppColors.dangerText),
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
                  '"Call now" opens your dialler with the number filled '
                  'in — you place the call. 108 is the national emergency '
                  'line and is free.',
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

/// One operator: name, ETA, locality and the number itself.
class _AmbulanceRow extends ConsumerWidget {
  const _AmbulanceRow({required this.provider});

  final AmbulanceProvider provider;

  /// Hands the number to the dialler. Nothing is dialled by the app itself.
  Future<void> _dial(BuildContext context, WidgetRef ref) async {
    var opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'tel', path: provider.phoneE164));
    } on PlatformException {
      opened = false;
    }
    if (opened || !context.mounted) return;
    ref
        .read(toastControllerProvider.notifier)
        .show('No dialler on this device. Dial ${provider.phoneE164}.');
  }

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
                      [
                        if (provider.etaLabel != null) provider.etaLabel!,
                        if (provider.localityLabel.isNotEmpty)
                          provider.localityLabel,
                      ].join(' · '),
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
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
                    PhIcon.bell,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(width: AppSpacing.x2.w),
                Expanded(
                  child: Text(
                    provider.phoneE164,
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
            semanticLabel: 'Call ${provider.name} on ${provider.phoneE164}',
            onPressed: () => _dial(context, ref),
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
        iconName: PhIcon.folder,
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
