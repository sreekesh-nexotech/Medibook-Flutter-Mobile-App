import '../../../../core/storage/cache/cached_result.dart';
import '../entities/support_ticket.dart';

/// Support tickets (§13). Reads are cached; mutations invalidate.
abstract interface class SupportTicketRepository {
  /// `GET /patient/support/tickets` — newest first, no messages.
  Stream<CachedResult<List<SupportTicket>>> tickets({
    bool forceRefresh = false,
  });

  /// `GET /patient/support/tickets/{id}` — with messages.
  Stream<CachedResult<SupportTicket>> ticket(
    String id, {
    bool forceRefresh = false,
  });

  /// `POST /patient/support/tickets` → **201** the created ticket.
  Future<SupportTicket> create(NewTicket ticket);

  /// `POST /patient/support/tickets/{id}/messages` → **201** the message.
  /// `409 STATE_CONFLICT` on a closed ticket. [attachmentFileIds]: up to
  /// five clean `ticket_attachment` files.
  Future<TicketMessage> reply(
    String ticketId,
    String body, {
    List<String> attachmentFileIds = const <String>[],
  });
}
