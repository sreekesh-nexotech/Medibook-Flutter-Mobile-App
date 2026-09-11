import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/endpoints.dart';

/// The auth endpoints, as a typed remote data source.
///
/// One level above [ApiClient] and one below the repository: it owns *which
/// endpoint and which payload shape*, and nothing else. No caching, no token
/// storage, no mapping to domain entities — the repository does those.
///
/// Kept as an interface plus a thin implementation (rather than a Retrofit
/// `@RestApi`) because `retrofit`/`dio` are absent from this presentation-layer
/// build. [HttpAuthApi] below already satisfies it over the [ApiClient]
/// interface, so when a real client is installed this file needs no change.
abstract interface class AuthApi {
  /// `POST /auth/login` → `{ user: {...}, access_token, refresh_token, … }`.
  Future<Map<String, Object?>> login({
    required String email,
    required String password,
  });

  /// `POST /auth/login/otp`.
  Future<Map<String, Object?>> loginWithOtp({
    required String phone,
    required String code,
  });

  /// `POST /auth/otp/request`.
  Future<void> requestOtp({required String phone});

  /// `POST /auth/signup`.
  Future<Map<String, Object?>> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  });

  /// `POST /auth/refresh`. Sends the refresh token explicitly rather than
  /// relying on the bearer header, which by then is expired.
  Future<Map<String, Object?>> refresh({required String refreshToken});

  /// `POST /auth/logout`. Best-effort: the caller clears local state whether
  /// or not this succeeds.
  Future<void> logout();

  /// `GET /me`.
  Future<Map<String, Object?>> me();

  /// `POST /auth/password/forgot`.
  Future<void> requestPasswordReset({required String email});

  /// `POST /auth/password/reset`.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  /// `POST /auth/password/change`.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

/// [AuthApi] over the [ApiClient] interface.
///
/// Every method is a path from [Endpoints] plus a body — no string literals
/// for URLs, no inline JSON keys outside this file. Errors propagate as
/// [NetworkException]s from the client and are mapped to `Failure` by the
/// repository, so this layer has no `try`/`catch` at all.
class HttpAuthApi implements AuthApi {
  const HttpAuthApi(this._client);

  final ApiClient _client;

  @override
  Future<Map<String, Object?>> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Endpoints.login,
      body: {'email': email, 'password': password},
      requiresAuth: false,
    );
    return response.asMap ?? const <String, Object?>{};
  }

  @override
  Future<Map<String, Object?>> loginWithOtp({
    required String phone,
    required String code,
  }) async {
    final response = await _client.post(
      Endpoints.loginWithOtp,
      body: {'phone': phone, 'code': code},
      requiresAuth: false,
    );
    return response.asMap ?? const <String, Object?>{};
  }

  @override
  Future<void> requestOtp({required String phone}) => _client.post(
    Endpoints.requestOtp,
    body: {'phone': phone},
    requiresAuth: false,
  );

  @override
  Future<Map<String, Object?>> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _client.post(
      Endpoints.signup,
      body: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      },
      requiresAuth: false,
    );
    return response.asMap ?? const <String, Object?>{};
  }

  @override
  Future<Map<String, Object?>> refresh({required String refreshToken}) async {
    final response = await _client.post(
      Endpoints.refresh,
      body: {'refresh_token': refreshToken},
      requiresAuth: false,
    );
    return response.asMap ?? const <String, Object?>{};
  }

  @override
  Future<void> logout() => _client.post(Endpoints.logout);

  @override
  Future<Map<String, Object?>> me() async {
    final response = await _client.get(Endpoints.me);
    return response.asMap ?? const <String, Object?>{};
  }

  @override
  Future<void> requestPasswordReset({required String email}) => _client.post(
    Endpoints.forgotPassword,
    body: {'email': email},
    requiresAuth: false,
  );

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _client.post(
    Endpoints.resetPassword,
    body: {'email': email, 'code': code, 'password': newPassword},
    requiresAuth: false,
  );

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _client.post(
    Endpoints.changePassword,
    body: {
      'current_password': currentPassword,
      'new_password': newPassword,
    },
  );
}
