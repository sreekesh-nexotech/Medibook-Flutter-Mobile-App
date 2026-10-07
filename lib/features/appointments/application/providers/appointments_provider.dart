import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/env.dart';
import '../../../../core/network/connectivity/connectivity_monitor.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/network_exceptions.dart'
    show NetworkExceptions;
import '../../../../core/network/realtime/ws_client.dart';
import '../../../../core/network/realtime/ws_session.dart';
import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../../../core/utils/logger.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/appointment_detail.dart';
import '../../domain/entities/appointment_event.dart';
import '../../domain/entities/appointment_filter.dart';
import '../../domain/entities/appointment_review.dart';
import '../../domain/entities/cancellation_preview.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/person_summary.dart';
import '../../domain/entities/receipt.dart';
import '../../domain/entities/token_card.dart';
import '../../domain/repositories/appointments_repository.dart';
import '../states/appointment_action_state.dart';
import '../states/appointments_list_state.dart';
import '../states/live_queue_state.dart';
import '../usecases/hospital_time.dart';
import '../../../../core/network/api_client.dart';

// ---------------------------------------------------------------------------
// Wiring
// ---------------------------------------------------------------------------

/// The appointments repository. Every caller depends on this, not on the
/// impl, so a test can `overrideWithValue(FakeAppointmentsRepository())`.
final appointmentsRepositoryProvider = Provider<AppointmentsRepository>(
  (ref) => throw UnimplementedError(
    'appointmentsRepositoryProvider is wired in app/di',
  ),
);

// ---------------------------------------------------------------------------
// Lists (§10.1)
// ---------------------------------------------------------------------------

/// Owns one paginated list: the first page through the three-layer cache
/// (cached rows first, then the network answer), later pages appended on
/// scroll.
///
/// Holds the domain contract, never the impl. No navigation, no toasts —
/// the screen reads the state and decides what to show.
class AppointmentsListController extends StateNotifier<AppointmentsListState> {
  AppointmentsListController({
    required AppointmentsRepository repository,
    required AppointmentListQuery query,
  }) : _repository = repository,
       _query = query,
       super(const AppointmentsListState()) {
    load();
  }

  final AppointmentsRepository _repository;
  final AppointmentListQuery _query;

  /// Every page-1 subscription still open. A reload does **not** cancel the
  /// previous one outright: cancelling an `async*` stream before its first
  /// event orphans any error it then throws as an unhandled exception, so a
  /// superseded subscription is instead ignored (see [_generation]) and
  /// cancelled at its next safe point — its first event, error or done.
  final Set<StreamSubscription<CachedResult<Page<Appointment>>>> _open = {};

  /// Bumped on every [load]; events from an older generation are ignored.
  int _generation = 0;

  /// Reload page 1 if the last load failed — the error view, or the "Could
  /// not update" bar over saved rows — now the connection is back.
  void reloadIfFailed() {
    if (mounted && state.failure != null) unawaited(load());
  }

  /// (Re)load page 1. Completes once the freshest answer available has
  /// arrived, so pull-to-refresh can await it. [forceRefresh] skips the
  /// cached copy (the ETag is still sent, so an unchanged list is a 304).
  Future<void> load({bool forceRefresh = false}) {
    final generation = ++_generation;
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    late final StreamSubscription<CachedResult<Page<Appointment>>> subscription;
    void retire() {
      if (_open.remove(subscription)) unawaited(subscription.cancel());
    }

    state = state.copyWith(
      isLoading: state.items.isEmpty,
      revalidating: state.items.isNotEmpty,
      clearFailure: true,
      clearLoadMoreFailure: true,
    );

    subscription = _repository
        .watchList(_query, page: 1, forceRefresh: forceRefresh)
        .listen(
          (result) {
            if (!mounted || generation != _generation) {
              retire();
              return finish();
            }
            final page = result.value;
            state = state.copyWith(
              items: page.results,
              page: page.page,
              hasNext: page.hasNext,
              total: page.total,
              isLoading: false,
              revalidating: result.revalidating,
              isStale: result.isStale,
              source: result.source,
              cachedAt: result.cachedAt,
              clearFailure: true,
            );
            if (!result.revalidating) finish();
          },
          onError: (Object error, StackTrace stackTrace) {
            _open.remove(subscription);
            if (mounted && generation == _generation) {
              final failure = NetworkExceptions.toFailure(error, stackTrace);
              AppLogger.warning(
                'Appointments list failed',
                name: 'appointments',
                error: failure,
              );
              state = state.copyWith(
                isLoading: false,
                revalidating: false,
                failure: failure,
              );
            }
            finish();
          },
          onDone: () {
            _open.remove(subscription);
            if (mounted && generation == _generation && state.revalidating) {
              state = state.copyWith(revalidating: false);
            }
            finish();
          },
        );
    _open.add(subscription);
    return done.future;
  }

