import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/address.dart';
import '../../domain/entities/emergency_contact.dart';
import '../../domain/entities/person.dart';

/// Wire → entity for §4.9, §5.6, §5.8, §5.9 and §6. The only file in the
/// profile feature that spells a JSON key (the `User` shape is mapped by
/// `AuthMappers` in the auth feature, which the repository reuses).
///
/// Every mapper is the Scenario-10 validation gate: a row missing what the
/// entity needs throws [ResponseFormatException] and nothing is cached.
abstract final class ProfileMappers {
  ProfileMappers._();

  // ---- §6.1 ----

  static List<Person> persons(Object? json) => Page.parse(json, person).results;

  static Person personFromBody(Object? json) =>
      person(_requireMap(json, 'person'));

  static Person person(Map<String, Object?> map) {
    final id = map['id'];
    final firstName = map['first_name'];
    if (id is! String || firstName is! String) {
      throw const ResponseFormatException(
        message: 'person has no id/first_name',
      );
    }
    final allergies = map['allergies'];
    return Person(
      id: id,
      isSelf: map['is_self'] == true,
      firstName: firstName,
      lastName: map['last_name'] as String?,
      relation: PersonRelation.fromWire(map['relation'] as String?),
      dateOfBirth: _dateTime(map['date_of_birth']),
      gender: Gender.fromWire(map['gender'] as String?),
      bloodGroup: map['blood_group'] as String?,
      allergies: allergies is List
          ? [for (final a in allergies) a.toString()]
          : const <String>[],
      phoneE164: map['phone_e164'] as String?,
      guardianNote: map['guardian_note'] as String?,
      version: (map['version'] as num?)?.toInt() ?? 1,
      createdAt: _dateTime(map['created_at']),
      updatedAt: _dateTime(map['updated_at']),
    );
  }

  // ---- §5.8 ----

