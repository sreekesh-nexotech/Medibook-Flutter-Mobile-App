import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/constants.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/connectivity/connectivity_monitor.dart';
import '../../../../core/utils/logger.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../common/attachments/domain/entities/stored_file.dart';
import '../../domain/entities/medical_document.dart';
import '../../domain/repositories/documents_repository.dart';
import '../states/document_form_state.dart';
import '../states/documents_list_state.dart';

// ---------------------------------------------------------------------------
// Data layer wiring
// ---------------------------------------------------------------------------

/// The documents repository. Returns the abstract type so a test can
/// `overrideWithValue(FakeDocumentsRepository())`.
final documentsRepositoryProvider = Provider<DocumentsRepository>(
  (ref) => throw UnimplementedError(
    'documentsRepositoryProvider is wired in app/di',
  ),
);

// ---------------------------------------------------------------------------
// Filters and sort — transient UI state, `autoDispose`
// ---------------------------------------------------------------------------

/// Owns [DocumentFilters] for the Records list. Every mutation produces a
/// new immutable value.
class DocumentsFilterController extends StateNotifier<DocumentFilters> {
  DocumentsFilterController() : super(const DocumentFilters());

  /// Tapping the active type clears it; tapping another replaces it (the
  /// backend filters on one `doc_type`).
  void toggleType(DocumentType type) => state = state.type == type
      ? state.copyWith(clearType: true)
      : state.copyWith(type: type);

  void clearType() => state = state.copyWith(clearType: true);

  void setPerson(String? personId) => state = personId == null
      ? state.copyWith(clearPerson: true)
      : state.copyWith(personId: personId);

  void setDateRange({DateTime? from, DateTime? to}) {
    if (from == null && to == null) {
      state = state.copyWith(clearDateRange: true);
      return;
    }
    state = state.copyWith(clearDateRange: true).copyWith(from: from, to: to);
  }

  void clearDateRange() => state = state.copyWith(clearDateRange: true);

  void setAppointment(String? appointmentId) => state = appointmentId == null
      ? state.copyWith(clearAppointment: true)
      : state.copyWith(appointmentId: appointmentId);

  void clearAll() => state = const DocumentFilters();
}

final documentsFilterProvider =
    StateNotifierProvider.autoDispose<
      DocumentsFilterController,
      DocumentFilters
    >((ref) => DocumentsFilterController());

/// Debounces the Records title search by [AppConstants.searchDebounce], so
/// the list is fetched once the patient pauses rather than on every key.
///
/// Clearing the box is *not* debounced: a patient who empties it wants the
/// whole list back immediately.
class DocumentsSearchController extends StateNotifier<DocumentsSearchState> {
  DocumentsSearchController({Duration? debounce})
    : _debounce = debounce ?? AppConstants.searchDebounce,
      super(const DocumentsSearchState());

  final Duration _debounce;
  Timer? _timer;

  void onInput(String value) {
    _timer?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      // Keep what is in the box (it may be spaces) but search for nothing.
      state = DocumentsSearchState(input: value);
      return;
    }
    // The last settled term stays while typing so the list does not flicker.
    state = state.copyWith(input: value);
    final term = trimmed.length > DocumentsSearchState.maxLength
        ? trimmed.substring(0, DocumentsSearchState.maxLength)
        : trimmed;
    _timer = Timer(_debounce, () {
      if (!mounted) return;
      state = state.copyWith(query: () => term);
    });
  }

  void clear() {
    _timer?.cancel();
    state = const DocumentsSearchState();
  }

  @override
  void dispose() {
    // A pending timer that fires after disposal would touch a dead notifier.
    _timer?.cancel();
    super.dispose();
  }
}

/// The Records title search. autoDispose — a search term is transient UI
/// state and must not survive leaving the tab.
final documentsSearchProvider =
    StateNotifierProvider.autoDispose<
      DocumentsSearchController,
      DocumentsSearchState
    >((ref) => DocumentsSearchController());

/// The active sort — the design's two pills.
final documentsSortProvider = StateProvider.autoDispose<DocumentSort>(
  (ref) => DocumentSort.newestFirst,
);

/// The query the list runs, composed from the filters, search and sort so the
/// screen never assembles one in `build()`.
final documentsQueryProvider = Provider.autoDispose<DocumentQuery>((ref) {
  final filters = ref.watch(documentsFilterProvider);
  final sort = ref.watch(documentsSortProvider);
  final search = ref.watch(documentsSearchProvider.select((s) => s.query));
  return filters.toQuery(
    sort: sort,
    search: search,
    pageSize: AppConstants.defaultPageSize,
  );
});

