import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../common/persons/domain/entities/person_summary.dart';
import '../../domain/entities/insurance_policy.dart';

/// Display strings for a policy, kept out of the domain entity so the
/// entity stays a plain value object.
extension PolicyLabels on InsurancePolicy {
  /// "₹5,00,000" — Indian grouping, from [Money]; "Not recorded" when the
  /// policy carries no sum insured.
  String get sumInsuredLabel {
    final paise = sumInsuredPaise;
    return paise == null ? 'Not recorded' : Money.paise(paise).format();
  }

  /// "Family Health Optima", or a neutral fallback.
  String get planLabel {
    final plan = planName;
    return plan == null || plan.trim().isEmpty ? 'Plan not recorded' : plan;
  }

  /// "01 Apr 2026 – 31 Mar 2027".
  String get validityLabel =>
      '${AppDates.dayMonthYear(validFrom)} – ${AppDates.dayMonthYear(validTo)}';

  /// "Active" / "Expires in 12 days" / "Expired" / "Starts 1 Jan 2027".
  String get statusLabel => switch (status) {
    PolicyStatus.expired => 'Expired',
    PolicyStatus.expiringSoon =>
      'Expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'}',
    PolicyStatus.notYetActive => 'Starts ${AppDates.dayMonthYear(validFrom)}',
    PolicyStatus.active => 'Active',
  };

  /// Who the policy covers (`person_id`, §6.4), named from the account's
  /// [persons] — the same choice the Add/Edit form offers. [persons] is null
  /// while the family list is still loading.
  String coversLabel(List<PersonSummary>? persons) {
    final id = personId;
    if (id == null) return 'Not tied to one person';
    if (persons == null) return 'A family member';
    final person = persons.where((p) => p.id == id).firstOrNull;
    if (person == null) return 'Someone no longer on your account';
    return person.isSelf ? '${person.fullName} (you)' : person.fullName;
  }
}
