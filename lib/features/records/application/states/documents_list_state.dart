import '../../../../core/error/failure.dart';
import '../../domain/entities/medical_document.dart';

/// The Records list: what has loaded, from where, and what is in flight.
///
/// Immutable; every update goes through [copyWith]. The four screen states
/// derive from it — skeleton ([isLoading] with nothing to show), error
/// ([failure] with nothing to show), empty, content — plus the HIVE
/// affordances: "updating…" ([revalidating]), the amber bar ([isStale]) and
/// the offline copy ([fromCache]).
class DocumentsListState {
  const DocumentsListState({
    required this.query,
    this.items = const <MedicalDocument>[],
    this.total = 0,
    this.hasNext = false,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.failure,
    this.fromCache = false,
    this.isStale = false,
    this.revalidating = false,
    this.cachedAt,
  });

  final DocumentQuery query;
  final List<MedicalDocument> items;
  final int total;
  final bool hasNext;

  /// First load with nothing to show yet.
  final bool isLoading;
  final bool isLoadingMore;
  final bool isRefreshing;

  /// The last load / refresh / load-more error.
  final Failure? failure;
  final bool fromCache;
  final bool isStale;
  final bool revalidating;
  final DateTime? cachedAt;

  bool get hasData => items.isNotEmpty;

  /// Nothing to show and nothing coming: the empty state.
  bool get isEmpty => !isLoading && failure == null && items.isEmpty;

  DocumentsListState copyWith({
    DocumentQuery? query,
    List<MedicalDocument>? items,
    int? total,
    bool? hasNext,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isRefreshing,
    Failure? failure,
    bool clearFailure = false,
    bool? fromCache,
    bool? isStale,
    bool? revalidating,
    DateTime? cachedAt,
  }) {
    return DocumentsListState(
      query: query ?? this.query,
      items: items ?? this.items,
      total: total ?? this.total,
      hasNext: hasNext ?? this.hasNext,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      failure: clearFailure ? null : (failure ?? this.failure),
      fromCache: fromCache ?? this.fromCache,
      isStale: isStale ?? this.isStale,
      revalidating: revalidating ?? this.revalidating,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}

/// The user-facing filter set on the Records list (CM-34), kept typed so a
/// [DocumentQuery] can be built from it without parsing labels.
///
/// The backend filters on a single `doc_type`, so the type facet is one
/// value, not a set.
class DocumentFilters {
  const DocumentFilters({
    this.type,
    this.personId,
    this.from,
    this.to,
    this.appointmentId,
  });

  final DocumentType? type;
  final String? personId;
  final DateTime? from;
  final DateTime? to;
  final String? appointmentId;

  bool get hasDateRange => from != null || to != null;

  bool get isActive =>
      type != null || personId != null || hasDateRange || appointmentId != null;

  /// How many removable chips the list renders.
  int get activeCount =>
      (type == null ? 0 : 1) +
      (personId == null ? 0 : 1) +
      (hasDateRange ? 1 : 0) +
      (appointmentId == null ? 0 : 1);

  DocumentQuery toQuery({
    required DocumentSort sort,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) => DocumentQuery(
    docType: type,
    personId: personId,
    dateFrom: from,
    dateTo: to,
    appointmentId: appointmentId,
    search: search,
    sort: sort,
    page: page,
    pageSize: pageSize,
  );

  DocumentFilters copyWith({
    DocumentType? type,
    bool clearType = false,
    String? personId,
    bool clearPerson = false,
    DateTime? from,
    DateTime? to,
    bool clearDateRange = false,
    String? appointmentId,
    bool clearAppointment = false,
  }) {
    return DocumentFilters(
      type: clearType ? null : (type ?? this.type),
      personId: clearPerson ? null : (personId ?? this.personId),
      from: clearDateRange ? null : (from ?? this.from),
      to: clearDateRange ? null : (to ?? this.to),
      appointmentId: clearAppointment
          ? null
          : (appointmentId ?? this.appointmentId),
    );
  }
}

/// What the Records search box holds ([input]) and the title the list is
/// fetched for ([query], debounced) — `q` on `GET /patient/documents`.
class DocumentsSearchState {
  const DocumentsSearchState({this.input = '', this.query});

  /// The longest title search sent to the server.
  static const int maxLength = 100;

  /// Raw text in the box.
  final String input;

  /// The settled, trimmed term the list uses — null when there is none.
  final String? query;

  bool get hasInput => input.isNotEmpty;

  DocumentsSearchState copyWith({String? input, String? Function()? query}) =>
      DocumentsSearchState(
        input: input ?? this.input,
        query: query != null ? query() : this.query,
      );
}
