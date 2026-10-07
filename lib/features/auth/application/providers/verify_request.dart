import 'package:flutter/foundation.dart';

import '../../../../app/router/app_routes.dart';
import 'auth_flow_draft.dart';

/// Why the Verify Code screen is on screen.
///
/// The three signed-out flows and the signed-in phone change all end on the
/// same four boxes; the caller names its purpose and the screen reads its
/// headline, its destination copy, its next route and — decisively — what a
/// correct code *does* from that.
enum VerifyPurpose {
  /// CM-03 — confirming the mobile number before the account is created
  /// (`POST /auth/signup/verify`).
  signup('signup'),

  /// CM-04 — signing in with a mobile number
  /// (`POST /auth/login/otp/verify`).
  mobileLogin('login'),

  /// CM-06 — the code step of a password reset
  /// (`POST /auth/password/forgot/verify` → `reset_token`).
  passwordReset('reset');

  // No phone-change purpose: a number change confirms both codes on its own
  // screen (`/profile/phone`). The one that lived here accepted any
  // well-formed code without asking the server (BL-AUTH-022).

  const VerifyPurpose(this.slug);

  /// The value carried in the `/verify?purpose=` query.
  final String slug;

  static VerifyPurpose fromSlug(String? value) {
    for (final purpose in values) {
      if (purpose.slug == value) return purpose;
    }
    return VerifyPurpose.passwordReset;
  }
}

/// Everything the Verify Code screen needs to serve one flow.
///
/// Built by the caller from the [OtpChallenge] the "start" call returned,
/// encoded into the `/verify` query so it survives a route rebuild, and
/// decoded again by [VerifyRequest.fromQuery]. The `challengeId` is what the
/// backend's verify call takes (§4); the code is bound to it and to this
/// device's fingerprint.
///
/// ```dart
/// context.go(VerifyRequest(
///   purpose: VerifyPurpose.signup,
///   channel: ResetChannel.sms,
///   destination: draft.phoneE164,
///   challengeId: challenge.challengeId,
///   codeLength: challenge.codeLength,
/// ).path);
/// ```
@immutable
class VerifyRequest {
  const VerifyRequest({
    required this.purpose,
    required this.channel,
    required this.destination,
    required this.challengeId,
    this.codeLength = 4,
    this.resendAfterSeconds = 30,
    this.expiresAt,
  });

  /// Reads the query `/verify` was entered with.
  factory VerifyRequest.fromQuery(Map<String, String> query) {
    final purpose = VerifyPurpose.fromSlug(query['purpose']);
    return VerifyRequest(
      purpose: purpose,
      channel: query.containsKey('channel')
          ? ResetChannel.fromSlug(query['channel'])
          : ResetChannel.sms,
      destination: query['to'] ?? '',
      challengeId: query['ch'] ?? '',
      codeLength: int.tryParse(query['len'] ?? '') ?? 4,
      resendAfterSeconds: int.tryParse(query['resend'] ?? '') ?? 30,
      expiresAt: switch (int.tryParse(query['exp'] ?? '')) {
        final ms? => DateTime.fromMillisecondsSinceEpoch(ms),
        null => null,
      },
    );
  }

  final VerifyPurpose purpose;

  /// How the code was delivered — decides whether the copy says "mobile
  /// number" or "email address". Patients reset by SMS only (§4.7), so a
  /// reset started with an email still arrives by SMS.
  final ResetChannel channel;

  /// The address or number the code went to, echoed in the copy. May be the
  /// masked form from the challenge.
  final String destination;

  /// The open challenge's id — required by every verify call.
  final String challengeId;

  /// Number of OTP boxes (`code_length`, backend-configured).
  final int codeLength;

  /// Seconds before "Resend" is offered.
  final int resendAfterSeconds;

  /// When the code stops working (`expires_at`, 180 s after sending). Null
  /// when the challenge did not say — then no countdown is shown.
  final DateTime? expiresAt;

  /// True when the screen was opened without a challenge (a stale or
  /// hand-typed link) and cannot verify anything.
  bool get isOrphan => challengeId.isEmpty;

  /// The `/verify` path that reproduces this request.
  String get path {
    final query = <String>[
      'purpose=${purpose.slug}',
      'channel=${channel.slug}',
      if (destination.isNotEmpty) 'to=${Uri.encodeQueryComponent(destination)}',
      if (challengeId.isNotEmpty) 'ch=${Uri.encodeQueryComponent(challengeId)}',
      'len=$codeLength',
      'resend=$resendAfterSeconds',
      if (expiresAt != null) 'exp=${expiresAt!.millisecondsSinceEpoch}',
    ];
    return '${AppRoutes.verify}?${query.join('&')}';
  }

  /// This request with a fresh challenge (after a resend).
  VerifyRequest withChallenge(
    String challengeId, {
    int? codeLength,
    int? resendAfterSeconds,
    DateTime? expiresAt,
  }) => VerifyRequest(
    purpose: purpose,
    channel: channel,
    destination: destination,
    challengeId: challengeId,
    codeLength: codeLength ?? this.codeLength,
    resendAfterSeconds: resendAfterSeconds ?? this.resendAfterSeconds,
    expiresAt: expiresAt,
  );

  /// The header title.
  String get title => switch (purpose) {
    VerifyPurpose.signup => 'Verify Mobile',
    VerifyPurpose.mobileLogin => 'Verify Mobile',
    VerifyPurpose.passwordReset => 'Verify Code',
  };

  /// The sentence above the code boxes, which ends with [destination].
  String get blurb => switch (purpose) {
    VerifyPurpose.signup =>
      'Confirm your mobile number to finish creating your account. '
          'We sent a $codeLength-digit code to ',
    VerifyPurpose.mobileLogin => 'We sent a $codeLength-digit code to ',
    VerifyPurpose.passwordReset => 'We sent a $codeLength-digit code to ',
  };

  /// What the code was sent to, in words — for the resend toast and the
  /// screen-reader label.
  String get channelLabel =>
      channel == ResetChannel.sms ? 'mobile number' : 'email address';

  /// The submit button's label.
  String get confirmLabel => switch (purpose) {
    VerifyPurpose.signup => 'Verify & Create Account',
    VerifyPurpose.mobileLogin => 'Verify & Log In',
    VerifyPurpose.passwordReset => 'Verify',
  };

  /// Where the back arrow goes — the screen that sent the code.
  String get backPath => switch (purpose) {
    VerifyPurpose.signup => AppRoutes.signup,
    VerifyPurpose.mobileLogin => AppRoutes.login,
    VerifyPurpose.passwordReset => AppRoutes.forgot,
  };

  /// True when a successful code signs the user in rather than unlocking the
  /// next step of a reset or confirming a detail on an existing session.
  bool get signsIn =>
      purpose == VerifyPurpose.signup || purpose == VerifyPurpose.mobileLogin;
}
