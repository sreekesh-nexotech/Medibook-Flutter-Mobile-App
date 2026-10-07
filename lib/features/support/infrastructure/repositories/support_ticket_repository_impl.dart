import '../../../../core/network/endpoints.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/repositories/support_ticket_repository.dart';
import '../data_sources/remote/support_ticket_api.dart';
import 'support_mappers.dart';

/// [SupportTicketRepository]: cached reads through [CachedFetcher], mutations
/// through the API followed by a cache invalidation so the next list read is
/// fresh. Every throw is a `Failure`.
class SupportTicketRepositoryImpl implements SupportTicketRepository {
  const SupportTicketRepositoryImpl({
    required SupportTicketApi api,
    required CachedFetcher fetcher,
  }) : _api = api,
       _fetcher = fetcher;

  final SupportTicketApi _api;
  final CachedFetcher _fetcher;

  @override
  Stream<CachedResult<List<SupportTicket>>> tickets({
    bool forceRefresh = false,
  }) => _fetcher
      .fetch(_api.tickets(), SupportMappers.tickets, forceRefresh: forceRefresh)
      .handleError(_rethrowAsFailure);

  @override
  Stream<CachedResult<SupportTicket>> ticket(
    String id, {
    bool forceRefresh = false,
  }) => _fetcher
      .fetch(
        _api.ticket(id),
        SupportMappers.ticketFromBody,
        forceRefresh: forceRefresh,
      )
      .handleError(_rethrowAsFailure);

  @override
  Future<SupportTicket> create(NewTicket ticket) async {
    final created = await _run(
      () async => SupportMappers.ticketFromBody(await _api.create(ticket)),
    );
    await _fetcher.invalidate(pathPrefix: Endpoints.supportTickets);
    return created;
  }

  @override
  Future<TicketMessage> reply(
    String ticketId,
    String body, {
    List<String> attachmentFileIds = const <String>[],
  }) async {
    final message = await _run(
      () async => SupportMappers.messageFromBody(
        await _api.reply(ticketId, body, attachmentFileIds: attachmentFileIds),
      ),
    );
    await _fetcher.invalidate(pathPrefix: Endpoints.supportTicket(ticketId));
    return message;
  }

  Future<T> _run<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (error, stackTrace) {
      throw NetworkExceptions.toFailure(error, stackTrace);
    }
  }

  static void _rethrowAsFailure(Object error, StackTrace stackTrace) =>
      throw NetworkExceptions.toFailure(error, stackTrace);
}
