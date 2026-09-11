import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/patient.dart';
import '../../../../core/mock_data/stores/dependants_store.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_date_picker_sheet.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_phone_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../../core/widgets/states/app_not_found_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/allergy_chips_field.dart';
import '../components/profile_option_sheet.dart';
import '../components/profile_picker_field.dart';
import '../controllers/dependant_form_controller.dart';

/// Add or edit a family member (`/dependants/edit?id=…`) — CM-16, CM-48.
///
/// Reached from the family-members list and from the booking flow's patient
/// picker, both of which link with [AppRoutes.dependantEditPath] — one screen,
/// one store, no forked copy of the data.
///
/// Covers everything the audit found missing: an add path, an edit path, a
/// remove control, **blood group** and **allergies**. Removal is on this
/// screen rather than in the list, because deleting a person's record is
/// destructive and should sit behind opening that record.
///
/// `DependantsStore.remove` returns false for the account holder and for an
/// unknown id. The Remove control is therefore **absent** on the account
/// holder's own record rather than present and doomed, and on a false return
/// the screen says the removal did not happen.
class DependantEditScreen extends ConsumerStatefulWidget {
  const DependantEditScreen({super.key, this.id});

  /// The patient being edited, or null to add one. Normally read from the
  /// `?id=` query; the parameter exists so the router can pass it explicitly
  /// and so the screen is testable without a router.
  final String? id;

  @override
  ConsumerState<DependantEditScreen> createState() =>
      _DependantEditScreenState();
}

