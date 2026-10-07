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
import '../../../../core/network/network_exceptions.dart';
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
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../../core/widgets/states/app_not_found_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../application/providers/profile_mutations_provider.dart';
import '../../application/providers/profile_provider.dart';
import '../../application/providers/release_provider.dart';
import '../../application/states/release_state.dart';
import '../../domain/entities/person.dart';
import '../components/allergy_chips_field.dart';
import '../components/code_entry_field.dart';
import '../components/profile_option_sheet.dart';
import '../components/profile_picker_field.dart';
import '../../application/providers/dependant_form_controller.dart';

/// Add or edit a family member (`/dependants/edit?id=…`) — CM-16, CM-48,
/// over `POST`/`PATCH`/`DELETE /patient/me/persons` (§6.1).
///
/// A PATCH sends only the changed fields with `If-Match`; a stale version
/// reloads the list and asks for a retry. Server field errors land on the
/// fields. Removal answers `PERSON_IS_SELF` / `PERSON_HAS_APPOINTMENTS` with
/// the actual reason rather than a generic failure.
///
/// A dependant who is 18+ can be **released** to their own account (§5.8):
/// their own mobile number, a code to it, and the person plus their history
/// leave this account.
class DependantEditScreen extends ConsumerStatefulWidget {
  const DependantEditScreen({super.key, this.id});

  /// The person being edited, or null to add one.
  final String? id;

  @override
  ConsumerState<DependantEditScreen> createState() =>
      _DependantEditScreenState();
}

