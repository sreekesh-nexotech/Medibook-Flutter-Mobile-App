import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/patient.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_date_picker_sheet.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_phone_field.dart';
import '../../../../core/widgets/app_stub_notice.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/profile_option_sheet.dart';
import '../components/profile_picker_field.dart';
import '../controllers/profile_edit_controller.dart';

/// Edit profile (`/profile/edit`) — CM-47.
///
/// Replaces the "Profile editing is stubbed in this demo" toast the audit
/// found on both of Profile's edit controls. Every field here is real: a save
/// writes the signed-in `User` **and** the account holder's `Patient` record,
/// so the change is visible on Profile, in the home greeting and in the
/// booking patient picker straight away.
///
/// ## The mobile number, and the one thing this screen cannot finish
///
/// A mobile number is a sign-in credential (CM-04 signs in with it), so
/// changing it must be confirmed by an SMS code to the **new** number. This
/// screen therefore never writes the number: "Change number" validates the
/// new one and stages it, and the staged number is shown as *unverified*,
/// with the old number still labelled as the one in force.
///
/// The verify screen that would finish the job is parameterised by
/// `VerifyPurpose`, and that enum has no `phoneChange` case — its success
/// `switch` is exhaustive, so the auth feature left the case out rather than
/// ship a branch that goes nowhere. Auth is not this feature's to edit, so
/// until the case exists the "Verify number" control declares itself stubbed
/// rather than claiming a number changed when it has not. What is needed:
///
/// ```dart
/// enum VerifyPurpose {
///   …,
///   /// CM-47 — confirming a NEW mobile number before it replaces the old one.
///   phoneChange('phone-change'),
/// }
/// ```
///
/// with `title` "Verify New Number", `confirmLabel` "Verify & Update Number",
/// `backPath` [AppRoutes.profileEdit], `signsIn` **false** (the session is
/// already signed in and must not be re-minted), and, on a correct code, the
/// success branch calling `authProvider.updateUser(user.copyWith(phone:
/// destination, phoneVerified: true))` and returning to
/// [AppRoutes.profileEdit]. This screen then swaps the stubbed button for
/// `context.push(VerifyRequest(purpose: VerifyPurpose.phoneChange, channel:
/// ResetChannel.sms, destination: pending).path)` — a one-line change.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;

  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();

  ProfileEditController get _controller =>
      ref.read(profileEditControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    final initial = ref.read(profileEditControllerProvider);
    _firstName = TextEditingController(text: initial.firstName);
    _lastName = TextEditingController(text: initial.lastName);
    _email = TextEditingController(text: initial.email);

    // A field's error appears when the user leaves it, not while they are
    // still typing the first character of a name (audit §3.5.4).
    _revealOnBlur(_firstNameFocus, ProfileEditField.firstName);
    _revealOnBlur(_lastNameFocus, ProfileEditField.lastName);
    _revealOnBlur(_emailFocus, ProfileEditField.email);
  }

  void _revealOnBlur(FocusNode node, String field) {
    node.addListener(() {
      if (!node.hasFocus) _controller.markTouched(field);
    });
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth(DateTime? current) async {
    final now = DateTime.now();
    final picked = await showAppDatePickerSheet(
      context,
      title: 'Date of birth',
      initialDay: current ?? DateTime(now.year - 30, now.month, now.day),
      // A date of birth cannot be in the future, so the calendar cannot offer
      // one; 120 years is the plausibility limit `Validators.dateOfBirth` uses.
      firstDay: DateTime(now.year - 120, 1, 1),
      lastDay: now,
    );
    if (picked != null) _controller.setDateOfBirth(picked);
  }

  Future<void> _pickGender(String? current) async {
    final picked = await showProfileOptionSheet<String>(
      context,
      title: 'Gender',
      selected: current,
      options: [
        for (final gender in PatientGenders.all)
          ProfileOption<String>(value: gender, label: gender),
      ],
    );
    if (picked != null) _controller.setGender(picked);
  }

  Future<void> _pickBloodGroup(String? current) async {
    final picked = await showProfileOptionSheet<String>(
      context,
      title: 'Blood group',
      selected: current,
      options: [
        for (final group in Validators.bloodGroups)
          ProfileOption<String>(value: group, label: group),
      ],
    );
    if (picked != null) _controller.setBloodGroup(picked);
  }

  Future<void> _changePhone(String currentPhone) async {
    final entered = await showPhoneChangeSheet(
      context,
      currentPhone: currentPhone,
    );
    if (entered == null) return;
    _controller.stagePhoneChange(entered);
  }

  void _save() {
    if (!_controller.validate()) {
      ref
          .read(toastControllerProvider.notifier)
          .show('Fix the highlighted fields first');
      return;
    }

    _controller.setSaving(true);
    final form = ref.read(profileEditControllerProvider);
    final accountUpdated = saveProfileEdit(ref, form);
    // isSaving stays true through the pop: the values are committed, so the
    // unsaved-changes guard must not challenge leaving.

    final toast = ref.read(toastControllerProvider.notifier);
    if (accountUpdated) {
      toast.show('Profile updated');
    } else {
      // No session to write the account record onto. The patient record did
      // change, so say exactly that rather than "Profile updated".
      toast.show('Saved to your patient record; sign in to change your email');
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(profileEditControllerProvider);
    final errors = form.errors;

    return AppUnsavedChangesGuard(
      hasUnsavedChanges: form.isDirty && !form.isSaving,
      title: 'Discard your changes?',
      consequence:
          'The details you have edited will not be saved to your account.',
      child: Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInnerHeader(
                title: 'Edit Profile',
                onBack: () => _leave(context),
                backSemanticLabel: 'Back to profile',
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
                    AppCard(
                      padding: EdgeInsets.all(AppSpacing.x4.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SectionTitle('Your name'),
                          SizedBox(height: AppSpacing.x3.h),
                          AppTextField(
                            label: 'First name',
                            controller: _firstName,
                            focusNode: _firstNameFocus,
                            hintText: 'Alexandra',
                            maxLength: 40,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.givenName],
                            errorText: errors.visible(
                              ProfileEditField.firstName,
                            ),
                            onChanged: _controller.setFirstName,
                            onSubmitted: (_) => _lastNameFocus.requestFocus(),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          AppTextField(
                            label: 'Last name',
                            controller: _lastName,
                            focusNode: _lastNameFocus,
                            hintText: 'Johnson',
                            maxLength: 40,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.familyName],
                            helperText: 'Optional',
                            errorText: errors.visible(
                              ProfileEditField.lastName,
                            ),
                            onChanged: _controller.setLastName,
                            onSubmitted: (_) => _emailFocus.requestFocus(),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.x4.h),

                    AppCard(
                      padding: EdgeInsets.all(AppSpacing.x4.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SectionTitle('Medical details'),
                          SizedBox(height: AppSpacing.x3.h),
                          ProfilePickerField(
                            label: 'Date of birth',
                            iconName: MedIcon.calendar,
                            value: form.dateOfBirth == null
                                ? null
                                : AppDates.dayMonthYear(form.dateOfBirth!),
                            placeholder: 'Select your date of birth',
                            errorText: errors.visible(
                              ProfileEditField.dateOfBirth,
                            ),
                            helperText: form.dateOfBirth == null
                                ? null
                                : '${AppDates.ageInYears(form.dateOfBirth!)} '
                                      'years old',
                            onTap: () => _pickDateOfBirth(form.dateOfBirth),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          ProfilePickerField(
                            label: 'Gender',
                            iconName: MedIcon.records,
                            value: form.gender,
                            placeholder: 'Select',
                            errorText: errors.visible(ProfileEditField.gender),
                            onTap: () => _pickGender(form.gender),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          ProfilePickerField(
                            label: 'Blood group',
                            iconName: MedIcon.hospital,
                            value: form.bloodGroup,
                            placeholder: 'Select',
                            errorText: errors.visible(
                              ProfileEditField.bloodGroup,
                            ),
                            helperText:
                                'Shown to the hospital in an emergency.',
                            onTap: () => _pickBloodGroup(form.bloodGroup),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.x4.h),

                    AppCard(
                      padding: EdgeInsets.all(AppSpacing.x4.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SectionTitle('How we reach you'),
                          SizedBox(height: AppSpacing.x3.h),
                          AppTextField(
                            label: 'Email',
                            controller: _email,
                            focusNode: _emailFocus,
                            hintText: 'you@example.com',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.email],
                            errorText: errors.visible(ProfileEditField.email),
                            helperText: 'Receipts and reminders go here.',
                            onChanged: _controller.setEmail,
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          _PhoneSection(
                            currentPhone: form.currentPhone,
                            pendingPhone: form.pendingPhone,
                            onChangeNumber: () =>
                                _changePhone(form.currentPhone),
                            onDiscardPending: _controller.discardPhoneChange,
                            onVerify: () => showStubbedToast(
                              context,
                              ref,
                              'Verifying a new mobile number',
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.x6.h),

                    AppButton(
                      label: 'Save Changes',
                      fullWidth: true,
                      loading: form.isSaving,
                      onPressed: _save,
                    ),
                    SizedBox(height: AppSpacing.x3.h),
                    AppButton(
                      label: 'Cancel',
                      variant: AppButtonVariant.ghost,
                      fullWidth: true,
                      onPressed: () => _leave(context),
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

  /// Leaves the form.
  ///
  /// `Navigator.maybePop`, **not** `context.pop()`: go_router's `pop` calls
  /// `NavigatorState.pop` directly and so bypasses the `PopScope` that
  /// [AppUnsavedChangesGuard] installs. Using it here would mean the system
  /// back gesture warns about unsaved work while this screen's own Back and
  /// Cancel silently discard it.
  void _leave(BuildContext context) {
    if (context.canPop()) {
      Navigator.maybePop(context);
      return;
    }
    context.go(AppRoutes.profile);
  }
}

/// The mobile-number block: what the number is now, and the staged change.
class _PhoneSection extends StatelessWidget {
  const _PhoneSection({
    required this.currentPhone,
    required this.pendingPhone,
    required this.onChangeNumber,
    required this.onDiscardPending,
    required this.onVerify,
  });

  final String currentPhone;
  final String? pendingPhone;
  final VoidCallback onChangeNumber;
  final VoidCallback onDiscardPending;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mobile number',
          style: AppText.poppins(
            size: AppFontSize.base,
            weight: AppText.medium,
            color: AppColors.textStrong,
          ),
        ),
        SizedBox(height: AppSpacing.x2.h),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.x4.w,
            vertical: AppSpacing.x3.h,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: AppRadii.md,
            border: Border.all(color: AppColors.border, width: 1.w),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentPhone,
                      style: AppText.inter(
                        size: AppFontSize.body,
                        weight: AppText.medium,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'In use for sign-in and appointment reminders',
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        height: 1.4,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.x2.w),
              AppButton(
                label: 'Change',
                variant: AppButtonVariant.soft,
                size: AppButtonSize.sm,
                semanticLabel: 'Change your mobile number',
                onPressed: onChangeNumber,
              ),
            ],
          ),
        ),
        if (pendingPhone != null) ...[
          SizedBox(height: AppSpacing.x3.h),
          Container(
            padding: EdgeInsets.all(AppSpacing.x4.w),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: AppRadii.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$pendingPhone — not verified',
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: AppText.semibold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Your number has not changed. We have to send a code to the '
                  'new number and have you enter it before it replaces '
                  '$currentPhone.',
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
                    AppButton(
                      label: 'Verify Number',
                      size: AppButtonSize.sm,
                      // The verify screen has no phoneChange case yet, so this
                      // says so instead of pretending the number moved.
                      stubbed: true,
                      onPressed: onVerify,
                    ),
                    AppButton(
                      label: 'Discard',
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.sm,
                      semanticLabel: 'Discard the new mobile number',
                      onPressed: onDiscardPending,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Collects a new mobile number, validated with `Validators.phone`.
///
/// Returns the number in E.164 (`+919845658525`), or null when dismissed — so
/// a dismissed sheet can never be mistaken for a cleared number. It does not
/// write anything: staging and verification are the caller's job.
Future<String?> showPhoneChangeSheet(
  BuildContext context, {
  required String currentPhone,
}) {
  return showAppSheet<String>(
    context,
    title: 'Change mobile number',
    builder: (sheetContext) => _PhoneChangeForm(currentPhone: currentPhone),
  );
}

class _PhoneChangeForm extends StatefulWidget {
  const _PhoneChangeForm({required this.currentPhone});

  final String currentPhone;

  @override
  State<_PhoneChangeForm> createState() => _PhoneChangeFormState();
}

class _PhoneChangeFormState extends State<_PhoneChangeForm> {
  /// Widget-local on purpose: this draft must not outlive the sheet, and
  /// nothing outside it needs to read a half-typed number.
  final TextEditingController _phone = TextEditingController();

  CountryCode _code = CountryCodes.india;
  String? _error;
  bool _submitted = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  /// Recomputes the error, but only shows it once submit has been pressed —
  /// after that, every keystroke re-checks, so the error clears when the
  /// number is actually valid (audit §3.5.4).
  void _recheck() {
    if (!_submitted) return;
    setState(() => _error = _validate());
  }

  String? _validate() {
    final error = Validators.phone(_phone.text);
    if (error != null) return error;
    final entered = '${_code.dialCode}${Validators.digitsOf(_phone.text)}';
    if (Validators.digitsOf(entered) ==
        Validators.digitsOf(widget.currentPhone)) {
      return 'This is already your number';
    }
    return null;
  }

  void _submit() {
    final error = _validate();
    setState(() {
      _submitted = true;
      _error = error;
    });
    if (error != null) return;
    Navigator.of(
      context,
    ).pop('${_code.dialCode}${Validators.digitsOf(_phone.text)}');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'We will send a 4-digit code to the new number. Your old number '
          'stays in use until you enter that code.',
          style: AppText.poppins(
            size: AppFontSize.sm,
            height: 1.5,
            color: AppColors.textBody,
          ),
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppPhoneField(
          label: 'New mobile number',
          controller: _phone,
          countryCode: _code,
          errorText: _error,
          textInputAction: TextInputAction.done,
          onCountryChanged: (next) {
            setState(() => _code = next);
            _recheck();
          },
          onChanged: (_) => _recheck(),
          onSubmitted: (_) => _submit(),
        ),
        SizedBox(height: AppSpacing.x5.h),
        AppButton(label: 'Continue', fullWidth: true, onPressed: _submit),
      ],
    );
  }
}

/// A card's section heading.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: AppText.poppins(
          size: AppFontSize.body,
          weight: AppText.bold,
          color: AppColors.textStrong,
        ),
      ),
    );
  }
}
