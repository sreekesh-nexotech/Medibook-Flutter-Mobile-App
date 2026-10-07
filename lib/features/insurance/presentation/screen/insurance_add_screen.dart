import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_date_picker_sheet.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../common/attachments/application/providers/attachments_provider.dart';
import '../../../common/attachments/domain/entities/stored_file.dart';
import '../../../common/attachments/presentation/components/attachment_upload_tile.dart';
import '../../../common/persons/application/providers/persons_read_provider.dart';
import '../../application/providers/insurance_provider.dart';
import '../../application/states/insurance_form_state.dart';
import '../components/insurance_fields.dart';
import '../components/policy_person_picker.dart';

/// Add an insurance policy (`/insurance/add`) — CM-38, §6.4.
///
/// The form collects every §6.4 field, typed: the sum insured as integer
/// paise, the validity window as two dates, an optional person the policy
/// covers, the TPA and notes. The policy PDF / e-card goes up through the
/// shared attachment slot (purpose `insurance`) and, once the policy is
/// created, is attached with `POST /{id}/documents`.
class InsuranceAddScreen extends ConsumerStatefulWidget {
  const InsuranceAddScreen({super.key, this.policyId});

  /// Set to edit that saved policy instead of adding one (BL-INS-006).
  final String? policyId;

  @override
  ConsumerState<InsuranceAddScreen> createState() => _InsuranceAddScreenState();
}

class _InsuranceAddScreenState extends ConsumerState<InsuranceAddScreen> {
  late final TextEditingController _provider;
  late final TextEditingController _policyNumber;
  late final TextEditingController _holderName;
  late final TextEditingController _planName;
  late final TextEditingController _sumInsured;
  late final TextEditingController _tpaName;
  late final TextEditingController _notes;

  final FocusNode _providerFocus = FocusNode();
  final FocusNode _policyNumberFocus = FocusNode();
  final FocusNode _holderNameFocus = FocusNode();
  final FocusNode _planNameFocus = FocusNode();
  final FocusNode _sumInsuredFocus = FocusNode();

  /// Adding, or editing [InsuranceAddScreen.policyId].
  AutoDisposeStateNotifierProvider<InsuranceFormController, InsuranceFormState>
  get _form => widget.policyId == null
      ? insuranceFormProvider
      : insuranceEditFormProvider(widget.policyId!);

  bool get _editing => widget.policyId != null;

  InsuranceFormController get _controller => ref.read(_form.notifier);

  @override
  void initState() {
    super.initState();
    final initial = ref.read(_form);
    _provider = TextEditingController(text: initial.provider);
    _policyNumber = TextEditingController(text: initial.policyNumber);
    _holderName = TextEditingController(text: initial.holderName);
    _planName = TextEditingController(text: initial.planName);
    _sumInsured = TextEditingController(
      text: initial.sumInsured == null
          ? ''
          : '${initial.sumInsured!.paise ~/ 100}',
    );
    _tpaName = TextEditingController(text: initial.tpaName);
    _notes = TextEditingController(text: initial.notes);

    _revealOnBlur(_providerFocus, InsuranceField.provider);
    _revealOnBlur(_policyNumberFocus, InsuranceField.policyNumber);
    _revealOnBlur(_holderNameFocus, InsuranceField.holderName);
    _revealOnBlur(_planNameFocus, InsuranceField.planName);
    _revealOnBlur(_sumInsuredFocus, InsuranceField.sumInsured);
  }

  void _revealOnBlur(FocusNode node, String field) {
    node.addListener(() {
      if (!node.hasFocus) _controller.markTouched(field);
    });
  }

  @override
  void dispose() {
    _provider.dispose();
    _policyNumber.dispose();
    _holderName.dispose();
    _planName.dispose();
    _sumInsured.dispose();
    _tpaName.dispose();
    _notes.dispose();
    _providerFocus.dispose();
    _policyNumberFocus.dispose();
    _holderNameFocus.dispose();
    _planNameFocus.dispose();
    _sumInsuredFocus.dispose();
    super.dispose();
  }

  Future<void> _pickValidFrom(DateTime? current) async {
    final now = DateTime.now();
    final picked = await showAppDatePickerSheet(
      context,
      title: 'Cover starts',
      initialDay: current ?? now,
      firstDay: DateTime(now.year - 20, 1, 1),
      lastDay: DateTime(now.year + 5, 12, 31),
    );
    if (picked != null) _controller.setValidFrom(picked);
  }

