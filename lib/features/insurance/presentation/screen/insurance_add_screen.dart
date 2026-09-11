import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/stores/insurance_store.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_date_picker_sheet.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_stub_notice.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/insurance_fields.dart';
import '../controllers/insurance_form_controller.dart';

/// Add an insurance policy (`/insurance/add`) — CM-38.
///
/// Everything the policy record holds is collected here and stored typed: the
/// sum insured as [Money] (so a bill can be checked against the cover) and the
/// validity window as two `DateTime`s (so "expired" is computed, and no amount
/// of editing text can make a lapsed policy look current).
///
/// ## The one control that cannot be real
///
/// Attaching the policy PDF or e-card needs a file picker, and this build
/// ships none — nor may it gain one. So the attach control declares itself
/// stubbed (`AppButton(stubbed: true)` + `showStubbedToast`) rather than
/// opening nothing or, worse, saying a file was attached. Everything around it
/// is wired: `InsuranceStore.attachDocument` exists and the detail screen
/// already renders whatever a policy's `documents` list holds, so wiring a
/// real picker later touches this one button.
class InsuranceAddScreen extends ConsumerStatefulWidget {
  const InsuranceAddScreen({super.key});

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

  final FocusNode _providerFocus = FocusNode();
  final FocusNode _policyNumberFocus = FocusNode();
  final FocusNode _holderNameFocus = FocusNode();
  final FocusNode _planNameFocus = FocusNode();
  final FocusNode _sumInsuredFocus = FocusNode();

  InsuranceFormController get _controller =>
      ref.read(insuranceFormControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    final initial = ref.read(insuranceFormControllerProvider);
    _provider = TextEditingController(text: initial.provider);
    _policyNumber = TextEditingController(text: initial.policyNumber);
    _holderName = TextEditingController(text: initial.holderName);
    _planName = TextEditingController(text: initial.planName);
    _sumInsured = TextEditingController();
    _tpaName = TextEditingController(text: initial.tpaName);

    // An error appears when the user leaves a field, not while they are still
    // typing its first character (audit §3.5.4).
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
      // A policy can have started years ago, and can start in the future when
      // a renewal has been bought early.
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
      // Cover cannot end before it starts, so the calendar cannot offer it.
      firstDay: earliest,
      lastDay: DateTime(now.year + 25, 12, 31),
    );
    if (picked != null) _controller.setValidTo(picked);
  }

  void _save() {
    if (!_controller.validate()) {
      ref
          .read(toastControllerProvider.notifier)
          .show('Fix the highlighted fields first');
      return;
    }

    final form = ref.read(insuranceFormControllerProvider);
    _controller.setSaving(true);

    final tpa = form.tpaName.trim();
    final stored = ref
        .read(insuranceStoreProvider.notifier)
        .add(
          provider: form.provider.trim(),
          policyNumber: form.policyNumber.trim(),
          holderName: form.holderName.trim(),
          planName: form.planName.trim(),
          sumInsured: form.sumInsured!,
          validFrom: form.validFrom!,
          validTo: form.validTo!,
          tpaName: tpa.isEmpty ? null : tpa,
        );

    // isSaving stays true through the navigation: the policy is stored, so the
    // unsaved-changes guard must not challenge leaving.
    ref
        .read(toastControllerProvider.notifier)
        .show(
          stored.isExpired
              // An expired policy is a legitimate thing to record, but saying
              // "policy added" without qualification would let the user
              // believe they have cover they do not.
              ? '${stored.provider} saved. Note it expired '
                    '${AppDates.dayMonthYear(stored.validTo)}.'
              : '${stored.provider} policy saved',
        );

    // Replaces this form in the stack with the policy just created, so Back
    // goes to the list rather than back into a filled-in add form.
    context.pushReplacement(AppRoutes.insurancePath(stored.id));
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(insuranceFormControllerProvider);
    final errors = form.errors;

    return AppUnsavedChangesGuard(
      hasUnsavedChanges: form.isDirty && !form.isSaving,
      title: 'Discard this policy?',
      consequence:
          'The policy details you have entered will not be saved, and nothing '
          'will be added to your insurance.',
      child: Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInnerHeader(
                title: 'Add Policy',
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
                            maxLength: 80,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            errorText: errors.visible(InsuranceField.provider),
                            onChanged: _controller.setProvider,
                            onSubmitted: (_) => _planNameFocus.requestFocus(),
                          ),
                          SizedBox(height: AppSpacing.x4.h),
                          AppTextField(
                            label: 'Plan name',
                            controller: _planName,
                            focusNode: _planNameFocus,
                            hintText: 'Family Health Optima',
                            maxLength: 80,
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
                            maxLength: 40,
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
                            hintText: 'Alexandra Johnson',
                            maxLength: 60,
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
                            label: 'Sum insured',
                            controller: _sumInsured,
                            focusNode: _sumInsuredFocus,
                            hintText: '500000',
                            keyboardType: TextInputType.number,
                            maxLength: 9,
                            // Digits only: the amount is stored as Money, and
                            // a field that accepted "5 lakh" would have to
                            // guess what that means.
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
                            label: 'TPA',
                            controller: _tpaName,
                            hintText: 'Medi Assist',
                            maxLength: 60,
                            textCapitalization: TextCapitalization.words,
                            errorText: errors.visible(InsuranceField.tpaName),
                            helperText:
                                'Optional. The administrator who approves '
                                'cashless claims, if your insurer uses one.',
                            onChanged: _controller.setTpaName,
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
                          const _SectionTitle('Policy documents'),
                          SizedBox(height: AppSpacing.x2.h),
                          AppStubBanner(
                            title: 'Attaching files is not available yet',
                            body:
                                'This build has no file picker, so the policy '
                                'PDF and e-card cannot be attached. Save the '
                                'policy now — you can attach the files from '
                                'the policy screen once it is wired up.',
                          ),
                          SizedBox(height: AppSpacing.x3.h),
                          AppButton(
                            label: 'Attach Policy PDF',
                            variant: AppButtonVariant.secondary,
                            fullWidth: true,
                            stubbed: true,
                            onPressed: () => showStubbedToast(
                              context,
                              ref,
                              'Attaching a policy document',
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.x6.h),

                    AppButton(
                      label: 'Save Policy',
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
    context.go(AppRoutes.insurance);
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
