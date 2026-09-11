import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/stores/dependants_store.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/validators.dart';

/// Field keys for the add-a-policy form's errors.
abstract final class InsuranceField {
  InsuranceField._();

  static const String provider = 'provider';
  static const String policyNumber = 'policyNumber';
  static const String holderName = 'holderName';
  static const String planName = 'planName';
  static const String sumInsured = 'sumInsured';
  static const String validFrom = 'validFrom';
  static const String validTo = 'validTo';
  static const String tpaName = 'tpaName';
}

/// Per-field validation state for the insurance form.
///
/// The same rule as everywhere else in the app (audit §3.5.4): the error map
/// always holds the truth, and [visible] decides when the user sees it — on
/// submit, or once a field has been touched. This is the Insurance feature's
/// own copy rather than an import from Profile, because a feature does not
/// reach into another feature's presentation layer.
@immutable
class InsuranceFormErrors {
  const InsuranceFormErrors({
    this.errors = const <String, String>{},
    this.touched = const <String>{},
    this.submitted = false,
  });

  final Map<String, String> errors;
  final Set<String> touched;
  final bool submitted;

  bool get isValid => errors.isEmpty;

  String? visible(String field) {
    if (!submitted && !touched.contains(field)) return null;
    return errors[field];
  }

  InsuranceFormErrors withErrors(Map<String, String?> next) {
    final cleaned = <String, String>{};
    next.forEach((field, message) {
      if (message != null) cleaned[field] = message;
    });
    return InsuranceFormErrors(
      errors: cleaned,
      touched: touched,
      submitted: submitted,
    );
  }

  InsuranceFormErrors withTouched(String field) {
    if (touched.contains(field)) return this;
    return InsuranceFormErrors(
      errors: errors,
      touched: {...touched, field},
      submitted: submitted,
    );
  }

  InsuranceFormErrors withSubmitted() =>
      InsuranceFormErrors(errors: errors, touched: touched, submitted: true);
}

/// The add-a-policy form (`/insurance/add`) — CM-38.
///
/// Typed throughout: [sumInsured] is [Money] (int paise), not "₹5,00,000", so
/// a claim can be checked against the cover; [validFrom] / [validTo] are
/// `DateTime`, so "expired" is computed and an expired policy cannot be made
/// to look active by editing a string.
@immutable
class InsuranceFormState {
  const InsuranceFormState({
    this.provider = '',
    this.policyNumber = '',
    this.holderName = '',
    this.planName = '',
    this.sumInsured,
    this.validFrom,
    this.validTo,
    this.tpaName = '',
    this.errors = const InsuranceFormErrors(),
    this.isSaving = false,
  });

  final String provider;
  final String policyNumber;
  final String holderName;
  final String planName;

  /// Null until a valid amount has been entered.
  final Money? sumInsured;

  final DateTime? validFrom;
  final DateTime? validTo;

  /// Third-party administrator. Optional — not every insurer uses one.
  final String tpaName;

  final InsuranceFormErrors errors;
  final bool isSaving;

  /// True when anything has been entered — the unsaved-changes baseline. An
  /// add form starts blank, so "dirty" is simply "not blank".
  bool get isDirty =>
      provider.trim().isNotEmpty ||
      policyNumber.trim().isNotEmpty ||
      holderName.trim().isNotEmpty ||
      planName.trim().isNotEmpty ||
      sumInsured != null ||
      validFrom != null ||
      validTo != null ||
      tpaName.trim().isNotEmpty;

