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
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_phone_field.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/app_switch.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../common/cached/presentation/components/cached_status_bar.dart';
import '../../application/providers/profile_mutations_provider.dart';
import '../../application/providers/profile_provider.dart';
import '../../domain/entities/emergency_contact.dart';
import '../components/profile_option_sheet.dart';
import '../components/profile_picker_field.dart';

/// Emergency contacts (`/profile/emergency`) — CM-49, over
/// `GET`/`POST`/`PATCH`/`DELETE /patient/me/emergency-contacts` and
/// `POST /{id}/primary` (§6.3), through the cache.
///
/// The ambulance screen reads the primary contact from the same provider, so
/// a contact added here is the contact offered there.
///
/// ## Honesty notes
///
/// * There is no "Call" button. This build ships no telephony; the number is
///   shown in full, selectable, instead.
/// * The form performs the save itself, so a server field error lands on the
///   field and the sheet only closes once the server has accepted it.
class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(emergencyContactsProvider);
    final busy = ref.watch(
      contactMutationControllerProvider.select((s) => s.isBusy),
    );
    Future<void> refresh() =>
        ref.read(emergencyContactsProvider.notifier).refresh(force: true);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInnerHeader(
              title: 'Emergency Contacts',
              onBack: () => _leave(context),
              backSemanticLabel: 'Back to profile',
            ),
            Expanded(
              child: state.isLoading
                  ? SingleChildScrollView(
                      child: AppSkeletonList(
                        count: 3,
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.x5.w,
                          AppSpacing.x4.h,
                          AppSpacing.x5.w,
                          AppSpacing.x6.h,
                        ),
                      ),
                    )
                  : state.isError
                  ? AppErrorView(
                      failure: state.failure!,
                      headline: 'We could not load your contacts',
                      onRetry: refresh,
                    )
                  : AppRefreshIndicator(
                      onRefresh: refresh,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.x5.w,
                          AppSpacing.x4.h,
                          AppSpacing.x5.w,
                          AppSpacing.x8.h,
                        ),
                        children: [
                          CachedStatusBar(state: state, onRefresh: refresh),
                          if (state.value!.isEmpty)
                            // A fresh account has none, so this empty state
                            // is the first thing a real user sees.
                            AppEmptyView(
                              iconName: PhIcon.bell,
                              headline: 'No emergency contact yet',
                              body:
                                  'If you are ever brought in unconscious, '
                                  'this is who the hospital calls. Add one '
                                  'person you would want reached.',
                              actionLabel: 'Add a Contact',
                              onAction: () => _add(context, ref),
                              secondaryLabel: 'Ambulance Numbers',
                              onSecondary: () =>
                                  context.push(AppRoutes.ambulance),
                            )
                          else ...[
                            Text(
                              state.value!.length == 1
                                  ? 'One contact. The primary contact is '
                                        'called first.'
                                  : '${state.value!.length} contacts. The '
                                        'primary contact is called first.',
                              style: AppText.poppins(
                                size: AppFontSize.xs,
                                height: 1.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                            SizedBox(height: AppSpacing.x4.h),
                            for (final contact in state.value!)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: AppSpacing.x3.h,
                                ),
                                child: _ContactCard(
                                  contact: contact,
                                  isBusy: busy,
                                  onEdit: () => _edit(context, ref, contact),
                                  onMakePrimary: contact.isPrimary
                                      ? null
                                      : () =>
                                            _makePrimary(context, ref, contact),
                                  onRemove: () =>
                                      _remove(context, ref, contact),
                                ),
                              ),
                            SizedBox(height: AppSpacing.x2.h),
                            AppButton(
                              label: 'Add Contact',
                              variant: AppButtonVariant.secondary,
                              fullWidth: true,
                              onPressed: () => _add(context, ref),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final saved = await showContactFormSheet(
      context,
      onSubmit: (draft) =>
          ref.read(contactMutationControllerProvider.notifier).create(draft),
    );
    if (saved != true || !context.mounted) return;
    ref.read(toastControllerProvider.notifier).show('Contact added');
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    EmergencyContact contact,
  ) async {
    final saved = await showContactFormSheet(
      context,
      existing: contact,
      onSubmit: (draft) => ref
          .read(contactMutationControllerProvider.notifier)
          .update(
            contact.id,
            draft,
            // The version now on file (reloaded after a conflict), not the
            // one this sheet opened with (BL-PROF-011).
            ifMatch: _versionOf(ref, contact),
            makePrimary: draft.isPrimary && !contact.isPrimary,
          ),
    );
    if (saved != true || !context.mounted) return;
    ref.read(toastControllerProvider.notifier).show('${contact.name} updated');
  }

  Future<void> _makePrimary(
    BuildContext context,
    WidgetRef ref,
    EmergencyContact contact,
  ) async {
    final failure = await ref
        .read(contactMutationControllerProvider.notifier)
        .setPrimary(contact.id);
    if (!context.mounted) return;
    ref
        .read(toastControllerProvider.notifier)
        .show(
          failure?.userMessage ?? '${contact.name} is now your primary contact',
        );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    EmergencyContact contact,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Remove ${contact.name}?',
      consequence: contact.isPrimary
          ? '${contact.name} is your primary contact. If you are brought in '
                'unconscious the hospital will have no one to call until you '
                'add another contact.'
          : 'The hospital will no longer be able to reach ${contact.name} on '
                'your behalf. You can add them again later.',
      confirmLabel: 'Remove Contact',
      iconName: PhIcon.xCircle,
    );
    if (confirmed != true || !context.mounted) return;

    final failure = await ref
        .read(contactMutationControllerProvider.notifier)
        .delete(contact.id);
    if (!context.mounted) return;
    ref
        .read(toastControllerProvider.notifier)
        .show(failure?.userMessage ?? '${contact.name} removed');
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.profile);
  }
}

