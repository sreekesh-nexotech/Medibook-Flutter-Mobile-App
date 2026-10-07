import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/endpoints.dart';
import '../../../domain/entities/person.dart';
import 'profile_api.dart';

/// The persons endpoints (§6.1) and release (§5.8). HTTP only.
abstract interface class PersonsApi {
  /// `GET /patient/me/persons`.
  ApiRequest persons();

  /// `POST /patient/me/persons` → 201.
  Future<Map<String, Object?>> create(PersonDraft draft);

  /// `PATCH /patient/me/persons/{id}` with `If-Match`.
  Future<Map<String, Object?>> update(
    String id,
    PersonDraft draft, {
    required int ifMatch,
  });

  /// `DELETE /patient/me/persons/{id}` → 204.
  Future<void> delete(String id);

  /// `POST …/{id}/release` — `Idempotency-Key` required.
  Future<Map<String, Object?>> startRelease({
    required String personId,
    required String phoneE164,
    required String idempotencyKey,
  });

  /// `POST …/{id}/release/verify`.
  Future<Map<String, Object?>> verifyRelease({
    required String personId,
    required String challengeId,
    required String code,
  });
}

class HttpPersonsApi implements PersonsApi {
  const HttpPersonsApi(this._client);

  final ApiClient _client;

  @override
  ApiRequest persons() => const ApiRequest(
    path: Endpoints.persons,
    query: {'sort': 'created_at', 'page_size': 100},
  );

  @override
  Future<Map<String, Object?>> create(PersonDraft draft) async {
    final response = await _client.post(Endpoints.persons, body: _body(draft));
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> update(
    String id,
    PersonDraft draft, {
    required int ifMatch,
  }) async {
    final response = await _client.patch(
      Endpoints.person(id),
      body: _body(draft),
      ifMatch: ifMatch,
    );
    return response.requireMap;
  }

  @override
  Future<void> delete(String id) => _client.delete(Endpoints.person(id));

  @override
  Future<Map<String, Object?>> startRelease({
    required String personId,
    required String phoneE164,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      Endpoints.personRelease(personId),
      body: {'phone_e164': phoneE164},
      idempotencyKey: idempotencyKey,
      withDeviceFingerprint: true,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> verifyRelease({
    required String personId,
    required String challengeId,
    required String code,
  }) async {
    final response = await _client.post(
      Endpoints.personReleaseVerify(personId),
      body: {'challenge_id': challengeId, 'code': code},
      withDeviceFingerprint: true,
    );
    return response.requireMap;
  }

  /// Only the fields the draft sets; explicit `null` for a clear.
  static Map<String, Object?> _body(PersonDraft draft) => {
    if (draft.firstName != null) 'first_name': draft.firstName,
    if (draft.clearLastName)
      'last_name': null
    else if (draft.lastName != null)
      'last_name': draft.lastName,
    if (draft.relation != null) 'relation': draft.relation!.wire,
    if (draft.clearDateOfBirth)
      'date_of_birth': null
    else if (draft.dateOfBirth != null)
      'date_of_birth': HttpProfileApi.wireDate(draft.dateOfBirth!),
    if (draft.clearGender)
      'gender': null
    else if (draft.gender != null)
      'gender': draft.gender!.wire,
    if (draft.clearBloodGroup)
      'blood_group': null
    else if (draft.bloodGroup != null)
      'blood_group': draft.bloodGroup,
    if (draft.allergies != null) 'allergies': draft.allergies,
    if (draft.clearPhone)
      'phone_e164': null
    else if (draft.phoneE164 != null)
      'phone_e164': draft.phoneE164,
    if (draft.clearGuardianNote)
      'guardian_note': null
    else if (draft.guardianNote != null)
      'guardian_note': draft.guardianNote,
  };
}
