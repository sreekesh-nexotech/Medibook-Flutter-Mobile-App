import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/phone.dart';
import '../../domain/entities/user.dart';

/// The two auth flows that span more than one screen keep their in-progress
/// data here.
///
/// ## Why these are not `autoDispose`
///
/// Every *form* controller in this folder is `autoDispose`, because its state
/// is worthless once its screen leaves the tree. These two are the opposite:
/// their whole job is to outlive one route.
///
/// * [signupDraftProvider] — the backend verifies the mobile number **before**
///   the account exists (`signup/start` → `signup/verify`, §4.1–4.2), so the
///   form's values have to survive the trip to `/verify` and back.
/// * [passwordResetDraftProvider] — `forgot/verify` hands back a
///   `reset_token` that `password/reset` needs (§4.7), so `/verify` and
///   `/reset` share it.
///
/// Both are cleared explicitly when the flow completes or is abandoned.
///
/// ## What is deliberately *not* here
///
/// The chosen password. `signup/start` takes it, so it is submitted once from
/// the form and then dropped; returning to the form re-fills every field
/// except the two password fields (Coding Standards §9).
@immutable
class SignupDraft {
  const SignupDraft({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.countryCode,
    required this.phoneNational,
    required this.dateOfBirth,
    this.addressLabel = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.city = '',
    this.stateName = '',
    this.pincode = '',
    this.marketingOptIn = false,
  });

  final String firstName;
  final String lastName;
  final String email;

  /// The dialling code chosen in `AppPhoneField`.
  final CountryCode countryCode;

  /// Digits only, without the dialling code.
  final String phoneNational;

  /// Required: account holders must be 18+ (`409 UNDER_AGE`, §4.1).
  final DateTime? dateOfBirth;

  final String addressLabel;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String stateName;
  final String pincode;
  final bool marketingOptIn;

  /// "Alexandra Johnson" — what the welcome toast uses.
  String get fullName => '$firstName $lastName'.trim();

  /// `+919845658525` — the number the OTP was sent to.
  String get phoneE164 => '${countryCode.dialCode}$phoneNational';

  /// `+91 98456 58525`, for copy that echoes the number back.
  String get phoneDisplay => '${countryCode.dialCode} $phoneNational';

  bool get hasAddress => addressLine1.trim().isNotEmpty;

  /// The wire request (§4.1). [password] is passed at submit time only.
  SignupRequest toRequest({String? password}) => SignupRequest(
    firstName: firstName,
    lastName: lastName.isEmpty ? null : lastName,
    phoneE164: phoneE164,
    dateOfBirth: dateOfBirth ?? DateTime.now(),
    email: email.isEmpty ? null : email,
    password: password,
    acceptedTerms: true,
    acceptedPrivacy: true,
    acceptedGuidelines: true,
    marketingOptIn: marketingOptIn,
    address: hasAddress
        ? SignupAddress(
            label: addressLabel.isEmpty ? 'Home' : addressLabel,
            addressLine1: addressLine1,
            addressLine2: addressLine2.isEmpty ? null : addressLine2,
            city: city,
            state: stateName,
            pincode: pincode,
          )
        : null,
  );

  SignupDraft copyWith({
    String? firstName,
    String? lastName,
    String? email,
    CountryCode? countryCode,
    String? phoneNational,
    DateTime? dateOfBirth,
    String? addressLabel,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? stateName,
    String? pincode,
    bool? marketingOptIn,
  }) {
    return SignupDraft(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      countryCode: countryCode ?? this.countryCode,
      phoneNational: phoneNational ?? this.phoneNational,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      addressLabel: addressLabel ?? this.addressLabel,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      stateName: stateName ?? this.stateName,
      pincode: pincode ?? this.pincode,
      marketingOptIn: marketingOptIn ?? this.marketingOptIn,
    );
  }
}

/// Holds the pending sign-up between `/signup` and `/verify`. Null when no
/// sign-up is in progress.
class SignupDraftController extends StateNotifier<SignupDraft?> {
  SignupDraftController() : super(null);

  void save(SignupDraft draft) => state = draft;

  void clear() => state = null;
}

/// The sign-up in progress, or null. See the file doc for why this is not
/// `autoDispose`.
final signupDraftProvider =
    StateNotifierProvider<SignupDraftController, SignupDraft?>(
      (ref) => SignupDraftController(),
    );

/// How a one-time code was delivered.
enum ResetChannel {
  /// To an email address.
  email('email'),

  /// To a mobile number by SMS.
  sms('sms');

  const ResetChannel(this.slug);

  /// The value used in the `/verify?channel=` query.
  final String slug;

  static ResetChannel fromSlug(String? value) =>
      value == email.slug ? ResetChannel.email : ResetChannel.sms;
}

/// The password reset in progress: where the code was sent, and the
/// `reset_token` once `/verify` has been accepted.
@immutable
class PasswordResetDraft {
  const PasswordResetDraft({
    required this.channel,
    required this.destination,
    required this.challengeId,
    this.resetToken,
    this.resetTokenExpiresAt,
  });

  final ResetChannel channel;

  /// The email address or `+91…` number the user typed.
  final String destination;

  /// The open challenge, so `/reset`'s back arrow can return to it.
  final String challengeId;

  /// From `forgot/verify` (§4.7 step 2). Null before that.
  final String? resetToken;

  final DateTime? resetTokenExpiresAt;

  bool get isVerified => resetToken != null && resetToken!.isNotEmpty;

  PasswordResetDraft copyWith({
    ResetChannel? channel,
    String? destination,
    String? challengeId,
    String? resetToken,
    DateTime? resetTokenExpiresAt,
  }) {
    return PasswordResetDraft(
      channel: channel ?? this.channel,
      destination: destination ?? this.destination,
      challengeId: challengeId ?? this.challengeId,
      resetToken: resetToken ?? this.resetToken,
      resetTokenExpiresAt: resetTokenExpiresAt ?? this.resetTokenExpiresAt,
    );
  }
}

/// Holds the pending reset across `/forgot` → `/verify` → `/reset`.
class PasswordResetDraftController extends StateNotifier<PasswordResetDraft?> {
  PasswordResetDraftController() : super(null);

  void start({
    required ResetChannel channel,
    required String destination,
    required String challengeId,
  }) {
    state = PasswordResetDraft(
      channel: channel,
      destination: destination,
      challengeId: challengeId,
    );
  }

  /// A resend minted a new challenge id.
  void challengeReplaced(String challengeId) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(challengeId: challengeId);
  }

  /// Record the grant `/verify` received, so `/reset` can submit it.
  void granted(String resetToken, {DateTime? expiresAt}) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(
      resetToken: resetToken,
      resetTokenExpiresAt: expiresAt,
    );
  }

  void clear() => state = null;
}

/// The password reset in progress, or null. See the file doc for why this is
/// not `autoDispose`.
final passwordResetDraftProvider =
    StateNotifierProvider<PasswordResetDraftController, PasswordResetDraft?>(
      (ref) => PasswordResetDraftController(),
    );
