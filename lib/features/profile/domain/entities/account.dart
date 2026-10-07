import '../../../auth/domain/entities/user.dart';
import 'person.dart';

/// The account-level objects of §4.9, §5.2, §5.6 and §5.9 that are not the
/// `User` itself (which lives in `features/auth`).

/// What `PATCH /patient/me` takes (§5.2): only the fields being changed.
/// Phone and email cannot be changed here.
class ProfileUpdate {
  const ProfileUpdate({
    this.firstName,
    this.lastName,
    this.locale,
    this.timezone,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.allergies,
    this.marketingOptIn,
    this.clearLastName = false,
    this.clearBloodGroup = false,
  });

  final String? firstName;
  final String? lastName;
  final String? locale;
  final String? timezone;
  final DateTime? dateOfBirth;
  final Gender? gender;
  final String? bloodGroup;

  /// ≤ 50 items, each ≤ 100 chars; replaces the list.
  final List<String>? allergies;
  final bool? marketingOptIn;

  final bool clearLastName;
  final bool clearBloodGroup;

  bool get isEmpty =>
      firstName == null &&
      lastName == null &&
      locale == null &&
      timezone == null &&
      dateOfBirth == null &&
      gender == null &&
      bloodGroup == null &&
      allergies == null &&
      marketingOptIn == null &&
      !clearLastName &&
      !clearBloodGroup;

  /// The subset of [this] whose values differ from [current] — so a save
  /// sends only the changed fields, as §5.2 asks.
  ProfileUpdate diffAgainst(User current) => ProfileUpdate(
    firstName: firstName == current.firstName ? null : firstName,
    lastName: lastName == (current.lastName ?? '') ? null : lastName,
    locale: locale == current.locale ? null : locale,
    timezone: timezone == current.timezone ? null : timezone,
    dateOfBirth: _sameDay(dateOfBirth, current.dateOfBirth)
        ? null
        : dateOfBirth,
    gender: gender?.wire == current.gender ? null : gender,
    bloodGroup: bloodGroup == current.bloodGroup ? null : bloodGroup,
    allergies: allergies != null && _sameList(allergies!, current.allergies)
        ? null
        : allergies,
    marketingOptIn: marketingOptIn == current.marketingOptIn
        ? null
        : marketingOptIn,
    clearLastName: clearLastName && current.lastName != null,
    clearBloodGroup: clearBloodGroup && current.bloodGroup != null,
  );

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// `Consent` (§5.9): one accepted document version.
class Consent {
  const Consent({
    required this.id,
    required this.documentSlug,
    required this.documentVersion,
    required this.acceptedAt,
  });

  final String id;
  final String documentSlug;
  final int documentVersion;
  final DateTime acceptedAt;

  @override
  bool operator ==(Object other) =>
      other is Consent &&
      other.id == id &&
      other.documentSlug == documentSlug &&
      other.documentVersion == documentVersion;

  @override
  int get hashCode => Object.hash(id, documentSlug, documentVersion);
}

/// A legal document the user still has to accept: the current published
/// version is newer than anything they accepted (§3.1 + §5.9).
class PendingConsent {
  const PendingConsent({
    required this.slug,
    required this.currentVersion,
    this.acceptedVersion,
  });

  final String slug;
  final int currentVersion;

  /// Null when the user never accepted this document.
  final int? acceptedVersion;

  bool get isFirstAcceptance => acceptedVersion == null;

  @override
  bool operator ==(Object other) =>
      other is PendingConsent &&
      other.slug == slug &&
      other.currentVersion == currentVersion &&
      other.acceptedVersion == acceptedVersion;

  @override
  int get hashCode => Object.hash(slug, currentVersion, acceptedVersion);
}

/// `DeletionRequest` (§5.6).
class DeletionRequest {
  const DeletionRequest({
    required this.requestNo,
    required this.status,
    required this.requestedAt,
    this.kind = 'deletion',
    this.coolingOffEndsAt,
    this.completedAt,
  });

  /// `DSR-2026-000012` — show this.
  final String requestNo;
  final String kind;
  final DeletionStatus status;
  final DateTime requestedAt;

  /// 30 days after [requestedAt]; the account can be reactivated until then.
  final DateTime? coolingOffEndsAt;
  final DateTime? completedAt;

  /// A request the user can still withdraw.
  bool get isOpen => switch (status) {
    DeletionStatus.requested ||
    DeletionStatus.coolingOff ||
    DeletionStatus.verifying => true,
    _ => false,
  };

  @override
  bool operator ==(Object other) =>
      other is DeletionRequest &&
      other.requestNo == requestNo &&
      other.status == status;

  @override
  int get hashCode => Object.hash(requestNo, status);
}

/// Deletion request `status` (§17).
enum DeletionStatus {
  requested('requested', 'Requested'),
  coolingOff('cooling_off', 'Cooling off'),
  verifying('verifying', 'Being verified'),
  processing('processing', 'Being processed'),
  completed('completed', 'Completed'),
  rejected('rejected', 'Rejected'),
  noData('no_data', 'No data to delete'),
  withdrawn('withdrawn', 'Withdrawn');

