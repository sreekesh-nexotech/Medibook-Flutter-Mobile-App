import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../domain/entities/ambulance_provider.dart';
import '../../domain/entities/app_config.dart';
import '../../domain/entities/faq.dart';
import '../../domain/entities/legal_document.dart';
import '../../domain/entities/support_ticket.dart';

/// Wire → entity for §3, §13 and §14. The only file in the support feature
/// that spells a JSON key.
///
/// Every mapper is the Scenario-10 validation gate for its endpoint: a body
/// without the fields the entity needs throws [ResponseFormatException], and
/// the fetcher then caches nothing.
abstract final class SupportMappers {
  SupportMappers._();

  // ---- §3.1 ----

  static AppConfig appConfig(Object? json) {
    final map = _requireMap(json, 'app-config');
    final versions = map['min_versions'];
    final flags = map['feature_flags_public'];
    final contacts = map['support_contacts'];
    final legal = map['legal_versions'];
    final coolingOff = map['dsr_cooling_off_days'];
    final uploadMax = map['upload_max_bytes'];
    return AppConfig(
      minVersionAndroid: versions is Map
          ? versions['android'] as String?
          : null,
      minVersionIos: versions is Map ? versions['ios'] as String? : null,
      featureFlags: flags is Map
          ? {
              for (final entry in flags.entries)
                entry.key.toString(): entry.value == true,
            }
          : const <String, bool>{},
      otpLength: (map['otp_length'] as num?)?.toInt() ?? 4,
      supportContacts: SupportContacts(
        phoneE164: contacts is Map ? contacts['phone_e164'] as String? : null,
        email: contacts is Map ? contacts['email'] as String? : null,
      ),
      legalVersions: legal is Map
          ? {
              for (final entry in legal.entries)
                if (entry.value is num)
                  entry.key.toString(): (entry.value as num).toInt(),
            }
          : const <String, int>{},
      // Not sent by the server yet (BB-28); a non-positive value is ignored.
      deletionCoolingOffDays: coolingOff is num && coolingOff > 0
          ? coolingOff.toInt()
          : null,
      // Not sent by the server yet either (BB-38).
      uploadMaxBytes: uploadMax is num && uploadMax > 0
          ? uploadMax.toInt()
          : null,
    );
  }

  // ---- §3.2 ----

  static LegalDocument legalDocument(Object? json) {
    final map = _requireMap(json, 'legal document');
    final slug = map['slug'];
    final body = map['body_md'];
    if (slug is! String || body is! String) {
      throw const ResponseFormatException(
        message: 'legal document has no slug/body_md',
      );
    }
    return LegalDocument(
      slug: slug,
      version: (map['version'] as num?)?.toInt() ?? 0,
      title: map['title']?.toString() ?? slug,
      bodyMd: body,
      publishedAt: _dateTime(map['published_at']),
    );
  }

  // ---- §3.3 ----

  static List<FaqCategory> faqs(Object? json) {
    final map = _requireMap(json, 'faqs');
    final categories = map['categories'];
    if (categories is! List) {
      throw const ResponseFormatException(message: 'faqs has no categories[]');
    }
    return [
      for (final raw in categories)
        if (raw is Map) _faqCategory(raw.cast<String, Object?>()),
    ];
  }

  static FaqCategory _faqCategory(Map<String, Object?> map) {
    final category = map['category']?.toString() ?? '';
    final entries = map['entries'];
    final parsed = <FaqEntry>[
      if (entries is List)
        for (final raw in entries)
          if (raw is Map) _faqEntry(raw.cast<String, Object?>(), category),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return FaqCategory(category: category, entries: parsed);
  }

  static FaqEntry _faqEntry(Map<String, Object?> map, String category) {
    final id = map['id'];
    final question = map['question'];
    if (id is! String || question is! String) {
      throw const ResponseFormatException(
        message: 'faq entry has no id/question',
      );
    }
    return FaqEntry(
      id: id,
      question: question,
      answerMd: map['answer_md']?.toString() ?? '',
      category: category,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  // ---- §14 ----

  static List<AmbulanceProvider> ambulanceProviders(Object? json) =>
      Page.parse(json, ambulanceProvider).results;

  static AmbulanceProvider ambulanceProvider(Map<String, Object?> map) {
    final id = map['id'];
    final name = map['name'];
    final phone = map['phone_e164'];
    if (id is! String || name is! String || phone is! String) {
      throw const ResponseFormatException(
        message: 'ambulance provider has no id/name/phone_e164',
      );
    }
    return AmbulanceProvider(
      id: id,
      name: name,
      phoneE164: phone,
      etaMinutes: (map['eta_minutes'] as num?)?.toInt(),
      serviceArea: map['service_area'] as String?,
      city: map['city'] as String?,
      area: map['area'] as String?,
    );
  }

  // ---- §13 ----

  static List<SupportTicket> tickets(Object? json) =>
      Page.parse(json, ticket).results;

  static SupportTicket ticketFromBody(Object? json) =>
      ticket(_requireMap(json, 'ticket'));

  static SupportTicket ticket(Map<String, Object?> map) {
    final id = map['id'];
    final ticketNo = map['ticket_no'];
    if (id is! String || ticketNo is! String) {
      throw const ResponseFormatException(
        message: 'ticket has no id/ticket_no',
      );
    }
    final messages = map['messages'];
    return SupportTicket(
      id: id,
      ticketNo: ticketNo,
      category: TicketCategory.fromWire(map['category'] as String?),
      subject: map['subject']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      priority: TicketPriority.fromWire(map['priority'] as String?),
      status: TicketStatus.fromWire(map['status'] as String?),
      createdAt: _dateTime(map['created_at']) ?? DateTime.now(),
      updatedAt: _dateTime(map['updated_at']) ?? DateTime.now(),
      resolvedAt: _dateTime(map['resolved_at']),
      closedAt: _dateTime(map['closed_at']),
      version: (map['version'] as num?)?.toInt() ?? 1,
      messages: [
        if (messages is List)
          for (final raw in messages)
            if (raw is Map) message(raw.cast<String, Object?>()),
      ],
    );
  }

  static TicketMessage messageFromBody(Object? json) =>
      message(_requireMap(json, 'ticket message'));

  static TicketMessage message(Map<String, Object?> map) {
    final id = map['id'];
    if (id is! String) {
      throw const ResponseFormatException(message: 'message has no id');
    }
    final attachments = map['attachment_file_ids'];
    return TicketMessage(
      id: id,
      authorKind: map['author_kind']?.toString() ?? 'requester',
      authorName: map['author_name']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      occurredAt: _dateTime(map['occurred_at']) ?? DateTime.now(),
      attachmentFileIds: attachments is List
          ? [for (final a in attachments) a.toString()]
          : const <String>[],
    );
  }

  // ---- helpers ----

  static Map<String, Object?> _requireMap(Object? json, String what) {
    if (json is Map) return json.cast<String, Object?>();
    throw ResponseFormatException(
      message: 'expected a $what object, got ${json.runtimeType}',
    );
  }

  static DateTime? _dateTime(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
}
