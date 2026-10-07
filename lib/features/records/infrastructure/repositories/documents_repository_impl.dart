import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../../common/attachments/domain/entities/stored_file.dart';
import '../../../common/attachments/infrastructure/repositories/file_mappers.dart';
import '../../../common/pagination/domain/entities/paged.dart';
import '../../domain/entities/medical_document.dart';
import '../../domain/repositories/documents_repository.dart';
import '../data_sources/remote/documents_api.dart';
import 'document_mappers.dart';

/// [DocumentsRepository] over [DocumentsApi] + [CachedFetcher].
///
/// * Reads: `CachedFetcher.fetch` / `.get` with [DocumentMappers.fromJson]
///   as the validation pipeline — a bad shape throws and nothing is cached.
/// * Mutations: the API, then `invalidate()` so the next read is fresh.
/// * Every throw is a `Failure` (via `NetworkExceptions.toFailure`).
class DocumentsRepositoryImpl implements DocumentsRepository {
  const DocumentsRepositoryImpl({
    required DocumentsApi api,
    required CachedFetcher fetcher,
  }) : _api = api,
       _fetcher = fetcher;

  final DocumentsApi _api;
  final CachedFetcher _fetcher;

  @override
  Stream<Snapshot<Paged<MedicalDocument>>> watchDocuments(
    DocumentQuery query, {
    bool forceRefresh = false,
  }) async* {
    try {
      await for (final result in _fetcher.fetch<Page<MedicalDocument>>(
        _listRequest(query),
        _decodePage,
        forceRefresh: forceRefresh,
      )) {
        yield _snapshot(result);
      }
    } catch (error, stackTrace) {
      throw NetworkExceptions.toFailure(error, stackTrace);
    }
  }

  @override
  Future<Paged<MedicalDocument>> fetchDocuments(DocumentQuery query) =>
      _run(() async {
        final page = await _fetcher.get<Page<MedicalDocument>>(
          _listRequest(query),
          _decodePage,
        );
        return _paged(page);
      });

  @override
  Future<MedicalDocument> document(String id, {bool forceRefresh = false}) =>
      _run(
        () => _fetcher.get<MedicalDocument>(
          _api.detailRequest(id),
          (json) => DocumentMappers.fromJson(_asMap(json)),
          forceRefresh: forceRefresh,
        ),
      );

  @override
  Future<MedicalDocument> create(DocumentDraft draft) => _mutate(() async {
    final json = await _api.create(DocumentMappers.draftToJson(draft));
    return DocumentMappers.fromJson(json);
  });

  @override
  Future<MedicalDocument> update(
    String id,
    DocumentPatch patch, {
    int? version,
  }) => _mutate(() async {
    final json = await _api.patch(
      id,
      DocumentMappers.patchToJson(patch),
      version: version,
    );
    return DocumentMappers.fromJson(json);
  });

  @override
  Future<void> delete(String id, {int? version}) =>
      _mutate(() => _api.delete(id, version: version));

  @override
  Future<SignedFileUrl> downloadUrl(String id) =>
      _run(() async => FileMappers.signedUrl(await _api.downloadUrl(id)));

  // ---- helpers ----

  ApiRequest _listRequest(DocumentQuery query) => _api.listRequest(
    docType: query.docType?.wire,
    personId: query.personId,
    dateFrom: query.dateFrom == null
        ? null
        : DocumentMappers.day(query.dateFrom!),
    dateTo: query.dateTo == null ? null : DocumentMappers.day(query.dateTo!),
    appointmentId: query.appointmentId,
    q: (query.search?.trim().isEmpty ?? true) ? null : query.search!.trim(),
    sort: query.sort.wire,
    page: query.page,
    pageSize: query.pageSize,
  );

  static Page<MedicalDocument> _decodePage(Object? json) =>
      Page.parse(json, DocumentMappers.fromJson);

  static Map<String, Object?> _asMap(Object? json) {
    if (json is Map) return json.cast<String, Object?>();
    throw ResponseFormatException(
      message: 'expected a document object, got ${json.runtimeType}',
    );
  }

  static Paged<MedicalDocument> _paged(Page<MedicalDocument> page) =>
      Paged<MedicalDocument>(
        items: page.results,
        page: page.page,
        pageSize: page.pageSize,
        total: page.total,
        hasNext: page.hasNext,
      );

  static Snapshot<Paged<MedicalDocument>> _snapshot(
    CachedResult<Page<MedicalDocument>> result,
  ) => Snapshot<Paged<MedicalDocument>>(
    value: _paged(result.value),
    cachedAt: result.cachedAt,
    fromCache: result.source != CacheSource.network,
    isStale: result.isStale,
    revalidating: result.revalidating,
  );

  Future<T> _run<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (error, stackTrace) {
      throw NetworkExceptions.toFailure(error, stackTrace);
    }
  }

  /// A mutation: run, then forget cached reads so the list and detail
  /// re-fetch (the fetcher's ETags make that a cheap 304 where unchanged).
  Future<T> _mutate<T>(Future<T> Function() request) async {
    final T result;
    try {
      result = await _run(request);
    } on Failure catch (failure) {
      // A stale `If-Match`: what is saved here is older than the server's
      // copy, so it must not be served again (BL-REC-018).
      if (failure.apiCode == ApiErrorCodes.conflictVersion) {
        await _fetcher.invalidate(pathPrefix: '/patient/documents');
      }
      rethrow;
    }
    await _fetcher.invalidate(pathPrefix: '/patient/documents');
    return result;
  }
}