  InsuranceFormState copyWith({
    String? provider,
    String? policyNumber,
    String? holderName,
    String? planName,
    Money? sumInsured,
    bool clearSumInsured = false,
    DateTime? validFrom,
    DateTime? validTo,
    String? tpaName,
    InsuranceFormErrors? errors,
    bool? isSaving,
  }) {
    return InsuranceFormState(
      provider: provider ?? this.provider,
      policyNumber: policyNumber ?? this.policyNumber,
      holderName: holderName ?? this.holderName,
      planName: planName ?? this.planName,
      sumInsured: clearSumInsured ? null : (sumInsured ?? this.sumInsured),
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      tpaName: tpaName ?? this.tpaName,
      errors: errors ?? this.errors,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class InsuranceFormController extends StateNotifier<InsuranceFormState> {
  InsuranceFormController({String? holderName})
    : super(InsuranceFormState(holderName: holderName ?? '')) {
    _revalidate();
  }

  /// The largest cover a retail health policy plausibly carries. A typo of one
  /// extra zero is worth catching: the number is what a hospital checks a bill
  /// against.
  static const int maxSumInsuredRupees = 100000000;

  /// The smallest cover worth recording.
  static const int minSumInsuredRupees = 1000;

  void setProvider(String value) {
    state = state.copyWith(provider: value);
    _revalidate();
  }

  void setPolicyNumber(String value) {
    state = state.copyWith(policyNumber: value);
    _revalidate();
  }

  void setHolderName(String value) {
    state = state.copyWith(holderName: value);
    _revalidate();
  }

  void setPlanName(String value) {
    state = state.copyWith(planName: value);
    _revalidate();
  }

  /// Takes the raw digits from the amount field and stores [Money].
  ///
  /// The field is digits-only, so this cannot be handed "5,00,000"; an empty
  /// field clears the amount rather than storing zero, because "no cover
  /// recorded" and "zero cover" are different statements.
  void setSumInsuredRupees(String digits) {
    final trimmed = digits.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(clearSumInsured: true);
      _revalidate();
      return;
    }
    final rupees = int.tryParse(Validators.digitsOf(trimmed));
    state = rupees == null
        ? state.copyWith(clearSumInsured: true)
        : state.copyWith(sumInsured: Money.rupees(rupees));
    _revalidate();
  }

  void setValidFrom(DateTime value) {
    state = state.copyWith(
      validFrom: value,
      errors: state.errors.withTouched(InsuranceField.validFrom),
    );
    _revalidate();
  }

  void setValidTo(DateTime value) {
    state = state.copyWith(
      validTo: value,
      errors: state.errors.withTouched(InsuranceField.validTo),
    );
    _revalidate();
  }

  void setTpaName(String value) {
    state = state.copyWith(tpaName: value);
    _revalidate();
  }

  void markTouched(String field) {
    state = state.copyWith(errors: state.errors.withTouched(field));
  }

  bool validate() {
    _revalidate();
    state = state.copyWith(errors: state.errors.withSubmitted());
    return state.errors.isValid;
  }

  void setSaving(bool value) => state = state.copyWith(isSaving: value);

  void _revalidate() {
    final from = state.validFrom;
    final to = state.validTo;

    state = state.copyWith(
      errors: state.errors.withErrors({
        InsuranceField.provider: Validators.requiredField(
          'the insurer',
          state.provider,
        ),
        InsuranceField.policyNumber: _policyNumberError(state.policyNumber),
        InsuranceField.holderName: Validators.personName(state.holderName),
        InsuranceField.planName: Validators.requiredField(
          'the plan name',
          state.planName,
        ),
        InsuranceField.sumInsured: _sumInsuredError(state.sumInsured),
        InsuranceField.validFrom: from == null
            ? 'Select the date cover started'
            : null,
        InsuranceField.validTo: to == null
            ? 'Select the date cover ends'
            : (from != null && !to.isAfter(from)
                  ? 'Cover must end after it starts'
                  : null),
        // Optional; nothing to check beyond a minimum length when given.
        InsuranceField.tpaName: state.tpaName.trim().isEmpty
            ? null
            : Validators.requiredField('a TPA name', state.tpaName),
      }),
    );
  }

  static String? _policyNumberError(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Enter the policy number';
    if (trimmed.length < 5) {
      return 'That looks too short for a policy number';
    }
    return null;
  }

  static String? _sumInsuredError(Money? value) {
    if (value == null) return 'Enter the sum insured';
    if (value.rupeePart < minSumInsuredRupees) {
      return 'Sum insured looks too low. Enter the amount in rupees.';
    }
    if (value.rupeePart > maxSumInsuredRupees) {
      return 'That is higher than any retail policy. Check for an extra zero.';
    }
    return null;
  }
}

/// autoDispose — an add form belongs to one visit to `/insurance/add`.
///
/// The holder name is seeded from the account holder's own patient record,
/// because a family policy is usually in their name. Read, not watched: a
/// re-seed mid-edit would overwrite what the user typed.
final insuranceFormControllerProvider =
    StateNotifierProvider.autoDispose<
      InsuranceFormController,
      InsuranceFormState
    >(
      (ref) => InsuranceFormController(
        holderName: ref.read(insuranceHolderDefaultProvider),
      ),
    );

/// The name to pre-fill as the policy holder — the account holder's own.
///
/// Read from `selfPatientProvider` rather than the seed constant, so a name
/// changed on `/profile/edit` pre-fills with the new one.
final insuranceHolderDefaultProvider = Provider<String>(
  (ref) => ref.watch(selfPatientProvider).name,
);
