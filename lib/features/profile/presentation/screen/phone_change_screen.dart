import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_countdown.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_phone_field.dart';
import '../../../../core/widgets/app_stepper.dart';
import '../../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../application/providers/phone_change_provider.dart';
import '../../application/states/phone_change_state.dart';
import '../components/code_entry_field.dart';

/// Change mobile number (`/profile/phone`) — the three calls of §5.3 on one
/// screen, as three steps:
///
/// 1. enter the new number → a code goes to the **current** number;
/// 2. enter that code → a code goes to the **new** number;
/// 3. enter that code → done; the account and the "self" person carry the
///    new number.
///
/// Both codes must be confirmed within 10 minutes of step 1; the countdown
/// is shown and an expiry sends the user back to step 1 with the reason.
class PhoneChangeScreen extends ConsumerStatefulWidget {
  const PhoneChangeScreen({super.key});

  @override
  ConsumerState<PhoneChangeScreen> createState() => _PhoneChangeScreenState();
}

class _PhoneChangeScreenState extends ConsumerState<PhoneChangeScreen> {
  /// When Resend unlocks for the open code, and which code that is.
  String? _resendFor;
  DateTime? _resendAt;

  final TextEditingController _phone = TextEditingController();

  /// Fixed: the new sign-in number must be an Indian mobile (§5.3,
  /// BL-AUTH-008).
  static const CountryCode _code = CountryCodes.india;
  String? _phoneError;
  bool _submitted = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String get _e164 => '${_code.dialCode}${Validators.digitsOf(_phone.text)}';

  String? _validatePhone() {
    final error = Validators.phone(_phone.text);
    if (error != null) return error;
    final current = ref.read(currentUserProvider)?.phoneE164 ?? '';
    if (Validators.digitsOf(_e164) == Validators.digitsOf(current)) {
      return 'This is already your number';
    }
    return null;
  }

  void _recheck() {
    if (!_submitted) return;
    setState(() => _phoneError = _validatePhone());
  }

  Future<void> _start() async {
    final error = _validatePhone();
    setState(() {
      _submitted = true;
      _phoneError = error;
    });
    if (error != null) return;
    final failure = await ref
        .read(phoneChangeControllerProvider.notifier)
        .start(_e164);
    if (!mounted) return;
    if (failure is ValidationFailure) {
      setState(
        () => _phoneError =
            failure.forField('new_phone_e164') ?? failure.userMessage,
      );
      return;
    }
    if (failure != null) _toast(failure.userMessage);
  }

  Future<void> _confirmOld(String code) async {
    final error = Validators.otp(code, length: _codeLength);
    if (error != null) return _toast(error);
    final failure = await ref
        .read(phoneChangeControllerProvider.notifier)
        .confirmOld(code);
    if (!mounted || failure == null) return;
    _toast(failure.userMessage);
  }

  Future<void> _verifyNew(String code) async {
    final error = Validators.otp(code, length: _codeLength);
    if (error != null) return _toast(error);
    final failure = await ref
        .read(phoneChangeControllerProvider.notifier)
        .verifyNew(code);
    if (!mounted) return;
    if (failure != null) {
      _toast(failure.userMessage);
      return;
    }
    _toast('Mobile number updated');
  }

  Future<void> _resend() async {
    final failure = await ref
        .read(phoneChangeControllerProvider.notifier)
        .resend();
    if (!mounted) return;
    _toast(failure?.userMessage ?? 'Code sent again');
  }

  int get _codeLength =>
      ref.read(phoneChangeControllerProvider).challenge?.codeLength ?? 4;

