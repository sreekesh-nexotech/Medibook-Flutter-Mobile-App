import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/error_view.dart';
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
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/app_switch.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/profile_option_sheet.dart';
import '../components/profile_picker_field.dart';
import '../controllers/list_lifecycle_controller.dart';

/// Saved addresses (`/profile/address`) — CM-50.
///
/// Backed by `addressesStoreProvider`, which the booking flow reads when a
/// home sample collection needs a destination — so this is not a private
/// Profile list, and an address removed here disappears from booking too.
/// That is why removal is a `showAppConfirmDialog` that names the
/// consequence, and why the store's `bool remove` return is honoured.
///
/// Note the field is `stateName` on the store's `add` (the model's own field is
/// `state`, which would shadow `State` in a widget file).
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesStoreProvider);
    final lifecycle = ref.watch(
      listLifecycleProvider(ProfileListKeys.addresses),
    );

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
            Expanded(child: _body(context, ref, addresses, lifecycle)),
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    List<Address> addresses,
    ListLifecycleState lifecycle,
  ) {
    final notifier = listLifecycleProvider(ProfileListKeys.addresses).notifier;

    if (lifecycle.isLoading) {
      return SingleChildScrollView(
        child: AppSkeletonList(
          count: 2,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.x5.w,
            AppSpacing.x4.h,
            AppSpacing.x5.w,
            AppSpacing.x6.h,
          ),
        ),
      );
    }

    if (lifecycle.failure != null && addresses.isEmpty) {
      return AppErrorView(
        failure: lifecycle.failure!,
        headline: 'We could not load your addresses',
        onRetry: () => ref.read(notifier).retry(),
      );
    }

    return AppRefreshIndicator(
      onRefresh: () => ref.read(notifier).refresh(),
      child: addresses.isEmpty
          ? ListView(
              children: [
                AppEmptyView(
                  iconName: MedIcon.location,
                  headline: 'No saved addresses',
                  body:
                      'Save the address a home sample collection should come '
                      'to, and it will be offered at checkout instead of '
                      'typed out each time.',
                  actionLabel: 'Add an Address',
                  onAction: () => _addAddress(context, ref),
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
                    onTap: () => ref.read(notifier).refresh(),
                  ),
                  SizedBox(height: AppSpacing.x4.h),
                ],
                for (final address in addresses)
                  Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.x3.h),
                    child: _AddressCard(
                      address: address,
                      onEdit: () => _editAddress(context, ref, address),
                      onMakeDefault: address.isDefault
                          ? null
                          : () => _makeDefault(ref, address),
                      onRemove: () => _removeAddress(context, ref, address),
                    ),
                  ),
                SizedBox(height: AppSpacing.x2.h),
                AppButton(
                  label: 'Add Address',
                  variant: AppButtonVariant.secondary,
                  fullWidth: true,
                  onPressed: () => _addAddress(context, ref),
                ),
              ],
            ),
    );
  }

  Future<void> _addAddress(BuildContext context, WidgetRef ref) async {
    final result = await showAddressFormSheet(context);
    if (result == null) return;
    final stored = ref
        .read(addressesStoreProvider.notifier)
        .add(
          label: result.label,
          line1: result.line1,
          line2: result.line2,
          city: result.city,
          stateName: result.stateName,
          pincode: result.pincode,
          isDefault: result.isDefault,
        );
    if (!context.mounted) return;
    ref
        .read(toastControllerProvider.notifier)
        .show(
          stored.isDefault
              ? '${stored.label} saved as your default address'
              : '${stored.label} saved',
        );
  }

  Future<void> _editAddress(
    BuildContext context,
    WidgetRef ref,
    Address address,
  ) async {
    final result = await showAddressFormSheet(context, existing: address);
    if (result == null) return;

    final store = ref.read(addressesStoreProvider.notifier);
    store.update(
      address.copyWith(
        label: result.label,
        line1: result.line1,
        line2: result.line2,
        city: result.city,
        state: result.stateName,
        pincode: result.pincode,
      ),
    );
    // `isDefault` is the store's to maintain — exactly one address holds it.
    if (result.isDefault && !address.isDefault) store.setDefault(address.id);

    if (!context.mounted) return;
    ref.read(toastControllerProvider.notifier).show('${result.label} updated');
  }

  void _makeDefault(WidgetRef ref, Address address) {
    ref.read(addressesStoreProvider.notifier).setDefault(address.id);
    ref
        .read(toastControllerProvider.notifier)
        .show('${address.label} is now your default address');
  }

  Future<void> _removeAddress(
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
      iconName: MedIcon.closeCircle,
    );
    if (confirmed != true || !context.mounted) return;

    final removed = ref
        .read(addressesStoreProvider.notifier)
        .remove(address.id);
    if (!context.mounted) return;

    // False means nothing was removed — say so rather than claim a deletion.
    ref
        .read(toastControllerProvider.notifier)
        .show(
          removed
              ? '${address.label} removed'
              : 'We could not remove ${address.label}. Pull down to refresh '
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

/// One saved address, its lines stacked as they would be written on a parcel.
class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onMakeDefault,
    required this.onRemove,
  });

  final Address address;
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
              AppIcon(MedIcon.location, size: 20, color: AppColors.brand),
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
          SizedBox(height: AppSpacing.x3.h),
          Wrap(
            spacing: AppSpacing.x2.w,
            runSpacing: AppSpacing.x2.h,
            children: [
              AppButton(
                label: 'Edit',
                variant: AppButtonVariant.soft,
                size: AppButtonSize.sm,
                semanticLabel: 'Edit the ${address.label} address',
                onPressed: onEdit,
              ),
              if (onMakeDefault != null)
                AppButton(
                  label: 'Make Default',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  semanticLabel: 'Make ${address.label} the default address',
                  onPressed: onMakeDefault,
                ),
              AppButton(
                label: 'Remove',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
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

/// What [showAddressFormSheet] returns — validated values, nothing stored.
@immutable
class AddressFormResult {
  const AddressFormResult({
    required this.label,
    required this.line1,
    required this.line2,
    required this.city,
    required this.stateName,
    required this.pincode,
    required this.isDefault,
  });

  final String label;
  final String line1;

  /// Null rather than empty when there is no second line, matching the model.
  final String? line2;

  final String city;

  /// Named `stateName` throughout this feature: `state` reads as a widget's
  /// `State` in Flutter code, and the store's `add` takes `stateName` too.
  final String stateName;

  final String pincode;
  final bool isDefault;
}

/// Adds or edits one saved address.
Future<AddressFormResult?> showAddressFormSheet(
  BuildContext context, {
  Address? existing,
}) {
  return showAppSheet<AddressFormResult>(
    context,
    title: existing == null ? 'Add address' : 'Edit address',
    builder: (sheetContext) => _AddressForm(existing: existing),
  );
}

class _AddressForm extends StatefulWidget {
  const _AddressForm({this.existing});

  final Address? existing;

  @override
  State<_AddressForm> createState() => _AddressFormState();
}

/// Widget-local form state — the draft lives exactly as long as the sheet.
class _AddressFormState extends State<_AddressForm> {
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _stateName;
  late final TextEditingController _pincode;

  String? _label;
  late bool _isDefault;

  bool _submitted = false;
  Map<String, String> _errors = const {};

  static const String _fieldLabel = 'label';
  static const String _fieldLine1 = 'line1';
  static const String _fieldCity = 'city';
  static const String _fieldState = 'state';
  static const String _fieldPincode = 'pincode';

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
    _label = existing == null
        ? null
        : (_labels.contains(existing.label) ? existing.label : 'Other');
    _line1 = TextEditingController(text: existing?.line1 ?? '');
    _line2 = TextEditingController(text: existing?.line2 ?? '');
    _city = TextEditingController(text: existing?.city ?? '');
    _stateName = TextEditingController(text: existing?.state ?? '');
    _pincode = TextEditingController(text: existing?.pincode ?? '');
    _isDefault = existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _stateName.dispose();
    _pincode.dispose();
    super.dispose();
  }

  String? _errorFor(String field) => _submitted ? _errors[field] : null;

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_label == null) errors[_fieldLabel] = 'Choose a label';
    final line1 = Validators.addressLine(
      _line1.text,
      label: 'the street address',
    );
    if (line1 != null) errors[_fieldLine1] = line1;
    final city = Validators.requiredField('a city', _city.text);
    if (city != null) errors[_fieldCity] = city;
    final stateName = Validators.requiredField('a state', _stateName.text);
    if (stateName != null) errors[_fieldState] = stateName;
    final pincode = Validators.pincode(_pincode.text);
    if (pincode != null) errors[_fieldPincode] = pincode;
    return errors;
  }

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

    final line2 = _line2.text.trim();
    Navigator.of(context).pop(
      AddressFormResult(
        label: _label!,
        line1: _line1.text.trim(),
        line2: line2.isEmpty ? null : line2,
        city: _city.text.trim(),
        stateName: _stateName.text.trim(),
        pincode: Validators.digitsOf(_pincode.text),
        isDefault: _isDefault,
      ),
    );
  }

  Future<void> _pickLabel() async {
    final picked = await showProfileOptionSheet<String>(
      context,
      title: 'Label',
      selected: _label,
      options: [
        for (final label in _labels)
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
          iconName: MedIcon.location,
          value: _label,
          placeholder: 'Home, Work …',
          errorText: _errorFor(_fieldLabel),
          onTap: _pickLabel,
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppTextField(
          label: 'Flat, house no., building, street',
          controller: _line1,
          hintText: '12 Marine Drive',
          maxLength: 80,
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
          hintText: 'Apartment 4B',
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.streetAddressLine2],
          helperText: 'Optional',
          onChanged: (_) => _recheck(),
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppTextField(
          label: 'City',
          controller: _city,
          hintText: 'Kochi',
          maxLength: 40,
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
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.addressState],
          errorText: _errorFor(_fieldState),
          onChanged: (_) => _recheck(),
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppTextField(
          label: 'PIN code',
          controller: _pincode,
          hintText: '682031',
          keyboardType: TextInputType.number,
          maxLength: 6,
          // Digits only, mirroring what `Validators.pincode` will accept, so
          // the field cannot take input the validator is bound to reject.
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofillHints: const [AutofillHints.postalCode],
          textInputAction: TextInputAction.done,
          errorText: _errorFor(_fieldPincode),
          onChanged: (_) => _recheck(),
          onSubmitted: (_) => _submit(),
        ),
        SizedBox(height: AppSpacing.x4.h),
        _DefaultToggleRow(
          value: _isDefault,
          isLocked: widget.existing?.isDefault ?? false,
          onChanged: (next) => setState(() => _isDefault = next),
        ),
        SizedBox(height: AppSpacing.x5.h),
        AppButton(
          label: widget.existing == null ? 'Save Address' : 'Save Changes',
          fullWidth: true,
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
