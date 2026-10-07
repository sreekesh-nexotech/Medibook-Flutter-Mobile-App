import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/connectivity/connectivity_monitor.dart';
import 'package:medibook/features/auth/application/providers/auth_provider.dart';
import 'package:medibook/features/common/attachments/domain/entities/stored_file.dart';
import 'package:medibook/features/common/pagination/domain/entities/paged.dart';
import 'package:medibook/features/records/application/providers/records_provider.dart';
import 'package:medibook/features/records/domain/entities/medical_document.dart';
import 'package:medibook/features/records/domain/repositories/documents_repository.dart';

/// The Records list, form and actions controllers against a fake
/// [DocumentsRepository]: skeleton → data, stale / cached flags, load more,
/// error with data kept, the form's validation and the bodies it sends.
void main() {
  late FakeDocumentsRepository repository;
  late _Monitor monitor;
  late ProviderContainer container;

  setUp(() {
    repository = FakeDocumentsRepository();
    monitor = _Monitor();
    container = ProviderContainer(
      overrides: [
        documentsRepositoryProvider.overrideWithValue(repository),
        selfPersonIdProvider.overrideWithValue(null),
        connectivityMonitorProvider.overrideWithValue(monitor),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('DocumentsListController', () {
    test('starts loading, then holds the page and its freshness', () async {
      repository.snapshots = [
        Snapshot(
          value: Paged(
            items: [_doc('a')],
            page: 1,
            pageSize: 20,
            total: 1,
            hasNext: false,
          ),
          cachedAt: DateTime(2026),
          fromCache: true,
          isStale: true,
          revalidating: true,
        ),
        Snapshot(
          value: Paged(
            items: [_doc('a'), _doc('b')],
            page: 1,
            pageSize: 20,
            total: 2,
            hasNext: true,
          ),
          cachedAt: DateTime.now(),
        ),
      ];
      final sub = container.listen(documentsListProvider, (_, _) {});
      addTearDown(sub.close);
      expect(container.read(documentsListProvider).isLoading, isTrue);
      await settle();
      await settle();
      final state = container.read(documentsListProvider);
      expect(state.isLoading, isFalse);
      expect(state.items.map((d) => d.id), ['a', 'b']);
      expect(state.total, 2);
      expect(state.hasNext, isTrue);
      expect(state.fromCache, isFalse);
      expect(state.isStale, isFalse);
      expect(state.revalidating, isFalse);
    });

    test('an empty page is the empty state, not an error', () async {
      repository.snapshots = [
        Snapshot(value: const Paged.empty(), cachedAt: DateTime.now()),
      ];
      final sub = container.listen(documentsListProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      final state = container.read(documentsListProvider);
      expect(state.isEmpty, isTrue);
      expect(state.failure, isNull);
    });

    test('a failed load with nothing cached is the error state', () async {
      repository.watchError = const NetworkFailure();
      final sub = container.listen(documentsListProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      final state = container.read(documentsListProvider);
      expect(state.isLoading, isFalse);
      expect(state.failure, isA<NetworkFailure>());
      expect(state.hasData, isFalse);
    });

    // Opened offline, the list shows the saved page and waits for the
    // network. A pull-to-refresh used to wait for that wait to end, so its
    // spinner turned until the connection was back.
    test('a pull-to-refresh offline does not wait for the network', () async {
      final network = Completer<void>();
      addTearDown(network.complete);
      repository
        ..snapshots = [_savedPage()]
        ..waitAfterSnapshots = network
        ..refreshError = const NetworkFailure();
      final sub = container.listen(documentsListProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();

      await container
          .read(documentsListProvider.notifier)
          .refresh()
          .timeout(const Duration(seconds: 1));
      final state = container.read(documentsListProvider);
      expect(state.items.map((d) => d.id), ['a'], reason: 'the saved page');
      expect(state.failure, isA<NetworkFailure>());
      expect(state.isRefreshing, isFalse);
    });

    test('a failed read loads again when the network returns', () async {
      repository.watchError = const NetworkFailure();
      final sub = container.listen(documentsListProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      expect(container.read(documentsListProvider).failure, isNotNull);

      repository
        ..watchError = null
        ..snapshots = [_savedPage()];
      monitor.reconnect();
      await settle();
      await settle();
      final state = container.read(documentsListProvider);
      expect(state.failure, isNull);
      expect(state.items.map((d) => d.id), ['a']);
    });

    test('load more appends the next page', () async {
      repository.snapshots = [
        Snapshot(
          value: Paged(
            items: [_doc('a')],
            page: 1,
            pageSize: 1,
            total: 2,
            hasNext: true,
          ),
          cachedAt: DateTime.now(),
        ),
      ];
      repository.nextPage = Paged(
        items: [_doc('b')],
        page: 2,
        pageSize: 1,
        total: 2,
        hasNext: false,
      );
      final sub = container.listen(documentsListProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      await container.read(documentsListProvider.notifier).loadMore();
      final state = container.read(documentsListProvider);
      expect(state.items.map((d) => d.id), ['a', 'b']);
      expect(state.hasNext, isFalse);
      expect(repository.fetchedQueries.single.page, 2);
    });

    test('the query follows the filters and sort', () async {
      repository.snapshots = [
        Snapshot(value: const Paged.empty(), cachedAt: DateTime.now()),
      ];
      final sub = container.listen(documentsListProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      container
          .read(documentsFilterProvider.notifier)
          .toggleType(DocumentType.scan);
      container.read(documentsSortProvider.notifier).state =
          DocumentSort.oldestFirst;
      await settle();
      final query = repository.watchedQueries.last;
      expect(query.docType, DocumentType.scan);
      expect(query.sort, DocumentSort.oldestFirst);
      // Tapping the active type again clears it (single-value doc_type).
      container
          .read(documentsFilterProvider.notifier)
          .toggleType(DocumentType.scan);
      expect(container.read(documentsFilterProvider).type, isNull);
    });
  });

  // BL-REC-016 (owner decision): Records can be searched by title.
  group('DocumentsSearchController', () {
    Future<void> pause() =>
        Future<void>.delayed(const Duration(milliseconds: 30));

    DocumentsSearchController build() {
      final controller = DocumentsSearchController(
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);
      return controller;
    }

    test('the term settles once typing pauses, trimmed', () async {
      final search = build()
        ..onInput(' bl')
        ..onInput(' blood ');
      expect(search.state.input, ' blood ');
      expect(search.state.query, isNull, reason: 'still typing');
      await pause();
      expect(search.state.query, 'blood');
    });

    test('emptying the box drops the term at once', () async {
      final search = build()..onInput('blood');
      await pause();
      search.onInput('');
      expect(search.state.query, isNull);
      expect(search.state.hasInput, isFalse);
    });

    test('spaces alone search for nothing', () async {
      final search = build()..onInput('   ');
      await pause();
      expect(search.state.query, isNull);
    });

    test('clear cancels a term that has not settled yet', () async {
      final search = build()
        ..onInput('blood')
        ..clear();
      await pause();
      expect(search.state.query, isNull);
      expect(search.state.input, isEmpty);
    });

    test('a very long term is cut to what the server takes', () async {
      final search = build()..onInput('a' * 140);
      await pause();
      expect(search.state.query, hasLength(100));
    });

    test('the list query carries the settled title', () async {
      repository.snapshots = [
        Snapshot(value: const Paged.empty(), cachedAt: DateTime.now()),
      ];
      final sub = container.listen(documentsListProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      expect(repository.watchedQueries.last.search, isNull);

      container.read(documentsSearchProvider.notifier).onInput('blood');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(repository.watchedQueries.last.search, 'blood');

      container.read(documentsSearchProvider.notifier).clear();
      await settle();
      expect(repository.watchedQueries.last.search, isNull);
    });
  });

  group('DocumentFormController', () {
    test('a create needs a title, a person and a clean file', () async {
      final form = container.read(documentFormProvider(null).notifier);
      final saved = await form.save();
      expect(saved, isNull);
      final state = container.read(documentFormProvider(null));
      expect(state.submitAttempted, isTrue);
      expect(state.titleError, isNotNull);
      expect(state.personError, isNotNull);
      expect(state.fileError(hasFile: false, needsFile: true), isNotNull);
      expect(repository.created, isEmpty);
    });

    test('a valid create posts the documented body', () async {
      final form = container.read(documentFormProvider(null).notifier);
      form
        ..setTitle('CBC report')
        ..setPerson('p1')
        ..setType(DocumentType.labReport)
        ..setDocumentDate(DateTime(2026, 9, 21))
        ..setNotes('fasting')
        ..setAppointment('appt-1', label: 'Dr X');
      final saved = await form.save(fileId: 'file-1');
      expect(saved, isNotNull);
      final draft = repository.created.single;
      expect(draft.fileId, 'file-1');
      expect(draft.personId, 'p1');
      expect(draft.title, 'CBC report');
      expect(draft.notes, 'fasting');
      expect(draft.appointmentId, 'appt-1');
      expect(container.read(documentFormProvider(null)).isDirty, isFalse);
    });

    // BL-REC-006: notes are optional, up to 2000 characters.
    test('blank notes are not saved', () async {
      final form = container.read(documentFormProvider(null).notifier);
      form
        ..setTitle('CBC report')
        ..setPerson('p1')
        ..setNotes('   \n  ');
      final saved = await form.save(fileId: 'file-1');
      expect(saved, isNotNull);
      expect(repository.created.single.notes, isNull);
    });

    test('notes of 2000 characters are accepted, 2001 are refused', () async {
      final form = container.read(documentFormProvider(null).notifier);
      form
        ..setTitle('CBC report')
        ..setPerson('p1')
        ..setNotes('n' * 2001);
      expect(
        container.read(documentFormProvider(null)).notesError,
        'Keep notes under 2000 characters',
      );
      expect(await form.save(fileId: 'file-1'), isNull);
      expect(repository.created, isEmpty);

      form.setNotes('n' * 2000);
      expect(container.read(documentFormProvider(null)).notesError, isNull);
      expect(await form.save(fileId: 'file-1'), isNotNull);
      expect(repository.created.single.notes, hasLength(2000));
    });

    test('a server validation error lands on the field', () async {
      repository.createError = const ValidationFailure(
        fieldErrors: {
          'file_id': 'Must be your own upload that passed the scan.',
        },
      );
      final form = container.read(documentFormProvider(null).notifier);
      form
        ..setTitle('CBC report')
        ..setPerson('p1');
      final saved = await form.save(fileId: 'file-1');
      expect(saved, isNull);
      final state = container.read(documentFormProvider(null));
      expect(state.failure, isA<ValidationFailure>());
      expect(
        state.fileError(hasFile: true, needsFile: true),
        contains('passed the scan'),
      );
      expect(state.isSaving, isFalse);
    });

    // BL-REC-007: a server error on the date or the file used to stay until
    // the title, person or appointment was edited, so Save stayed blocked.
    test(
      'a server error on the date clears when the date is changed',
      () async {
        repository.createError = const ValidationFailure(
          fieldErrors: {
            'document_date': 'A document cannot be dated in the future.',
          },
        );
        final form = container.read(documentFormProvider(null).notifier);
        form
          ..setTitle('CBC report')
          ..setPerson('p1')
          ..setDocumentDate(DateTime(2026, 9, 21));
        expect(await form.save(fileId: 'file-1'), isNull);
        expect(
          container.read(documentFormProvider(null)).dateError(),
          contains('future'),
        );

        // The patient picks another date; the server now accepts it.
        repository.createError = null;
        form.setDocumentDate(DateTime(2026, 9, 20));
        expect(container.read(documentFormProvider(null)).dateError(), isNull);
        expect(await form.save(fileId: 'file-1'), isNotNull);
      },
    );

    test(
      'a server error on the file clears when the file is replaced',
      () async {
        repository.createError = const ValidationFailure(
          fieldErrors: {
            'file_id': 'Must be your own upload that passed the scan.',
            'title': 'Already used.',
          },
        );
        final form = container.read(documentFormProvider(null).notifier);
        form
          ..setTitle('CBC report')
          ..setPerson('p1');
        expect(await form.save(fileId: 'file-1'), isNull);

        form.fileChanged();

        final state = container.read(documentFormProvider(null));
        expect(state.fileError(hasFile: true, needsFile: true), isNull);
        expect(state.titleError, 'Already used.', reason: 'other errors stay');
      },
    );

    test('applyDefaultPerson only fills an empty person', () {
      final form = container.read(documentFormProvider(null).notifier);
      form.applyDefaultPerson('p1');
      expect(container.read(documentFormProvider(null)).personId, 'p1');
      form.applyDefaultPerson('p2');
      expect(container.read(documentFormProvider(null)).personId, 'p1');
    });
  });

  group('DocumentActionsController', () {
    test('delete sends the version and reports null on success', () async {
      final actions = container.read(documentActionsProvider('a').notifier);
      final failure = await actions.delete(_doc('a', version: 4));
      expect(failure, isNull);
      expect(repository.deleted.single, ('a', 4));
    });

    test(
      'downloadUrl hands the signed URL back and keeps failures on state',
      () async {
        final actions = container.read(documentActionsProvider('a').notifier);
        final url = await actions.downloadUrl('a');
        expect(url?.url, 'https://signed.example/a');

        repository.urlError = const NotFoundFailure();
        final missing = await actions.downloadUrl('a');
        expect(missing, isNull);
        expect(
          container.read(documentActionsProvider('a')).failure,
          isA<NotFoundFailure>(),
        );
      },
    );
  });
}

MedicalDocument _doc(String id, {int version = 1}) => MedicalDocument(
  id: id,
  personId: 'p1',
  docType: DocumentType.labReport,
  title: 'Doc $id',
  documentDate: DateTime(2026, 9, 21),
  file: const DocumentFile(
    id: 'f',
    originalName: 'a.pdf',
    mime: 'application/pdf',
    sizeBytes: 10,
    status: FileStatus.clean,
  ),
  version: version,
);

/// One saved document, as the cache serves it.
Snapshot<Paged<MedicalDocument>> _savedPage() => Snapshot(
  value: Paged(
    items: [_doc('a')],
    page: 1,
    pageSize: 20,
    total: 1,
    hasNext: false,
  ),
  cachedAt: DateTime(2026),
  fromCache: true,
);

/// A connectivity monitor whose reconnects the test sends.
class _Monitor extends ConnectivityMonitor {
  final StreamController<void> _reconnects = StreamController<void>.broadcast();

  void reconnect() => _reconnects.add(null);

  @override
  Stream<void> get onReconnect => _reconnects.stream;
}

class FakeDocumentsRepository implements DocumentsRepository {
  List<Snapshot<Paged<MedicalDocument>>> snapshots = [];
  Failure? watchError;
  Paged<MedicalDocument>? nextPage;
  Failure? createError;
  Failure? urlError;
  final List<DocumentQuery> watchedQueries = [];
  final List<DocumentQuery> fetchedQueries = [];
  final List<DocumentDraft> created = [];
  final List<(String, int?)> deleted = [];

  @override
  Stream<Snapshot<Paged<MedicalDocument>>> watchDocuments(
    DocumentQuery query, {
    bool forceRefresh = false,
  }) async* {
    watchedQueries.add(query);
    if (watchError != null) throw watchError!;
    if (forceRefresh && refreshError != null) throw refreshError!;
    for (final snapshot in snapshots) {
      yield snapshot;
    }
    // The saved page was shown, then the network read failed…
    if (errorAfterSnapshots != null) throw errorAfterSnapshots!;
    // …or it waits for the network to come back.
    final network = waitAfterSnapshots;
    if (network != null) await network.future;
  }

  /// Thrown after [snapshots] — a cached page followed by a failed refresh.
  Failure? errorAfterSnapshots;

  /// Holds the read open after [snapshots] until completed — the cache
  /// offline, waiting for the network (HIVE Scenario 3).
  Completer<void>? waitAfterSnapshots;

  /// Thrown at once by a forced read (pull-to-refresh) — offline.
  Failure? refreshError;

  @override
  Future<Paged<MedicalDocument>> fetchDocuments(DocumentQuery query) async {
    fetchedQueries.add(query);
    return nextPage ?? const Paged.empty();
  }

  @override
  Future<MedicalDocument> document(
    String id, {
    bool forceRefresh = false,
  }) async => _doc(id);

  @override
  Future<MedicalDocument> create(DocumentDraft draft) async {
    if (createError != null) throw createError!;
    created.add(draft);
    return _doc('new');
  }

  @override
  Future<MedicalDocument> update(
    String id,
    DocumentPatch patch, {
    int? version,
  }) async => _doc(id, version: (version ?? 1) + 1);

  @override
  Future<void> delete(String id, {int? version}) async =>
      deleted.add((id, version));

  @override
  Future<SignedFileUrl> downloadUrl(String id) async {
    if (urlError != null) throw urlError!;
    return SignedFileUrl(
      url: 'https://signed.example/$id',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
  }
}
