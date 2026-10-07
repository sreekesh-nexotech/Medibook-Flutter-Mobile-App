import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/endpoints.dart';
import '../../../domain/entities/account.dart';

/// The account endpoints (§4.9 sessions, §5.2–§5.4, §5.6, §5.7, §5.9): cacheable
/// reads as request descriptions (performed by the cache layer), mutations
/// performed here over [ApiClient] and returned as decoded JSON.
///
/// No mapping, no caching, no `try`/`catch` — errors reach the repository as
/// `NetworkException`s. Every OTP call sets `withDeviceFingerprint` (§1.3).
abstract interface class ProfileApi {
  /// `PATCH /patient/me` with `If-Match`.
  Future<Map<String, Object?>> updateProfile(
    ProfileUpdate update, {
    required int ifMatch,
  });

  Future<Map<String, Object?>> startPhoneChange({required String newPhoneE164});
  Future<Map<String, Object?>> confirmOldPhone({
    required String challengeId,
    required String code,
  });
  Future<Map<String, Object?>> verifyNewPhone({
    required String challengeId,
    required String code,
  });

  Future<Map<String, Object?>> setAlternatePhone({required String phoneE164});
  Future<Map<String, Object?>> removeAlternatePhone();

  Future<Map<String, Object?>> requestDeletion({
    String? reason,
    required String idempotencyKey,
  });
  ApiRequest deletionRequests();
  Future<Map<String, Object?>> withdrawDeletion(String requestNo);
  Future<Map<String, Object?>> reactivate();

  ApiRequest dataExports();
  Future<Map<String, Object?>> requestDataExport({
    required String idempotencyKey,
  });
  Future<Map<String, Object?>> dataExportDownloadUrl(String id);

  ApiRequest consents();
  Future<Map<String, Object?>> acceptConsent({
    required String documentSlug,
    required int documentVersion,
  });

  ApiRequest sessions();
  Future<void> revokeSession(String sessionId);
}

class HttpProfileApi implements ProfileApi {
  const HttpProfileApi(this._client);

  final ApiClient _client;

  @override
  Future<Map<String, Object?>> updateProfile(
    ProfileUpdate update, {
    required int ifMatch,
  }) async {
    final response = await _client.patch(
      Endpoints.me,
      ifMatch: ifMatch,
      body: {
        if (update.firstName != null) 'first_name': update.firstName,
        if (update.clearLastName)
          'last_name': null
        else if (update.lastName != null)
          'last_name': update.lastName,
        if (update.locale != null) 'locale': update.locale,
        if (update.timezone != null) 'timezone': update.timezone,
        if (update.dateOfBirth != null)
          'date_of_birth': wireDate(update.dateOfBirth!),
        if (update.gender != null) 'gender': update.gender!.wire,
        if (update.clearBloodGroup)
          'blood_group': null
        else if (update.bloodGroup != null)
          'blood_group': update.bloodGroup,
        if (update.allergies != null) 'allergies': update.allergies,
        if (update.marketingOptIn != null)
          'marketing_opt_in': update.marketingOptIn,
      },
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> startPhoneChange({
    required String newPhoneE164,
  }) async {
    final response = await _client.post(
      Endpoints.phoneChangeStart,
      body: {'new_phone_e164': newPhoneE164},
      withDeviceFingerprint: true,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> confirmOldPhone({
    required String challengeId,
    required String code,
  }) async {
    final response = await _client.post(
      Endpoints.phoneChangeConfirmOld,
      body: {'challenge_id': challengeId, 'code': code},
      withDeviceFingerprint: true,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> verifyNewPhone({
    required String challengeId,
    required String code,
  }) async {
    final response = await _client.post(
      Endpoints.phoneChangeVerifyNew,
      body: {'challenge_id': challengeId, 'code': code},
      withDeviceFingerprint: true,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> setAlternatePhone({
    required String phoneE164,
  }) async {
    final response = await _client.post(
      Endpoints.alternatePhone,
      body: {'phone_e164': phoneE164},
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> removeAlternatePhone() async {
    final response = await _client.delete(Endpoints.alternatePhone);
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> requestDeletion({
    String? reason,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      Endpoints.deletionRequests,
      body: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason},
      idempotencyKey: idempotencyKey,
    );
    return response.requireMap;
  }

  @override
  ApiRequest deletionRequests() => const ApiRequest(
    path: Endpoints.deletionRequests,
    query: {'sort': '-requested_at'},
  );

  @override
  Future<Map<String, Object?>> withdrawDeletion(String requestNo) async {
    final response = await _client.delete(Endpoints.deletionRequest(requestNo));
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> reactivate() async {
    final response = await _client.post(Endpoints.reactivate);
    return response.requireMap;
  }

  @override
  ApiRequest dataExports() => const ApiRequest(
    path: Endpoints.dataExports,
    query: {'sort': '-requested_at'},
  );

  @override
  Future<Map<String, Object?>> requestDataExport({
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      Endpoints.dataExports,
      idempotencyKey: idempotencyKey,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> dataExportDownloadUrl(String id) async {
    final response = await _client.get(Endpoints.dataExportDownloadUrl(id));
    return response.requireMap;
  }

  @override
  ApiRequest consents() => const ApiRequest(
    path: Endpoints.consents,
    query: {'sort': '-accepted_at', 'page_size': 100},
  );

  @override
  Future<Map<String, Object?>> acceptConsent({
    required String documentSlug,
    required int documentVersion,
  }) async {
    final response = await _client.post(
      Endpoints.consents,
      body: {
        'document_slug': documentSlug,
        'document_version': documentVersion,
      },
    );
    return response.requireMap;
  }

  @override
  ApiRequest sessions() => const ApiRequest(
    path: Endpoints.sessions,
    query: {'sort': '-last_seen_at', 'page_size': 100},
  );

  @override
  Future<void> revokeSession(String sessionId) =>
      _client.delete(Endpoints.session(sessionId));

  /// `YYYY-MM-DD` — the wire date format (§1.11).
  static String wireDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