// ---------------------------------------------------------------------------
// The list
// ---------------------------------------------------------------------------

/// Loads the Records list for one [DocumentQuery]: cached page first, then
/// the network page, then more pages on demand.
///
/// Holds no `BuildContext` and shows nothing; it maps every failure to a
/// `Failure` on the state and the screen renders it.
class DocumentsListController extends StateNotifier<DocumentsListState> {
  DocumentsListController({
    required DocumentsRepository repository,
    required DocumentQuery query,
  }) : _repository = repository,
       super(DocumentsListState(query: query)) {
    _load();
  }

  final DocumentsRepository _repository;
  StreamSubscription<Object?>? _subscription;

  Future<void> _load({bool forceRefresh = false}) async {
    // Not awaited: offline, the list being replaced is parked until the
    // network returns and would finish cancelling only then — the
    // pull-to-refresh spinner turned until the connection was back. A
    // cancelled subscription delivers nothing more.
    unawaited(_subscription?.cancel());
    final completer = Completer<void>();
    _subscription = _repository
        .watchDocuments(
          state.query.copyWith(page: 1),
          forceRefresh: forceRefresh,
        )
        .listen(
          (snapshot) {
            if (!mounted) return;
            final page = snapshot.value;
            state = state.copyWith(
              items: page.items,
              total: page.total,
              hasNext: page.hasNext,
              isLoading: false,
              isRefreshing: false,
              clearFailure: true,
              fromCache: snapshot.fromCache,
              isStale: snapshot.isStale,
              revalidating: snapshot.revalidating,
              cachedAt: snapshot.cachedAt,
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted) return;
            final failure = error.asFailure(stackTrace);
            AppLogger.warning(
              'Documents load failed',
              name: 'records',
              error: failure,
            );
            state = state.copyWith(
              isLoading: false,
              isRefreshing: false,
              revalidating: false,
              failure: failure,
            );
            if (!completer.isCompleted) completer.complete();
          },
          onDone: () {
            if (mounted && state.revalidating) {
              state = state.copyWith(revalidating: false);
            }
            if (!completer.isCompleted) completer.complete();
          },
        );
    return completer.future;
  }

  /// Pull-to-refresh / "tap to refresh": network first, ETag still sent.
  Future<void> refresh() {
    if (state.isRefreshing) return Future.value();
    state = state.copyWith(isRefreshing: true, clearFailure: true);
    return _load(forceRefresh: true);
  }

  /// The error state's retry.
  Future<void> retry() {
    state = state.copyWith(isLoading: !state.hasData, clearFailure: true);
    return _load(forceRefresh: true);
  }

  /// Load again after a failed read, once the network is back. A
  /// pull-to-refresh that failed offline replaced the read that was waiting
  /// for the network, so its "You appear to be offline" stayed up after the
  /// connection returned.
  void reloadIfFailed() {
    if (mounted && state.failure != null) unawaited(retry());
  }

