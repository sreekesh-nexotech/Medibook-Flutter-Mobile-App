import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/connectivity/connectivity_monitor.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/api_client.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/core/storage/local_store.dart';
import 'package:medibook/features/records/domain/entities/medical_document.dart';
import 'package:medibook/features/records/infrastructure/data_sources/remote/documents_api.dart';
import 'package:medibook/features/records/infrastructure/repositories/documents_repository_impl.dart';

/// The real repository + the real three-layer fetcher over a scripted
/// [ApiClient]: the wire is exactly §11.2 (only listed query parameters,
/// `If-Match` on PATCH), reads come back cached-then-network, mutations
/// invalidate, and the download URL is never cached.
void main() {
  late _ScriptedApiClient client;
  late CachedFetcher fetcher;
  late DocumentsRepositoryImpl repository;

  setUp(() {
    client = _ScriptedApiClient();
    fetcher = CachedFetcher(
      client: client,
      connectivity: ConnectivityMonitor(),
      store: InMemoryLocalStore(),
    );
    addTearDown(fetcher.dispose);
    repository = DocumentsRepositoryImpl(
      api: HttpDocumentsApi(client),
      fetcher: fetcher,
    );
  });

  test(
    'sends only the documented query parameters, dates as YYYY-MM-DD',
    () async {
      client.onGet = (request) => _page([]);
      await repository.fetchDocuments(
        DocumentQuery(
          docType: DocumentType.scan,
          personId: 'p1',
          dateFrom: DateTime(2026, 1, 1),
          dateTo: DateTime(2026, 12, 31),
          appointmentId: 'a1',
          search: ' cbc ',
          sort: DocumentSort.oldestFirst,
          page: 2,
          pageSize: 20,
        ),
      );
      final sent = client.requests.single;
      expect(sent.path, '/patient/documents');
      expect(sent.normalisedQuery, {
        'doc_type': 'scan',
        'person_id': 'p1',
        'date_from': '2026-01-01',
        'date_to': '2026-12-31',
        'appointment_id': 'a1',
        'q': 'cbc',
        'sort': 'document_date',
        'page': '2',
        'page_size': '20',
      });
    },
  );

  test(
    'drops unused filters entirely (an unknown or empty one is a 400)',
    () async {
      client.onGet = (request) => _page([]);
      await repository.fetchDocuments(const DocumentQuery());
      expect(client.requests.single.normalisedQuery, {
        'sort': '-document_date',
        'page': '1',
        'page_size': '20',
      });
    },
  );

  test('a second read is served from memory without a network call', () async {
    client.onGet = (request) => _page([_doc('d1')]);
    final first = await repository
        .watchDocuments(const DocumentQuery())
        .toList();
    expect(first.last.fromCache, isFalse);
    expect(first.last.value.items.single.id, 'd1');

    final second = await repository
        .watchDocuments(const DocumentQuery())
        .toList();
    expect(second.first.fromCache, isTrue);
    expect(client.requests, hasLength(1));
  });

  test(
    'a mutation invalidates the cache so the next read hits the network',
    () async {
      client.onGet = (request) => _page([_doc('d1')]);
      await repository.fetchDocuments(const DocumentQuery());
      client.onMutation = (request) => ApiResponse(statusCode: 204);
      await repository.delete('d1', version: 3);
      final delete = client.requests.last;
      expect(delete.method, HttpMethod.delete);
      expect(delete.path, '/patient/documents/d1');
      expect(delete.ifMatch, 3);

      await repository.fetchDocuments(const DocumentQuery());
      expect(
        client.requests.where((r) => r.method == HttpMethod.get),
        hasLength(2),
      );
    },
  );

  // BL-REC-018: after "changed elsewhere" the old copy kept being shown.
  test('a version conflict clears the saved copy', () async {
    client.onGet = (request) => _page([_doc('d1')]);
    await repository.fetchDocuments(const DocumentQuery());
    client.onMutation = (request) => throw HttpStatusException.fromBody(409, {
      'code': 'CONFLICT_VERSION',
      'message': 'Changed elsewhere.',
      'request_id': 'x',
      'meta': {},
    });
    await expectLater(
      repository.update('d1', const DocumentPatch(title: 'New'), version: 1),
      throwsA(isA<ConflictFailure>()),
    );

    await repository.fetchDocuments(const DocumentQuery());
    expect(
      client.requests.where((r) => r.method == HttpMethod.get),
      hasLength(2),
      reason: 'the next read goes to the server',
    );
  });

  test('update sends a PATCH with If-Match and maps the response', () async {
    client.onMutation = (request) => ApiResponse(
      statusCode: 200,
      data: _docJson('d1', title: 'Renamed', version: 2),
    );
    final updated = await repository.update(
      'd1',
      const DocumentPatch(title: 'Renamed'),
      version: 1,
    );
    expect(updated.title, 'Renamed');
    expect(updated.version, 2);
    final sent = client.requests.single;
    expect(sent.method, HttpMethod.patch);
    expect(sent.ifMatch, 1);
    expect(sent.body, {'title': 'Renamed'});
  });

  test(
    'a rejected file_id is a ValidationFailure with the field error',
    () async {
      client.onMutation = (request) => throw HttpStatusException.fromBody(400, {
        'code': 'VALIDATION_ERROR',
        'message': 'Some fields are invalid.',
        'errors': {
          'file_id': [
            'Must be your own medical_document upload that passed the scan.',
          ],
        },
        'request_id': 'x',
        'meta': {},
      });
      await expectLater(
        repository.create(
          DocumentDraft(
            fileId: 'pending',
            personId: 'p1',
            docType: DocumentType.labReport,
            title: 'CBC',
            documentDate: DateTime(2026, 9, 21),
          ),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.fieldErrors['file_id'],
            'file_id',
            contains('passed the scan'),
          ),
        ),
      );
    },
  );

  test('the download URL is fetched every time and never cached', () async {
    client.onGet = (request) => ApiResponse(
      statusCode: 200,
      data: {
        'url': 'https://signed.example/a',
        'expires_at': '2026-09-30T10:10:00+00:00',
      },
    );
    await repository.downloadUrl('d1');
    await repository.downloadUrl('d1');
    expect(client.requests, hasLength(2));
    expect(client.requests.first.path, '/patient/documents/d1/download-url');
  });

  test('a 404 detail is a NotFoundFailure', () async {
    client.onGet = (request) => throw HttpStatusException.fromBody(404, {
      'code': 'NOT_FOUND',
      'message': 'Not found.',
      'errors': {},
    });
    await expectLater(
      repository.document('nope'),
      throwsA(isA<NotFoundFailure>()),
    );
  });
}

