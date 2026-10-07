import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/file_size.dart';
import 'stored_file.dart';

/// The client-side half of the upload rules in
/// `FLUTTER_API_INTEGRATION.md` §11.1: the per-purpose MIME allowlist and the
/// 10 MB cap, checked **before** any request is made.
///
/// The server enforces the same rules (`415 FILE_TYPE_NOT_ALLOWED`,
/// `413 FILE_TOO_LARGE`); this exists so a patient hears "that file type is
/// not accepted" instantly rather than after a wasted round trip. The
/// failures it produces carry the same `apiCode`s, so the UI branches once.
abstract final class UploadPolicy {
  UploadPolicy._();

  static const String mimePdf = 'application/pdf';
  static const String mimeJpeg = 'image/jpeg';
  static const String mimePng = 'image/png';
  static const String mimeHeic = 'image/heic';

  /// The server's default cap (`meta.max_bytes` = 10485760). Only a fallback:
  /// the real one is the platform setting `upload_max_bytes`, passed to
  /// [validate] as `limitBytes` once app-config publishes it.
  static const int maxBytes = 10 * 1024 * 1024;

  /// The §11.1 table, verbatim.
  static const Map<FileUploadPurpose, Set<String>> allowedMimes = {
    FileUploadPurpose.medicalDocument: {mimePdf, mimeJpeg, mimePng, mimeHeic},
    FileUploadPurpose.insurance: {mimePdf, mimeJpeg, mimePng, mimeHeic},
    FileUploadPurpose.ticketAttachment: {mimePdf, mimeJpeg, mimePng},
    FileUploadPurpose.avatar: {mimeJpeg, mimePng, mimeHeic},
  };

  static const Map<String, String> _mimeByExtension = {
    'pdf': mimePdf,
    'jpg': mimeJpeg,
    'jpeg': mimeJpeg,
    'png': mimePng,
    'heic': mimeHeic,
    'heif': mimeHeic,
  };

  /// Extensions the platform picker should offer for [purpose] — the
  /// allowlist expressed the way `file_picker` wants it.
  static List<String> allowedExtensions(FileUploadPurpose purpose) {
    final allowed = allowedMimes[purpose] ?? const <String>{};
    return [
      for (final entry in _mimeByExtension.entries)
        if (allowed.contains(entry.value)) entry.key,
    ];
  }

  /// MIME type for a file name, or null when the extension is not one this
  /// app knows. A platform-supplied [hint] wins when it is on the allowlist.
  static String? mimeFor(String fileName, {String? hint}) {
    if (hint != null && hint.isNotEmpty) {
      final lower = hint.toLowerCase();
      if (_mimeByExtension.containsValue(lower)) return lower;
      if (lower == 'image/heif') return mimeHeic;
    }
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return null;
    return _mimeByExtension[fileName.substring(dot + 1).toLowerCase()];
  }

  /// Null when [file] may be uploaded for [purpose]; otherwise the
  /// [ValidationFailure] the UI should show, carrying the matching server
  /// error code and `meta`.
  ///
  /// [limitBytes] is the server's current cap (`upload_max_bytes` from
  /// app-config); [maxBytes] only when it has not said.
  static ValidationFailure? validate(
    PickedFile file,
    FileUploadPurpose purpose, {
    int limitBytes = maxBytes,
  }) {
    final allowed = allowedMimes[purpose] ?? const <String>{};
    if (!allowed.contains(file.mime)) {
      return ValidationFailure(
        userMessage:
            'That file type is not accepted. '
            'Use ${_describe(allowed)}.',
        apiCode: 'FILE_TYPE_NOT_ALLOWED',
        meta: {'allowed': allowed.toList()},
        fieldErrors: const {'file': 'File type not allowed'},
        debugMessage: 'mime ${file.mime} not in allowlist for ${purpose.wire}',
      );
    }
    if (file.sizeBytes <= 0) {
      return const ValidationFailure(
        userMessage: 'That file is empty. Choose another one.',
        fieldErrors: {'file': 'Empty file'},
        debugMessage: 'size_bytes <= 0',
      );
    }
    if (file.sizeBytes > limitBytes) {
      return ValidationFailure(
        userMessage:
            'That file is too large. The limit is '
            '${formatSizeLimit(limitBytes)}.',
        apiCode: 'FILE_TOO_LARGE',
        meta: {'max_bytes': limitBytes},
        fieldErrors: const {'file': 'File too large'},
        debugMessage: 'size_bytes ${file.sizeBytes} > $limitBytes',
      );
    }
    return null;
  }

  static String _describe(Set<String> mimes) {
    final names = <String>[
      if (mimes.contains(mimePdf)) 'a PDF',
      if (mimes.contains(mimeJpeg) || mimes.contains(mimePng)) 'a JPEG or PNG',
      if (mimes.contains(mimeHeic)) 'a HEIC photo',
    ];
    if (names.isEmpty) return 'a supported file';
    if (names.length == 1) return names.first;
    return '${names.sublist(0, names.length - 1).join(', ')} or ${names.last}';
  }
}