  /// Next page, appended. No-op while busy or on the last page.
  Future<void> loadMore() async {
    if (!state.hasNext || state.isLoadingMore || state.isLoading) return;
    final nextPage = (state.items.length / state.query.pageSize).ceil() + 1;
    state = state.copyWith(isLoadingMore: true, clearFailure: true);
    try {
      final page = await _repository.fetchDocuments(
        state.query.copyWith(page: nextPage),
      );
      if (!mounted) return;
      final known = {for (final item in state.items) item.id};
      state = state.copyWith(
        items: [
          ...state.items,
          for (final item in page.items)
            if (!known.contains(item.id)) item,
        ],
        total: page.total,
        hasNext: page.hasNext,
        isLoadingMore: false,
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingMore: false,
        failure: error.asFailure(stackTrace),
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// The Records list. Re-created whenever the query changes (a new query is
/// a new list) and dropped when the screen goes — `autoDispose`.
///
/// After a mutation the screens call `ref.invalidate(documentsListProvider)`
/// so the list reloads through the (already invalidated) cache.
final documentsListProvider =
    StateNotifierProvider.autoDispose<
      DocumentsListController,
      DocumentsListState
    >((ref) {
      final controller = DocumentsListController(
        repository: ref.watch(documentsRepositoryProvider),
        query: ref.watch(documentsQueryProvider),
      );
      // A failed read loads once more when the connection returns, as the
      // appointment lists do (HIVE Scenario 3, BL-CACHE-017).
      final reconnects = ref
          .watch(connectivityMonitorProvider)
          .onReconnect
          .listen((_) => controller.reloadIfFailed());
      ref.onDispose(reconnects.cancel);
      return controller;
    });

// ---------------------------------------------------------------------------
// One document
// ---------------------------------------------------------------------------

/// `GET /patient/documents/{id}`, cached-first. Throws the mapped `Failure`
/// into `AsyncValue.error`; a `NotFoundFailure` is the not-found screen.
final documentProvider = FutureProvider.autoDispose
    .family<MedicalDocument, String>((ref, id) async {
      try {
        return await ref.watch(documentsRepositoryProvider).document(id);
      } catch (error, stackTrace) {
        throw error.asFailure(stackTrace);
      }
    });

// ---------------------------------------------------------------------------
// The form (create / edit)
// ---------------------------------------------------------------------------

/// Drives the upload form (`/documents/upload`) and the edit sheet.
///
/// The file is not part of this state: it lives in the shared attachment
/// slot (`attachmentUploadProvider(FileUploadPurpose.medicalDocument)`) and
/// its clean `file_id` is handed to [save].
class DocumentFormController extends StateNotifier<DocumentFormState> {
  DocumentFormController({
    required DocumentsRepository repository,
    MedicalDocument? existing,
    String? defaultPersonId,
  }) : _repository = repository,
       _existing = existing,
       super(
         DocumentFormState(
           title: existing?.title ?? '',
           docType: existing?.docType ?? DocumentType.labReport,
           personId: existing?.personId ?? defaultPersonId ?? '',
           documentDate: existing?.documentDate ?? DateTime.now(),
           notes: existing?.notes ?? '',
           appointmentId: existing?.appointmentId,
         ),
       );

  final DocumentsRepository _repository;
  final MedicalDocument? _existing;

  bool get isEditing => _existing != null;

  void setTitle(String value) =>
      state = state.copyWith(title: value, isDirty: true, serverErrors: {});

  void setType(DocumentType type) =>
      state = state.copyWith(docType: type, isDirty: true);

  void setPerson(String personId) => state = state.copyWith(
    personId: personId,
    isDirty: true,
    serverErrors: {},
  );

  /// Fill in the person only when none is chosen yet — for the account's
  /// default (self, or the only family member) once the list has loaded.
  void applyDefaultPerson(String personId) {
    if (state.personId.isNotEmpty || personId.isEmpty) return;
    state = state.copyWith(personId: personId);
  }

  void setDocumentDate(DateTime day) => state = state.copyWith(
    documentDate: day,
    isDirty: true,
    // The server's complaint was about the old date (BL-REC-007).
    serverErrors: _withoutServerError('document_date'),
  );

  /// The file in the attachment slot was replaced or removed, so a server
  /// error about the previous file no longer applies (BL-REC-007).
  void fileChanged() {
    if (!state.serverErrors.containsKey('file_id')) return;
    state = state.copyWith(serverErrors: _withoutServerError('file_id'));
  }

  Map<String, String> _withoutServerError(String field) => {
    for (final entry in state.serverErrors.entries)
      if (entry.key != field) entry.key: entry.value,
  };

  void setNotes(String value) =>
      state = state.copyWith(notes: value, isDirty: true);

  void setAppointment(String? appointmentId, {String? label}) {
    if (appointmentId == null) {
      state = state.copyWith(clearAppointment: true, isDirty: true);
      return;
    }
    state = state.copyWith(
      appointmentId: appointmentId,
      appointmentLabel: label,
      isDirty: true,
      serverErrors: {},
    );
  }

  void markTouched(DocumentFormField field) {
    if (state.touched.contains(field)) return;
    state = state.copyWith(touched: {...state.touched, field});
  }

  /// Reveal every error. Returns whether the form is submittable.
  bool validate({required bool hasFile}) {
    state = state.copyWith(submitAttempted: true);
    return state.isValidWith(hasFile: hasFile, needsFile: !isEditing);
  }

  /// Validate and write. Returns the saved document, or null when the form
  /// is invalid, a save is already in flight, or the server refused — in
  /// which case [DocumentFormState.failure] / `serverErrors` say why.
  Future<MedicalDocument?> save({String? fileId}) async {
    if (state.isSaving) return null;
    if (!validate(hasFile: fileId != null)) return null;

    state = state.copyWith(isSaving: true, clearFailure: true);
    final title = state.title.trim();
    final notes = state.notes.trim();

    try {
      final existing = _existing;
      final MedicalDocument saved;
      if (existing == null) {
        saved = await _repository.create(
          DocumentDraft(
            fileId: fileId!,
            personId: state.personId,
            docType: state.docType,
            title: title,
            documentDate: state.documentDate,
            notes: notes.isEmpty ? null : notes,
            appointmentId: state.appointmentId,
          ),
        );
      } else {
        final patch = DocumentPatch(
          title: title == existing.title ? null : title,
          docType: state.docType == existing.docType ? null : state.docType,
          personId: state.personId == existing.personId ? null : state.personId,
          documentDate: _sameDay(state.documentDate, existing.documentDate)
              ? null
              : state.documentDate,
          notes: notes.isEmpty || notes == (existing.notes ?? '')
              ? null
              : notes,
          clearNotes: notes.isEmpty && existing.hasNotes,
          appointmentId: state.appointmentId == existing.appointmentId
              ? null
              : state.appointmentId,
          clearAppointment:
              state.appointmentId == null && existing.appointmentId != null,
        );
        saved = patch.isEmpty
            ? existing
            : await _repository.update(
                existing.id,
                patch,
                version: existing.version,
              );
      }
      if (!mounted) return saved;
      state = state.copyWith(isSaving: false, isDirty: false);
      return saved;
    } catch (error, stackTrace) {
      if (!mounted) return null;
      final failure = error.asFailure(stackTrace);
      state = state.copyWith(
        isSaving: false,
        failure: failure,
        serverErrors: failure is ValidationFailure ? failure.fieldErrors : {},
      );
      return null;
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// The document form, keyed by the id being edited — null to create.
/// `autoDispose`: leaving the screen must not leave a half-typed draft.
///
/// For an edit the document is read from [documentProvider], which the
/// detail screen has already loaded before it opens the sheet.
final documentFormProvider = StateNotifierProvider.autoDispose
    .family<DocumentFormController, DocumentFormState, String?>((
      ref,
      documentId,
    ) {
      final existing = documentId == null
          ? null
          : ref.read(documentProvider(documentId)).valueOrNull;
      return DocumentFormController(
        repository: ref.watch(documentsRepositoryProvider),
        existing: existing,
        // The account holder when there is a self person; otherwise the
        // screen fills in the first family member once persons load.
        defaultPersonId: ref.read(selfPersonIdProvider),
      );
    });

// ---------------------------------------------------------------------------
// Actions on one document
// ---------------------------------------------------------------------------

/// Delete and "open" for one document. Nothing here navigates or launches
/// a URL: [downloadUrl] hands the signed URL back and the screen opens it.
class DocumentActionsController extends StateNotifier<DocumentActionsState> {
  DocumentActionsController({required DocumentsRepository repository})
    : _repository = repository,
      super(const DocumentActionsState());

  final DocumentsRepository _repository;

  /// `DELETE`. Returns null on success, else the failure (also on state).
  Future<Failure?> delete(MedicalDocument document) async {
    if (state.isBusy) return state.failure;
    state = state.copyWith(isDeleting: true, clearFailure: true);
    try {
      await _repository.delete(document.id, version: document.version);
      if (mounted) state = state.copyWith(isDeleting: false);
      return null;
    } catch (error, stackTrace) {
      final failure = error.asFailure(stackTrace);
      if (mounted) state = state.copyWith(isDeleting: false, failure: failure);
      return failure;
    }
  }

  /// A fresh ten-minute URL (§11.3) — fetched every time, never cached.
  /// Returns null with the failure on state when it cannot be had.
  Future<SignedFileUrl?> downloadUrl(String documentId) async {
    if (state.isBusy) return null;
    state = state.copyWith(isResolvingUrl: true, clearFailure: true);
    try {
      final url = await _repository.downloadUrl(documentId);
      if (mounted) state = state.copyWith(isResolvingUrl: false);
      return url;
    } catch (error, stackTrace) {
      if (mounted) {
        state = state.copyWith(
          isResolvingUrl: false,
          failure: error.asFailure(stackTrace),
        );
      }
      return null;
    }
  }

  void clearFailure() => state = state.copyWith(clearFailure: true);
}

final documentActionsProvider = StateNotifierProvider.autoDispose
    .family<DocumentActionsController, DocumentActionsState, String>(
      (ref, documentId) => DocumentActionsController(
        repository: ref.watch(documentsRepositoryProvider),
      ),
    );