  void _toast(String text) =>
      ref.read(toastControllerProvider.notifier).show(text);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneChangeControllerProvider);
    final user = ref.watch(currentUserProvider);
    final stepIndex = switch (state.step) {
      PhoneChangeStep.enterNumber => 1,
      PhoneChangeStep.confirmOld => 2,
      PhoneChangeStep.verifyNew => 3,
      PhoneChangeStep.done => 3,
    };
    final inFlight =
        state.step == PhoneChangeStep.confirmOld ||
        state.step == PhoneChangeStep.verifyNew;

    return AppUnsavedChangesGuard(
      hasUnsavedChanges: inFlight,
      title: 'Stop changing your number?',
      consequence:
          'Your current number stays in place. The codes we sent will expire.',
      child: Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInnerHeader(
                title: 'Change Mobile Number',
                onBack: () => _leave(context),
                backSemanticLabel: 'Back to edit profile',
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
                    AppStepper(current: stepIndex, steps: 3),
                    SizedBox(height: AppSpacing.x4.h),
                    if (state.step != PhoneChangeStep.done)
                      _CurrentNumberNote(
                        current: user?.phoneE164 == null
                            ? 'Not set'
                            : PhoneFormat.display(user!.phoneE164!),
                        pending: state.newPhoneE164,
                        deadline: inFlight ? state.deadline : null,
                      ),
                    SizedBox(height: AppSpacing.x4.h),
                    AppCard(
                      padding: EdgeInsets.all(AppSpacing.x4.w),
                      child: switch (state.step) {
                        PhoneChangeStep.enterNumber => _numberStep(state),
                        PhoneChangeStep.confirmOld => _codeStep(
                          state,
                          title: 'Confirm it is you',
                          body:
                              'First, the code we sent to your current '
                              'number.',
                          onSubmit: _confirmOld,
                        ),
                        PhoneChangeStep.verifyNew => _codeStep(
                          state,
                          title: 'Verify the new number',
                          body: 'Now the code we sent to the new number.',
                          onSubmit: _verifyNew,
                        ),
                        PhoneChangeStep.done => _doneStep(user?.phoneE164),
                      },
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

  Widget _numberStep(PhoneChangeState state) {
    final failure = state.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'New mobile number',
          style: AppText.poppins(
            size: AppFontSize.body,
            weight: AppText.bold,
            color: AppColors.textStrong,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'We will send a code to your current number first, then one to '
          'the new number. Both must be entered within 10 minutes.',
          style: AppText.poppins(
            size: AppFontSize.xs,
            height: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        if (failure != null && failure is! ValidationFailure) ...[
          SizedBox(height: AppSpacing.x3.h),
          Container(
            padding: EdgeInsets.all(AppSpacing.x3.w),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: AppRadii.md,
            ),
            child: Text(
              failure.userMessage,
              style: AppText.poppins(
                size: AppFontSize.xs,
                height: 1.45,
                color: AppColors.dangerText,
              ),
            ),
          ),
        ],
        SizedBox(height: AppSpacing.x4.h),
        AppPhoneField(
          label: 'New mobile number',
          controller: _phone,
          countryCode: _code,
          errorText: _phoneError,
          textInputAction: TextInputAction.done,
          enabled: !state.isBusy,
          // No country choice: the new sign-in number must be an Indian
          // mobile (§5.3, BL-AUTH-008).
          onChanged: (_) => _recheck(),
          onSubmitted: (_) => _start(),
        ),
        SizedBox(height: AppSpacing.x5.h),
        AppButton(
          label: 'Send Codes',
          fullWidth: true,
          loading: state.isBusy,
          onPressed: _start,
        ),
      ],
    );
  }

  Widget _codeStep(
    PhoneChangeState state, {
    required String title,
    required String body,
    required ValueChanged<String> onSubmit,
  }) {
    final challenge = state.challenge;
    final failure = state.failure;
    // Fixed once per code sent: worked out on every build, a wrong code's
    // rebuild restarted the countdown and cleared the box (BL-PROF-017).
    if (challenge != null && challenge.challengeId != _resendFor) {
      _resendFor = challenge.challengeId;
      _resendAt = DateTime.now().add(
        Duration(seconds: challenge.resendAfterSeconds),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: AppText.poppins(
            size: AppFontSize.body,
            weight: AppText.bold,
            color: AppColors.textStrong,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          body,
          style: AppText.poppins(
            size: AppFontSize.xs,
            height: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(height: AppSpacing.x4.h),
        CodeEntryField(
          key: ValueKey(challenge?.challengeId),
          codeLength: challenge?.codeLength ?? 4,
          destinationMasked: challenge?.destinationMasked,
          resendAfter: challenge == null ? null : _resendAt,
          errorText: failure is UnauthorizedFailure && !failure.sessionExpired
              ? failure.userMessage
              : null,
          attemptsRemaining: state.attemptsRemaining,
          isBusy: state.isBusy,
          submitLabel: state.step == PhoneChangeStep.verifyNew
              ? 'Verify & Update Number'
              : 'Continue',
          onSubmit: onSubmit,
          onResend: _resend,
        ),
        SizedBox(height: AppSpacing.x2.h),
        AppButton(
          label: 'Start again',
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.sm,
          disabled: state.isBusy,
          onPressed: ref.read(phoneChangeControllerProvider.notifier).reset,
        ),
      ],
    );
  }

  Widget _doneStep(String? phone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppIcon(PhIcon.checkBold, size: 22, color: AppColors.brand),
            SizedBox(width: AppSpacing.x2.w),
            Expanded(
              child: Text(
                'Number updated',
                style: AppText.poppins(
                  size: AppFontSize.body,
                  weight: AppText.bold,
                  color: AppColors.textStrong,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.x2.h),
        Text(
          '${phone ?? 'Your new number'} is now used to sign in and for '
          'appointment reminders.',
          style: AppText.poppins(
            size: AppFontSize.sm,
            height: 1.5,
            color: AppColors.textBody,
          ),
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppButton(
          label: 'Done',
          fullWidth: true,
          onPressed: () => _leave(context),
        ),
      ],
    );
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      Navigator.maybePop(context);
      return;
    }
    context.go(AppRoutes.profileEdit);
  }
}

/// What the number is now, what it will become, and how long is left.
class _CurrentNumberNote extends StatelessWidget {
  const _CurrentNumberNote({
    required this.current,
    required this.pending,
    required this.deadline,
  });

  final String current;
  final String? pending;
  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.x3.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.md,
        border: Border.all(color: AppColors.border, width: 1.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current number: $current',
            style: AppText.inter(
              size: AppFontSize.sm,
              weight: AppText.medium,
              color: AppColors.textPrimary,
            ),
          ),
          if (pending != null) ...[
            SizedBox(height: 2.h),
            Text(
              'Changing to: $pending — not applied until both codes are '
              'confirmed.',
              style: AppText.poppins(
                size: AppFontSize.xs,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ],
          if (deadline != null) ...[
            SizedBox(height: AppSpacing.x2.h),
            AppCountdownPill(deadline: deadline!, prefix: 'Time left'),
          ],
        ],
      ),
    );
  }
}
