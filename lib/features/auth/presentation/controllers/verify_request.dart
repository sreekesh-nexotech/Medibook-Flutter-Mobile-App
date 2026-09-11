import 'package:flutter/foundation.dart';

import '../../../../app/router/app_routes.dart';
import 'auth_flow_draft.dart';

/// Why the Verify Code screen is on screen.
///
/// The screen was built for exactly one caller — the email password-reset flow
/// (audit CM-03: *"a code-entry screen exists, but only inside the email
/// password-reset flow. Sign-up never reaches it"*). Rather than clone it per
/// flow, the three callers now name their [VerifyPurpose] and the screen reads
/// its headline, its destination copy and its next route from that.
enum VerifyPurpose {
  /// CM-03 — confirming the mobile number before the account is created.
  signup('signup'),

  /// CM-04 — signing in with a mobile number instead of a password.
  mobileLogin('login'),

  /// CM-06 — the code step of a password reset, by email or by SMS.
  passwordReset('reset');

  const VerifyPurpose(this.slug);

  /// The value carried in the `/verify?purpose=` query.
  final String slug;

  static VerifyPurpose fromSlug(String? value) {
    for (final purpose in values) {
      if (purpose.slug == value) return purpose;
    }
    // An unrecognised (or absent) purpose is the flow the screen shipped with,
    // so an old link still lands somewhere sensible.
    return VerifyPurpose.passwordReset;
  }
}

/// Everything the Verify Code screen needs to serve one flow.
///
/// Built by the caller, encoded into the `/verify` query so it survives a route
/// rebuild, and decoded again by [VerifyRequest.fromQuery]. The route itself
/// stays the single `/verify` entry in the route table — the orchestrator wires
/// nothing new for this.
///
/// ```dart
/// context.go(VerifyRequest(
///   purpose: VerifyPurpose.signup,
///   channel: ResetChannel.sms,
///   destination: draft.phoneE164,
/// ).path);
/// ```
@immutable
class VerifyRequest {
  const VerifyRequest({
    required this.purpose,
    required this.channel,
    required this.destination,
  });

  /// Reads the query `/verify` was entered with.
  ///
  /// Also accepts the flow's original `?email=` parameter, so a link written
  /// before this screen was parameterised still resolves to the email reset.
  factory VerifyRequest.fromQuery(Map<String, String> query) {
    final purpose = VerifyPurpose.fromSlug(query['purpose']);
    final legacyEmail = query['email'];
    final destination = query['to'] ?? legacyEmail ?? '';
    final channel = query.containsKey('channel')
        ? ResetChannel.fromSlug(query['channel'])
        // No channel named: a sign-up or mobile sign-in is always SMS, and the
        // legacy reset link was always email.
        : (purpose == VerifyPurpose.passwordReset
              ? ResetChannel.email
              : ResetChannel.sms);
    return VerifyRequest(
      purpose: purpose,
      channel: channel,
      destination: destination,
    );
  }

  final VerifyPurpose purpose;

  /// How the code was delivered — decides whether the copy says "mobile
  /// number" or "email address".
  final ResetChannel channel;

  /// The address or number the code went to, echoed in the copy.
  final String destination;

  /// The `/verify` path that reproduces this request.
  String get path {
    final query = <String>[
      'purpose=${purpose.slug}',
      'channel=${channel.slug}',
      if (destination.isNotEmpty) 'to=${Uri.encodeQueryComponent(destination)}',
    ];
    return '${AppRoutes.verify}?${query.join('&')}';
  }

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
          'We sent a 4-digit code to ',
    VerifyPurpose.mobileLogin => 'We sent a 4-digit code to ',
    VerifyPurpose.passwordReset => 'We sent a 4-digit code to ',
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
  /// next step of a reset.
  bool get signsIn => purpose != VerifyPurpose.passwordReset;
}
