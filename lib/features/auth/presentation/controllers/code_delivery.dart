import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/feature_flags.dart';
import '../../../../core/error/failure.dart';
import '../../application/providers/auth_provider.dart';

/// Asking for a one-time code to be sent — the step before `/verify` in three
/// flows (sign-up CM-03, mobile sign-in CM-04, password reset CM-06).
///
/// ## The demo / real split
///
/// This build installs no `ApiClient`, so nothing can actually be sent. Both
/// halves are honest about that:
///
/// * **Demo mode** resolves to "sent" without inventing a network call,
///   because the Verify screen accepts `AppConstants.demoOtpCode` and says so
///   on screen behind the same [FeatureFlags.demoMode] flag. The reviewer gets
///   a flow that works end to end and is told why it works.
/// * **Outside demo mode** the repository is asked for real and whatever it
///   throws comes back as a [Failure] for the screen to render — no toast
///   claiming a code was sent when none was.
abstract final class CodeDelivery {
  CodeDelivery._();

  /// Send an SMS one-time code to [phoneE164]. Null on success.
  static Future<Failure?> requestSmsCode(Ref ref, String phoneE164) async {
    if (FeatureFlags.demoMode) return null;
    try {
      await ref.read(authRepositoryProvider).requestOtp(phone: phoneE164);
      return null;
    } catch (error, stackTrace) {
      return error.asFailure(stackTrace);
    }
  }

  /// Send a password-reset code to [email]. Null on success.
  static Future<Failure?> requestEmailResetCode(Ref ref, String email) async {
    if (FeatureFlags.demoMode) return null;
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(email: email);
      return null;
    } catch (error, stackTrace) {
      return error.asFailure(stackTrace);
    }
  }
}
