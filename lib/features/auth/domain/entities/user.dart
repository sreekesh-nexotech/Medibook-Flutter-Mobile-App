/// Which sign-in method minted the current session. Drives what the profile
/// screen offers (an OTP-only user is offered "set a password").
enum AuthMethod { password, otp }

/// The signed-in patient — the backend's `User` object
/// (`FLUTTER_API_INTEGRATION.md` §4) plus the optional `profile` from
/// `GET /patient/me` (§5.1), which the app treats as one account view.
///
/// A **domain entity**: no JSON, no Hive annotations, no Flutter import. The
/// infrastructure layer maps API payloads onto this, and the presentation layer
/// reads it — neither direction leaks into the other.
///
/// Immutable, with value equality, so Riverpod can tell "same user" from
/// "changed user" without an identity check.
class User {
  const User({
    required this.id,
    required this.firstName,
    this.lastName,
    this.email,
    this.phoneE164,
    this.alternatePhoneE164,
    this.hasPassword = false,
    this.status = UserStatus.active,
    this.locale = 'en-IN',
    this.timezone = 'Asia/Kolkata',
    this.version = 1,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.lastLoginAt,
    this.deletionRequestedAt,
    this.authMethod = AuthMethod.password,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.allergies = const <String>[],
    this.marketingOptIn = false,
    this.avatarFileId,
    this.profileVersion,
  });

  /// Server-assigned id. The only user field safe to log or send to analytics.
  final String id;

  final String firstName;
  final String? lastName;

  /// Nullable on the wire: OTP-only accounts may have no email.
  final String? email;

  /// E.164 with the `+` (`+919845658525`), or null when not on file.
  final String? phoneE164;

  /// A contact number only — never a login (§5.4).
  final String? alternatePhoneE164;

  /// False for an OTP-only account (§4 `User.has_password`).
  final bool hasPassword;

  final UserStatus status;
  final String locale;
  final String timezone;

  /// Row version — sent back as `If-Match` on `PATCH /patient/me` (§1.9).
  final int version;

  final bool emailVerified;
  final bool phoneVerified;
  final DateTime? lastLoginAt;

  /// Set while the account is in its 30-day deletion cooling-off (§5.6).
  final DateTime? deletionRequestedAt;

  final AuthMethod authMethod;

  // ---- Profile (§5.1 `profile`) — null-able until the profile row exists ----
  final DateTime? dateOfBirth;

  /// `female | male | other | undisclosed`, or null.
  final String? gender;

  /// One of the eight ABO/Rh groups, or null.
  final String? bloodGroup;

  final List<String> allergies;
  final bool marketingOptIn;

  /// A file id (§1.11), not a URL. Resolve with `GET /shared/files/{id}/url`.
  final String? avatarFileId;

  /// `profile.version`, or null when there is no profile row yet.
  final int? profileVersion;

  /// "Anita Menon" — what the greeting, the avatar and the forms use.
  String get name => [
    firstName.trim(),
    (lastName ?? '').trim(),
  ].where((part) => part.isNotEmpty).join(' ');

  /// Backwards-compatible alias for [phoneE164].
  String? get phone => phoneE164;

  /// Up to two initials, for the avatar fallback.
  String get initials {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    final first = parts.first.substring(0, 1);
    final second = parts.length > 1 ? parts[1].substring(0, 1) : '';
    return (first + second).toUpperCase();
  }

  /// Whether the account can change its own password (CM-51). An OTP-only
  /// account *sets* one instead (`POST /patient/me/password` without
  /// `current_password`).
  bool get canChangePassword => hasPassword;

  bool get isPendingDeletion => status == UserStatus.pendingDeletion;