/// One contact: who they are, their number, and the three things you can do.
class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.isBusy,
    required this.onEdit,
    required this.onMakePrimary,
    required this.onRemove,
  });

  final EmergencyContact contact;
  final bool isBusy;
  final VoidCallback onEdit;

  /// Null when this contact is already primary.
  final VoidCallback? onMakePrimary;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      contact.name,
                      style: AppText.poppins(
                        size: AppFontSize.body,
                        weight: AppText.bold,
                        color: AppColors.textStrong,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      contact.relation,
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (contact.isPrimary) ...[
                SizedBox(width: AppSpacing.x2.w),
                const AppBadge(label: 'Primary', tone: AppBadgeTone.brand),
              ],
            ],
          ),
          SizedBox(height: AppSpacing.x3.h),
          // Selectable rather than a Call button: there is no dialler in
          // this build.
          SelectableText(
            contact.phoneE164,
            style: AppText.inter(
              size: AppFontSize.base,
              weight: AppText.medium,
              color: AppColors.textLink,
            ),
          ),
          SizedBox(height: AppSpacing.x3.h),
          Wrap(
            spacing: AppSpacing.x2.w,
            runSpacing: AppSpacing.x2.h,
            children: [
              AppButton(
                label: 'Edit',
                variant: AppButtonVariant.soft,
                size: AppButtonSize.sm,
                disabled: isBusy,
                semanticLabel: 'Edit ${contact.name}',
                onPressed: onEdit,
              ),
              if (onMakePrimary != null)
                AppButton(
                  label: 'Make Primary',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  disabled: isBusy,
                  semanticLabel: 'Make ${contact.name} the primary contact',
                  onPressed: onMakePrimary,
                ),
              AppButton(
                label: 'Remove',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                disabled: isBusy,
                semanticLabel: 'Remove ${contact.name}',
                onPressed: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Adds or edits one emergency contact. The sheet performs the save through
/// [onSubmit] and pops `true` once the server has accepted it.
Future<bool?> showContactFormSheet(
  BuildContext context, {
  required Future<Failure?> Function(ContactDraft draft) onSubmit,
  EmergencyContact? existing,
}) {
  return showAppSheet<bool>(
    context,
    title: existing == null ? 'Add emergency contact' : 'Edit contact',
    builder: (sheetContext) =>
        _ContactForm(existing: existing, onSubmit: onSubmit),
  );
}

class _ContactForm extends StatefulWidget {
  const _ContactForm({required this.onSubmit, this.existing});

  final Future<Failure?> Function(ContactDraft draft) onSubmit;
  final EmergencyContact? existing;

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

/// Widget-local form state: the draft lives exactly as long as the sheet.
class _ContactFormState extends State<_ContactForm> {
  late final TextEditingController _name;
  late final TextEditingController _phone;

  String? _relation;
  late bool _isPrimary;
  late CountryCode _code;

  bool _submitted = false;
  bool _isSaving = false;
  Map<String, String> _errors = const {};
  String? _formError;

  /// Wire field names (§6.3).
  static const String _fieldName = 'name';
  static const String _fieldRelation = 'relation';
  static const String _fieldPhone = 'phone_e164';

  /// `relation` is free text on the wire (≤ 50); these are the offered
  /// values, with "Other" as the escape hatch.
  static const List<String> _relations = [
    'Spouse',
    'Husband',
    'Wife',
    'Son',
    'Daughter',
    'Father',
    'Mother',
    'Brother',
    'Sister',
    'Friend',
    'Neighbour',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _relation = existing?.relation;
    _isPrimary = existing?.isPrimary ?? false;

    final stored = existing?.phoneE164 ?? '';
    _code = CountryCodes.all.firstWhere(
      (code) => stored.startsWith(code.dialCode),
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
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String get _e164 => '${_code.dialCode}${Validators.digitsOf(_phone.text)}';

  String? _errorFor(String field) => _submitted ? _errors[field] : null;

  Map<String, String> _validate() {
    final errors = <String, String>{};
    final nameError = Validators.personName(_name.text);
    if (nameError != null) errors[_fieldName] = nameError;
    if (_relation == null || _relation!.trim().isEmpty) {
      errors[_fieldRelation] = 'Choose a relation';
    }
    final phoneError = _code == CountryCodes.india
        ? Validators.phone(_phone.text)
        : Validators.phoneE164(_e164);
    if (phoneError != null) errors[_fieldPhone] = phoneError;
    return errors;
  }

  void _recheck() {
    if (!_submitted) return;
    setState(() => _errors = _validate());
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    final errors = _validate();
    setState(() {
      _submitted = true;
      _errors = errors;
      _formError = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _isSaving = true);
    final failure = await widget.onSubmit(
      ContactDraft(
        name: _name.text.trim(),
        relation: _relation!,
        phoneE164: _e164,
        isPrimary: _isPrimary,
      ),
    );
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isSaving = false;
      if (failure is ValidationFailure && failure.fieldErrors.isNotEmpty) {
        _errors = {..._errors, ...failure.fieldErrors};
      } else {
        _formError = failure.userMessage;
      }
    });
  }

  Future<void> _pickRelation() async {
    final picked = await showProfileOptionSheet<String>(
      context,
      title: 'Relation',
      selected: _relation,
      options: [
        for (final relation in _relations)
          ProfileOption<String>(value: relation, label: relation),
        if (_relation != null && !_relations.contains(_relation))
          ProfileOption<String>(value: _relation!, label: _relation!),
      ],
    );
    if (picked == null) return;
    setState(() => _relation = picked);
    _recheck();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          label: 'Full name',
          controller: _name,
          hintText: 'Ravi Nair',
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          errorText: _errorFor(_fieldName),
          onChanged: (_) => _recheck(),
        ),
        SizedBox(height: AppSpacing.x4.h),
        ProfilePickerField(
          label: 'Relation to you',
          iconName: PhIcon.folder,
          value: _relation,
          placeholder: 'Select',
          errorText: _errorFor(_fieldRelation),
          onTap: _pickRelation,
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppPhoneField(
          label: 'Mobile number',
          controller: _phone,
          countryCode: _code,
          errorText: _errorFor(_fieldPhone),
          textInputAction: TextInputAction.done,
          onCountryChanged: (next) {
            setState(() => _code = next);
            _recheck();
          },
          onChanged: (_) => _recheck(),
          onSubmitted: (_) => _submit(),
        ),
        SizedBox(height: AppSpacing.x4.h),
        _PrimaryToggleRow(
          value: _isPrimary,
          isLocked: widget.existing?.isPrimary ?? false,
          onChanged: (next) => setState(() => _isPrimary = next),
        ),
        if (_formError != null) ...[
          SizedBox(height: AppSpacing.x3.h),
          Container(
            padding: EdgeInsets.all(AppSpacing.x3.w),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: AppRadii.md,
            ),
            child: Text(
              _formError!,
              style: AppText.poppins(
                size: AppFontSize.xs,
                height: 1.45,
                color: AppColors.dangerText,
              ),
            ),
          ),
        ],
        SizedBox(height: AppSpacing.x5.h),
        AppButton(
          label: widget.existing == null ? 'Add Contact' : 'Save Changes',
          fullWidth: true,
          loading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// The "call this person first" row.
class _PrimaryToggleRow extends StatelessWidget {
  const _PrimaryToggleRow({
    required this.value,
    required this.isLocked,
    required this.onChanged,
  });

  final bool value;

  /// True when this contact is already primary; demoting has to be done by
  /// promoting someone else, so the control says so instead of pretending.
  final bool isLocked;
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
                  'Call this person first',
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: AppText.medium,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  isLocked
                      ? 'Already your primary contact. To change it, make '
                            'another contact primary.'
                      : 'Makes this your primary contact, replacing the '
                            'current one.',
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
            label: 'Make this the primary emergency contact',
            child: AppSwitch(
              value: value || isLocked,
              onChanged: isLocked ? null : onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// [contact]'s version as the (possibly reloaded) list now has it.
int _versionOf(WidgetRef ref, EmergencyContact contact) {
  final list = ref.read(emergencyContactsProvider).value;
  if (list == null) return contact.version;
  for (final item in list) {
    if (item.id == contact.id) return item.version;
  }
  return contact.version;
}