  /// Append the next page (infinite scroll). A no-op while one is already
  /// loading or when the server said there is none.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasNext || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, clearLoadMoreFailure: true);
    try {
      final next = await _repository.fetchList(_query, page: state.page + 1);
      if (!mounted) return;
      state = state.copyWith(
        items: [...state.items, ...next.results],
        page: next.page,
        hasNext: next.hasNext,
        total: next.total,
        isLoadingMore: false,
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreFailure: NetworkExceptions.toFailure(error, stackTrace),
      );
    }
  }

  @override
  void dispose() {
    for (final subscription in _open) {
      unawaited(subscription.cancel());
    }
    _open.clear();
    super.dispose();
  }
}

/// One list per query (tab + filter, or a search term). autoDispose family:
/// the query space is unbounded, so a list must not outlive its screen.
final appointmentsListProvider = StateNotifierProvider.autoDispose
    .family<
      AppointmentsListController,
      AppointmentsListState,
      AppointmentListQuery
    >((ref, query) {
      final controller = AppointmentsListController(
        repository: ref.watch(appointmentsRepositoryProvider),
        query: query,
      );
      // A list that failed (offline at start) loads itself again when the
      // connection returns (BL-CACHE-017).
      final reconnects = ref
          .watch(connectivityMonitorProvider)
          .onReconnect
          .listen((_) => controller.reloadIfFailed());
      ref.onDispose(reconnects.cancel);
      return controller;
    });

// ---------------------------------------------------------------------------
// Detail and its sub-resources (§10.2–10.4, §10.6, §10.8, §10.11)
// ---------------------------------------------------------------------------

/// `GET /patient/appointments/{id}` through the cache: the cached copy is
/// emitted first (with `revalidating`), then the network answer.
final appointmentDetailProvider = StreamProvider.autoDispose
    .family<CachedResult<AppointmentDetail>, String>(
      (ref, id) => ref.watch(appointmentsRepositoryProvider).watchDetail(id),
    );

/// History timeline (§10.3).
final appointmentEventsProvider = FutureProvider.autoDispose
    .family<List<AppointmentEvent>, String>(
      (ref, id) => guardedRead(
        'appointment events',
        () async => (await ref.watch(appointmentsRepositoryProvider).events(id))
            .results,
      ),
    );

/// The token card (§10.4).
final tokenCardProvider = FutureProvider.autoDispose.family<TokenCard, String>(
  (ref, id) => guardedRead(
    'token card',
    () => ref.watch(appointmentsRepositoryProvider).tokenCard(id),
  ),
);

/// The issued receipt (§10.8). `NotFoundFailure` until the booking is paid.
final appointmentReceiptProvider = FutureProvider.autoDispose
    .family<Receipt, String>(
      (ref, id) => guardedRead(
        'receipt',
        () => ref.watch(appointmentsRepositoryProvider).receipt(id),
      ),
    );

/// Payments against one appointment (§10.11).
final appointmentPaymentsProvider = FutureProvider.autoDispose
    .family<List<Payment>, String>(
      (ref, id) => guardedRead(
        'appointment payments',
        () async =>
            (await ref.watch(appointmentsRepositoryProvider).payments(id))
                .results,
      ),
    );

