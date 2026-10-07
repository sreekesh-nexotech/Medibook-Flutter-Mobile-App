import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/features/support/application/providers/support_provider.dart';
import 'package:medibook/features/support/application/states/ticket_form_state.dart';
import 'package:medibook/features/support/domain/entities/support_ticket.dart';
import 'package:medibook/features/support/domain/repositories/support_ticket_repository.dart';

/// The "raise a request" form and ticket replies (§13) against a fake
/// repository.
void main() {
  late FakeSupportTicketRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeSupportTicketRepository();
    container = ProviderContainer(
      overrides: [
        supportTicketRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  TicketFormController form() =>
      container.read(ticketFormControllerProvider.notifier);

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('errors are hidden until submit, then shown and re-validated', () async {
    final state = container.read(ticketFormControllerProvider);
    expect(state.isValid, isFalse);
    expect(state.errorFor(TicketFormField.subject), isNull);

    final failure = await form().submit();

    expect(failure, isA<ValidationFailure>());
    expect(repository.created, isEmpty);
    var shown = container.read(ticketFormControllerProvider);
    expect(shown.errorFor(TicketFormField.subject), isNotNull);
    expect(
      shown.errorFor(TicketFormField.description),
      contains('what happened'),
    );

    form().setSubject('Charged twice');
    form().setDescription('Short');
    shown = container.read(ticketFormControllerProvider);
    expect(shown.errorFor(TicketFormField.subject), isNull);
    expect(shown.errorFor(TicketFormField.description), contains('20'));
  });

  test('a valid form creates the ticket and prepends it to the list', () async {
    container.listen<Object?>(supportTicketsProvider, (_, _) {});
    await settle();
    form()
      ..setCategory(TicketCategory.billing)
      ..setPriority(TicketPriority.high)
      ..setSubject('  Charged twice  ')
      ..setDescription('I was charged twice for the same appointment today.');

    final failure = await form().submit();

    expect(failure, isNull);
    final sent = repository.created.single;
    expect(sent.category, TicketCategory.billing);
    expect(sent.priority, TicketPriority.high);
    expect(sent.subject, 'Charged twice');
    final state = container.read(ticketFormControllerProvider);
    expect(state.created?.ticketNo, 'TKT-2026-0001');
    expect(state.isSending, isFalse);
    expect(
      container.read(supportTicketsProvider).value?.first.ticketNo,
      'TKT-2026-0001',
    );
  });

  // BL-SUP-006: files attached to the request go with it.
  test('the request carries its attached files', () async {
    form()
      ..setSubject('Charged twice')
      ..setDescription('I was charged twice for the same appointment today.');

    final failure = await form().submit(attachmentFileIds: ['f-1', 'f-2']);

    expect(failure, isNull);
    expect(repository.created.single.attachmentFileIds, ['f-1', 'f-2']);
  });

  // BL-SUP-005: the screen now starts a fresh form after a request is
  // raised, so pressing Send again cannot raise the same request twice.
  test('a fresh form after raising a request sends nothing', () async {
    final sub = container.listen(ticketFormControllerProvider, (_, _) {});
    form()
      ..setSubject('Charged twice')
      ..setDescription('I was charged twice for the same appointment today.');
    expect(await form().submit(), isNull);
    expect(repository.created, hasLength(1));

    container.invalidate(ticketFormControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(ticketFormControllerProvider).subject, isEmpty);

    expect(await form().submit(), isA<ValidationFailure>());
    expect(repository.created, hasLength(1), reason: 'no duplicate');
    sub.close();
  });

  test('server field errors land on the fields', () async {
    form()
      ..setSubject('Charged twice')
      ..setDescription('I was charged twice for the same appointment today.');
    repository.nextFailure = const ValidationFailure(
      apiCode: ApiErrorCodes.validationError,
      fieldErrors: {'category': '"nope" is not a valid choice.'},
    );

    final failure = await form().submit();

    expect(failure, isA<ValidationFailure>());
    expect(
      container
          .read(ticketFormControllerProvider)
          .errorFor(TicketFormField.category),
      contains('not a valid choice'),
    );
    expect(container.read(ticketFormControllerProvider).failure, isNull);
  });

  test('a non-field failure is kept on the form and returned', () async {
    form()
      ..setSubject('Charged twice')
      ..setDescription('I was charged twice for the same appointment today.');
    repository.nextFailure = const NetworkFailure();

    final failure = await form().submit();

    expect(failure, isA<NetworkFailure>());
    expect(
      container.read(ticketFormControllerProvider).failure,
      isA<NetworkFailure>(),
    );
    expect(container.read(ticketFormControllerProvider).created, isNull);
  });

  test('a reply appends to the thread and reopens a resolved ticket', () async {
    repository.detail = repository.detail.copyWith(
      status: TicketStatus.resolved,
    );
    container.listen<Object?>(supportTicketDetailProvider('t1'), (_, _) {});
    await settle();

    final failure = await container
        .read(ticketReplyControllerProvider('t1').notifier)
        .send('  Any update?  ');

    expect(failure, isNull);
    expect(repository.replies, [('t1', 'Any update?')]);
    final ticket = container.read(supportTicketDetailProvider('t1')).value!;
    expect(ticket.messages.map((m) => m.body), ['Any update?']);
    expect(ticket.status, TicketStatus.open);
  });

  test('a reply carries its attached files', () async {
    container.listen<Object?>(supportTicketDetailProvider('t1'), (_, _) {});
    await settle();

    await container
        .read(ticketReplyControllerProvider('t1').notifier)
        .send('Here is the receipt', attachmentFileIds: ['f-9']);

    expect(repository.replyAttachments, [
      ['f-9'],
    ]);
  });

  test('an empty reply is refused locally; a closed ticket is the server\'s '
      'STATE_CONFLICT', () async {
    container.listen<Object?>(supportTicketDetailProvider('t1'), (_, _) {});
    await settle();
    final notifier = container.read(
      ticketReplyControllerProvider('t1').notifier,
    );

    expect(await notifier.send('   '), isA<ValidationFailure>());
    expect(repository.replies, isEmpty);

    repository.nextFailure = const ConflictFailure(
      apiCode: ApiErrorCodes.stateConflict,
    );
    final failure = await notifier.send('Hello');
    expect(failure?.apiCode, ApiErrorCodes.stateConflict);
  });
}

class FakeSupportTicketRepository implements SupportTicketRepository {
  final List<NewTicket> created = <NewTicket>[];
  final List<(String, String)> replies = <(String, String)>[];
  Failure? nextFailure;
  List<SupportTicket> rows = const <SupportTicket>[];
  SupportTicket detail = SupportTicket(
    id: 't1',
    ticketNo: 'TKT-2026-0001',
    category: TicketCategory.technical,
    subject: 'Existing',
    description: 'Existing ticket.',
    priority: TicketPriority.normal,
    status: TicketStatus.open,
    createdAt: DateTime(2026, 9, 30),
    updatedAt: DateTime(2026, 9, 30),
  );

  CachedResult<T> _fresh<T>(T value) => CachedResult<T>(
    value: value,
    source: CacheSource.network,
    cachedAt: DateTime.now(),
  );

  Future<T> _answer<T>(T Function() value) async {
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
    return value();
  }

  @override
  Stream<CachedResult<List<SupportTicket>>> tickets({
    bool forceRefresh = false,
  }) => Stream.value(_fresh(rows));

  @override
  Stream<CachedResult<SupportTicket>> ticket(
    String id, {
    bool forceRefresh = false,
  }) => Stream.value(_fresh(detail));

  @override
  Future<SupportTicket> create(NewTicket ticket) {
    created.add(ticket);
    return _answer(
      () => SupportTicket(
        id: 't${created.length}',
        ticketNo: 'TKT-2026-000${created.length}',
        category: ticket.category,
        subject: ticket.subject,
        description: ticket.description,
        priority: ticket.priority ?? TicketPriority.normal,
        status: TicketStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  final List<List<String>> replyAttachments = <List<String>>[];

  @override
  Future<TicketMessage> reply(
    String ticketId,
    String body, {
    List<String> attachmentFileIds = const <String>[],
  }) => _answer(() {
    replies.add((ticketId, body));
    replyAttachments.add(attachmentFileIds);
    return TicketMessage(
      id: 'm${replies.length}',
      authorKind: 'requester',
      authorName: 'Anita Menon',
      body: body,
      occurredAt: DateTime.now(),
    );
  });
}
