import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/endpoints.dart';
import '../../../domain/entities/support_ticket.dart';

/// The support-ticket endpoints (§13): cacheable reads as request
/// descriptions (performed by the cache layer), mutations performed here over
/// [ApiClient] and returned as decoded JSON. No mapping, no caching, no
/// `try`/`catch` — errors reach the repository as `NetworkException`s.
abstract interface class SupportTicketApi {
  /// `GET /patient/support/tickets?sort=-created_at`.
  ApiRequest tickets();

  /// `GET /patient/support/tickets/{id}`.
  ApiRequest ticket(String id);

  /// `POST /patient/support/tickets` → 201.
  Future<Map<String, Object?>> create(NewTicket ticket);

  /// `POST /patient/support/tickets/{id}/messages` → 201.
  Future<Map<String, Object?>> reply(
    String ticketId,
    String body, {
    List<String> attachmentFileIds = const <String>[],
  });
}

class HttpSupportTicketApi implements SupportTicketApi {
  const HttpSupportTicketApi(this._client);

  final ApiClient _client;

  @override
  ApiRequest tickets() => const ApiRequest(
    path: Endpoints.supportTickets,
    query: {'sort': '-created_at', 'page_size': 100},
  );

  @override
  ApiRequest ticket(String id) => ApiRequest(path: Endpoints.supportTicket(id));

  @override
  Future<Map<String, Object?>> create(NewTicket ticket) async {
    final response = await _client.post(
      Endpoints.supportTickets,
      body: {
        'category': ticket.category.wire,
        'subject': ticket.subject,
        'description': ticket.description,
        if (ticket.priority != null) 'priority': ticket.priority!.wire,
        if (ticket.attachmentFileIds.isNotEmpty)
          'attachment_file_ids': ticket.attachmentFileIds,
      },
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> reply(
    String ticketId,
    String body, {
    List<String> attachmentFileIds = const <String>[],
  }) async {
    final response = await _client.post(
      Endpoints.supportTicketMessages(ticketId),
      body: {'body': body, 'attachment_file_ids': attachmentFileIds},
    );
    return response.requireMap;
  }
}
