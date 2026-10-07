import '../../../common/attachments/domain/entities/stored_file.dart';

/// Where a policy stands today. Not a wire field — derived from `valid_to`
/// (`FLUTTER_API_INTEGRATION.md` §6.4).
enum PolicyStatus { active, expiringSoon, expired, notYetActive }

/// A file attached to a policy (§6.4 `documents[]`; detail / create /
/// update only — the list omits them).
class PolicyDocument {
  const PolicyDocument({
    required this.fileId,
    required this.originalName,
    required this.mime,
    required this.sizeBytes,
    required this.status,
    this.attachedAt,
  });

  final String fileId;
  final String originalName;
  final String mime;
  final int sizeBytes;
  final FileStatus status;
  final DateTime? attachedAt;
}

/// A health-insurance policy on the account (§6.4 `Policy`). Private to the
/// patient; hospitals never see it.
class InsurancePolicy {
  const InsurancePolicy({
    required this.id,
    required this.providerName,
    required this.policyNumber,
    required this.holderName,
    required this.validFrom,
    required this.validTo,
    required this.version,
    this.personId,
    this.planName,
    this.sumInsuredPaise,
    this.tpaName,
    this.notes,
    this.createdAt,
    this.documents,
  });

  final String id;

  /// One of the user's persons, or null when the policy is not tied to one.
  final String? personId;
  final String providerName;
  final String policyNumber;
  final String holderName;
  final String? planName;

  /// Integer paise (₹5,00,000 = 50000000), or null when not recorded.
  final int? sumInsuredPaise;
  final DateTime validFrom;
  final DateTime validTo;
  final String? tpaName;
  final String? notes;
  final int version;
  final DateTime? createdAt;

  /// Null on rows from the list endpoint, which omits documents.
  final List<PolicyDocument>? documents;

  /// The renewal-nudge window (CM-39).
  static const int expiringSoonDays = 30;

  int daysUntilExpiryOn(DateTime now) => DateTime(
    validTo.year,
    validTo.month,
    validTo.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;

  PolicyStatus statusOn(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (today.isAfter(DateTime(validTo.year, validTo.month, validTo.day))) {
      return PolicyStatus.expired;
    }
    if (today.isBefore(
      DateTime(validFrom.year, validFrom.month, validFrom.day),
    )) {
      return PolicyStatus.notYetActive;
    }
    if (daysUntilExpiryOn(now) <= expiringSoonDays) {
      return PolicyStatus.expiringSoon;
    }
    return PolicyStatus.active;
  }

  // Convenience for the UI, against the wall clock.
  PolicyStatus get status => statusOn(DateTime.now());
  bool get isExpired => status == PolicyStatus.expired;
  bool get isExpiringSoon => status == PolicyStatus.expiringSoon;
  bool get isActive =>
      status == PolicyStatus.active || status == PolicyStatus.expiringSoon;
  int get daysUntilExpiry => daysUntilExpiryOn(DateTime.now());
  bool get hasDocuments => documents != null && documents!.isNotEmpty;

  InsurancePolicy copyWith({List<PolicyDocument>? documents, int? version}) =>
      InsurancePolicy(
        id: id,
        personId: personId,
        providerName: providerName,
        policyNumber: policyNumber,
        holderName: holderName,
        planName: planName,
        sumInsuredPaise: sumInsuredPaise,
        validFrom: validFrom,
        validTo: validTo,
        tpaName: tpaName,
        notes: notes,
        version: version ?? this.version,
        createdAt: createdAt,
        documents: documents ?? this.documents,
      );
}

/// The body of `POST /patient/me/insurance-policies`.
class PolicyDraft {
  const PolicyDraft({
    required this.providerName,
    required this.policyNumber,
    required this.holderName,
    required this.validFrom,
    required this.validTo,
    this.personId,
    this.planName,
    this.sumInsuredPaise,
    this.tpaName,
    this.notes,
  });

  final String providerName;
  final String policyNumber;
  final String holderName;
  final DateTime validFrom;
  final DateTime validTo;
  final String? personId;
  final String? planName;
  final int? sumInsuredPaise;
  final String? tpaName;
  final String? notes;
}

/// The body of `PATCH /patient/me/insurance-policies/{id}` — any subset.
class PolicyPatch {
  const PolicyPatch({
    this.providerName,
    this.policyNumber,
    this.holderName,
    this.validFrom,
    this.validTo,
    this.personId,
    this.clearPerson = false,
    this.planName,
    this.sumInsuredPaise,
    this.tpaName,
    this.notes,
  });

  final String? providerName;
  final String? policyNumber;
  final String? holderName;
  final DateTime? validFrom;
  final DateTime? validTo;
  final String? personId;
  final bool clearPerson;
  final String? planName;
  final int? sumInsuredPaise;
  final String? tpaName;
  final String? notes;
}