class _DependantEditScreenState extends ConsumerState<DependantEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  /// Resolved once in [initState]: the id decides which form provider this
  /// screen talks to, so it must not change under it mid-edit.
  String? _id;

  bool _resolved = false;

  /// True when the `?id=` pointed at a patient that does not exist.
  bool _notFound = false;

  /// The id that was asked for, kept so the not-found view can show the path
  /// that failed rather than a blank one.
  String? _attemptedId;

  DependantFormController get _controller =>
      ref.read(dependantFormProvider(_id).notifier);

  bool get _isEditing => _id != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _revealOnBlur(_nameFocus, DependantField.name);
    _revealOnBlur(_phoneFocus, DependantField.phone);
  }

  void _revealOnBlur(FocusNode node, String field) {
    node.addListener(() {
      if (!node.hasFocus && !_notFound) _controller.markTouched(field);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolved) return;
    _resolved = true;

    // The route's query is only readable once this is in the tree, so the id
    // and the initial field text are resolved here rather than in initState.
    final queryId = GoRouterState.of(context).uri.queryParameters['id'];
    final rawId = widget.id ?? queryId;
    final id = (rawId == null || rawId.isEmpty) ? null : rawId;

    _attemptedId = id;
    if (id != null &&
        ref.read(dependantsStoreProvider.notifier).byId(id) == null) {
      // A stale deep link, or a record removed on another screen. Say so
      // rather than silently opening a blank "add" form the user did not ask
      // for and would unknowingly create a second person with.
      setState(() => _notFound = true);
      return;
    }

    _id = id;
    final initial = ref.read(dependantFormProvider(_id));
    _name.text = initial.name;
    _phone.text = initial.phone;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
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

  Future<void> _pickRelation(String? current, {required bool isSelf}) async {
    final picked = await showProfileOptionSheet<String>(
      context,
      title: 'Relation to you',
      selected: current,
      options: [
        for (final relation in relationOptionsFor(isSelf: isSelf))
          ProfileOption<String>(value: relation, label: relation),
      ],
    );
    if (picked != null) _controller.setRelation(picked);
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

  void _save() {
    if (!_controller.validate()) {
      ref
          .read(toastControllerProvider.notifier)
          .show('Fix the highlighted fields first');
      return;
    }

    final form = ref.read(dependantFormProvider(_id));
    final store = ref.read(dependantsStoreProvider.notifier);
    final phone = form.phone.trim();

    _controller.setSaving(true);
    if (_isEditing) {
      store.patch(
        _id!,
        name: form.name.trim(),
        relation: form.relation,
        dateOfBirth: form.dateOfBirth,
        gender: form.gender,
        bloodGroup: form.bloodGroup,
        allergies: form.allergies,
        phone: phone.isEmpty ? null : phone,
      );
    } else {
      store.add(
        name: form.name.trim(),
        relation: form.relation!,
        dateOfBirth: form.dateOfBirth!,
        gender: form.gender!,
        bloodGroup: form.bloodGroup,
        allergies: form.allergies,
        phone: phone.isEmpty ? null : phone,
      );
    }
    // isSaving stays true through the pop: the work is committed, so the
    // unsaved-changes guard must not challenge leaving.
    ref
        .read(toastControllerProvider.notifier)
        .show(
          _isEditing
              ? '${form.name.trim()} updated'
              : '${form.name.trim()} added to your family',
        );
    _leave(context);
  }

  Future<void> _remove(DependantFormState form) async {
    final name = form.name.trim();
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Remove $name?',
      consequence:
          '$name will no longer be selectable as the patient when you book, '
          'and their documents will stay in your records but will not be '
          'linked to anyone. This cannot be undone.',
      confirmLabel: 'Remove $name',
      iconName: MedIcon.closeCircle,
    );
    if (confirmed != true || !mounted) return;

    final removed = ref.read(dependantsStoreProvider.notifier).remove(_id!);
    if (!mounted) return;

    if (!removed) {
      // False means the store refused — the account holder, or an id that has
      // already gone. Never a success message.
      ref
          .read(toastControllerProvider.notifier)
          .show('$name could not be removed');
      return;
    }
    // Same reason as in _save: the record is gone, so leaving loses nothing.
    _controller.setSaving(true);
    ref.read(toastControllerProvider.notifier).show('$name removed');
    _leave(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_notFound) {
      return AppNotFoundView(
        headline: 'Family member not found',
        body:
            'This record is no longer on your account. It may have been '
            'removed on another screen.',
        attemptedPath: AppRoutes.dependantEditPath(_attemptedId),
        onGoHome: () => context.go(AppRoutes.home),
        onGoBack: context.canPop() ? () => context.pop() : null,
      );
    }

    final form = ref.watch(dependantFormProvider(_id));
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
                            label: 'Full name',
                            controller: _name,
                            focusNode: _nameFocus,
                            hintText: 'Emily Johnson',
                            maxLength: 60,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            errorText: errors.visible(DependantField.name),
                            onChanged: _controller.setName,
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          ProfilePickerField(
                            label: 'Relation to you',
                            iconName: MedIcon.records,
                            value: form.relation,
                            placeholder: 'Select',
                            errorText: errors.visible(DependantField.relation),
                            // The account holder's own record is always
                            // "Self"; the control says why it cannot change.
                            enabled: !form.isSelf,
                            helperText: form.isSelf
                                ? 'This is your own record, so the relation '
                                      'cannot be changed.'
                                : null,
                            onTap: () => _pickRelation(
                              form.relation,
                              isSelf: form.isSelf,
                            ),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          ProfilePickerField(
                            label: 'Date of birth',
                            iconName: MedIcon.calendar,
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
                            iconName: MedIcon.records,
                            value: form.gender,
                            placeholder: 'Select',
                            errorText: errors.visible(DependantField.gender),
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
                            iconName: MedIcon.hospital,
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
                        errorText: errors.visible(DependantField.phone),
                        helperText:
                            'Optional. Appointment reminders for them go to '
                            'this number as well as yours.',
                        textInputAction: TextInputAction.done,
                        onChanged: _controller.setPhone,
                      ),
                    ),
                    SizedBox(height: AppSpacing.x6.h),

                    AppButton(
                      label: _isEditing ? 'Save Changes' : 'Add Family Member',
                      fullWidth: true,
                      loading: form.isSaving,
                      onPressed: _save,
                    ),
                    SizedBox(height: AppSpacing.x3.h),
                    // No Remove control on the account holder's record: the
                    // store refuses it, so it is absent rather than doomed.
                    if (_isEditing && !form.isSelf)
                      AppButton(
                        label: 'Remove from Family',
                        variant: AppButtonVariant.danger,
                        fullWidth: true,
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
    context.go(AppRoutes.dependants);
  }
}
