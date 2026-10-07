import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/common/attachments/infrastructure/data_sources/remote/files_api.dart';
import 'package:medibook/features/common/attachments/infrastructure/repositories/file_url_resolver_impl.dart';

/// `GET /shared/files/{id}/url` memoised in memory only, until shortly
/// before `expires_at`; concurrent callers share one request; a 404 for a
/// file that is not clean is a NotFoundFailure.
void main() {
  late _UrlApi api;
  late DateTime now;

  setUp(() {
    api = _UrlApi();
    now = DateTime.utc(2026, 9, 30, 10);
  });

  FileUrlResolverImpl resolver() =>
      FileUrlResolverImpl(api: api, now: () => now);

  test(
    'memoises a URL for its lifetime and refreshes once it is near expiry',
    () async {
      api.expiresAt = now.add(const Duration(minutes: 10));
      final r = resolver();

      final first = await r.resolve('f1');
      final second = await r.resolve('f1');
      expect(api.calls, 1);
      expect(second.url, first.url);

      now = now.add(const Duration(minutes: 9, seconds: 45));
      await r.resolve('f1');
      expect(api.calls, 2, reason: 'inside the 30 s safety margin');
    },
  );

  test('forceRefresh and forget bypass the memo', () async {
    api.expiresAt = now.add(const Duration(minutes: 10));
    final r = resolver();
    await r.resolve('f1');
    await r.resolve('f1', forceRefresh: true);
    expect(api.calls, 2);
    r.forget('f1');
    await r.resolve('f1');
    expect(api.calls, 3);
  });

  test('concurrent callers for one id share a single request', () async {
    api.expiresAt = now.add(const Duration(minutes: 10));
    final r = resolver();
    final results = await Future.wait([r.resolve('f1'), r.resolve('f1')]);
    expect(api.calls, 1);
    expect(results[0].url, results[1].url);
  });

  test(
    'a 404 (file not clean) is a NotFoundFailure and is not memoised',
    () async {
      api.error = const HttpStatusException(statusCode: 404, code: 'NOT_FOUND');
      final r = resolver();
      await expectLater(r.resolve('f1'), throwsA(isA<NotFoundFailure>()));
      api.error = null;
      api.expiresAt = now.add(const Duration(minutes: 10));
      await r.resolve('f1');
      expect(api.calls, 2);
    },
  );
}

class _UrlApi implements FilesApi {
  int calls = 0;
  DateTime? expiresAt;
  Object? error;

  @override
  Future<Map<String, Object?>> url(String fileId) async {
    calls++;
    if (error != null) throw error!;
    return {
      'url': 'https://signed.example/$fileId?n=$calls',
      'expires_at': expiresAt!.toIso8601String(),
    };
  }

  @override
  Future<Map<String, Object?>> complete(String fileId) =>
      throw UnimplementedError();

  @override
  Future<Map<String, Object?>> createUpload({
    required String purpose,
    required String mime,
    required int sizeBytes,
    String? sha256,
    String? originalName,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(String fileId, {int? version}) =>
      throw UnimplementedError();

  @override
  Future<Map<String, Object?>> file(String fileId) =>
      throw UnimplementedError();
}