  Future<void> _pickValidTo(DateTime? current, DateTime? from) async {
    final now = DateTime.now();
    final earliest = from ?? DateTime(now.year - 20, 1, 1);
    final picked = await showAppDatePickerSheet(
      context,
      title: 'Cover ends',
      initialDay: current ?? (from ?? now),
      firstDay: earliest,
      lastDay: DateTime(now.year + 25, 12, 31),
    );
    if (picked != null) _controller.setValidTo(picked);
  }

  Future<void> _save() async {
    final toast = ref.read(toastControllerProvider.notifier);
    final slot = ref.read(
      attachmentUploadProvider(FileUploadPurpose.insurance),
    );
    if (slot.isBusy) {
      toast.show('Wait for the file to finish uploading');
      return;
    }

    final stored = await _controller.save();
    if (!mounted) return;
    if (_editing && stored != null) {
      ref.invalidate(insurancePolicyProvider(stored.id));
      ref.invalidate(insuranceListProvider);
      ref.invalidate(insurancePolicyCountProvider);
      toast.show(
        stored.isExpired
            ? '${stored.providerName} updated. Note it expired '
                  '${AppDates.dayMonthYear(stored.validTo)}.'
            : '${stored.providerName} policy updated',
      );
      Navigator.of(context).pop();
      return;
    }
    if (stored == null) {
      final failure = ref.read(_form).failure;
      toast.show(
        failure is ValidationFailure || failure == null
            ? 'Fix the highlighted fields first'
            : failure.userMessage,
      );
      return;
    }

    // Attach the uploaded file, if there is one. A failed attach does not
    // undo the policy: say so and let the detail screen offer a retry.
    final fileId = slot.readyFileId;
    var attachFailed = false;
    if (fileId != null) {
      final attached = await ref
          .read(policyActionsProvider(stored.id).notifier)
          .attach(stored.id, fileId);
      attachFailed = attached == null;
      if (!mounted) return;
      if (!attachFailed) {
        ref
            .read(
              attachmentUploadProvider(FileUploadPurpose.insurance).notifier,
            )
            .detachOwnership();
      }
    }
    ref.invalidate(insuranceListProvider);
    ref.invalidate(insurancePolicyCountProvider);

    toast.show(
      attachFailed
          ? '${stored.providerName} policy saved, but the file could not be '
                'attached. Try again from the policy.'
          : stored.isExpired
          ? '${stored.providerName} saved. Note it expired '
                '${AppDates.dayMonthYear(stored.validTo)}.'
          : '${stored.providerName} policy saved',
    );
    context.pushReplacement(AppRoutes.insurancePath(stored.id));
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(_form);
    final errors = form.errors;
    final upload = ref.watch(
      attachmentUploadProvider(FileUploadPurpose.insurance),
    );
    final failure = form.failure;

    return AppUnsavedChangesGuard(
      hasUnsavedChanges:
          (form.isDirty || upload.hasSelection) && !form.isSaving,
      title: _editing ? 'Discard your changes?' : 'Discard this policy?',
      consequence: _editing
          ? 'The changes you have made to this policy will not be saved.'
          : 'The policy details you have entered will not be saved, and '
                'nothing will be added to your insurance.',
      child: Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInnerHeader(
                title: _editing ? 'Edit Policy' : 'Add Policy',
                onBack: () => _leave(context),
                backSemanticLabel: 'Back to insurance',
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
                          const _SectionTitle('The policy'),
                          SizedBox(height: AppSpacing.x3.h),
                          AppTextField(
                            label: 'Insurer',
                            controller: _provider,
                            focusNode: _providerFocus,
                            hintText: 'Star Health & Allied Insurance',
                            maxLength: 200,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            errorText: errors.visible(InsuranceField.provider),
                            onChanged: _controller.setProvider,
                            onSubmitted: (_) => _planNameFocus.requestFocus(),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          AppTextField(
                            label: 'Plan name (optional)',
                            controller: _planName,
                            focusNode: _planNameFocus,
                            hintText: 'Family Health Optima',
                            maxLength: 200,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            errorText: errors.visible(InsuranceField.planName),
                            onChanged: _controller.setPlanName,
                            onSubmitted: (_) =>
                                _policyNumberFocus.requestFocus(),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          AppTextField(
                            label: 'Policy number',
                            controller: _policyNumber,
                            focusNode: _policyNumberFocus,
                            hintText: 'P/181234/01/2026/004521',
                            maxLength: 100,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.next,
                            errorText: errors.visible(
                              InsuranceField.policyNumber,
                            ),
                            helperText:
                                'Exactly as printed on your policy or e-card.',
                            onChanged: _controller.setPolicyNumber,
                            onSubmitted: (_) => _holderNameFocus.requestFocus(),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          AppTextField(
                            label: 'Policy holder',
                            controller: _holderName,
                            focusNode: _holderNameFocus,
                            hintText: 'Anita Menon',
                            maxLength: 200,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            errorText: errors.visible(
                              InsuranceField.holderName,
                            ),
                            helperText:
                                'Whose name the policy is in — it may be a '
                                'family member.',
                            onChanged: _controller.setHolderName,
                            onSubmitted: (_) => _sumInsuredFocus.requestFocus(),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          PolicyPersonPicker(
                            selectedId: form.personId,
                            errorText: errors.visible(InsuranceField.person),
                            onChanged: _controller.setPerson,
                            onRetry: () =>
                                ref.invalidate(personSummariesProvider),
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
                          const _SectionTitle('Cover and dates'),
                          SizedBox(height: AppSpacing.x3.h),
                          AppTextField(
                            label: 'Sum insured (optional)',
                            controller: _sumInsured,
                            focusNode: _sumInsuredFocus,
                            hintText: '500000',
                            keyboardType: TextInputType.number,
                            maxLength: 9,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textInputAction: TextInputAction.done,
                            errorText: errors.visible(
                              InsuranceField.sumInsured,
                            ),
                            helperText: form.sumInsured == null
                                ? 'In rupees, digits only.'
                                : 'Cover: ${form.sumInsured!.format()}',
                            onChanged: _controller.setSumInsuredRupees,
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          InsuranceDateField(
                            label: 'Cover starts',
                            value: form.validFrom == null
                                ? null
                                : AppDates.dayMonthYear(form.validFrom!),
                            errorText: errors.visible(InsuranceField.validFrom),
                            onTap: () => _pickValidFrom(form.validFrom),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          InsuranceDateField(
                            label: 'Cover ends',
                            value: form.validTo == null
                                ? null
                                : AppDates.dayMonthYear(form.validTo!),
                            errorText: errors.visible(InsuranceField.validTo),
                            helperText: form.validFrom == null
                                ? 'Choose when cover starts first.'
                                : null,
                            onTap: () =>
                                _pickValidTo(form.validTo, form.validFrom),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          AppTextField(
                            label: 'TPA (optional)',
                            controller: _tpaName,
                            hintText: 'Medi Assist',
                            maxLength: 200,
                            textCapitalization: TextCapitalization.words,
                            errorText: errors.visible(InsuranceField.tpaName),
                            helperText:
                                'The administrator who approves cashless '
                                'claims, if your insurer uses one.',
                            onChanged: _controller.setTpaName,
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          AppTextField(
                            label: 'Notes (optional)',
                            controller: _notes,
                            hintText: 'Cashless at Lakeshore; call TPA first',
                            maxLines: 3,
                            maxLength: 2000,
                            textCapitalization: TextCapitalization.sentences,
                            errorText: errors.visible(InsuranceField.notes),
                            onChanged: _controller.setNotes,
                          ),
                        ],
                      ),
                    ),
                    // Documents of a saved policy are managed on its screen.
                    if (!_editing) ...[
                      SizedBox(height: AppSpacing.x4.h),

                      AppCard(
                        padding: EdgeInsets.all(AppSpacing.x4.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SectionTitle('Policy documents'),
                            SizedBox(height: AppSpacing.x3.h),
                            AttachmentUploadTile(
                              purpose: FileUploadPurpose.insurance,
                              title: 'Policy PDF or e-card (optional)',
                              helper:
                                  'A PDF or a photo — attached once the policy '
                                  'is saved',
                              enabled: !form.isSaving,
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (failure != null && failure is! ValidationFailure) ...[
                      SizedBox(height: AppSpacing.x4.h),
                      AppInlineError(failure: failure, onRetry: _save),
                    ],
                    SizedBox(height: AppSpacing.x6.h),

                    AppButton(
                      label: upload.isBusy
                          ? 'Waiting for the file…'
                          : _editing
                          ? 'Save Changes'
                          : 'Save Policy',
                      fullWidth: true,
                      loading: form.isSaving,
                      disabled: upload.isBusy,
                      onPressed: upload.isBusy ? null : _save,
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

  /// `Navigator.maybePop` so the unsaved-changes `PopScope` gets its say.
  void _leave(BuildContext context) {
    if (context.canPop()) {
      Navigator.maybePop(context);
      return;
    }
    context.go(AppRoutes.insurance);
  }
}

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
