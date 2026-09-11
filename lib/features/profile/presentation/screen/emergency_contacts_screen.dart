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
import '../../../../core/mock_data/models/patient.dart';
import '../../../../core/mock_data/models/support_content.dart';
import '../../../../core/mock_data/stores/profile_store.dart';
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
import '../components/profile_option_sheet.dart';
import '../components/profile_picker_field.dart';
import '../controllers/list_lifecycle_controller.dart';

/// Emergency contacts (`/profile/emergency`) — CM-49.
///
/// The audit's finding was blunt: *"Neither exists anywhere in the app."* This
/// screen is the whole feature — add, edit, re-order by primary, and remove —
/// over `emergencyContactsStoreProvider`, which the emergency/ambulance screen
/// reads too, so a contact added here is the contact offered there.
///
/// ## Honesty notes
///
/// * There is no "Call" button. This build ships no telephony, and a control
///   that looks like it calls your husband in an emergency and does nothing is
///   the most dangerous fake success in the app. The number is shown in full,
///   selectable, instead.
/// * `remove` returns `bool`, and it can refuse. The success message is
///   rendered **only** on a true return.
class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(emergencyContactsStoreProvider);
    final lifecycle = ref.watch(
      listLifecycleProvider(ProfileListKeys.emergencyContacts),
    );

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
            Expanded(child: _body(context, ref, contacts, lifecycle)),
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    List<EmergencyContact> contacts,
    ListLifecycleState lifecycle,
  ) {
    if (lifecycle.isLoading) {
      return SingleChildScrollView(
        child: AppSkeletonList(
          count: 3,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.x5.w,
            AppSpacing.x4.h,
            AppSpacing.x5.w,
            AppSpacing.x6.h,
          ),
        ),
      );
    }

    if (lifecycle.failure != null && contacts.isEmpty) {
      return AppErrorView(
        failure: lifecycle.failure!,
        headline: 'We could not load your contacts',
        onRetry: () => ref
            .read(
              listLifecycleProvider(ProfileListKeys.emergencyContacts).notifier,
            )
            .retry(),
      );
    }

    return AppRefreshIndicator(
      onRefresh: () => ref
          .read(
            listLifecycleProvider(ProfileListKeys.emergencyContacts).notifier,
          )
          .refresh(),
      child: contacts.isEmpty
          ? ListView(
              children: [
                // A fresh account has none, so this empty state is the first
                // thing a real user sees — it has to do the work.
                AppEmptyView(
                  iconName: MedIcon.bell,
                  headline: 'No emergency contact yet',
                  body:
                      'If you are ever brought in unconscious, this is who the '
                      'hospital calls. Add one person you would want reached.',
                  actionLabel: 'Add a Contact',
                  onAction: () => _addContact(context, ref),
                  secondaryLabel: 'Ambulance Numbers',
                  onSecondary: () => context.push(AppRoutes.ambulance),
                ),
              ],
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.x5.w,
                AppSpacing.x4.h,
                AppSpacing.x5.w,
                AppSpacing.x8.h,
              ),
              children: [
                if (lifecycle.failure != null) ...[
                  AppErrorBanner(
                    message: lifecycle.failure!.userMessage,
                    onTap: () => ref
                        .read(
                          listLifecycleProvider(
                            ProfileListKeys.emergencyContacts,
                          ).notifier,
                        )
                        .refresh(),
                  ),
                  SizedBox(height: AppSpacing.x4.h),
                ],
                Text(
                  contacts.length == 1
                      ? 'One contact. The primary contact is called first.'
                      : '${contacts.length} contacts. The primary contact is '
                            'called first.',
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: AppSpacing.x4.h),
                for (final contact in contacts)
                  Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.x3.h),
                    child: _ContactCard(
                      contact: contact,
                      onEdit: () => _editContact(context, ref, contact),
                      onMakePrimary: contact.isPrimary
                          ? null
                          : () => _makePrimary(ref, contact),
                      onRemove: () => _removeContact(context, ref, contact),
                    ),
                  ),
                SizedBox(height: AppSpacing.x2.h),
                AppButton(
                  label: 'Add Contact',
                  variant: AppButtonVariant.secondary,
                  fullWidth: true,
                  onPressed: () => _addContact(context, ref),
                ),
              ],
            ),
    );
  }

  Future<void> _addContact(BuildContext context, WidgetRef ref) async {
    final result = await showContactFormSheet(context);
    if (result == null) return;
    final stored = ref
        .read(emergencyContactsStoreProvider.notifier)
        .add(
          name: result.name,
          relation: result.relation,
          phone: result.phone,
          isPrimary: result.isPrimary,
        );
    if (!context.mounted) return;
    ref
        .read(toastControllerProvider.notifier)
        .show(
          stored.isPrimary
              ? '${stored.name} added as your primary contact'
              : '${stored.name} added',
        );
  }

  Future<void> _editContact(
    BuildContext context,
    WidgetRef ref,
    EmergencyContact contact,
  ) async {
    final result = await showContactFormSheet(context, existing: contact);
    if (result == null) return;

    final store = ref.read(emergencyContactsStoreProvider.notifier);
    store.patch(
      contact.id,
      name: result.name,
      relation: result.relation,
      phone: result.phone,
    );
    // `patch` cannot change who is primary, so a promotion goes through the
    // one method that maintains the "exactly one primary" rule.
    if (result.isPrimary && !contact.isPrimary) store.setPrimary(contact.id);

    if (!context.mounted) return;
    ref.read(toastControllerProvider.notifier).show('${result.name} updated');
  }

  void _makePrimary(WidgetRef ref, EmergencyContact contact) {
    ref.read(emergencyContactsStoreProvider.notifier).setPrimary(contact.id);
    ref
        .read(toastControllerProvider.notifier)
        .show('${contact.name} is now your primary contact');
  }

  Future<void> _removeContact(
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
      iconName: MedIcon.closeCircle,
    );
    if (confirmed != true || !context.mounted) return;

    final removed = ref
        .read(emergencyContactsStoreProvider.notifier)
        .remove(contact.id);
    if (!context.mounted) return;

    // `remove` returns false for an unknown id — never report success on it.
    ref
        .read(toastControllerProvider.notifier)
        .show(
          removed
              ? '${contact.name} removed'
              : 'We could not remove ${contact.name}. Pull down to refresh '
                    'and try again.',
        );
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
    required this.onEdit,
    required this.onMakePrimary,
    required this.onRemove,
  });

  final EmergencyContact contact;
  final VoidCallback onEdit;

  /// Null when this contact is already primary — the control is absent rather
  /// than present-and-inert.
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
          // Selectable rather than a Call button: there is no dialer in this
          // build, so the honest control is the one that lets you read or copy
          // the number yourself.
          SelectableText(
            contact.phone,
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
                semanticLabel: 'Edit ${contact.name}',
                onPressed: onEdit,
              ),
              if (onMakePrimary != null)
                AppButton(
                  label: 'Make Primary',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  semanticLabel: 'Make ${contact.name} the primary contact',
                  onPressed: onMakePrimary,
                ),
              AppButton(
                label: 'Remove',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
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

/// What [showContactFormSheet] returns — a validated contact, not a stored one.
@immutable
class ContactFormResult {
  const ContactFormResult({
    required this.name,
    required this.relation,
    required this.phone,
    required this.isPrimary,
  });

  final String name;
  final String relation;

  /// E.164, so the stored number is dialable from anywhere.
  final String phone;

  final bool isPrimary;
}

/// Adds or edits one emergency contact.
///
/// Returns the validated values, or null when dismissed — the caller writes to
/// the store, so this sheet cannot half-save anything.
Future<ContactFormResult?> showContactFormSheet(
  BuildContext context, {
  EmergencyContact? existing,
}) {
  return showAppSheet<ContactFormResult>(
    context,
    title: existing == null ? 'Add emergency contact' : 'Edit contact',
    builder: (sheetContext) => _ContactForm(existing: existing),
  );
}

class _ContactForm extends StatefulWidget {
  const _ContactForm({this.existing});

  final EmergencyContact? existing;

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

/// Widget-local form state: the draft lives exactly as long as the sheet, and
/// nothing outside it can read a half-typed contact.
class _ContactFormState extends State<_ContactForm> {
  late final TextEditingController _name;
  late final TextEditingController _phone;

  String? _relation;
  late bool _isPrimary;
  late CountryCode _code;

  bool _submitted = false;
  Map<String, String> _errors = const {};

  static const String _fieldName = 'name';
  static const String _fieldRelation = 'relation';
  static const String _fieldPhone = 'phone';

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _relation = existing?.relation;
    _isPrimary = existing?.isPrimary ?? false;

    // Split a stored E.164 back into a country code and a national number, so
    // editing a contact does not lose the country or show "+91" twice.
    final stored = existing?.phone ?? '';
    final matched = CountryCodes.all.firstWhere(
      (code) => stored.startsWith(code.dialCode),
      orElse: () => CountryCodes.india,
    );
    _code = matched;
    _phone = TextEditingController(
      text: stored.startsWith(matched.dialCode)
          ? stored.substring(matched.dialCode.length)
          : Validators.digitsOf(stored),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _errorFor(String field) => _submitted ? _errors[field] : null;

  Map<String, String> _validate() {
    final errors = <String, String>{};
    final nameError = Validators.personName(_name.text);
    if (nameError != null) errors[_fieldName] = nameError;
    if (_relation == null) errors[_fieldRelation] = 'Choose a relation';
    final phoneError = Validators.phone(_phone.text);
    if (phoneError != null) errors[_fieldPhone] = phoneError;
    return errors;
  }

  /// Re-validates on every change once submit has been pressed, so an error
  /// clears the moment the field is actually right (audit §3.5.4).
  void _recheck() {
    if (!_submitted) return;
    setState(() => _errors = _validate());
  }

  void _submit() {
    final errors = _validate();
    setState(() {
      _submitted = true;
      _errors = errors;
    });
    if (errors.isNotEmpty) return;

    Navigator.of(context).pop(
      ContactFormResult(
        name: _name.text.trim(),
        relation: _relation!,
        phone: '${_code.dialCode}${Validators.digitsOf(_phone.text)}',
        isPrimary: _isPrimary,
      ),
    );
  }

  Future<void> _pickRelation() async {
    final picked = await showProfileOptionSheet<String>(
      context,
      title: 'Relation',
      selected: _relation,
      options: [
        for (final relation in PatientRelations.all)
          ProfileOption<String>(value: relation, label: relation),
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
          hintText: 'Michael Johnson',
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          errorText: _errorFor(_fieldName),
          onChanged: (_) => _recheck(),
        ),
        SizedBox(height: AppSpacing.x4.h),
        ProfilePickerField(
          label: 'Relation to you',
          iconName: MedIcon.records,
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
          // The first contact is primary whatever the switch says, and the
          // current primary cannot demote itself without another contact to
          // promote — so the row explains rather than silently disagreeing.
          isLocked: widget.existing?.isPrimary ?? false,
          onChanged: (next) => setState(() => _isPrimary = next),
        ),
        SizedBox(height: AppSpacing.x5.h),
        AppButton(
          label: widget.existing == null ? 'Add Contact' : 'Save Changes',
          fullWidth: true,
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
