import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/endpoints.dart';
import '../../../domain/entities/user.dart';

/// The auth endpoints (`FLUTTER_API_INTEGRATION.md` §4, §5.1, §5.5), as a
/// typed remote data source.
///
/// One level above [ApiClient] and one below the repository: it owns *which
/// endpoint and which payload shape*, and nothing else. No caching, no token
/// storage, no mapping to domain entities — the repository does those. Every
/// method returns the decoded JSON object; errors propagate as
/// `NetworkException`s from the client and are mapped to `Failure` by the
/// repository, so this layer has no `try`/`catch` at all.
abstract interface class AuthApi {
  /// `POST /patient/auth/login/password`.
  Future<Map<String, Object?>> loginWithPassword({
    required String identifier,
    required String password,
    String? deviceId,
  });

  /// `POST /patient/auth/login/otp/start`.
  Future<Map<String, Object?>> startOtpLogin({required String phoneE164});

  /// `POST /patient/auth/login/otp/verify`.
  Future<Map<String, Object?>> verifyOtpLogin({
    required String challengeId,
    required String code,
    String? deviceId,
  });

  /// `POST /patient/auth/otp/resend`.
  Future<Map<String, Object?>> resendOtp({required String challengeId});

  /// `POST /patient/auth/signup/start`.
  Future<Map<String, Object?>> startSignup(SignupRequest request);

  /// `POST /patient/auth/signup/verify`.
  Future<Map<String, Object?>> verifySignup({
    required String challengeId,
    required String code,
  });

  /// `POST /patient/auth/password/forgot/start`.
  Future<Map<String, Object?>> startPasswordReset({required String identifier});

  /// `POST /patient/auth/password/forgot/verify`.
  Future<Map<String, Object?>> verifyPasswordReset({
    required String challengeId,
    required String code,
  });

  /// `POST /patient/auth/password/reset` → 204.
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  });

  /// `POST /patient/auth/token/refresh`. Sends the refresh token explicitly
  /// rather than relying on the bearer header, which by then is expired.
  Future<Map<String, Object?>> refresh({required String refreshToken});

  /// `POST /patient/auth/logout` → 204. Best-effort: the caller clears local
  /// state whether or not this succeeds.
  Future<void> logout();

  /// `POST /patient/auth/logout-all` → 204.
  Future<void> logoutAll();

  /// `GET /patient/me`.
  Future<Map<String, Object?>> me();

  /// `POST /patient/me/password` → 204.
  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  });
}

/// [AuthApi] over the [ApiClient] interface.
///
/// Every method is a path from [Endpoints] plus a body — no string literals
/// for URLs, no inline JSON keys outside this file. OTP calls set
/// `withDeviceFingerprint` so the client attaches `X-Device-Fingerprint`
/// (§1.3).
class HttpAuthApi implements AuthApi {
  const HttpAuthApi(this._client);

  final ApiClient _client;

  @override
  Future<Map<String, Object?>> loginWithPassword({
    required String identifier,
    required String password,
    String? deviceId,
  }) async {
    final response = await _client.post(
      Endpoints.loginPassword,
      body: {
        'identifier': identifier,
        'password': password,
        'device_id': ?deviceId,
      },
      requiresAuth: false,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> startOtpLogin({
    required String phoneE164,
  }) async {
    final response = await _client.post(
      Endpoints.loginOtpStart,
      body: {'phone_e164': phoneE164},
      requiresAuth: false,
      withDeviceFingerprint: true,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> verifyOtpLogin({
    required String challengeId,
    required String code,
    String? deviceId,
  }) async {
    final response = await _client.post(
      Endpoints.loginOtpVerify,
      body: {'challenge_id': challengeId, 'code': code, 'device_id': ?deviceId},
      requiresAuth: false,
      withDeviceFingerprint: true,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> resendOtp({required String challengeId}) async {
    final response = await _client.post(
      Endpoints.otpResend,
      body: {'challenge_id': challengeId},
      requiresAuth: false,
      withDeviceFingerprint: true,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> startSignup(SignupRequest request) async {
    final address = request.address;
    final response = await _client.post(
      Endpoints.signupStart,
      body: {
        'first_name': request.firstName,
        if (request.lastName != null && request.lastName!.isNotEmpty)
          'last_name': request.lastName,
        'phone_e164': request.phoneE164,
        'date_of_birth': _date(request.dateOfBirth),
        if (request.email != null && request.email!.isNotEmpty)
          'email': request.email,
        if (request.password != null && request.password!.isNotEmpty)
          'password': request.password,
        if (request.alternatePhoneE164 != null)
          'alternate_phone_e164': request.alternatePhoneE164,
        if (address != null)
          'address': {
            if (address.label != null) 'label': address.label,
            'address_line1': address.addressLine1,
            'address_line2': address.addressLine2,
            'address_line3': address.addressLine3,
            'city': address.city,
            'state': address.state,
            'pincode': address.pincode,
            'phone_e164': address.phoneE164,
          },
        'consents': {
          'terms': request.acceptedTerms,
          'privacy': request.acceptedPrivacy,
          'guidelines': request.acceptedGuidelines,
          'marketing': request.marketingOptIn,
        },
      },
      requiresAuth: false,
      withDeviceFingerprint: true,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> verifySignup({
    required String challengeId,
    required String code,
  }) async {
    final response = await _client.post(
      Endpoints.signupVerify,
      body: {'challenge_id': challengeId, 'code': code},
      requiresAuth: false,
      withDeviceFingerprint: true,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> startPasswordReset({
    required String identifier,
  }) async {
    final response = await _client.post(
      Endpoints.forgotStart,
      body: {'identifier': identifier},
      requiresAuth: false,
      withDeviceFingerprint: true,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> verifyPasswordReset({
    required String challengeId,
    required String code,
  }) async {
    final response = await _client.post(
      Endpoints.forgotVerify,
      body: {'challenge_id': challengeId, 'code': code},
      requiresAuth: false,
      withDeviceFingerprint: true,
    );
    return response.requireMap;
  }

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) => _client.post(
    Endpoints.passwordReset,
    body: {'reset_token': resetToken, 'new_password': newPassword},
    requiresAuth: false,
  );

  @override
  Future<Map<String, Object?>> refresh({required String refreshToken}) async {
    final response = await _client.post(
      Endpoints.tokenRefresh,
      body: {'refresh': refreshToken},
      requiresAuth: false,
    );
    return response.requireMap;
  }

  @override
  Future<void> logout() => _client.post(Endpoints.logout);

  @override
  Future<void> logoutAll() => _client.post(Endpoints.logoutAll);

  @override
  Future<Map<String, Object?>> me() async {
    final response = await _client.get(Endpoints.me);
    return response.requireMap;
  }

  @override
  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  }) => _client.post(
    Endpoints.mePassword,
    body: {
      if (currentPassword != null && currentPassword.isNotEmpty)
        'current_password': currentPassword,
      'new_password': newPassword,
    },
  );

  /// `YYYY-MM-DD` — the wire date format (§1.11).
  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
