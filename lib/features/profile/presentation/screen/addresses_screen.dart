import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../domain/entities/address.dart';
import '../components/profile_option_sheet.dart';
import '../components/profile_picker_field.dart';

/// Saved addresses (`/profile/address`) — CM-50, over
/// `GET`/`POST`/`PATCH`/`DELETE /patient/me/addresses` and
/// `POST /{id}/default` (§6.2), through the cache.
///
/// The form uses the API's structured columns (label, three lines, city,
/// state, PIN). A PATCH sends `If-Match`; a stale version reloads the list
/// and asks for a retry. Server field errors land on the form's fields, so
/// the sheet stays open until the save actually succeeds.
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addressesProvider);
    final busy = ref.watch(
      addressMutationControllerProvider.select((s) => s.isBusy),
    );
    Future<void> refresh() =>
        ref.read(addressesProvider.notifier).refresh(force: true);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInnerHeader(
              title: 'Saved Addresses',
              onBack: () => _leave(context),
              backSemanticLabel: 'Back to profile',
            ),
            Expanded(
              child: state.isLoading
                  ? SingleChildScrollView(
                      child: AppSkeletonList(
                        count: 2,
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
                      headline: 'We could not load your addresses',
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
                            AppEmptyView(
                              iconName: PhIcon.mapPin,
                              headline: 'No saved addresses',
                              body:
                                  'Save the address a home sample collection '
                                  'should come to, and it will be offered at '
                                  'checkout instead of typed out each time.',
                              actionLabel: 'Add an Address',
                              onAction: () => _add(context, ref),
                            )
                          else ...[
                            for (final address in state.value!)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: AppSpacing.x3.h,
                                ),
                                child: _AddressCard(
                                  address: address,
                                  isBusy: busy,
                                  onEdit: () => _edit(context, ref, address),
                                  onMakeDefault: address.isDefault
                                      ? null
                                      : () =>
                                            _makeDefault(context, ref, address),
                                  onRemove: () =>
                                      _remove(context, ref, address),
                                ),
                              ),
                            SizedBox(height: AppSpacing.x2.h),
                            AppButton(
                              label: 'Add Address',
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
    final saved = await showAddressFormSheet(
      context,
      onSubmit: (draft) =>
          ref.read(addressMutationControllerProvider.notifier).create(draft),
    );
    if (saved != true || !context.mounted) return;
    ref.read(toastControllerProvider.notifier).show('Address saved');
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Address address,
  ) async {
    final saved = await showAddressFormSheet(
      context,
      existing: address,
      onSubmit: (draft) => ref
          .read(addressMutationControllerProvider.notifier)
          .update(
            address.id,
            draft,
            // The version now on file — after "changed elsewhere" the list
            // is reloaded, and the copy this sheet opened with would
            // conflict on every retry (BL-PROF-011).
            ifMatch: _versionOf(ref, address),
            makeDefault: draft.isDefault && !address.isDefault,
          ),
    );
    if (saved != true || !context.mounted) return;
    ref.read(toastControllerProvider.notifier).show('${address.label} updated');
  }

  Future<void> _makeDefault(
    BuildContext context,
    WidgetRef ref,
    Address address,
  ) async {
    final failure = await ref
        .read(addressMutationControllerProvider.notifier)
        .setDefault(address.id);
    if (!context.mounted) return;
    ref
        .read(toastControllerProvider.notifier)
        .show(
          failure?.userMessage ??
              '${address.label} is now your default address',
        );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Address address,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Remove ${address.label}?',
      consequence: address.isDefault
          ? '${address.singleLine} is your default address. Home visits and '
                'invoices will fall back to another saved address, or to none '
                'if this is your last.'
          : '${address.singleLine} will no longer be offered when a home '
                'visit or an invoice needs an address.',
      confirmLabel: 'Remove Address',
      iconName: PhIcon.xCircle,
    );
    if (confirmed != true || !context.mounted) return;

    final failure = await ref
        .read(addressMutationControllerProvider.notifier)
        .delete(address.id);
    if (!context.mounted) return;
    ref
        .read(toastControllerProvider.notifier)
        .show(failure?.userMessage ?? '${address.label} removed');
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.profile);
  }
}