  static ReleaseResult releaseResult(Object? json) {
    final map = _requireMap(json, 'release result');
    final moved = map['moved'];
    return ReleaseResult(
      personId: map['person_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      moved: moved is Map
          ? {
              for (final entry in moved.entries)
                if (entry.value is num)
                  entry.key.toString(): (entry.value as num).toInt(),
            }
          : const <String, int>{},
    );
  }

  // ---- §6.2 ----

  static List<Address> addresses(Object? json) =>
      Page.parse(json, address).results;

  static Address addressFromBody(Object? json) =>
      address(_requireMap(json, 'address'));

  static Address address(Map<String, Object?> map) {
    final id = map['id'];
    final line1 = map['address_line1'];
    if (id is! String || line1 is! String) {
      throw const ResponseFormatException(
        message: 'address has no id/address_line1',
      );
    }
    return Address(
      id: id,
      label: map['label']?.toString() ?? '',
      addressLine1: line1,
      addressLine2: map['address_line2'] as String?,
      addressLine3: map['address_line3'] as String?,
      city: map['city']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      pincode: map['pincode']?.toString() ?? '',
      phoneE164: map['phone_e164'] as String?,
      isDefault: map['is_default'] == true,
      version: (map['version'] as num?)?.toInt() ?? 1,
      createdAt: _dateTime(map['created_at']),
    );
  }

  // ---- §6.3 ----

  static List<EmergencyContact> contacts(Object? json) =>
      Page.parse(json, contact).results;

  static EmergencyContact contactFromBody(Object? json) =>
      contact(_requireMap(json, 'emergency contact'));

  static EmergencyContact contact(Map<String, Object?> map) {
    final id = map['id'];
    final phone = map['phone_e164'];
    if (id is! String || phone is! String) {
      throw const ResponseFormatException(
        message: 'emergency contact has no id/phone_e164',
      );
    }
    return EmergencyContact(
      id: id,
      name: map['name']?.toString() ?? '',
      relation: map['relation']?.toString() ?? '',
      phoneE164: phone,
      isPrimary: map['is_primary'] == true,
      version: (map['version'] as num?)?.toInt() ?? 1,
      createdAt: _dateTime(map['created_at']),
    );
  }

  // ---- §5.9 ----

  static List<Consent> consents(Object? json) =>
      Page.parse(json, consent).results;

  static Consent consentFromBody(Object? json) =>
      consent(_requireMap(json, 'consent'));

  static Consent consent(Map<String, Object?> map) {
    final id = map['id'];
    final slug = map['document_slug'];
    if (id is! String || slug is! String) {
      throw const ResponseFormatException(
        message: 'consent has no id/document_slug',
      );
    }
    return Consent(
      id: id,
      documentSlug: slug,
      documentVersion: (map['document_version'] as num?)?.toInt() ?? 0,
      acceptedAt: _dateTime(map['accepted_at']) ?? DateTime.now(),
    );
  }

  // ---- §5.6 ----

  static List<DeletionRequest> deletionRequests(Object? json) =>
      Page.parse(json, deletionRequest).results;

  static DeletionRequest deletionRequestFromBody(Object? json) =>
      deletionRequest(_requireMap(json, 'deletion request'));

  static DeletionRequest deletionRequest(Map<String, Object?> map) {
    final requestNo = map['request_no'];
    if (requestNo is! String) {
      throw const ResponseFormatException(
        message: 'deletion request has no request_no',
      );
    }
    return DeletionRequest(
      requestNo: requestNo,
      kind: map['kind']?.toString() ?? 'deletion',
      status: DeletionStatus.fromWire(map['status'] as String?),
      requestedAt: _dateTime(map['requested_at']) ?? DateTime.now(),
      coolingOffEndsAt: _dateTime(map['cooling_off_ends_at']),
      completedAt: _dateTime(map['completed_at']),
    );
  }

  // ---- §5.7 ----

  static List<DataExportRequest> dataExports(Object? json) =>
      Page.parse(json, dataExport).results;

  static DataExportRequest dataExportFromBody(Object? json) =>
      dataExport(_requireMap(json, 'data export request'));

  static DataExportRequest dataExport(Map<String, Object?> map) {
    final id = map['id'];
    final requestNo = map['request_no'];
    if (id is! String || requestNo is! String) {
      throw const ResponseFormatException(
        message: 'data export request has no id/request_no',
      );
    }
    return DataExportRequest(
      id: id,
      requestNo: requestNo,
      status: DataExportStatus.fromWire(map['status'] as String?),
      requestedAt: _dateTime(map['requested_at']) ?? DateTime.now(),
      dueAt: _dateTime(map['due_at']),
      completedAt: _dateTime(map['completed_at']),
    );
  }

  static DataExportLink dataExportLink(Object? json) {
    final map = _requireMap(json, 'data export link');
    final url = map['url'];
    if (url is! String || url.isEmpty) {
      throw const ResponseFormatException(
        message: 'data export link has no url',
      );
    }
    return DataExportLink(
      url: url,
      expiresAt: _dateTime(map['expires_at']),
      fileExpiresAt: _dateTime(map['file_expires_at']),
      requestNo: map['request_no'] as String?,
    );
  }

  // ---- §4.9 ----

  static List<AccountSession> sessions(Object? json) =>
      Page.parse(json, session).results;

  static AccountSession session(Map<String, Object?> map) {
    final id = map['id'];
    if (id is! String) {
      throw const ResponseFormatException(message: 'session has no id');
    }
    return AccountSession(
      id: id,
      isCurrent: map['current'] == true,
      deviceId: map['device_id'] as String?,
      userAgent: map['user_agent'] as String?,
      ip: map['ip'] as String?,
      createdAt: _dateTime(map['created_at']),
      lastSeenAt: _dateTime(map['last_seen_at']),
      absoluteExpiresAt: _dateTime(map['absolute_expires_at']),
    );
  }

  // ---- helpers ----

  static Map<String, Object?> _requireMap(Object? json, String what) {
    if (json is Map) return json.cast<String, Object?>();
    throw ResponseFormatException(
      message: 'expected a $what object, got ${json.runtimeType}',
    );
  }

  static DateTime? _dateTime(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
}
