import '../../../../../core/error/failure.dart';
import '../../../../../core/network/network_exceptions.dart';
import '../../../domain/entities/user.dart';
import 'auth_api.dart';
import '../../../../../app/config/feature_flags.dart';

/// [AuthApi] for a client-review build (`FeatureFlags.demoMode`, off by
/// default).
///
/// Answers every call with the **same payload shapes the real backend sends**
/// (§4), so `AuthRepositoryImpl` maps a demo session exactly as it would a real
/// one and nothing above this layer knows the difference. A wrong demo
/// password or code is rejected with the real error codes, so the lockout
/// path is demonstrable.
class DemoAuthApi implements AuthApi {
  const DemoAuthApi();

  static const String _userId = 'demo-user';
  static const String _challengeId = 'demo-challenge';

  @override
  Future<Map<String, Object?>> loginWithPassword({
    required String identifier,
    required String password,
    String? deviceId,
  }) async {
    final matches =
        identifier.trim().toLowerCase() == DemoCredentials.email &&
        password == DemoCredentials.password;
    if (!matches) {
      throw const UnauthorizedFailure(
        userMessage: 'That email and password do not match an account.',
        sessionExpired: false,
        apiCode: ApiErrorCodes.authInvalidCredentials,
        meta: {'attempts_remaining': 4},
        debugMessage: 'demo credential mismatch',
      );
    }
    return _tokens();
  }

  @override
  Future<Map<String, Object?>> startOtpLogin({
    required String phoneE164,
  }) async => _challenge(phoneE164);

  @override
  Future<Map<String, Object?>> verifyOtpLogin({
    required String challengeId,
    required String code,
    String? deviceId,
  }) async {
    _requireDemoCode(code);
    return _tokens();
  }

  @override
  Future<Map<String, Object?>> resendOtp({required String challengeId}) async =>
      _challenge(null);

  @override
  Future<Map<String, Object?>> startSignup(SignupRequest request) async =>
      _challenge(request.phoneE164);

  @override
  Future<Map<String, Object?>> verifySignup({
    required String challengeId,
    required String code,
  }) async {
    _requireDemoCode(code);
    return {
      ..._tokens(),
      'profile': {
        'date_of_birth': null,
        'gender': null,
        'blood_group': null,
        'allergies': <String>[],
        'avatar_file_id': null,
        'marketing_opt_in': false,
        'version': 1,
      },
      'person_self': {'id': 'demo-person-self', 'is_self': true},
    };
  }

  @override
  Future<Map<String, Object?>> startPasswordReset({
    required String identifier,
  }) async => _challenge(identifier);

  @override
  Future<Map<String, Object?>> verifyPasswordReset({
    required String challengeId,
    required String code,
  }) async {
    _requireDemoCode(code);
    return {
      'reset_token': 'demo-reset-token',
      'expires_at': DateTime.now()
          .add(const Duration(minutes: 15))
          .toUtc()
          .toIso8601String(),
    };
  }

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {}

  @override
  Future<Map<String, Object?>> refresh({required String refreshToken}) async =>
      _tokens(includeUser: false);

  @override
  Future<void> logout() async {}

  @override
  Future<void> logoutAll() async {}

  @override
  Future<Map<String, Object?>> me() async => {'user': _user(), 'profile': null};

  @override
  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword != DemoCredentials.password) {
      throw const UnauthorizedFailure(
        userMessage: 'The current password is incorrect.',
        sessionExpired: false,
        apiCode: ApiErrorCodes.authInvalidCredentials,
        debugMessage: 'demo current-password mismatch',
      );
    }
  }

  /// A wrong code is a rejected credential with the real code, so it counts
  /// exactly as a rejected password does.
  void _requireDemoCode(String code) {
    if (code == DemoCredentials.otpCode) return;
    throw const UnauthorizedFailure(
      userMessage: 'That code is not right. Check it and try again.',
      sessionExpired: false,
      apiCode: ApiErrorCodes.authOtpInvalid,
      meta: {'attempts_remaining': 2},
      debugMessage: 'demo OTP mismatch',
    );
  }

  Map<String, Object?> _challenge(String? destination) => {
    'challenge_id': _challengeId,
    'code_length': DemoCredentials.otpCode.length,
    'expires_at': DateTime.now()
        .add(const Duration(seconds: 180))
        .toUtc()
        .toIso8601String(),
    'resend_after_seconds': 30,
    'destination_masked': destination,
  };

  Map<String, Object?> _user() => {
    'id': _userId,
    'first_name': 'Alexandra',
    'last_name': 'Johnson',
    'phone_e164': '+919845658525',
    'phone_verified_at': '2026-01-01T00:00:00Z',
    'alternate_phone_e164': null,
    'email': DemoCredentials.email,
    'email_verified_at': '2026-01-01T00:00:00Z',
    'has_password': true,
    'status': 'active',
    'deletion_requested_at': null,
    'locale': 'en-IN',
    'timezone': 'Asia/Kolkata',
    'last_login_at': null,
    'version': 1,
  };

  Map<String, Object?> _tokens({bool includeUser = true}) => {
    'access': 'demo-access-token',
    'refresh': 'demo-refresh-token',
    'access_expires_in': 900,
    'session_id': 'demo-session',
    if (includeUser) 'user': _user(),
  };
}