  const DeletionStatus(this.wire, this.label);

  final String wire;
  final String label;

  static DeletionStatus fromWire(String? value) => values.firstWhere(
    (s) => s.wire == value,
    orElse: () => DeletionStatus.requested,
  );
}

/// One personal-data export request (`/patient/me/data-exports`, §5.7).
///
/// The patient asks for it; Medibook prepares the file (the nightly run or
/// compliance staff) and a `dsr.export_ready` notification follows. Once
/// [isReady], [id] buys a ten-minute download link for the seven days the
/// file is kept. Medical documents and insurance are never in an export.
class DataExportRequest {
  const DataExportRequest({
    required this.id,
    required this.requestNo,
    required this.status,
    required this.requestedAt,
    this.dueAt,
    this.completedAt,
  });

  /// The `dsr_id` the download link takes. Never shown.
  final String id;

  /// `DSR-2026-0001` — show this.
  final String requestNo;
  final DataExportStatus status;
  final DateTime requestedAt;

  /// The date Medibook must have answered by (30 days after [requestedAt]).
  final DateTime? dueAt;
  final DateTime? completedAt;

  /// Still being prepared — a second request is refused while one is open
  /// (`409 STATE_CONFLICT`).
  bool get isOpen => switch (status) {
    DataExportStatus.requested ||
    DataExportStatus.verifying ||
    DataExportStatus.processing => true,
    _ => false,
  };

  /// The file exists and a download link can be asked for.
  bool get isReady => status == DataExportStatus.completed;

  @override
  bool operator ==(Object other) =>
      other is DataExportRequest &&
      other.id == id &&
      other.status == status &&
      other.completedAt == completedAt;

  @override
  int get hashCode => Object.hash(id, status, completedAt);
}

/// Export request `status` — the data-subject-request states (§17) an export
/// can be in.
enum DataExportStatus {
  requested('requested', 'Requested'),
  verifying('verifying', 'Being verified'),
  processing('processing', 'Being prepared'),
  completed('completed', 'Ready'),
  rejected('rejected', 'Rejected'),
  noData('no_data', 'Nothing to export'),
  withdrawn('withdrawn', 'Withdrawn');

  const DataExportStatus(this.wire, this.label);

  final String wire;
  final String label;

  static DataExportStatus fromWire(String? value) => values.firstWhere(
    (s) => s.wire == value,
    orElse: () => DataExportStatus.requested,
  );
}

/// `GET /shared/data-exports/{id}/download-url` (§5.7): a signed link, valid
/// for ten minutes, to a file kept until [fileExpiresAt].
class DataExportLink {
  const DataExportLink({
    required this.url,
    this.expiresAt,
    this.fileExpiresAt,
    this.requestNo,
  });

  final String url;
  final DateTime? expiresAt;
  final DateTime? fileExpiresAt;
  final String? requestNo;
}

/// `Session` (§4.9): one signed-in device.
class AccountSession {
  const AccountSession({
    required this.id,
    required this.isCurrent,
    this.deviceId,
    this.userAgent,
    this.ip,
    this.createdAt,
    this.lastSeenAt,
    this.absoluteExpiresAt,
  });

  final String id;
  final bool isCurrent;
  final String? deviceId;
  final String? userAgent;
  final String? ip;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final DateTime? absoluteExpiresAt;

  static const String _appProduct = 'Medibook/';

  /// The device the session was signed in from, read from its `user_agent`:
  /// "Medibook/1.0.0 (Google Pixel 7; Android 14)" → "Google Pixel 7 ·
  /// Android 14". An app sign-in from before the app named its device
  /// ("Medibook/1.0") reads "Medibook app"; anything else — a browser, a
  /// script — is shown as it was sent.
  String get deviceLabel {
    final ua = userAgent?.trim();
    if (ua == null || ua.isEmpty) return 'Unknown device';
    final paren = ua.indexOf('(');
    if (paren != -1 && ua.endsWith(')')) {
      final details = ua
          .substring(paren + 1, ua.length - 1)
          .split(';')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(' · ');
      if (details.isNotEmpty) return details;
    }
    if (ua.startsWith(_appProduct)) return 'Medibook app';
    return ua;
  }

  /// "Medibook 1.0.0" — the app build that signed in — when the user agent
  /// names its device too. Null for other clients, and for old app sign-ins
  /// whose version was a fixed placeholder rather than the build's.
  String? get appVersionLabel {
    final ua = userAgent?.trim();
    if (ua == null || !ua.startsWith(_appProduct) || !ua.contains('(')) {
      return null;
    }
    final version = ua.substring(_appProduct.length, ua.indexOf('(')).trim();
    return version.isEmpty ? null : 'Medibook $version';
  }

  @override
  bool operator ==(Object other) =>
      other is AccountSession &&
      other.id == id &&
      other.isCurrent == isCurrent &&
      other.lastSeenAt == lastSeenAt;

  @override
  int get hashCode => Object.hash(id, isCurrent, lastSeenAt);
}
