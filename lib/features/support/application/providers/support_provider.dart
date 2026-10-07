import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity/connectivity_monitor.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../../common/cached/application/providers/cached_controller.dart';
import '../../../common/cached/application/states/cached_state.dart';
import '../../../common/mutation/application/states/mutation_state.dart';
import '../../domain/entities/ambulance_provider.dart';
import '../../domain/entities/faq.dart';
import '../../domain/entities/legal_document.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/repositories/support_content_repository.dart';
import '../../domain/repositories/support_ticket_repository.dart';
import '../states/ticket_form_state.dart';

// ---------------------------------------------------------------------------
// Wiring
// ---------------------------------------------------------------------------

/// Public content (app config, legal, FAQ, ambulance). Tests override this
/// with a fake; nothing below reads the implementation.
final supportContentRepositoryProvider = Provider<SupportContentRepository>(
  (ref) => throw UnimplementedError(
    'supportContentRepositoryProvider is wired in app/di',
  ),
);

final supportTicketRepositoryProvider = Provider<SupportTicketRepository>(
  (ref) => throw UnimplementedError(
    'supportTicketRepositoryProvider is wired in app/di',
  ),
);

// ---------------------------------------------------------------------------
// Public content reads
// ---------------------------------------------------------------------------

/// `GET /patient/legal/{slug}` (§3.2), cached.
///
/// Keyed by slug and **autoDispose**: a policy is read on demand (consent
/// screen, sign-up, Help) and need not stay resident. A `404` — nothing
/// published under that slug — surfaces as a `NotFoundFailure` in
/// `CachedState.failure`, which the legal screen renders as not-found.
///
/// The onboarding consent controller in `features/auth` should read this
/// (`ref.read(legalDocumentProvider(slug)).value?.version`) instead of the
/// seed's provider of the same name; `version` here is an `int`.
final legalDocumentProvider = StateNotifierProvider.autoDispose
    .family<
      CachedController<LegalDocument>,
      CachedState<LegalDocument>,
      String
    >((ref, slug) {
      final repository = ref.watch(supportContentRepositoryProvider);
      // The consent screen keeps these documents in memory. Opened offline,
      // a failed load stayed failed — the policy page showed "You appear to
      // be offline" after the connection was back (CL ONB-004). Load again
      // when the device reconnects.
      return CachedController<LegalDocument>(
        ({required forceRefresh}) =>
            repository.legalDocument(slug, forceRefresh: forceRefresh),
        reconnects: ref.watch(connectivityMonitorProvider).onReconnect,
      );
    });

/// `GET /patient/faqs` (§3.3), cached; categories in server order.
final supportFaqsProvider =
    StateNotifierProvider.autoDispose<
      CachedController<List<FaqCategory>>,
      CachedState<List<FaqCategory>>
    >((ref) {
      final repository = ref.watch(supportContentRepositoryProvider);
      return CachedController<List<FaqCategory>>(
        ({required forceRefresh}) =>
            repository.faqs(forceRefresh: forceRefresh),
        reconnects: ref.watch(connectivityMonitorProvider).onReconnect,
      );
    });

/// `GET /patient/ambulance/providers` (§14) for one [AmbulanceFilter].
///
/// The dashboard's ambulance screen reads this — `ref.watch(
/// ambulanceProvidersProvider(const AmbulanceFilter(city: 'Kochi')))` — and
/// gets a `CachedState<List<AmbulanceProvider>>` with the usual loading /
/// stale / failure affordances. Pass [AmbulanceFilter.none] for everything.
final ambulanceProvidersProvider = StateNotifierProvider.autoDispose
    .family<
      CachedController<List<AmbulanceProvider>>,
      CachedState<List<AmbulanceProvider>>,
      AmbulanceFilter
    >((ref, filter) {
      final repository = ref.watch(supportContentRepositoryProvider);
      return CachedController<List<AmbulanceProvider>>(
        ({required forceRefresh}) =>
            repository.ambulanceProviders(filter, forceRefresh: forceRefresh),
        reconnects: ref.watch(connectivityMonitorProvider).onReconnect,
      );
    });

// ---------------------------------------------------------------------------
// Tickets
// ---------------------------------------------------------------------------

/// The user's tickets (§13), newest first, cached. autoDispose: it belongs to
/// the support screens.
final supportTicketsProvider =
    StateNotifierProvider.autoDispose<
      CachedController<List<SupportTicket>>,
      CachedState<List<SupportTicket>>
    >((ref) {
      final repository = ref.watch(supportTicketRepositoryProvider);
      return CachedController<List<SupportTicket>>(
        ({required forceRefresh}) =>
            repository.tickets(forceRefresh: forceRefresh),
        reconnects: ref.watch(connectivityMonitorProvider).onReconnect,
      );
    });

/// One ticket with its messages, cached; keyed by id.
final supportTicketDetailProvider = StateNotifierProvider.autoDispose
    .family<
      CachedController<SupportTicket>,
      CachedState<SupportTicket>,
      String
    >((ref, id) {
      final repository = ref.watch(supportTicketRepositoryProvider);
      return CachedController<SupportTicket>(
        ({required forceRefresh}) =>
            repository.ticket(id, forceRefresh: forceRefresh),
        reconnects: ref.watch(connectivityMonitorProvider).onReconnect,
      );
    });

/// Owns the "raise a request" form and its submit.
///
/// No `BuildContext`, no toast, no navigation: the screen watches
/// [TicketFormState.created] to leave, and toasts from its own callback on
/// the returned [Failure].
class TicketFormController extends StateNotifier<TicketFormState> {
  TicketFormController(this._ref, {required SupportTicketRepository repository})
    : _repository = repository,
      super(const TicketFormState()) {
    _revalidate();
  }

