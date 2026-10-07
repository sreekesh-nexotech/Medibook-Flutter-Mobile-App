import '../../../../core/error/failure.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/insurance_policy.dart';

/// Field keys for the add-a-policy form's errors.
abstract final class InsuranceField {
  InsuranceField._();

  static const String provider = 'provider_name';
  static const String policyNumber = 'policy_number';
  static const String holderName = 'holder_name';
  static const String planName = 'plan_name';
  static const String sumInsured = 'sum_insured_paise';
  static const String validFrom = 'valid_from';
  static const String validTo = 'valid_to';
  static const String tpaName = 'tpa_name';
  static const String person = 'person_id';
  static const String notes = 'notes';
}

/// Per-field validation state. The error map always holds the truth and
/// [visible] decides when the user sees it — on submit, or once a field
/// has been touched.
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

  /// Merge the server's field errors (keyed by wire name, which the field
  /// keys above match) and reveal them.
  InsuranceFormErrors withServerErrors(Map<String, String> server) =>
      InsuranceFormErrors(
        errors: {...errors, ...server},
        touched: {...touched, ...server.keys},
        submitted: true,
      );

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

/// The add-a-policy form (`/insurance/add`) — CM-38, §6.4 fields.
///
/// Typed throughout: [sumInsured] is [Money] (int paise), the validity
/// window is two `DateTime`s, and [personId] is one of the account's
/// persons or null.
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
    this.notes = '',
    this.personId,
    this.errors = const InsuranceFormErrors(),
    this.isSaving = false,
    this.failure,
    this.editing,
  });

  /// The form opened on a saved policy (Edit), with its values.
  factory InsuranceFormState.fromPolicy(InsurancePolicy policy) =>
      InsuranceFormState(
        provider: policy.providerName,
        policyNumber: policy.policyNumber,
        holderName: policy.holderName,
        planName: policy.planName ?? '',
        sumInsured: policy.sumInsuredPaise == null
            ? null
            : Money.paise(policy.sumInsuredPaise!),
        validFrom: policy.validFrom,
        validTo: policy.validTo,
        tpaName: policy.tpaName ?? '',
        notes: policy.notes ?? '',
        personId: policy.personId,
        editing: policy,
      );

  final String provider;
  final String policyNumber;
  final String holderName;
  final String planName;

  /// Null until a valid amount has been entered (optional on the wire).
  final Money? sumInsured;
  final DateTime? validFrom;
  final DateTime? validTo;
  final String tpaName;
  final String notes;

  /// Whose policy — optional.
  final String? personId;
  final InsuranceFormErrors errors;
  final bool isSaving;

  /// The last save's failure, for the screen to show.
  final Failure? failure;

  /// The saved policy being edited, or null when adding one (BL-INS-006).
  final InsurancePolicy? editing;

  bool get isEditing => editing != null;

  bool get isDirty => editing != null
      ? _differsFrom(editing!)
      : provider.trim().isNotEmpty ||
            policyNumber.trim().isNotEmpty ||
            planName.trim().isNotEmpty ||
            sumInsured != null ||
            validFrom != null ||
            validTo != null ||
            tpaName.trim().isNotEmpty ||
            notes.trim().isNotEmpty ||
            personId != null;

  bool _differsFrom(InsurancePolicy p) =>
      provider.trim() != p.providerName ||
      policyNumber.trim() != p.policyNumber ||
      holderName.trim() != p.holderName ||
      planName.trim() != (p.planName ?? '') ||
      sumInsured?.paise != p.sumInsuredPaise ||
      validFrom != p.validFrom ||
      validTo != p.validTo ||
      tpaName.trim() != (p.tpaName ?? '') ||
      notes.trim() != (p.notes ?? '') ||
      personId != p.personId;

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
    String? notes,
    String? personId,
    bool clearPerson = false,
    InsuranceFormErrors? errors,
    bool? isSaving,
    Failure? failure,
    bool clearFailure = false,
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
      notes: notes ?? this.notes,
      personId: clearPerson ? null : (personId ?? this.personId),
      errors: errors ?? this.errors,
      isSaving: isSaving ?? this.isSaving,
      failure: clearFailure ? null : (failure ?? this.failure),
      editing: editing,
    );
  }
}