class _DependantEditScreenState extends ConsumerState<DependantEditScreen> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _guardianNote;
  CountryCode _code = CountryCodes.india;

  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  String? _id;
  bool _resolved = false;
  bool _notFound = false;
  String? _attemptedId;

  DependantFormController get _controller =>
      ref.read(dependantFormProvider(_id).notifier);

  bool get _isEditing => _id != null;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController();
    _lastName = TextEditingController();
    _phone = TextEditingController();
    _guardianNote = TextEditingController();
    _revealOnBlur(_firstNameFocus, DependantField.firstName);
    _revealOnBlur(_lastNameFocus, DependantField.lastName);
    _revealOnBlur(_phoneFocus, DependantField.phone);
  }

  void _revealOnBlur(FocusNode node, String field) {
    node.addListener(() {
      if (!node.hasFocus && _resolved && !_notFound) {
        _controller.markTouched(field);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveIfReady();
  }

  /// The persons list must be known before the id can be resolved; the build
  /// shows a skeleton until then. Called on first build and again whenever
  /// the list changes: it used to run only here, so a list still loading
  /// when the screen opened (Add family member from booking) left the
  /// skeleton up for good (CL BOOK-009).
  void _resolveIfReady() {
    if (_resolved) return;
    final persons = ref.read(personsProvider);
    if (persons.isLoading) return;
    _resolved = true;

    final queryId = GoRouterState.of(context).uri.queryParameters['id'];
    final rawId = widget.id ?? queryId;
    final id = (rawId == null || rawId.isEmpty) ? null : rawId;
    _attemptedId = id;

    if (id != null && ref.read(personByIdProvider(id)) == null) {
      _notFound = true;
      return;
    }
    _id = id;
    final initial = ref.read(dependantFormProvider(_id));
    _firstName.text = initial.firstName;
    _lastName.text = initial.lastName;
    _guardianNote.text = initial.guardianNote;
    final stored = initial.phone;
    _code = CountryCodes.all.firstWhere(
      (c) => stored.startsWith(c.dialCode),
      orElse: () => CountryCodes.india,
    );
    _phone.text = stored.startsWith(_code.dialCode)
        ? stored.substring(_code.dialCode.length)
        : Validators.digitsOf(stored);
    setState(() {});
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _guardianNote.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _syncPhone() {
    final digits = Validators.digitsOf(_phone.text);
    _controller.setPhone(digits.isEmpty ? '' : '${_code.dialCode}$digits');
  }

  Future<void> _pickDateOfBirth(DateTime? current) async {
    final now = DateTime.now();
    final picked = await showAppDatePickerSheet(
      context,
      title: 'Date of birth',
      initialDay: current ?? DateTime(now.year - 10, now.month, now.day),
      firstDay: DateTime(now.year - 120, 1, 1),
      lastDay: now,
    );
    if (picked != null) _controller.setDateOfBirth(picked);
  }

  Future<void> _pickRelation(PersonRelation? current) async {
    final picked = await showProfileOptionSheet<PersonRelation>(
      context,
      title: 'Relation to you',
      selected: current,
      options: [
        for (final relation in PersonRelation.selectable)
          ProfileOption<PersonRelation>(
            value: relation,
            label: relation.label,
            subtitle: relation.hint,
          ),
      ],
    );
    if (picked != null) _controller.setRelation(picked);
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

  static const String _noBloodGroup = '__none__';

  Future<void> _pickBloodGroup(String? current) async {
    final picked = await showProfileOptionSheet<String>(
      context,
      title: 'Blood group',
      selected: current ?? _noBloodGroup,
      options: [
        for (final group in BloodGroups.all)
          ProfileOption<String>(value: group, label: group),
        const ProfileOption<String>(value: _noBloodGroup, label: 'Not known'),
      ],
    );
    if (picked == null) return;
    _controller.setBloodGroup(picked == _noBloodGroup ? null : picked);
  }

  Future<void> _save() async {
    // A second tap in the same frame must not reach the controller: it would
    // come back as "nothing to report", read here as success — a false
    // 'added' message while the real save is still running (BL-CACHE-024).
    if (ref.read(dependantFormProvider(_id)).isSaving) return;
    if (!_controller.validate()) {
      _toast('Fix the highlighted fields first');
      return;
    }
    final form = ref.read(dependantFormProvider(_id));
    _controller.setSaving(true);
    final notifier = ref.read(personMutationControllerProvider.notifier);
    final failure = _isEditing
        ? await notifier.update(
            _id!,
            form.toPatchDraft(),
            // The version now on file (the list is reloaded after a
            // conflict), not the one the form opened with (BL-PROF-011).
            ifMatch:
                ref.read(personByIdProvider(_id!))?.version ?? form.version,
          )
        : await notifier.create(form.toCreateDraft());
    if (!mounted) return;

    if (failure == null) {
      // isSaving stays true through the pop: the work is committed.
      _toast(
        _isEditing
            ? '${form.fullName} updated'
            : '${form.fullName} added to your family',
      );
      _leave(context);
      return;
    }
    _controller.setSaving(false);
    if (failure is ValidationFailure && failure.fieldErrors.isNotEmpty) {
      _controller.applyServerErrors(failure.fieldErrors);
      _toast('Fix the highlighted fields first');
      return;
    }
    _toast(failure.userMessage);
  }

  Future<void> _remove(DependantFormState form) async {
    final name = form.fullName;
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Remove $name?',
      consequence:
          '$name will no longer be selectable as the patient when you book. '
          'Their past appointments stay in your history. This cannot be '
          'undone.',
      confirmLabel: 'Remove $name',
      iconName: PhIcon.xCircle,
    );
    if (confirmed != true || !mounted) return;

    final failure = await ref
        .read(personMutationControllerProvider.notifier)
        .delete(_id!);
    if (!mounted) return;
    if (failure != null) {
      _toast(switch (failure.apiCode) {
        ApiErrorCodes.personHasAppointments =>
          '$name has upcoming appointments. Cancel them before removing '
              'them from your family.',
        ApiErrorCodes.personIsSelf => 'Your own record cannot be removed.',
        _ => failure.userMessage,
      });
      return;
    }
    _controller.setSaving(true);
    _toast('$name removed');
    _leave(context);
  }

  Future<void> _release(Person person) async {
    final released = await showAppSheet<bool>(
      context,
      title: 'Move to their own account',
      isDismissible: false,
      builder: (sheetContext) => _ReleaseSheet(person: person),
    );
    if (released != true || !mounted) return;
    _controller.setSaving(true);
    _toast('${person.name} now has their own Medibook account');
    _leave(context);
  }

  void _toast(String text) =>
      ref.read(toastControllerProvider.notifier).show(text);

  @override
  Widget build(BuildContext context) {
    // Keeps the autoDispose save controller alive for the life of the form,
    // so a save in flight is not dropped mid-request (Screen Coverage pass).
    ref.watch(personMutationControllerProvider);
    if (!_resolved) {
      // Waiting for the persons list (deep link before the list loaded).
      ref.listen(personsProvider, (_, _) => setState(_resolveIfReady));
      return Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInnerHeader(
                title: 'Family Member',
                onBack: () => _leave(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: AppSkeletonList(
                    count: 2,
                    padding: EdgeInsets.all(AppSpacing.x5.w),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_notFound) {
      return AppNotFoundView(
        headline: 'Family member not found',
        body:
            'This record is no longer on your account. It may have been '
            'removed or moved to their own account.',
        attemptedPath: AppRoutes.dependantEditPath(_attemptedId),
        onGoHome: () => context.go(AppRoutes.home),
        onGoBack: context.canPop() ? () => context.pop() : null,
      );
    }

    final form = ref.watch(dependantFormProvider(_id));
    final busy = ref.watch(
      personMutationControllerProvider.select((s) => s.isBusy),
    );
    final person = _id == null ? null : ref.watch(personByIdProvider(_id!));
    final errors = form.errors;

    return AppUnsavedChangesGuard(
      hasUnsavedChanges: form.isDirty && !form.isSaving,
      title: 'Discard this family member?',
      consequence: _isEditing
          ? 'The changes you have made will not be saved.'
          : 'The details you have entered will not be saved and no family '
                'member will be added.',
      child: Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInnerHeader(
                title: _isEditing ? 'Edit Family Member' : 'Add Family Member',
                onBack: () => _leave(context),
                backSemanticLabel: 'Back to family members',
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
                          AppTextField(
                            label: 'First name',
                            controller: _firstName,
                            focusNode: _firstNameFocus,
                            hintText: 'Arjun',
                            maxLength: 100,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            errorText: errors.visible(DependantField.firstName),
                            onChanged: _controller.setFirstName,
                            onSubmitted: (_) => _lastNameFocus.requestFocus(),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          AppTextField(
                            label: 'Last name',
                            controller: _lastName,
                            focusNode: _lastNameFocus,
                            hintText: 'Nair',
                            maxLength: 100,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            helperText: 'Optional',
                            errorText: errors.visible(DependantField.lastName),
                            onChanged: _controller.setLastName,
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          ProfilePickerField(
                            label: 'Relation to you',
                            iconName: PhIcon.folder,
                            value: form.isSelf
                                ? 'You'
                                : form.relation?.labelFor(form.gender),
                            placeholder: 'Select',
                            errorText: errors.visible(DependantField.relation),
                            enabled: !form.isSelf,
                            helperText: form.isSelf
                                ? 'This is your own record, so the relation '
                                      'cannot be changed.'
                                : null,
                            onTap: () => _pickRelation(form.relation),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          ProfilePickerField(
                            label: 'Date of birth',
                            iconName: PhIcon.calendarBlank,
                            value: form.dateOfBirth == null
                                ? null
                                : AppDates.dayMonthYear(form.dateOfBirth!),
                            placeholder: 'Select a date of birth',
                            errorText: errors.visible(
                              DependantField.dateOfBirth,
                            ),
                            helperText: form.dateOfBirth == null
                                ? 'Their age is worked out from this.'
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
                            errorText: errors.visible(DependantField.gender),
                            helperText: 'Optional',
                            onTap: () => _pickGender(form.gender),
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
                          Semantics(
                            header: true,
                            child: Text(
                              'What the doctor needs to know',
                              style: AppText.poppins(
                                size: AppFontSize.body,
                                weight: AppText.bold,
                                color: AppColors.textStrong,
                              ),
                            ),
                          ),
                          SizedBox(height: AppSpacing.x3.h),
                          ProfilePickerField(
                            label: 'Blood group',
                            iconName: PhIcon.firstAid,
                            value: form.bloodGroup,
                            placeholder: 'Select',
                            errorText: errors.visible(
                              DependantField.bloodGroup,
                            ),
                            helperText: 'Optional, but useful in an emergency.',
                            onTap: () => _pickBloodGroup(form.bloodGroup),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          AllergyChipsField(
                            allergies: form.allergies,
                            onChanged: _controller.setAllergies,
                          ),
                          if (errors.visible(DependantField.allergies) != null)
                            Padding(
                              padding: EdgeInsets.only(top: 6.h),
                              child: Text(
                                errors.visible(DependantField.allergies)!,
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
                      child: AppPhoneField(
                        label: 'Their mobile number',
                        controller: _phone,
                        focusNode: _phoneFocus,
                        countryCode: _code,
                        errorText: errors.visible(DependantField.phone),
                        helperText:
                            'Optional. Needed if they later move to their '
                            'own account.',
                        textInputAction: TextInputAction.done,
                        onCountryChanged: (next) {
                          setState(() => _code = next);
                          _syncPhone();
                        },
                        onChanged: (_) => _syncPhone(),
                      ),
                    ),
                    // `guardian_note` (§6.1). Kept on the person for the
                    // account holder; the hospital is not sent it.
                    if (!form.isSelf) ...[
                      SizedBox(height: AppSpacing.x4.h),
                      AppCard(
                        padding: EdgeInsets.all(AppSpacing.x4.w),
                        child: AppTextField(
                          label: 'Guardian note',
                          controller: _guardianNote,
                          hintText:
                              'Who looks after them, or anything to '
                              'remember',
                          maxLines: 3,
                          maxLength: guardianNoteMaxLength,
                          textCapitalization: TextCapitalization.sentences,
                          helperText:
                              'Optional. For your own reference — for '
                              'example, who usually brings them in.',
                          errorText: errors.visible(
                            DependantField.guardianNote,
                          ),
                          onChanged: _controller.setGuardianNote,
                        ),
                      ),
                    ],
                    SizedBox(height: AppSpacing.x6.h),

                    AppButton(
                      label: _isEditing ? 'Save Changes' : 'Add Family Member',
                      fullWidth: true,
                      loading: form.isSaving || busy,
                      onPressed: _save,
                    ),
                    SizedBox(height: AppSpacing.x3.h),
                    if (person != null && person.canBeReleased) ...[
                      _ReleaseCard(
                        person: person,
                        onRelease: () => _release(person),
                      ),
                      SizedBox(height: AppSpacing.x3.h),
                    ],
                    if (_isEditing && !form.isSelf)
                      AppButton(
                        label: 'Remove from Family',
                        variant: AppButtonVariant.danger,
                        fullWidth: true,
                        disabled: busy,
                        onPressed: () => _remove(form),
                      )
                    else
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
    context.go(AppRoutes.dependants);
  }
}

/// Offers the release flow (§5.8) for an 18+ dependant.
class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.person, required this.onRelease});

  final Person person;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: AppRadii.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${person.firstName} is ${person.ageInYears()} — they can have '
            'their own account',
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Their record, appointments, payments and receipts move to a '
            'Medibook account under their own mobile number, and leave '
            'yours.',
            style: AppText.poppins(
              size: AppFontSize.xs,
              height: 1.5,
              color: AppColors.textBody,
            ),
          ),
          SizedBox(height: AppSpacing.x3.h),
          AppButton(
            label: 'Move to Their Own Account',
            variant: AppButtonVariant.soft,
            size: AppButtonSize.sm,
            onPressed: onRelease,
          ),
        ],
      ),
    );
  }
}

/// The two-step release sheet: their number, then the code sent to it.
/// Pops `true` once the person has left this account.
class _ReleaseSheet extends ConsumerStatefulWidget {
  const _ReleaseSheet({required this.person});

  final Person person;

  @override
  ConsumerState<_ReleaseSheet> createState() => _ReleaseSheetState();
}

class _ReleaseSheetState extends ConsumerState<_ReleaseSheet> {
  late final TextEditingController _phone;

  /// Fixed: their new sign-in number must be an Indian mobile (§5.8,
  /// BL-AUTH-008).
  static const CountryCode _code = CountryCodes.india;
  String? _phoneError;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // Pre-filled only with an Indian number already on file; anything else
    // could never be accepted here.
    final stored = widget.person.phoneE164 ?? '';
    _phone = TextEditingController(
      text: stored.startsWith(_code.dialCode)
          ? stored.substring(_code.dialCode.length)
          : '',
    );
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String get _e164 => '${_code.dialCode}${Validators.digitsOf(_phone.text)}';

  String? _validate() => Validators.phone(_phone.text);

  void _recheck() {
    if (!_submitted) return;
    setState(() => _phoneError = _validate());
  }

  Future<void> _start() async {
    final error = _validate();
    setState(() {
      _submitted = true;
      _phoneError = error;
    });
    if (error != null) return;
    final failure = await ref
        .read(releaseControllerProvider(widget.person.id).notifier)
        .start(_e164);
    if (!mounted || failure == null) return;
    if (failure is ValidationFailure) {
      setState(
        () =>
            _phoneError = failure.forField('phone_e164') ?? failure.userMessage,
      );
    }
  }

  Future<void> _verify(String code) async {
    final length =
        ref
            .read(releaseControllerProvider(widget.person.id))
            .challenge
            ?.codeLength ??
        4;
    final error = Validators.otp(code, length: length);
    if (error != null) {
      ref.read(toastControllerProvider.notifier).show(error);
      return;
    }
    final failure = await ref
        .read(releaseControllerProvider(widget.person.id).notifier)
        .verify(code);
    if (!mounted || failure != null) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _resend() async {
    final failure = await ref
        .read(releaseControllerProvider(widget.person.id).notifier)
        .resend();
    if (!mounted) return;
    ref
        .read(toastControllerProvider.notifier)
        .show(failure?.userMessage ?? 'Code sent again');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(releaseControllerProvider(widget.person.id));
    final failure = state.failure;
    final challenge = state.challenge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.step == ReleaseStep.enterNumber) ...[
          Text(
            'Enter ${widget.person.firstName}\'s own mobile number. We send '
            'a code there; once it is entered, their record and history move '
            'to their new account.',
            style: AppText.poppins(
              size: AppFontSize.sm,
              height: 1.5,
              color: AppColors.textBody,
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
                switch (failure.apiCode) {
                  ApiErrorCodes.underAge =>
                    'They must be 18 or older to have their own account.',
                  ApiErrorCodes.stateConflict =>
                    'This record cannot be moved right now. Try again later.',
                  _ => failure.userMessage,
                },
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
            label: 'Their mobile number',
            controller: _phone,
            countryCode: _code,
            errorText: _phoneError,
            textInputAction: TextInputAction.done,
            enabled: !state.isBusy,
            // No country choice: this becomes their sign-in number, which
            // must be an Indian mobile (§5.8, BL-AUTH-008).
            onChanged: (_) => _recheck(),
            onSubmitted: (_) => _start(),
          ),
          SizedBox(height: AppSpacing.x5.h),
          AppButton(
            label: 'Send Code',
            fullWidth: true,
            loading: state.isBusy,
            onPressed: _start,
          ),
          SizedBox(height: AppSpacing.x2.h),
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.ghost,
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ] else ...[
          CodeEntryField(
            key: ValueKey(challenge?.challengeId),
            codeLength: challenge?.codeLength ?? 4,
            destinationMasked: challenge?.destinationMasked,
            resendAfter: challenge == null
                ? null
                : DateTime.now().add(
                    Duration(seconds: challenge.resendAfterSeconds),
                  ),
            errorText: failure is UnauthorizedFailure && !failure.sessionExpired
                ? failure.userMessage
                : failure?.userMessage,
            attemptsRemaining: state.attemptsRemaining,
            isBusy: state.isBusy,
            submitLabel: 'Move to Their Account',
            onSubmit: _verify,
            onResend: _resend,
          ),
          SizedBox(height: AppSpacing.x2.h),
          AppButton(
            label: 'Change number',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            disabled: state.isBusy,
            onPressed: ref
                .read(releaseControllerProvider(widget.person.id).notifier)
                .backToNumber,
          ),
        ],
      ],
    );
  }
}
