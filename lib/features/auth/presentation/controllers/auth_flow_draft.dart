import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_phone_field.dart';

/// The two auth flows that span more than one screen keep their in-progress
/// data here.
///
/// ## Why these are not `autoDispose`
///
/// Every *form* controller in this folder is `autoDispose`, because its state
/// is worthless once its screen leaves the tree. These two are the opposite:
/// their whole job is to outlive one route.
///
/// * [signupDraftProvider] — CM-03 requires the mobile number to be verified
///   **before** the account is created, so the sign-up form's values have to
///   survive the trip to `/verify` and back.
/// * [passwordResetDraftProvider] — CM-06 runs reset over email *or* mobile,
///   so `/verify` and `/reset` both need to know which channel was used and
///   where the code went.
///
/// Both are cleared explicitly ([SignupDraftController.clear],
/// [PasswordResetDraftController.clear]) when the flow completes or is
/// abandoned, which is the trade for not being `autoDispose`.
///
/// ## What is deliberately *not* here
///
/// The chosen password. It is validated on the sign-up form and then dropped:
/// this build has no account-creation endpoint to hand it to, and carrying a
/// credential across two routes to use it nowhere is a liability, not a
/// feature (Coding Standards §9). Returning to the form re-fills every field
/// except the two password fields, which have to be re-typed.
@immutable
class SignupDraft {
  const SignupDraft({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.countryCode,
    required this.phoneNational,
    this.addressLabel = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.city = '',
    this.stateName = '',
    this.pincode = '',
  });

  final String firstName;
  final String lastName;
  final String email;

  /// The dialling code chosen in `AppPhoneField`.
  final CountryCode countryCode;

  /// Digits only, without the dialling code.
  final String phoneNational;

  final String addressLabel;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String stateName;
  final String pincode;

  /// "Alexandra Johnson" — what the welcome toast and the account use.
  String get fullName => '$firstName $lastName'.trim();

  /// `+919845658525` — the number the OTP was sent to.
  String get phoneE164 => '${countryCode.dialCode}$phoneNational';

  /// `+91 98456 58525`, for copy that echoes the number back.
  String get phoneDisplay => '${countryCode.dialCode} $phoneNational';

  SignupDraft copyWith({
    String? firstName,
    String? lastName,
    String? email,
    CountryCode? countryCode,
    String? phoneNational,
    String? addressLabel,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? stateName,
    String? pincode,
  }) {
    return SignupDraft(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      countryCode: countryCode ?? this.countryCode,
      phoneNational: phoneNational ?? this.phoneNational,
      addressLabel: addressLabel ?? this.addressLabel,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      stateName: stateName ?? this.stateName,
      pincode: pincode ?? this.pincode,
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
      value == sms.slug ? ResetChannel.sms : ResetChannel.email;
}

/// The password reset in progress: where the code was sent, and the code once
/// it has been verified.
@immutable
class PasswordResetDraft {
  const PasswordResetDraft({
    required this.channel,
    required this.destination,
    this.code = '',
  });

  final ResetChannel channel;

  /// The email address or `+91…` number the code went to.
  final String destination;

  /// The verified code, once `/verify` has accepted one. Empty before that.
  final String code;

  bool get isVerified => code.isNotEmpty;

  PasswordResetDraft copyWith({
    ResetChannel? channel,
    String? destination,
    String? code,
  }) {
    return PasswordResetDraft(
      channel: channel ?? this.channel,
      destination: destination ?? this.destination,
      code: code ?? this.code,
    );
  }
}

/// Holds the pending reset across `/forgot` → `/verify` → `/reset`.
class PasswordResetDraftController extends StateNotifier<PasswordResetDraft?> {
  PasswordResetDraftController() : super(null);

  void start({required ResetChannel channel, required String destination}) {
    state = PasswordResetDraft(channel: channel, destination: destination);
  }

  /// Record the code `/verify` accepted, so `/reset` can submit it.
  void codeVerified(String code) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(code: code);
  }

  void clear() => state = null;
}

/// The password reset in progress, or null. See the file doc for why this is
/// not `autoDispose`.
final passwordResetDraftProvider =
    StateNotifierProvider<PasswordResetDraftController, PasswordResetDraft?>(
      (ref) => PasswordResetDraftController(),
    );
