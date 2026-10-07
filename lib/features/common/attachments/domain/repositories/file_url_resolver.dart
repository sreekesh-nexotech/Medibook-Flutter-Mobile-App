import '../entities/stored_file.dart';

/// Turns a `*_file_id` into a signed URL (`FLUTTER_API_INTEGRATION.md` §11.4).
///
/// The URL lives ten minutes and must never be persisted: implementations
/// memoise in memory only, until shortly before `expires_at`. A token is
/// required, so a signed-out caller gets `UnauthorizedFailure`; a file that
/// is not `clean` is a `NotFoundFailure`.
abstract interface class FileUrlResolver {
  /// A URL for [fileId] that is valid now. Memoised per id while it lasts;
  /// [forceRefresh] fetches a new one regardless.
  Future<SignedFileUrl> resolve(String fileId, {bool forceRefresh = false});

  /// Drop the memoised URL for [fileId] (after a detach / delete).
  void forget(String fileId);
}
