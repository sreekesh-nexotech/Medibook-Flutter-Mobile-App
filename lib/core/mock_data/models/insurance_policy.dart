import '../../utils/date_utils.dart';
import '../../utils/money.dart';

/// A health-insurance policy on the account (CM-37 … CM-39).
///
/// Presentation view-model — immutable, no logic. [sumInsured] is [Money], so a
/// claim can be checked against the cover instead of comparing strings.
class InsurancePolicy {
  const InsurancePolicy({
    required this.id,
    required this.provider,
    required this.policyNumber,
    required this.holderName,
    required this.planName,
    required this.sumInsured,
    required this.validFrom,
    required this.validTo,
    this.documents = const <String>[],
    this.tpaName,
  });

  final String id;

  /// Insurer ("Star Health & Allied Insurance").
  final String provider;

  final String policyNumber;

  /// Whose name the policy is in — may be a dependant.
  final String holderName;

  /// Plan/product name ("Family Health Optima").
  final String planName;

  /// Total cover.
  final Money sumInsured;

  final DateTime validFrom;
  final DateTime validTo;

  /// Attached document ids (see `MedicalRecord`) — the policy PDF, the
  /// e-card.
  final List<String> documents;

  /// Third-party administrator, when the insurer uses one.
  final String? tpaName;

  /// "₹5,00,000" — Indian grouping, from [Money].
  String get sumInsuredLabel => sumInsured.format();

  /// "01 Apr 2026 – 31 Mar 2027".
  String get validityLabel =>
      '${AppDates.dayMonthYear(validFrom)} – ${AppDates.dayMonthYear(validTo)}';

  /// True while the policy is in force today.
  bool get isActive {
    final now = DateTime.now();
    return !now.isBefore(validFrom) && !now.isAfter(validTo);
  }

  bool get isExpired => DateTime.now().isAfter(validTo);

  /// Days until expiry; negative once expired.
  int get daysUntilExpiry => AppDates.startOfDay(
    validTo,
  ).difference(AppDates.startOfDay(DateTime.now())).inDays;

  /// True within 30 days of expiry — the renewal nudge (CM-39).
  bool get isExpiringSoon => !isExpired && daysUntilExpiry <= 30;

  /// "Active" / "Expires in 12 days" / "Expired".
  String get statusLabel {
    if (isExpired) return 'Expired';
    if (isExpiringSoon) {
      return 'Expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'}';
    }
    return 'Active';
  }

  bool get hasDocuments => documents.isNotEmpty;

  InsurancePolicy copyWith({
    String? id,
    String? provider,
    String? policyNumber,
    String? holderName,
    String? planName,
    Money? sumInsured,
    DateTime? validFrom,
    DateTime? validTo,
    List<String>? documents,
    String? tpaName,
  }) {
    return InsurancePolicy(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      policyNumber: policyNumber ?? this.policyNumber,
      holderName: holderName ?? this.holderName,
      planName: planName ?? this.planName,
      sumInsured: sumInsured ?? this.sumInsured,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      documents: documents ?? this.documents,
      tpaName: tpaName ?? this.tpaName,
    );
  }
}
