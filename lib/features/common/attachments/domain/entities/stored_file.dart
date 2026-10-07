import 'dart:typed_data';

/// Why a file is being uploaded (`FLUTTER_API_INTEGRATION.md` §11.1, §17).
/// Decides the MIME allowlist and what the file may later be attached to.
enum FileUploadPurpose {
  medicalDocument('medical_document'),
  insurance('insurance'),
  ticketAttachment('ticket_attachment'),
  avatar('avatar');

  const FileUploadPurpose(this.wire);

  final String wire;
}

/// The server-side state of a stored file (§11.1, §17).
enum FileStatus {
  pending('pending', 'Upload not finished'),
  uploaded('uploaded', 'Waiting for its virus check'),
  scanning('scanning', 'Being checked for viruses'),
  clean('clean', 'Ready'),
  infected('infected', 'Blocked — a virus was found'),
  sealed('sealed', 'Locked after the account was deleted'),
  scanFailed('scan_failed', 'Could not be checked'),

  /// A value this build does not know — kept so a new server state cannot
  /// crash the decoder.
  unknown('unknown', 'Not available');

  const FileStatus(this.wire, this.label);

  final String wire;

  /// What the patient reads — never the wire value.
  final String label;

  static FileStatus fromWire(String? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return FileStatus.unknown;
  }

  /// The scan reached a verdict, good or bad.
  bool get isTerminal =>
      this == clean || this == infected || this == scanFailed || this == sealed;

  /// The virus scanner refused the file; tell the user it was rejected.
  bool get isRejected => this == infected || this == scanFailed;
}

/// A file the backend holds (`File` in §11.1).
class StoredFile {
  const StoredFile({
    required this.id,
    required this.purpose,
    required this.originalName,
    required this.mime,
    required this.sizeBytes,
    required this.status,
    required this.version,
    this.sha256,
    this.uploadedAt,
    this.scannedAt,
    this.createdAt,
  });

  final String id;
  final FileUploadPurpose purpose;
  final String originalName;
  final String mime;
  final int sizeBytes;
  final FileStatus status;
  final int version;

  /// Hex digest; null until the scanner has seen the bytes.
  final String? sha256;
  final DateTime? uploadedAt;
  final DateTime? scannedAt;
  final DateTime? createdAt;

  StoredFile copyWith({FileStatus? status, int? version}) => StoredFile(
    id: id,
    purpose: purpose,
    originalName: originalName,
    mime: mime,
    sizeBytes: sizeBytes,
    status: status ?? this.status,
    version: version ?? this.version,
    sha256: sha256,
    uploadedAt: uploadedAt,
    scannedAt: scannedAt,
    createdAt: createdAt,
  );
}

/// A file chosen on the device, before anything has left it.
///
/// [readBytes] is deferred so the picker never loads a 10 MB file into
/// memory just to show its name; the upload reads it once, when it needs
/// it.
class PickedFile {
  const PickedFile({
    required this.name,
    required this.mime,
    required this.sizeBytes,
    required this.readBytes,
    this.path,
  });

  /// Original file name, as shown to the user and sent as `original_name`.
  final String name;

  /// MIME type derived from the extension / the platform's hint.
  final String mime;

  final int sizeBytes;

  /// Local path when the platform gives one (a camera capture, a document
  /// picked from storage); null on platforms that only expose bytes.
  final String? path;

  final Future<Uint8List> Function() readBytes;
}

/// What step 1 of the upload handed back (§11.1) — where to PUT the bytes and
/// exactly which headers to send with them.
class UploadTicket {
  const UploadTicket({
    required this.file,
    required this.uploadUrl,
    required this.method,
    required this.headers,
    this.expiresAt,
  });

  final StoredFile file;
  final String uploadUrl;
  final String method;

  /// Sent **exactly** as given — no bearer, no extras (§11.1 step 2).
  final Map<String, String> headers;
  final DateTime? expiresAt;
}

/// A short-lived signed URL (§11.3, §11.4). Never cache it beyond
/// [expiresAt]; the resolver keeps it in memory only.
class SignedFileUrl {
  const SignedFileUrl({required this.url, required this.expiresAt});

  final String url;
  final DateTime expiresAt;

  bool isValidAt(
    DateTime now, {
    Duration margin = const Duration(seconds: 30),
  }) => expiresAt.subtract(margin).isAfter(now);
}

/// Where an upload is, for the progress UI.
enum UploadPhase {
  /// Reading the file and registering it (step 1).
  preparing,

  /// PUT to storage (step 2). [UploadProgress.fraction] moves here.
  uploading,

  /// `complete` sent; waiting for the virus scan (step 3 + polling).
  scanning,
}

class UploadProgress {
  const UploadProgress({required this.phase, this.fraction = 0});

  final UploadPhase phase;

  /// 0..1 of the bytes sent during [UploadPhase.uploading].
  final double fraction;
}

/// The typed end of an upload. Transport and validation problems are
/// *thrown* as `Failure`; these are the outcomes of a run that completed.
sealed class UploadOutcome {
  const UploadOutcome(this.file);

  /// The file as last seen from the server.
  final StoredFile file;
}

/// Scanned and clean — the id may now be attached to a document or policy.
class UploadClean extends UploadOutcome {
  const UploadClean(super.file);
}

/// `infected` or `scan_failed` — tell the user the file was rejected.
class UploadRejected extends UploadOutcome {
  const UploadRejected(super.file);
}

/// The scanner had not answered within the polling budget. The file exists
/// server-side and may still turn clean; the caller decides whether to
/// keep polling later or discard it.
class UploadScanTimedOut extends UploadOutcome {
  const UploadScanTimedOut(super.file);
}