/// Refunds against one appointment (§10.11).
final appointmentRefundsProvider = FutureProvider.autoDispose
    .family<List<Refund>, String>(
      (ref, id) => guardedRead(
        'appointment refunds',
        () async =>
            (await ref.watch(appointmentsRepositoryProvider).refunds(id))
                .results,
      ),
    );

// ---------------------------------------------------------------------------
// Actions (§10.6, §10.7, §10.9, §10.10, §10.12)
// ---------------------------------------------------------------------------

/// Runs the detail screen's mutations and the two file actions.
///
/// * **Cancel** mints one `Idempotency-Key` per attempt and reuses it while
///   the attempt is retried after a network / server failure (§1.8). A
///   definitive rejection (409, 404) drops the key — the action is over.
/// * Every method returns the outcome or null, with the [Failure] left in
///   [AppointmentActionState.failure] for the screen to toast.
class AppointmentActionsController
    extends StateNotifier<AppointmentActionState> {
  AppointmentActionsController({
    required AppointmentsRepository repository,
    required String appointmentId,
  }) : _repository = repository,
       _id = appointmentId,
       super(const AppointmentActionState());

  final AppointmentsRepository _repository;
  final String _id;
  String? _cancelKey;

  /// `GET cancellation-preview` — call before the confirm dialog.
  Future<CancellationPreview?> previewCancellation() =>
      _run(AppointmentActionKind.cancel, () async {
        final preview = await _repository.cancellationPreview(_id);
        if (mounted) state = state.copyWith(preview: preview);
        return preview;
      });

  /// `POST cancel` with the attempt's key.
  Future<CancelOutcome?> cancel({String? reason}) =>
      _run(AppointmentActionKind.cancel, () async {
        final key = _cancelKey ??= IdempotencyKeys.mint();
        try {
          final outcome = await _repository.cancel(
            _id,
            idempotencyKey: key,
            reason: reason,
          );
          _cancelKey = null;
          return outcome;
        } on Failure catch (failure) {
          // A conflict / not-found is final: a retry must not replay it.
          if (!failure.isRetryable) _cancelKey = null;
          rethrow;
        }
      });

  /// `POST review {rating, comment}`.
  Future<AppointmentReview?> submitReview({
    required int rating,
    String? comment,
  }) => _run(
    AppointmentActionKind.review,
    () => _repository.review(_id, rating: rating, comment: comment),
  );

  /// `GET receipt.pdf` → the ten-minute URL to open.
  Future<ReceiptPdfLink?> receiptPdfLink() => _run(
    AppointmentActionKind.receiptPdf,
    () => _repository.receiptPdfLink(_id),
  );

  /// `GET calendar.ics` saved to a file → its path.
  Future<String?> saveCalendar() => _run(
    AppointmentActionKind.calendar,
    () => _repository.saveCalendarFile(_id),
  );

  void clearFailure() {
    if (state.failure != null) state = state.copyWith(clearFailure: true);
  }

  Future<T?> _run<T>(
    AppointmentActionKind kind,
    Future<T> Function() operation,
  ) async {
    if (state.isBusy) return null;
    state = state.copyWith(busy: kind, clearFailure: true);
    try {
      return await operation();
    } catch (error, stackTrace) {
      final failure = error.asFailure(stackTrace);
      AppLogger.warning(
        'Appointment action $kind failed',
        name: 'appointments',
        error: failure,
      );
      if (mounted) state = state.copyWith(failure: failure);
      return null;
    } finally {
      if (mounted) state = state.copyWith(clearBusy: true);
    }
  }
}

/// One action controller per appointment. autoDispose family — transient
/// UI state for whichever appointment screen is open.
final appointmentActionsProvider = StateNotifierProvider.autoDispose
    .family<AppointmentActionsController, AppointmentActionState, String>(
      (ref, id) => AppointmentActionsController(
        repository: ref.watch(appointmentsRepositoryProvider),
        appointmentId: id,
      ),
    );

// ---------------------------------------------------------------------------
// Live queue (§10.5 + §15.1)
// ---------------------------------------------------------------------------

