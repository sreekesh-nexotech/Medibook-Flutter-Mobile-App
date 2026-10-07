import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../globals.dart';
import '../../../support/application/providers/app_config_provider.dart';
import '../../application/providers/app_update_provider.dart';
import '../../application/states/app_update_state.dart';

/// Runs the in-app update check and shows its two prompts. Wrap the app body
/// once, above the router (see `app/app.dart`).
///
/// * Checks at launch — once the app config has answered, because its
///   minimum version decides which flow runs — and on every return to the
///   foreground.
/// * A downloaded flexible update asks for a restart with the shared confirm
///   dialog.
/// * A mandatory update the user backed out of covers the whole app with
///   [_UpdateRequiredScreen] until they update.
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The first answer (cached, network, or a failure) ends `isLoading`; a
    // later change to the minimum version re-checks.
    ref.listenManual<(bool, String?)>(
      appConfigProvider.select(
        (s) => (s.isLoading, s.value?.minVersionAndroid),
      ),
      (_, next) {
        if (!next.$1) _check();
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  void _check() => ref.read(appUpdateProvider.notifier).check();

  Future<void> _promptRestart() async {
    // This widget sits above the router, so the dialog needs the root
    // navigator's context rather than its own.
    final navigatorContext = Globals.currentContext;
    if (navigatorContext == null) return;
    final restart = await showAppConfirmDialog(
      navigatorContext,
      title: 'Update ready',
      consequence:
          'The latest version of Medibook has been downloaded. Restart now '
          'to finish installing — it only takes a moment.',
      confirmLabel: 'Restart',
      cancelLabel: 'Later',
      isDestructive: false,
      iconName: 'download',
    );
    if (!mounted) return;
    final controller = ref.read(appUpdateProvider.notifier);
    if (restart == true) {
      controller.install();
    } else {
      controller.deferInstall();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppUpdatePhase>(appUpdateProvider.select((s) => s.phase), (
      previous,
      next,
    ) {
      if (next == AppUpdatePhase.readyToInstall) _promptRestart();
    });

    final blocked = ref.watch(
      appUpdateProvider.select((s) => s.phase == AppUpdatePhase.required),
    );
    return Stack(
      children: [
        // The covered app must not stay reachable to a screen reader.
        ExcludeSemantics(excluding: blocked, child: widget.child),
        if (blocked) const Positioned.fill(child: _UpdateRequiredScreen()),
      ],
    );
  }
}

/// The blocking screen for a version below the supported minimum.
class _UpdateRequiredScreen extends ConsumerWidget {
  const _UpdateRequiredScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBusy = ref.watch(appUpdateProvider.select((s) => s.isBusy));
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceTint,
                  shape: BoxShape.circle,
                ),
                child: const AppIcon(
                  'download',
                  size: 26,
                  color: AppColors.brand,
                ),
              ),
              SizedBox(height: 20.h),
              Semantics(
                header: true,
                child: Text(
                  'Update required',
                  textAlign: TextAlign.center,
                  style: AppText.poppins(
                    size: AppFontSize.h2,
                    weight: AppText.bold,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'This version of Medibook is no longer supported. Update to '
                'keep booking and managing your appointments.',
                textAlign: TextAlign.center,
                style: AppText.poppins(
                  size: AppFontSize.base,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
              SizedBox(height: 28.h),
              AppButton(
                label: 'Update now',
                fullWidth: true,
                loading: isBusy,
                onPressed: () =>
                    ref.read(appUpdateProvider.notifier).retryRequired(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