ApiResponse _page(List<Map<String, Object?>> rows) => ApiResponse(
  statusCode: 200,
  data: {
    'results': rows,
    'page': 1,
    'page_size': 20,
    'total': rows.length,
    'has_next': false,
  },
  headers: const {'etag': 'W/"1"'},
);

Map<String, Object?> _doc(String id) => _docJson(id);

Map<String, Object?> _docJson(
  String id, {
  String title = 'CBC',
  int version = 1,
}) => {
  'id': id,
  'person_id': 'p1',
  'appointment_id': null,
  'doc_type': 'lab_report',
  'title': title,
  'document_date': '2026-09-21',
  'notes': null,
  'file': {
    'id': 'f-$id',
    'original_name': 'a.pdf',
    'mime': 'application/pdf',
    'size_bytes': 10,
    'status': 'clean',
  },
  'version': version,
  'created_at': '2026-09-30T08:09:04+00:00',
  'updated_at': '2026-09-30T08:09:04+00:00',
};

/// Records every request; GETs and mutations are answered by callbacks.
class _ScriptedApiClient with ApiClientVerbs implements ApiClient {
  final List<ApiRequest> requests = [];
  ApiResponse Function(ApiRequest request)? onGet;
  ApiResponse Function(ApiRequest request)? onMutation;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (request.method == HttpMethod.get) return onGet!(request);
    return onMutation!(request);
  }
}