/// One saved address, its lines stacked as they would be written on a parcel.
class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.isBusy,
    required this.onEdit,
    required this.onMakeDefault,
    required this.onRemove,
  });

  final Address address;
  final bool isBusy;
  final VoidCallback onEdit;

  /// Null when this is already the default.
  final VoidCallback? onMakeDefault;
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
              AppIcon(PhIcon.mapPin, size: 20, color: AppColors.brand),
              SizedBox(width: AppSpacing.x2.w),
              Expanded(
                child: Text(
                  address.label,
                  style: AppText.poppins(
                    size: AppFontSize.body,
                    weight: AppText.bold,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
              if (address.isDefault) ...[
                SizedBox(width: AppSpacing.x2.w),
                const AppBadge(label: 'Default', tone: AppBadgeTone.brand),
              ],
            ],
          ),
          SizedBox(height: AppSpacing.x3.h),
          for (final line in address.lines)
            Padding(
              padding: EdgeInsets.only(bottom: 2.h),
              child: Text(
                line,
                style: AppText.poppins(
                  size: AppFontSize.base,
                  height: 1.5,
                  color: AppColors.textBody,
                ),
              ),
            ),
          if (address.phoneE164 != null)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(
                'Contact: ${address.phoneE164}',
                style: AppText.poppins(
                  size: AppFontSize.xs,
                  color: AppColors.textMuted,
                ),
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
                semanticLabel: 'Edit the ${address.label} address',
                onPressed: onEdit,
              ),
              if (onMakeDefault != null)
                AppButton(
                  label: 'Make Default',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  disabled: isBusy,
                  semanticLabel: 'Make ${address.label} the default address',
                  onPressed: onMakeDefault,
                ),
              AppButton(
                label: 'Remove',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                disabled: isBusy,
                semanticLabel: 'Remove the ${address.label} address',
                onPressed: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Adds or edits one saved address. The sheet performs the save through
/// [onSubmit] so a server field error can be shown on the field; it pops
/// `true` only once the server has accepted the address.
Future<bool?> showAddressFormSheet(
  BuildContext context, {
  required Future<Failure?> Function(AddressDraft draft) onSubmit,
  Address? existing,
}) {
  return showAppSheet<bool>(
    context,
    title: existing == null ? 'Add address' : 'Edit address',
    builder: (sheetContext) =>
        _AddressForm(existing: existing, onSubmit: onSubmit),
  );
}

class _AddressForm extends StatefulWidget {
  const _AddressForm({required this.onSubmit, this.existing});

  final Future<Failure?> Function(AddressDraft draft) onSubmit;
  final Address? existing;

  @override
  State<_AddressForm> createState() => _AddressFormState();
}

/// Widget-local form state — the draft lives exactly as long as the sheet.
class _AddressFormState extends State<_AddressForm> {
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _line3;
  late final TextEditingController _city;
  late final TextEditingController _stateName;
  late final TextEditingController _pincode;

  /// The address's own contact number (`phone_e164`), digits only; the
  /// country code is [_code].
  late final TextEditingController _phone;
  CountryCode _code = CountryCodes.india;

  String? _label;
  late bool _isDefault;
  bool _submitted = false;
  bool _isSaving = false;
  Map<String, String> _errors = const {};
  String? _formError;

  /// Wire field names (§6.2), so server errors map 1:1.
  static const String _fieldLabel = 'label';
  static const String _fieldLine1 = 'address_line1';
  static const String _fieldLine2 = 'address_line2';
  static const String _fieldLine3 = 'address_line3';
  static const String _fieldCity = 'city';
  static const String _fieldState = 'state';
  static const String _fieldPincode = 'pincode';
  static const String _fieldPhone = 'phone_e164';

  /// The labels offered. Free text would give four addresses all called
  /// "home"; the list keeps them distinguishable at the checkout step.
  static const List<String> _labels = [
    'Home',
    'Work',
    'Parents',
    'Clinic',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    // A label set elsewhere ("Beach house") is kept and offered, not
    // replaced by "Other" on the first save (BL-PROF-024).
    _label = existing?.label;
    _line1 = TextEditingController(text: existing?.addressLine1 ?? '');
    _line2 = TextEditingController(text: existing?.addressLine2 ?? '');
    _line3 = TextEditingController(text: existing?.addressLine3 ?? '');
    _city = TextEditingController(text: existing?.city ?? '');
    _stateName = TextEditingController(text: existing?.state ?? '');
    _pincode = TextEditingController(text: existing?.pincode ?? '');
    final stored = existing?.phoneE164 ?? '';
    _code = CountryCodes.all.firstWhere(
      (c) => stored.startsWith(c.dialCode),
      orElse: () => CountryCodes.india,
    );
    _phone = TextEditingController(
      text: stored.startsWith(_code.dialCode)
          ? stored.substring(_code.dialCode.length)
          : Validators.digitsOf(stored),
    );
    _isDefault = existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _line1.dispose();
    _line2.dispose();
    _line3.dispose();
    _city.dispose();
    _stateName.dispose();
    _pincode.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _errorFor(String field) => _submitted ? _errors[field] : null;

  /// The contact number in E.164, or null when the field is empty (which
  /// clears it on the server).
  String? get _phoneE164 {
    final digits = Validators.digitsOf(_phone.text);
    return digits.isEmpty ? null : '${_code.dialCode}$digits';
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_label == null) errors[_fieldLabel] = 'Choose a label';
    final line1 = Validators.addressLine(
      _line1.text,
      label: 'the street address',
    );
    if (line1 != null) errors[_fieldLine1] = line1;
    if (_line1.text.trim().length > 200) {
      errors[_fieldLine1] = 'Keep this line under 200 characters';
    }
    final city = Validators.requiredField('a city', _city.text);
    if (city != null) errors[_fieldCity] = city;
    final stateName = Validators.requiredField('a state', _stateName.text);
    if (stateName != null) errors[_fieldState] = stateName;
    final pincode = Validators.pincode(_pincode.text);
    if (pincode != null) errors[_fieldPincode] = pincode;
    final phone = _phoneE164;
    if (phone != null) {
      final phoneError = Validators.phoneE164(phone);
      if (phoneError != null) errors[_fieldPhone] = phoneError;
    }
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
      AddressDraft(
        label: _label!,
        addressLine1: _line1.text.trim(),
        addressLine2: _line2.text.trim().isEmpty ? null : _line2.text.trim(),
        addressLine3: _line3.text.trim().isEmpty ? null : _line3.text.trim(),
        city: _city.text.trim(),
        state: _stateName.text.trim(),
        pincode: Validators.digitsOf(_pincode.text),
        // Opens with the number on file, so an untouched form keeps it
        // (BL-PROF-024); emptying the field removes it.
        phoneE164: _phoneE164,
        isDefault: _isDefault,
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

  /// The fixed labels, plus this address's own when it is not one of them.
  List<String> get _labelOptions {
    final own = widget.existing?.label;
    if (own == null || _labels.contains(own)) return _labels;
    return [own, ..._labels];
  }

  Future<void> _pickLabel() async {
    final picked = await showProfileOptionSheet<String>(
      context,
      title: 'Label',
      selected: _label,
      options: [
        for (final label in _labelOptions)
          ProfileOption<String>(value: label, label: label),
      ],
    );
    if (picked == null) return;
    setState(() => _label = picked);
    _recheck();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfilePickerField(
          label: 'Label',
          iconName: PhIcon.mapPin,
          value: _label,
          placeholder: 'Home, Work …',
          errorText: _errorFor(_fieldLabel),
          onTap: _pickLabel,
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppTextField(
          label: 'Flat, house no., building, street',
          controller: _line1,
          hintText: '12 MG Road',
          maxLength: 200,
          maxLines: 2,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.streetAddressLine1],
          errorText: _errorFor(_fieldLine1),
          onChanged: (_) => _recheck(),
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppTextField(
          label: 'Area, landmark',
          controller: _line2,
          hintText: 'Near the metro station',
          maxLength: 200,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.streetAddressLine2],
          helperText: 'Optional',
          errorText: _errorFor(_fieldLine2),
          onChanged: (_) => _recheck(),
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppTextField(
          label: 'Additional line',
          controller: _line3,
          hintText: 'Apartment 4B',
          maxLength: 200,
          textCapitalization: TextCapitalization.words,
          helperText: 'Optional',
          errorText: _errorFor(_fieldLine3),
          onChanged: (_) => _recheck(),
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppTextField(
          label: 'City',
          controller: _city,
          hintText: 'Kochi',
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.addressCity],
          errorText: _errorFor(_fieldCity),
          onChanged: (_) => _recheck(),
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppTextField(
          label: 'State',
          controller: _stateName,
          hintText: 'Kerala',
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.addressState],
          errorText: _errorFor(_fieldState),
          onChanged: (_) => _recheck(),
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppTextField(
          label: 'PIN code',
          controller: _pincode,
          hintText: '682001',
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofillHints: const [AutofillHints.postalCode],
          textInputAction: TextInputAction.next,
          errorText: _errorFor(_fieldPincode),
          onChanged: (_) => _recheck(),
        ),
        SizedBox(height: AppSpacing.x4.h),
        // `phone_e164` on the address (§6.2) — shown on the card as
        // "Contact: …" and editable here.
        AppPhoneField(
          label: 'Phone at this address',
          controller: _phone,
          countryCode: _code,
          helperText:
              'Optional. Who to call when someone comes to this '
              'address.',
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
        _DefaultToggleRow(
          value: _isDefault,
          isLocked: widget.existing?.isDefault ?? false,
          onChanged: (next) => setState(() => _isDefault = next),
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
          label: widget.existing == null ? 'Save Address' : 'Save Changes',
          fullWidth: true,
          loading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// The "use this address by default" row.
class _DefaultToggleRow extends StatelessWidget {
  const _DefaultToggleRow({
    required this.value,
    required this.isLocked,
    required this.onChanged,
  });

  final bool value;

  /// True when this address is already the default: unsetting it has to be
  /// done by making another one default, so the switch says so.
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
                  'Use as my default address',
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: AppText.medium,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  isLocked
                      ? 'Already your default. To change it, make another '
                            'address default.'
                      : 'Offered first for home visits and on invoices.',
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
            label: 'Use this as the default address',
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

/// [address]'s version as the (possibly reloaded) list now has it.
int _versionOf(WidgetRef ref, Address address) {
  final list = ref.read(addressesProvider).value;
  if (list == null) return address.version;
  for (final item in list) {
    if (item.id == address.id) return item.version;
  }
  return address.version;
}
