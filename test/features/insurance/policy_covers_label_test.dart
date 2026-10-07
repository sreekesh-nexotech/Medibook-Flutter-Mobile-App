import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/common/persons/domain/entities/person_summary.dart';
import 'package:medibook/features/insurance/domain/entities/insurance_policy.dart';
import 'package:medibook/features/insurance/presentation/components/policy_labels.dart';

/// The policy detail names who the policy covers (`person_id`, §6.4) — the
/// choice the Add/Edit form asks for, which used to be saved but never shown.
void main() {
  InsurancePolicy policy({String? personId}) => InsurancePolicy(
    id: 'p1',
    providerName: 'Star Health',
    policyNumber: 'P/1',
    holderName: 'Sanjay Varma',
    validFrom: DateTime(2026, 4, 1),
    validTo: DateTime(2027, 3, 31),
    version: 1,
    personId: personId,
  );

  const persons = [
    PersonSummary(
      id: 'self',
      firstName: 'Sanjay',
      lastName: 'Varma',
      relation: 'self',
      isSelf: true,
    ),
    PersonSummary(
      id: 'tara',
      firstName: 'Tara',
      lastName: 'Varma',
      relation: 'spouse',
      isSelf: false,
    ),
  ];

  test('names the covered family member', () {
    expect(policy(personId: 'tara').coversLabel(persons), 'Tara Varma');
    expect(policy(personId: 'self').coversLabel(persons), 'Sanjay Varma (you)');
  });

  test('says so when the policy is not tied to one person', () {
    expect(policy().coversLabel(persons), 'Not tied to one person');
    expect(policy().coversLabel(null), 'Not tied to one person');
  });

  test('holds a neutral line while the family list loads or misses', () {
    expect(policy(personId: 'tara').coversLabel(null), 'A family member');
    expect(
      policy(personId: 'gone').coversLabel(persons),
      'Someone no longer on your account',
    );
  });
}
