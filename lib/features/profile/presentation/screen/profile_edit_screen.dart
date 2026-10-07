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
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_date_picker_sheet.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_phone_field.dart';
import '../../../../core/widgets/app_switch.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../application/providers/profile_mutations_provider.dart';
import '../../domain/entities/person.dart';
import '../components/allergy_chips_field.dart';
import '../components/profile_option_sheet.dart';
import '../components/profile_picker_field.dart';
import '../../application/providers/profile_edit_controller.dart';

/// Edit profile (`/profile/edit`) — CM-47, over `PATCH /patient/me` (§5.2).
///
/// Only the changed fields are sent, with `If-Match: user.version`. On
/// `409 CONFLICT_VERSION` the account is reloaded and a banner asks the user
/// to review and save again; on `409 UNDER_AGE` or a `400` the message lands
/// on the field. After a save the session user is replaced, so Profile, the
/// home greeting and the booking picker change immediately.
///
/// What this form deliberately does **not** edit:
/// * **Mobile number** — a sign-in credential, changed by the three-step OTP
///   flow on `/profile/phone` (§5.3). The row here links there.
/// * **Email** — the API has no call to change it (§18); it is shown
///   read-only with that said.
/// The alternate (contact-only) number is edited here (§5.4).
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;

  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();

  ProfileEditController get _controller =>
      ref.read(profileEditControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    final initial = ref.read(profileEditControllerProvider);
    _firstName = TextEditingController(text: initial.firstName);
    _lastName = TextEditingController(text: initial.lastName);
    _revealOnBlur(_firstNameFocus, ProfileEditField.firstName);
    _revealOnBlur(_lastNameFocus, ProfileEditField.lastName);
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
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth(DateTime? current) async {
    final now = DateTime.now();
    final picked = await showAppDatePickerSheet(
      context,
      title: 'Date of birth',
      initialDay: current ?? DateTime(now.year - 30, now.month, now.day),
      firstDay: DateTime(now.year - 120, 1, 1),
      lastDay: now,
    );
    if (picked != null) _controller.setDateOfBirth(picked);
  }

  Future<void> _pickGender(Gender? current) async {
    final picked = await showProfileOptionSheet<Gender>(
      context,
      title: 'Gender',
      selected: current,
      options: [
        for (final gender in Gender.values)
          ProfileOption<Gender>(value: gender, label: gender.label),
      ],
    );
    if (picked != null) _controller.setGender(picked);
  }

  Future<void> _pickBloodGroup(String? current) async {
    final picked = await showProfileOptionSheet<String>(
      context,
      title: 'Blood group',
      selected: current ?? _noBloodGroup,
      options: [
        for (final group in BloodGroups.all)
          ProfileOption<String>(value: group, label: group),
        const ProfileOption<String>(
          value: _noBloodGroup,
          label: 'Not known',
          subtitle: 'Clear the blood group on your account',
        ),
      ],
    );
    if (picked == null) return;
    _controller.setBloodGroup(picked == _noBloodGroup ? null : picked);
  }

  static const String _noBloodGroup = '__none__';

  Future<void> _save() async {
    // A second tap in the same frame, before the button shows its spinner,
    // must not reach the controller: it would come back as "nothing to
    // report", read here as success — a false 'Profile updated' and the
    // screen closed while the real save is still running (BL-CACHE-024).
    if (ref.read(profileEditControllerProvider).isSaving) return;
    if (!_controller.validate()) {
      ref
          .read(toastControllerProvider.notifier)
          .show('Fix the highlighted fields first');
      return;
    }
    final form = ref.read(profileEditControllerProvider);
    _controller.setSaving(true);
    final failure = await ref
        .read(profileSaveControllerProvider.notifier)
        .save(form.toUpdate());
    if (!mounted) return;

    final toast = ref.read(toastControllerProvider.notifier);
    if (failure == null) {
      // isSaving stays true through the pop: the values are committed, so
      // the unsaved-changes guard must not challenge leaving.
      toast.show('Profile updated');
      _leave(context);
      return;
    }
    _controller.setSaving(false);
    if (failure is ValidationFailure && failure.fieldErrors.isNotEmpty) {
      _controller.applyServerErrors(failure.fieldErrors);
      toast.show('Fix the highlighted fields first');
      return;
    }
    if (failure is ConflictFailure) {
      // The account was reloaded by the controller; move the dirty baseline
      // so the user's edits are kept and compared against the live values.
      final user = ref.read(currentUserProvider);
      if (user != null) {
        _controller.rebase(
          ProfileEditValues(
            firstName: user.firstName,
            lastName: user.lastName ?? '',
            dateOfBirth: user.dateOfBirth,
            gender: Gender.fromWire(user.gender),
            bloodGroup: user.bloodGroup,
            allergies: user.allergies,
            marketingOptIn: user.marketingOptIn,
          ),
        );
        // Untouched names may have changed: show what will be sent.
        final merged = ref.read(profileEditControllerProvider);
        if (_firstName.text != merged.firstName) {
          _firstName.text = merged.firstName;
        }
        if (_lastName.text != merged.lastName) {
          _lastName.text = merged.lastName;
        }
      }
    }
    toast.show(failure.userMessage);
  }

  Future<void> _editAlternatePhone(String? current) async {
    final entered = await showAlternatePhoneSheet(
      context,
      current: current,
      mainPhoneE164: ref.read(currentUserProvider)?.phoneE164,
    );
    if (entered == null || !mounted) return;
    final notifier = ref.read(alternatePhoneControllerProvider.notifier);
    final failure = entered.isEmpty
        ? await notifier.remove()
        : await notifier.set(entered);
    if (!mounted) return;
    ref
        .read(toastControllerProvider.notifier)
        .show(
          // A refusal on the number says why — the sheet is closed, so a
          // "check the highlighted fields" toast pointed at nothing
          // (BL-PROF-020).
          (failure is ValidationFailure && failure.fieldErrors.isNotEmpty
                  ? failure.fieldErrors.values.first
                  : failure?.userMessage) ??
              (entered.isEmpty
                  ? 'Alternate number removed'
                  : 'Alternate number saved'),
        );
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(profileEditControllerProvider);
    final save = ref.watch(profileSaveControllerProvider);
    final user = ref.watch(currentUserProvider);
    final altBusy = ref.watch(
      alternatePhoneControllerProvider.select((s) => s.isBusy),
    );
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
                    if (save.hasConflict) ...[
                      AppErrorBanner(
                        message:
                            'Your details were changed elsewhere and have '
                            'been reloaded. Review them and save again.',
                        tone: AppBannerTone.warning,
                        onTap: ref
                            .read(profileSaveControllerProvider.notifier)
                            .clearConflict,
                      ),
                      SizedBox(height: AppSpacing.x4.h),
                    ],
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
                            hintText: 'Anita',
                            maxLength: 100,
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
                            hintText: 'Menon',
                            maxLength: 100,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.familyName],
                            helperText: 'Optional',
                            errorText: errors.visible(
                              ProfileEditField.lastName,
                            ),
                            onChanged: _controller.setLastName,
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
                            iconName: PhIcon.calendarBlank,
                            value: form.dateOfBirth == null
                                ? null
                                : AppDates.dayMonthYear(form.dateOfBirth!),
                            placeholder: 'Select your date of birth',
                            errorText: errors.visible(
                              ProfileEditField.dateOfBirth,
                            ),
                            helperText: form.dateOfBirth == null
                                ? 'Account holders must be 18 or older.'
                                : '${AppDates.ageInYears(form.dateOfBirth!)} '
                                      'years old',
                            onTap: () => _pickDateOfBirth(form.dateOfBirth),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          ProfilePickerField(
                            label: 'Gender',
                            iconName: PhIcon.user,
                            value: form.gender?.label,
                            placeholder: 'Select',
                            errorText: errors.visible(ProfileEditField.gender),
                            onTap: () => _pickGender(form.gender),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          ProfilePickerField(
                            label: 'Blood group',
                            iconName: PhIcon.firstAid,
                            value: form.bloodGroup,
                            placeholder: 'Select',
                            errorText: errors.visible(
                              ProfileEditField.bloodGroup,
                            ),
                            helperText:
                                'Shown to the hospital in an emergency.',
                            onTap: () => _pickBloodGroup(form.bloodGroup),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          AllergyChipsField(
                            allergies: form.allergies,
                            onChanged: _controller.setAllergies,
                          ),
                          if (errors.visible(ProfileEditField.allergies) !=
                              null)
                            Padding(
                              padding: EdgeInsets.only(top: 6.h),
                              child: Text(
                                errors.visible(ProfileEditField.allergies)!,
                                style: AppText.poppins(
                                  size: AppFontSize.xs,
                                  color: AppColors.dangerText,
                                ),
                              ),
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
                          _ReadOnlyRow(
                            label: 'Email',
                            value: user?.email ?? 'No email on file',
                            note:
                                'Receipts and reminders go here. Changing '
                                'the email address is not available yet.',
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          _PhoneRow(
                            label: 'Mobile number',
                            value: _phone(user?.phoneE164),
                            note: 'Used to sign in and for reminders.',
                            actionLabel: 'Change',
                            actionSemanticLabel: 'Change your mobile number',
                            onAction: () =>
                                context.push(AppRoutes.profilePhone),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          _PhoneRow(
                            label: 'Alternate number',
                            value: _phone(user?.alternatePhoneE164),
                            note:
                                'A contact number only — never used to sign in.',
                            actionLabel: user?.alternatePhoneE164 == null
                                ? 'Add'
                                : 'Edit',
                            actionSemanticLabel:
                                'Edit your alternate contact number',
                            isBusy: altBusy,
                            onAction: () =>
                                _editAlternatePhone(user?.alternatePhoneE164),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          _MarketingRow(
                            value: form.marketingOptIn,
                            onChanged: _controller.setMarketingOptIn,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.x6.h),

                    AppButton(
                      label: 'Save Changes',
                      fullWidth: true,
                      loading: form.isSaving || save.isSaving,
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

  /// `Navigator.maybePop`, **not** `context.pop()`, so the unsaved-changes
  /// guard's `PopScope` runs for Back and Cancel as well as the gesture.
  void _leave(BuildContext context) {
    if (context.canPop()) {
      Navigator.maybePop(context);
      return;
    }
    context.go(AppRoutes.profile);
  }
}

/// A stored number as people read it, or "Not set".
String _phone(String? e164) =>
    e164 == null ? 'Not set' : PhoneFormat.display(e164);

/// A value the API cannot change on this screen, with the reason.
class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
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
            color: AppColors.grey100,
            borderRadius: AppRadii.md,
            border: Border.all(color: AppColors.border, width: 1.w),
          ),
          child: SelectableText(
            value,
            style: AppText.inter(
              size: AppFontSize.body,
              color: AppColors.textMuted,
            ),
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          note,
          style: AppText.poppins(
            size: AppFontSize.xs,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// A phone number with its action (Change / Add / Edit).
class _PhoneRow extends StatelessWidget {
  const _PhoneRow({
    required this.label,
    required this.value,
    required this.note,
    required this.actionLabel,
    required this.actionSemanticLabel,
    required this.onAction,
    this.isBusy = false,
  });

  final String label;
  final String value;
  final String note;
  final String actionLabel;
  final String actionSemanticLabel;
  final VoidCallback onAction;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
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
                      value,
                      style: AppText.inter(
                        size: AppFontSize.body,
                        weight: AppText.medium,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      note,
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
                label: actionLabel,
                variant: AppButtonVariant.soft,
                size: AppButtonSize.sm,
                loading: isBusy,
                semanticLabel: actionSemanticLabel,
                onPressed: onAction,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `marketing_opt_in` — the one consent that lives on the profile (§5.9).
class _MarketingRow extends StatelessWidget {
  const _MarketingRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.x3.w),
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
                  'Offers and health camp updates',
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: AppText.medium,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Occasional messages from Medibook and partner hospitals.',
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.x3.w),
          Semantics(
            label: 'Receive offers and health camp updates',
            child: AppSwitch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

/// Collects an alternate contact number (§5.4).
///
/// Returns the number in E.164, an **empty string** to remove the current
/// one, or null when dismissed.
Future<String?> showAlternatePhoneSheet(
  BuildContext context, {
  required String? current,
  String? mainPhoneE164,
}) {
  return showAppSheet<String>(
    context,
    title: current == null ? 'Add alternate number' : 'Alternate number',
    builder: (sheetContext) =>
        _AlternatePhoneForm(current: current, mainPhoneE164: mainPhoneE164),
  );
}

class _AlternatePhoneForm extends StatefulWidget {
  const _AlternatePhoneForm({required this.current, this.mainPhoneE164});

  final String? current;

  /// The account's sign-in number, which cannot also be the alternate one.
  final String? mainPhoneE164;

  @override
  State<_AlternatePhoneForm> createState() => _AlternatePhoneFormState();
}

class _AlternatePhoneFormState extends State<_AlternatePhoneForm> {
  late final TextEditingController _phone;
  late CountryCode _code;
  String? _error;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final stored = widget.current ?? '';
    _code = CountryCodes.all.firstWhere(
      (c) => stored.startsWith(c.dialCode),
      orElse: () => CountryCodes.india,
    );
    _phone = TextEditingController(
      text: stored.startsWith(_code.dialCode)
          ? stored.substring(_code.dialCode.length)
          : Validators.digitsOf(stored),
    );
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String get _e164 => '${_code.dialCode}${Validators.digitsOf(_phone.text)}';

  String? _validate() {
    final format = _code == CountryCodes.india
        ? Validators.phone(_phone.text)
        : Validators.phoneE164(_e164);
    if (format != null) return format;
    // Caught here, with the sheet still open: the server refuses it, and
    // that used to close the sheet with nothing to show (BL-PROF-020).
    if (_e164 == widget.mainPhoneE164) {
      return 'This is already your sign-in number. Enter a different one.';
    }
    return null;
  }

  void _recheck() {
    if (!_submitted) return;
    setState(() => _error = _validate());
  }

  void _submit() {
    final error = _validate();
    setState(() {
      _submitted = true;
      _error = error;
    });
    if (error != null) return;
    Navigator.of(context).pop(_e164);
  }

  Future<void> _remove() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Remove alternate number?',
      consequence: 'We will only be able to reach you on your main number.',
      confirmLabel: 'Remove',
      iconName: PhIcon.xCircle,
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop('');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'A second number the hospital can try. It is never used to sign in '
          'and no code is sent to it.',
          style: AppText.poppins(
            size: AppFontSize.sm,
            height: 1.5,
            color: AppColors.textBody,
          ),
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppPhoneField(
          label: 'Alternate number',
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
        AppButton(label: 'Save', fullWidth: true, onPressed: _submit),
        if (widget.current != null) ...[
          SizedBox(height: AppSpacing.x3.h),
          AppButton(
            label: 'Remove Number',
            variant: AppButtonVariant.ghost,
            fullWidth: true,
            onPressed: _remove,
          ),
        ],
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
