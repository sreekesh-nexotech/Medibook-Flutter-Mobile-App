import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import 'auth_provider.dart';
import '../../domain/entities/user.dart';

/// Asking for a one-time code to be sent — the step before `/verify` in three
/// flows (sign-up §4.1, mobile sign-in §4.3, password reset §4.7).
///
/// Each call returns the [OtpChallenge] whose `challengeId` the verify step
/// needs, or null with the [Failure] read back from `authProvider`.
abstract final class CodeDelivery {
  CodeDelivery._();

  /// Send a sign-in code to [phoneE164].
  static Future<OtpChallenge?> requestLoginCode(Ref ref, String phoneE164) =>
      ref.read(authProvider.notifier).startOtpLogin(phoneE164: phoneE164);

  /// Validate the sign-up and send its code. No account exists yet.
  static Future<OtpChallenge?> requestSignupCode(
    Ref ref,
    SignupRequest request,
  ) => ref.read(authProvider.notifier).startSignup(request);

  /// Send a password-reset code for [identifier] (phone or email; arrives by
  /// SMS either way).
  static Future<OtpChallenge?> requestResetCode(Ref ref, String identifier) =>
      ref
          .read(authProvider.notifier)
          .startPasswordReset(identifier: identifier);

  /// Re-send the code for an open challenge.
  static Future<OtpChallenge?> resend(Ref ref, String challengeId) =>
      ref.read(authProvider.notifier).resendOtp(challengeId: challengeId);

  /// The failure the last delivery left behind, if any.
  static Failure? lastFailure(Ref ref) => ref.read(authProvider).failure;
}
