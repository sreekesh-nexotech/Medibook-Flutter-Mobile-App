/// Which sign-in method minted the current session. Drives what the profile
/// screen offers (a password-less user has no "change password" row).
enum AuthMethod { password, otp, google, apple }

/// The signed-in patient.
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
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.authMethod = AuthMethod.password,
    this.emailVerified = false,
    this.phoneVerified = false,
  });

  /// Server-assigned id. The only user field safe to log or send to analytics.
  final String id;

  final String name;
  final String email;

  /// E.164 without the `+` (`919845658525`), or null when not on file.
  final String? phone;

  final String? avatarUrl;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;

  final AuthMethod authMethod;
  final bool emailVerified;
  final bool phoneVerified;

  /// First name, for the home greeting ("Hi, Alexandra").
  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final space = trimmed.indexOf(' ');
    return space == -1 ? trimmed : trimmed.substring(0, space);
  }

  /// Up to two initials, for the avatar fallback.
  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    final first = parts.first.substring(0, 1);
    final second = parts.length > 1 ? parts[1].substring(0, 1) : '';
    return (first + second).toUpperCase();
  }

  /// Whether the account can change its own password (CM-51).
  bool get canChangePassword => authMethod == AuthMethod.password;

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    AuthMethod? authMethod,
    bool? emailVerified,
    bool? phoneVerified,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      authMethod: authMethod ?? this.authMethod,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is User &&
      other.id == id &&
      other.name == name &&
      other.email == email &&
      other.phone == phone &&
      other.avatarUrl == avatarUrl &&
      other.dateOfBirth == dateOfBirth &&
      other.gender == gender &&
      other.bloodGroup == bloodGroup &&
      other.authMethod == authMethod &&
      other.emailVerified == emailVerified &&
      other.phoneVerified == phoneVerified;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    email,
    phone,
    avatarUrl,
    dateOfBirth,
    gender,
    bloodGroup,
    authMethod,
    emailVerified,
    phoneVerified,
  );

  /// Id only — a health app must never log a patient's name or contact details.
  @override
  String toString() => 'User($id)';
}

/// The credential pair a session is made of.
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
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

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
