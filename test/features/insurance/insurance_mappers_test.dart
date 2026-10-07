import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/common/attachments/domain/entities/stored_file.dart';
import 'package:medibook/features/insurance/domain/entities/insurance_policy.dart';
import 'package:medibook/features/insurance/infrastructure/repositories/insurance_mappers.dart';

/// The §6.4 `Policy` shape (with and without `documents`), the bodies out,
/// and the active / expiring / expired derivation from `valid_to`.
void main() {
  final detail = <String, Object?>{
    'id': 'pol-1',
    'person_id': null,
    'provider_name': 'Star Health',
    'policy_number': 'P/123456/01',
    'holder_name': 'Anita Nair',
    'plan_name': 'Family Optima',
    'sum_insured_paise': 50000000,
    'valid_from': '2026-04-01',
    'valid_to': '2027-03-31',
    'tpa_name': null,
    'notes': null,
    'version': 1,
    'created_at': '2026-09-30T08:09:04.204384+00:00',
    'documents': [
      {
        'file_id': 'file-1',
        'original_name': 'policy.pdf',
        'mime': 'application/pdf',
        'size_bytes': 182044,
        'status': 'clean',
        'attached_at': '2026-09-30T08:10:00+00:00',
      },
    ],
  };

  test('decodes the detail shape with documents', () {
    final policy = InsuranceMappers.fromJson(detail);
    expect(policy.id, 'pol-1');
    expect(policy.sumInsuredPaise, 50000000);
    expect(policy.validFrom, DateTime(2026, 4, 1));
    expect(policy.validTo, DateTime(2027, 3, 31));
    expect(policy.documents, hasLength(1));
    expect(policy.documents!.single.fileId, 'file-1');
    expect(policy.documents!.single.status, FileStatus.clean);
    expect(policy.hasDocuments, isTrue);
  });

  test('a list row has no documents (null, not empty)', () {
    final row = Map<String, Object?>.from(detail)..remove('documents');
    final policy = InsuranceMappers.fromJson(row);
    expect(policy.documents, isNull);
    expect(policy.hasDocuments, isFalse);
  });

  test('a row missing valid_to is a format error', () {
    expect(
      () => InsuranceMappers.fromJson({...detail, 'valid_to': null}),
      throwsA(isA<ResponseFormatException>()),
    );
  });

  test('status is derived from the validity window', () {
    final policy = InsuranceMappers.fromJson(detail);
    expect(policy.statusOn(DateTime(2026, 9, 30)), PolicyStatus.active);
    expect(policy.statusOn(DateTime(2027, 3, 10)), PolicyStatus.expiringSoon);
    expect(policy.statusOn(DateTime(2027, 3, 31)), PolicyStatus.expiringSoon);
    expect(policy.statusOn(DateTime(2027, 4, 1)), PolicyStatus.expired);
    expect(policy.statusOn(DateTime(2026, 3, 1)), PolicyStatus.notYetActive);
    expect(policy.daysUntilExpiryOn(DateTime(2027, 3, 30)), 1);
  });

  test(
    'the POST body sends the documented fields, optionals only when set',
    () {
      final body = InsuranceMappers.draftToJson(
        PolicyDraft(
          providerName: 'Star Health',
          policyNumber: 'P/1',
          holderName: 'Anita',
          validFrom: DateTime(2026, 4, 1),
          validTo: DateTime(2027, 3, 31),
          sumInsuredPaise: 50000000,
          planName: '',
          tpaName: '  ',
          notes: 'n',
        ),
      );
      expect(body, {
        'provider_name': 'Star Health',
        'policy_number': 'P/1',
        'holder_name': 'Anita',
        'valid_from': '2026-04-01',
        'valid_to': '2027-03-31',
        'sum_insured_paise': 50000000,
        'notes': 'n',
      });
    },
  );

  test('the PATCH body carries the subset with explicit nulls', () {
    expect(
      InsuranceMappers.patchToJson(
        const PolicyPatch(notes: 'patched', clearPerson: true),
      ),
      {'notes': 'patched', 'person_id': null},
    );
  });
}