  final Ref _ref;
  final SupportTicketRepository _repository;

  static const int subjectMax = 200;
  static const int descriptionMax = 5000;

  void setCategory(TicketCategory value) {
    state = state.copyWith(category: value);
    _revalidate();
  }

  void setPriority(TicketPriority? value) {
    state = value == null
        ? state.copyWith(clearPriority: true)
        : state.copyWith(priority: value);
  }

  void setSubject(String value) {
    state = state.copyWith(subject: value);
    _revalidate();
  }

  void setDescription(String value) {
    state = state.copyWith(description: value);
    _revalidate();
  }

  /// Validates, marks submitted, and sends when clean. Returns null on
  /// success (with [TicketFormState.created] set), otherwise the failure —
  /// a `ValidationFailure` whose field errors have already been applied.
  ///
  /// [attachmentFileIds]: the request's files, already uploaded and passed
  /// by the virus check (BL-SUP-006).
  Future<Failure?> submit({
    List<String> attachmentFileIds = const <String>[],
  }) async {
    if (state.isSending) return null;
    _revalidate();
    state = state.copyWith(submitted: true, clearFailure: true);
    if (!state.isValid) {
      return const ValidationFailure();
    }
    state = state.copyWith(isSending: true);
    try {
      final created = await _repository.create(
        NewTicket(
          category: state.category,
          subject: state.subject.trim(),
          description: state.description.trim(),
          priority: state.priority,
          attachmentFileIds: attachmentFileIds,
        ),
      );
      if (!mounted) return null;
      state = state.copyWith(isSending: false, created: created);
      // The list is invalidated in the repository; refresh it if a screen
      // holds it so the new ticket shows without a pull.
      _ref
          .read(supportTicketsProvider.notifier)
          .update(
            (current) => [created, ...current.where((t) => t.id != created.id)],
          );
      return null;
    } catch (error, stackTrace) {
      if (!mounted) return null;
      final failure = error.asFailure(stackTrace);
      if (failure is ValidationFailure && failure.fieldErrors.isNotEmpty) {
        state = state.copyWith(
          isSending: false,
          errors: {...state.errors, ...failure.fieldErrors},
        );
      } else {
        state = state.copyWith(isSending: false, failure: failure);
      }
      return failure;
    }
  }

  void _revalidate() {
    final errors = <String, String>{};
    final subject = Validators.requiredField('a short subject', state.subject);
    if (subject != null) {
      errors[TicketFormField.subject] = subject;
    } else if (state.subject.trim().length > subjectMax) {
      errors[TicketFormField.subject] =
          'Keep the subject under $subjectMax characters';
    }
    final description = state.description.trim();
    if (description.isEmpty) {
      errors[TicketFormField.description] = 'Tell us what happened';
    } else if (description.length < 20) {
      errors[TicketFormField.description] =
          'Add a little more detail so we can help (at least 20 characters)';
    } else if (description.length > descriptionMax) {
      errors[TicketFormField.description] =
          'Keep the description under $descriptionMax characters';
    }
    state = state.copyWith(errors: errors);
  }
}

/// autoDispose — the draft belongs to one visit to the form.
final ticketFormControllerProvider =
    StateNotifierProvider.autoDispose<TicketFormController, TicketFormState>(
      (ref) => TicketFormController(
        ref,
        repository: ref.watch(supportTicketRepositoryProvider),
      ),
    );

/// Sends a reply on one ticket (`POST /{id}/messages`).
class TicketReplyController extends StateNotifier<MutationState> {
  TicketReplyController(
    this._ref, {
    required SupportTicketRepository repository,
    required String ticketId,
  }) : _repository = repository,
       _ticketId = ticketId,
       super(const MutationState());

  final Ref _ref;
  final SupportTicketRepository _repository;
  final String _ticketId;

  static const int bodyMax = 5000;

  /// Returns null on success; the detail provider is updated in place so the
  /// message appears immediately.
  Future<Failure?> send(
    String body, {
    List<String> attachmentFileIds = const <String>[],
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return const ValidationFailure(userMessage: 'Type a message first');
    }
    if (trimmed.length > bodyMax) {
      return const ValidationFailure(
        userMessage: 'Keep the message under 5000 characters',
      );
    }
    if (state.isBusy) return null;
    state = state.copyWith(isBusy: true, clearFailure: true);
    try {
      final message = await _repository.reply(
        _ticketId,
        trimmed,
        attachmentFileIds: attachmentFileIds,
      );
      if (!mounted) return null;
      state = state.copyWith(isBusy: false);
      _ref
          .read(supportTicketDetailProvider(_ticketId).notifier)
          .update(
            (ticket) => ticket.copyWith(
              messages: [...ticket.messages, message],
              // A reply on a resolved / waiting ticket reopens it (§13).
              status: ticket.status.isOpen ? ticket.status : TicketStatus.open,
              updatedAt: message.occurredAt,
            ),
          );
      return null;
    } catch (error, stackTrace) {
      if (!mounted) return null;
      final failure = error.asFailure(stackTrace);
      state = state.copyWith(isBusy: false, failure: failure);
      return failure;
    }
  }
}

final ticketReplyControllerProvider = StateNotifierProvider.autoDispose
    .family<TicketReplyController, MutationState, String>(
      (ref, ticketId) => TicketReplyController(
        ref,
        repository: ref.watch(supportTicketRepositoryProvider),
        ticketId: ticketId,
      ),
    );