/// The session as the live-queue socket sees it: the token it presents, and
/// a refresh that is skipped when the API client has already replaced it.
final liveQueueWsSessionProvider = Provider<WsSession>(
  (ref) => WsSession(
    accessToken: () => ref.read(authRepositoryProvider).accessToken(),
    refresh: () async {
      await ref.read(authRepositoryProvider).refreshSession();
    },
  ),
);

/// Builds a [WsClient] for a `/ws/patient/…` path. Overridden in tests.
final wsClientFactoryProvider = Provider<WsClient Function(String path)>(
  (ref) =>
      (path) => WsClient(
        url: '${Env.wsBaseUrl}$path',
        accessToken: () => ref.read(liveQueueWsSessionProvider).accessToken(),
        allowBadCertificate: Env.allowBadCertificate && !Env.isProd,
      ),
);

/// Owns the live-queue screen: the REST reading plus the session socket.
///
/// * `session.updated` → re-fetch `GET …/queue` (the frame is about the
///   whole session; only the endpoint knows `tokens_ahead` for this patient).
/// * `token.called` for this appointment → "it's your turn".
/// * close 4401, or a handshake refused with HTTP 403 (how the live server
///   answers an expired token) → refresh the session, then reconnect; any
///   other drop → reconnect with backoff, up to [maxReconnects]; never
///   inside [WsClient].
/// * disposed with the screen — nothing keeps retrying in the background.
class LiveQueueController extends StateNotifier<LiveQueueState> {
  LiveQueueController({
    required AppointmentsRepository repository,
    required String appointmentId,
    required WsClient Function(String path) openSocket,
    required Future<void> Function() refreshSession,
  }) : _repository = repository,
       _id = appointmentId,
       _openSocket = openSocket,
       _refreshSession = refreshSession,
       super(const LiveQueueState()) {
    unawaited(refresh());
    unawaited(_connect());
  }

  static const int maxReconnects = 5;

  final AppointmentsRepository _repository;
  final String _id;
  final WsClient Function(String path) _openSocket;
  final Future<void> Function() _refreshSession;

  WsClient? _socket;
  StreamSubscription<WsFrame>? _frames;
  StreamSubscription<WsCloseReason>? _closed;
  Timer? _reconnectTimer;
  int _drops = 0;

  /// True once a handshake was refused even with a freshly refreshed token.
  bool _refusedWithFreshToken = false;
  bool _disposed = false;

  /// Pull-to-refresh: re-read the queue and, once live updates have given
  /// up ("Live updates unavailable. Pull down to refresh."), start them
  /// again — the banner promised the pull would (BL-QUEUE-013).
  Future<void> pullToRefresh() async {
    if (state.connection == LiveQueueConnection.offline && !_disposed) {
      _reconnectTimer?.cancel();
      _drops = 0;
      _refusedWithFreshToken = false;
      unawaited(_connect());
    }
    await refresh();
  }

  /// `GET /patient/appointments/{id}/queue`.
  Future<void> refresh() async {
    try {
      final queue = await _repository.queue(_id);
      if (!mounted) return;
      state = state.copyWith(
        queue: queue,
        isLoading: false,
        clearFailure: true,
        // The endpoint is the source of truth once the desk has moved on.
        isYourTurn: state.isYourTurn && !queue.isOver,
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        failure: NetworkExceptions.toFailure(error, stackTrace),
      );
    }
  }

  Future<void> _connect({bool withFreshToken = false}) async {
    if (_disposed) return;
    if (withFreshToken) {
      try {
        await _refreshSession();
      } catch (error) {
        AppLogger.warning(
          'Live queue: token refresh failed; staying on REST',
          name: 'appointments',
          error: error,
        );
        _setConnection(LiveQueueConnection.offline);
        return;
      }
      if (_disposed) return;
    }
    await _teardownSocket();
    final socket = _openSocket(Endpoints.wsSession(_id));
    _socket = socket;
    _frames = socket.frames.listen(_onFrame);
    _closed = socket.closed.listen(_onClosed);
    try {
      await socket.connect();
      _drops = 0;
      _refusedWithFreshToken = false;
      _setConnection(LiveQueueConnection.live);
    } catch (error) {
      AppLogger.warning(
        'Live queue: socket refused',
        name: 'appointments',
        error: error,
      );
      // A refused handshake is how the server answers an expired token
      // (HTTP 403, never a 4401 close): one retry with a fresh token before
      // falling back to the backoff.
      if (error is WsHandshakeRefused) {
        if (withFreshToken) {
          // Refused with a brand-new token too: the token is not the reason
          // (this is not the patient's appointment, say). The later retries
          // must not refresh again — each refresh rotates the session and
          // the server allows only a few a minute (BL-QUEUE-015).
          _refusedWithFreshToken = true;
        } else if (!_refusedWithFreshToken) {
          unawaited(_connect(withFreshToken: true));
          return;
        }
      }
      _scheduleReconnect();
    }
  }