  User copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? name,
    String? email,
    String? phoneE164,
    String? phone,
    String? alternatePhoneE164,
    bool clearAlternatePhone = false,
    bool? hasPassword,
    UserStatus? status,
    String? locale,
    String? timezone,
    int? version,
    bool? emailVerified,
    bool? phoneVerified,
    DateTime? lastLoginAt,
    DateTime? deletionRequestedAt,
    bool clearDeletionRequested = false,
    AuthMethod? authMethod,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    List<String>? allergies,
    bool? marketingOptIn,
    String? avatarFileId,
    int? profileVersion,
  }) {
    var resolvedFirst = firstName ?? this.firstName;
    var resolvedLast = lastName ?? this.lastName;
    if (name != null) {
      final trimmed = name.trim();
      final space = trimmed.indexOf(' ');
      resolvedFirst = space == -1 ? trimmed : trimmed.substring(0, space);
      resolvedLast = space == -1 ? null : trimmed.substring(space + 1).trim();
    }
    return User(
      id: id ?? this.id,
      firstName: resolvedFirst,
      lastName: resolvedLast,
      email: email ?? this.email,
      phoneE164: phoneE164 ?? phone ?? this.phoneE164,
      alternatePhoneE164: clearAlternatePhone
          ? null
          : (alternatePhoneE164 ?? this.alternatePhoneE164),
      hasPassword: hasPassword ?? this.hasPassword,
      status: status ?? this.status,
      locale: locale ?? this.locale,
      timezone: timezone ?? this.timezone,
      version: version ?? this.version,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      deletionRequestedAt: clearDeletionRequested
          ? null
          : (deletionRequestedAt ?? this.deletionRequestedAt),
      authMethod: authMethod ?? this.authMethod,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      marketingOptIn: marketingOptIn ?? this.marketingOptIn,
      avatarFileId: avatarFileId ?? this.avatarFileId,
      profileVersion: profileVersion ?? this.profileVersion,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is User &&
      other.id == id &&
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.email == email &&
      other.phoneE164 == phoneE164 &&
      other.alternatePhoneE164 == alternatePhoneE164 &&
      other.hasPassword == hasPassword &&
      other.status == status &&
      other.version == version &&
      other.emailVerified == emailVerified &&
      other.phoneVerified == phoneVerified &&
      other.deletionRequestedAt == deletionRequestedAt &&
      other.authMethod == authMethod &&
      other.dateOfBirth == dateOfBirth &&
      other.gender == gender &&
      other.bloodGroup == bloodGroup &&
      other.marketingOptIn == marketingOptIn &&
      other.avatarFileId == avatarFileId &&
      other.profileVersion == profileVersion &&
      _listEquals(other.allergies, allergies);

  @override
  int get hashCode => Object.hash(
    id,
    firstName,
    lastName,
    email,
    phoneE164,
    hasPassword,
    status,
    version,
    dateOfBirth,
    gender,
    bloodGroup,
    profileVersion,
    Object.hashAll(allergies),
  );

  /// Id only — a health app must never log a patient's name or contact details.
  @override
  String toString() => 'User($id)';

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// `User.status` (§17).
enum UserStatus {
  active('active'),
  blocked('blocked'),
  deleted('deleted'),
  pendingDeletion('pending_deletion');

  const UserStatus(this.wire);

  final String wire;

  static UserStatus fromWire(String? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return UserStatus.active;
  }
}

/// The credential pair a session is made of (§4 `Tokens`).
///
/// Deliberately **not** part of [User]: tokens live in
/// `core/storage/secure_store.dart`, and keeping them off the entity means a
/// `User` can be logged, cached or put in a widget without leaking a
/// credential.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.sessionId,
  });

  final String accessToken;

  /// Rotates on every refresh (§1.4) — always store the newest.
  final String? refreshToken;

  /// When [accessToken] stops working (15 minutes from issue).
  final DateTime? expiresAt;

  /// The backend session id (`Tokens.session_id`).
  final String? sessionId;

  /// True when there is no recorded expiry, or it is still in the future.
  bool get isValid {
    if (accessToken.isEmpty) return false;
    final expiry = expiresAt;
    return expiry == null || expiry.isAfter(DateTime.now());
  }

  /// Never prints the token itself.
  @override
  String toString() =>
      'AuthSession(expiresAt: ${expiresAt?.toIso8601String() ?? 'unknown'})';
}

/// An open one-time-code challenge (§4 `Challenge`).
///
/// Returned by every "start" and "resend" call; the `challengeId` is what the
/// matching "verify" call needs, so it travels with the flow (in the
/// `/verify` query, see `VerifyRequest`).
class OtpChallenge {
  const OtpChallenge({
    required this.challengeId,
    required this.codeLength,
    required this.expiresAt,
    required this.resendAfterSeconds,
    this.destinationMasked,
  });

  final String challengeId;

  /// Build this many OTP boxes (the backend decides, §3.1 / §4).
  final int codeLength;

  /// 180 s after sending — the countdown the screen may show.
  final DateTime? expiresAt;

  /// Seconds before "Resend" may be tapped again (30).
  final int resendAfterSeconds;

  /// `+91******10`, or null when it must not be revealed.
  final String? destinationMasked;

  @override
  String toString() => 'OtpChallenge($challengeId)';
}

/// What `POST /patient/auth/signup/start` takes (§4.1).
class SignupRequest {
  const SignupRequest({
    required this.firstName,
    required this.phoneE164,
    required this.dateOfBirth,
    required this.acceptedTerms,
    required this.acceptedPrivacy,
    required this.acceptedGuidelines,
    this.lastName,
    this.email,
    this.password,
    this.alternatePhoneE164,
    this.marketingOptIn = false,
    this.address,
  });

  final String firstName;
  final String? lastName;
  final String phoneE164;
  final DateTime dateOfBirth;
  final String? email;

  /// Optional: an OTP-only account is normal (§5.1). Sent once, here, and
  /// never carried across a route.
  final String? password;
  final String? alternatePhoneE164;
  final bool acceptedTerms;
  final bool acceptedPrivacy;
  final bool acceptedGuidelines;
  final bool marketingOptIn;

  /// Becomes the default address when given.
  final SignupAddress? address;
}

/// The structured address block on sign-up (§4.1 / §6.2).
class SignupAddress {
  const SignupAddress({
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.pincode,
    this.label,
    this.addressLine2,
    this.addressLine3,
    this.phoneE164,
  });

  final String? label;
  final String addressLine1;
  final String? addressLine2;
  final String? addressLine3;
  final String city;
  final String state;
  final String pincode;
  final String? phoneE164;
}

/// A signed-in user plus the credential that proves it, and — after
/// `signup/verify` — the id of the "self" person to book with (§4.2).
class AuthResult {
  const AuthResult({
    required this.user,
    required this.session,
    this.selfPersonId,
  });

  final User user;
  final AuthSession session;

  /// `person_self.id` from sign-up; null on a plain login.
  final String? selfPersonId;
}

/// The result of `forgot/verify` (§4.7 step 2): the token `password/reset`
/// needs, valid 15 minutes.
class PasswordResetGrant {
  const PasswordResetGrant({required this.resetToken, this.expiresAt});

  final String resetToken;
  final DateTime? expiresAt;

  @override
  String toString() =>
      'PasswordResetGrant(expires ${expiresAt?.toIso8601String()})';
}
