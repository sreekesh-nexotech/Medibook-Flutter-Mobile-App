import '../../../../../core/network/network_exceptions.dart';
import '../../domain/entities/stored_file.dart';
import '../../domain/repositories/file_url_resolver.dart';
import '../data_sources/remote/files_api.dart';
import 'file_mappers.dart';

/// [FileUrlResolver] over `GET /shared/files/{id}/url`.
///
/// Memoised **in memory only** — a signed URL is never written to Hive or
/// the response cache (§11.3: "do not cache the URL"). An entry is reused
/// until 30 s before its `expires_at`; concurrent callers for the same id
/// share one in-flight request.
class FileUrlResolverImpl implements FileUrlResolver {
  FileUrlResolverImpl({required FilesApi api, DateTime Function()? now})
    : _api = api,
      _now = now ?? DateTime.now;

  final FilesApi _api;
  final DateTime Function() _now;
  final Map<String, SignedFileUrl> _memo = <String, SignedFileUrl>{};
  final Map<String, Future<SignedFileUrl>> _inFlight =
      <String, Future<SignedFileUrl>>{};

  @override
  Future<SignedFileUrl> resolve(String fileId, {bool forceRefresh = false}) {
    if (!forceRefresh) {
      final cached = _memo[fileId];
      if (cached != null && cached.isValidAt(_now())) {
        return Future.value(cached);
      }
      final pending = _inFlight[fileId];
      if (pending != null) return pending;
    }
    final future = _fetch(fileId);
    _inFlight[fileId] = future;
    future.whenComplete(() => _inFlight.remove(fileId)).ignore();
    return future;
  }

  Future<SignedFileUrl> _fetch(String fileId) async {
    try {
      final signed = FileMappers.signedUrl(await _api.url(fileId));
      _memo[fileId] = signed;
      return signed;
    } catch (error, stackTrace) {
      _memo.remove(fileId);
      throw NetworkExceptions.toFailure(error, stackTrace);
    }
  }

  @override
  void forget(String fileId) => _memo.remove(fileId);
}