  void _onFrame(WsFrame frame) {
    switch (frame.type) {
      case 'session.updated':
        unawaited(refresh());
      case 'token.called':
        if (frame.data['appointment_id'] == _id) {
          if (mounted) {
            state = state.copyWith(
              isYourTurn: true,
              calledAt: frame.timestamp ?? DateTime.now().toUtc(),
            );
          }
          unawaited(refresh());
        }
    }
  }

  void _onClosed(WsCloseReason reason) {
    if (_disposed) return;
    switch (reason) {
      case WsCloseReason.unauthorized:
        unawaited(_connect(withFreshToken: true));
      case WsCloseReason.idle:
      case WsCloseReason.other:
        _scheduleReconnect();
      case WsCloseReason.local:
        break;
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _drops++;
    if (_drops > maxReconnects) {
      _setConnection(LiveQueueConnection.offline);
      return;
    }
    _setConnection(LiveQueueConnection.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      NetworkExceptions.backoffFor(_drops + 1),
      () => unawaited(_connect()),
    );
  }

  void _setConnection(LiveQueueConnection connection) {
    if (mounted && state.connection != connection) {
      state = state.copyWith(connection: connection);
    }
  }

  Future<void> _teardownSocket() async {
    await _frames?.cancel();
    await _closed?.cancel();
    _frames = null;
    _closed = null;
    final socket = _socket;
    _socket = null;
    await socket?.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    unawaited(_teardownSocket());
    super.dispose();
  }
}

/// The live queue for one appointment. autoDispose family: the socket lives
/// exactly as long as the screen that watches it.
final liveQueueProvider = StateNotifierProvider.autoDispose
    .family<LiveQueueController, LiveQueueState, String>(
      (ref, id) => LiveQueueController(
        repository: ref.watch(appointmentsRepositoryProvider),
        appointmentId: id,
        openSocket: ref.watch(wsClientFactoryProvider),
        refreshSession: () =>
            ref.read(liveQueueWsSessionProvider).refreshIfStale(),
      ),
    );

// ---------------------------------------------------------------------------
// Cross-feature read models
// ---------------------------------------------------------------------------

/// The first page of `bucket=upcoming&sort=scheduled_start_at`, for Home.
///
/// Not autoDispose: Home is a shell tab that is rebuilt constantly, and the
/// answer is small. Refreshed when the user signs in / out and by
/// `ref.invalidate` after a booking or cancellation.
final upcomingAppointmentsPeekProvider = FutureProvider<Page<Appointment>>((
  ref,
) async {
  if (!ref.watch(isAuthenticatedProvider)) return const Page.empty();
  final repository = ref.watch(appointmentsRepositoryProvider);
  return guardedRead(
    'upcoming appointments',
    () => repository.fetchList(
      const AppointmentListQuery(tab: AppointmentTab.upcoming),
      pageSize: 5,
    ),
  );
});

/// The next upcoming appointment (Home's "Your Token" card), or null.
///
/// Read by the dashboard feature: `ref.watch(nextUpcomingAppointmentProvider)`
/// → `AsyncValue<Appointment?>`.
final nextUpcomingAppointmentProvider = Provider<AsyncValue<Appointment?>>((
  ref,
) {
  return ref
      .watch(upcomingAppointmentsPeekProvider)
      .whenData((page) => page.results.isEmpty ? null : page.results.first);
});

/// An appointment a document can be attached to, pre-resolved for display —
/// the shape the records feature links against. [when], [bookingRef],
/// [status] and [personId] are what tell two visits with the same doctor on
/// the same day apart.
typedef LinkableAppointmentRef = ({
  String id,
  String label,
  DateTime scheduledAt,
  String doctorName,
  String hospitalName,
  String when,
  String bookingRef,
  AppointmentStatus status,
  String personId,
});

/// "Dr. Anil Kumar · 10 Jul 2026" — how a document names the visit it is
/// linked to, in the hospital's own calendar.
String appointmentLinkLabel(Appointment appointment) =>
    '${appointment.doctor.name} · '
    '${HospitalTime.dayMonthYear(appointment.scheduledStartAt, timezone: appointment.hospital.timezone)}';

/// One linked visit in full — "Dr. Anil Kumar · 10 Jul 2026 · Lakeshore
/// Multispeciality Hospital" — from `GET /patient/appointments/{id}` alone,
/// for a screen that names a single linked visit (the document detail)
/// without loading every list. Null while it loads or when it cannot be
/// read.
final appointmentLinkLabelProvider = Provider.autoDispose
    .family<String?, String>((ref, id) {
      final appointment = ref
          .watch(appointmentDetailProvider(id))
          .valueOrNull
          ?.value
          .appointment;
      if (appointment == null) return null;
      final hospital = appointment.hospital.name;
      final label = appointmentLinkLabel(appointment);
      return hospital.isEmpty ? label : '$label · $hospital';
    });

/// Every appointment on the account (upcoming first, then past), newest
/// first, with the doctor and hospital names already on it.
///
/// Read by the records feature (`document_form`, `documents_filter_sheet`)
/// in place of its former seed-backed `linkableAppointmentsProvider`.
final appointmentsForLinkingProvider =
    FutureProvider.autoDispose<List<LinkableAppointmentRef>>((ref) async {
      final repository = ref.watch(appointmentsRepositoryProvider);
      const size = appointmentsMaxPageSize;
      final pages = await guardedRead(
        'appointments for linking',
        () => Future.wait([
          repository.fetchList(
            const AppointmentListQuery(tab: AppointmentTab.upcoming),
            pageSize: size,
          ),
          repository.fetchList(
            const AppointmentListQuery(tab: AppointmentTab.completed),
            pageSize: size,
          ),
          repository.fetchList(
            const AppointmentListQuery(tab: AppointmentTab.cancelled),
            pageSize: size,
          ),
        ]),
      );
      final seen = <String>{};
      final items = <LinkableAppointmentRef>[
        for (final page in pages)
          for (final appointment in page.results)
            if (seen.add(appointment.id))
              (
                id: appointment.id,
                label: appointmentLinkLabel(appointment),
                scheduledAt: appointment.scheduledStartAt,
                doctorName: appointment.doctor.name,
                hospitalName: appointment.hospital.name,
                when: HospitalTime.dateAndTime(
                  appointment.scheduledStartAt,
                  timezone: appointment.hospital.timezone,
                ),
                bookingRef: appointment.bookingRef,
                status: appointment.status,
                personId: appointment.personId,
              ),
      ]..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
      return items;
    });

// ---------------------------------------------------------------------------
// Persons join (§6.1)
// ---------------------------------------------------------------------------

/// The account's family members, for "For Aarav (Son)" on cards and the
/// patient filter. Cached by the fetcher; not autoDispose because every
/// appointment screen reads it.
final appointmentPersonsProvider = FutureProvider<List<PersonSummary>>((
  ref,
) async {
  if (!ref.watch(isAuthenticatedProvider)) return const <PersonSummary>[];
  final repository = ref.watch(appointmentsRepositoryProvider);
  return guardedRead('family members', repository.persons);
});

/// "Aarav Nair (Child)" for a person id, or null while the persons list has
/// not loaded / the id is unknown (a released family member).
final personForLabelProvider = Provider.autoDispose.family<String?, String>((
  ref,
  personId,
) {
  final persons = ref.watch(appointmentPersonsProvider).valueOrNull;
  if (persons == null) return null;
  for (final person in persons) {
    if (person.id == personId) return person.forLabel;
  }
  return null;
});
