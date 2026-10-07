import '../../../../../core/network/network_exceptions.dart';
import '../../domain/entities/stored_file.dart';

/// Wire ↔ entity for `/shared/files` (§11.1). The only place those field
/// names are spelled. Every decoder throws [ResponseFormatException] on a
/// body that does not match, so nothing malformed reaches the UI or a cache.
abstract final class FileMappers {
  FileMappers._();

  static StoredFile storedFile(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const ResponseFormatException(message: 'file has no id');
    }
    final purpose = json['purpose'];
    return StoredFile(
      id: id,
      purpose: FileUploadPurpose.values.firstWhere(
        (p) => p.wire == purpose,
        orElse: () => FileUploadPurpose.medicalDocument,
      ),
      originalName: (json['original_name'] as String?) ?? '',
      mime: (json['mime'] as String?) ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      status: FileStatus.fromWire(json['status'] as String?),
      version: (json['version'] as num?)?.toInt() ?? 1,
      sha256: json['sha256'] as String?,
      uploadedAt: dateTime(json['uploaded_at']),
      scannedAt: dateTime(json['scanned_at']),
      createdAt: dateTime(json['created_at']),
    );
  }

  static UploadTicket ticket(Map<String, Object?> json) {
    final url = json['upload_url'];
    final file = json['file'];
    if (url is! String || url.isEmpty || file is! Map) {
      throw const ResponseFormatException(
        message: 'upload ticket is missing upload_url / file',
      );
    }
    final headers = json['headers'];
    final method = json['method'];
    return UploadTicket(
      file: storedFile(file.cast<String, Object?>()),
      uploadUrl: url,
      method: method is String && method.isNotEmpty ? method : 'PUT',
      headers: {
        if (headers is Map)
          for (final entry in headers.entries)
            entry.key.toString(): entry.value.toString(),
      },
      expiresAt: dateTime(json['expires_at']),
    );
  }

  static SignedFileUrl signedUrl(Map<String, Object?> json) {
    final url = json['url'];
    final expires = dateTime(json['expires_at']);
    if (url is! String || url.isEmpty) {
      throw const ResponseFormatException(message: 'signed url has no url');
    }
    return SignedFileUrl(
      url: url,
      // A missing expiry is treated as "already stale" so it is never reused.
      expiresAt: expires ?? DateTime.now().toUtc(),
    );
  }

  static DateTime? dateTime(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
