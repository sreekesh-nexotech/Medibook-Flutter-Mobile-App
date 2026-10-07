import 'package:intl/intl.dart';

import '../../../../core/network/network_exceptions.dart';
import '../../../common/attachments/domain/entities/stored_file.dart';
import '../../domain/entities/insurance_policy.dart';

/// Wire ↔ entity for `/patient/me/insurance-policies` (§6.4). The only
/// place the field names are spelled; decoders throw
/// [ResponseFormatException] on a bad shape so nothing partial is cached.
abstract final class InsuranceMappers {
  InsuranceMappers._();

  static final DateFormat _day = DateFormat('yyyy-MM-dd');

  static InsurancePolicy fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final provider = json['provider_name'];
    final number = json['policy_number'];
    final holder = json['holder_name'];
    final from = json['valid_from'];
    final to = json['valid_to'];
    if (id is! String ||
        id.isEmpty ||
        provider is! String ||
        number is! String ||
        holder is! String ||
        from is! String ||
        to is! String) {
      throw const ResponseFormatException(
        message:
            'policy is missing id / provider_name / policy_number / '
            'holder_name / valid_from / valid_to',
      );
    }
    final validFrom = DateTime.tryParse(from);
    final validTo = DateTime.tryParse(to);
    if (validFrom == null || validTo == null) {
      throw ResponseFormatException(message: 'bad policy dates "$from"–"$to"');
    }
    final documents = json['documents'];
    return InsurancePolicy(
      id: id,
      personId: json['person_id'] as String?,
      providerName: provider,
      policyNumber: number,
      holderName: holder,
      planName: json['plan_name'] as String?,
      sumInsuredPaise: (json['sum_insured_paise'] as num?)?.toInt(),
      validFrom: validFrom,
      validTo: validTo,
      tpaName: json['tpa_name'] as String?,
      notes: json['notes'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: _dateTime(json['created_at']),
      documents: documents is List
          ? [
              for (final row in documents)
                if (row is Map) documentFromJson(row.cast<String, Object?>()),
            ]
          : null,
    );
  }

  static PolicyDocument documentFromJson(Map<String, Object?> json) {
    final fileId = json['file_id'];
    if (fileId is! String || fileId.isEmpty) {
      throw const ResponseFormatException(
        message: 'policy document has no file_id',
      );
    }
    return PolicyDocument(
      fileId: fileId,
      originalName: (json['original_name'] as String?) ?? '',
      mime: (json['mime'] as String?) ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      status: FileStatus.fromWire(json['status'] as String?),
      attachedAt: _dateTime(json['attached_at']),
    );
  }

  static Map<String, Object?> draftToJson(PolicyDraft draft) => {
    'provider_name': draft.providerName,
    'policy_number': draft.policyNumber,
    'holder_name': draft.holderName,
    'valid_from': day(draft.validFrom),
    'valid_to': day(draft.validTo),
    // Optionals only when present; the server accepts explicit nulls for
    // these but there is no reason to send them.
    'person_id': ?draft.personId,
    'plan_name': ?_nullIfBlank(draft.planName),
    'sum_insured_paise': ?draft.sumInsuredPaise,
    'tpa_name': ?_nullIfBlank(draft.tpaName),
    'notes': ?_nullIfBlank(draft.notes),
  };

  static Map<String, Object?> patchToJson(PolicyPatch patch) => {
    if (patch.providerName != null) 'provider_name': patch.providerName,
    if (patch.policyNumber != null) 'policy_number': patch.policyNumber,
    if (patch.holderName != null) 'holder_name': patch.holderName,
    if (patch.validFrom != null) 'valid_from': day(patch.validFrom!),
    if (patch.validTo != null) 'valid_to': day(patch.validTo!),
    if (patch.clearPerson)
      'person_id': null
    else if (patch.personId != null)
      'person_id': patch.personId,
    if (patch.planName != null) 'plan_name': _nullIfBlank(patch.planName),
    if (patch.sumInsuredPaise != null)
      'sum_insured_paise': patch.sumInsuredPaise,
    if (patch.tpaName != null) 'tpa_name': _nullIfBlank(patch.tpaName),
    if (patch.notes != null) 'notes': _nullIfBlank(patch.notes),
  };

  static String day(DateTime value) => _day.format(value);

  static DateTime? _dateTime(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static String? _nullIfBlank(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
