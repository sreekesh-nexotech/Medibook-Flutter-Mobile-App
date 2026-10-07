import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/support/domain/entities/support_ticket.dart';
import 'package:medibook/features/support/infrastructure/repositories/support_mappers.dart';
import 'package:medibook/features/support/presentation/components/legal_prose.dart';
import 'package:medibook/features/support/application/providers/faq_controller.dart';

/// Wire → entity for §3, §13 and §14, against the shapes the live backend
/// returned during verification, plus the Markdown subset renderer.
void main() {
  group('app-config (§3.1)', () {
    test('maps every section', () {
      final config = SupportMappers.appConfig(const {
        'min_versions': {'android': '1.0.0', 'ios': null},
        'feature_flags_public': {
          'patient_app.insurance': true,
          'patient_app.reviews': false,
        },
        'otp_length': 4,
        'support_contacts': {'phone_e164': '+914847100000'},
        'legal_versions': {'terms': 1, 'privacy': 1, 'guidelines': 1},
      });
      expect(config.minVersionAndroid, '1.0.0');
      expect(config.minVersionIos, isNull);
      expect(config.flag('patient_app.insurance'), isTrue);
      expect(config.flag('patient_app.reviews'), isFalse);
      expect(config.flag('missing'), isFalse);
      expect(config.otpLength, 4);
      expect(config.supportContacts.phoneE164, '+914847100000');
      expect(config.supportContacts.isEmpty, isFalse);
      expect(config.legalVersion('terms'), 1);
      expect(config.legalVersion('refunds'), isNull);
    });

    test('tolerates an empty support_contacts and missing flags', () {
      final config = SupportMappers.appConfig(const {
        'otp_length': 6,
        'support_contacts': {},
      });
      expect(config.otpLength, 6);
      expect(config.supportContacts.isEmpty, isTrue);
      expect(config.featureFlags, isEmpty);
      expect(config.legalVersions, isEmpty);
    });

    // BB-28: the server does not send it yet; the app falls back to the
    // platform default (30) until it does, and uses the server's value once
    // it is there.
    test('reads dsr_cooling_off_days when present, ignores it otherwise', () {
      expect(
        SupportMappers.appConfig(const {
          'dsr_cooling_off_days': 14,
        }).deletionCoolingOffDays,
        14,
      );
      expect(SupportMappers.appConfig(const {}).deletionCoolingOffDays, isNull);
      expect(
        SupportMappers.appConfig(const {
          'dsr_cooling_off_days': 0,
        }).deletionCoolingOffDays,
        isNull,
      );
    });

    // BB-38: the upload cap is a platform setting too.
    test('reads upload_max_bytes when present, ignores it otherwise', () {
      expect(
        SupportMappers.appConfig(const {
          'upload_max_bytes': 20971520,
        }).uploadMaxBytes,
        20971520,
      );
      expect(SupportMappers.appConfig(const {}).uploadMaxBytes, isNull);
      expect(
        SupportMappers.appConfig(const {'upload_max_bytes': -1}).uploadMaxBytes,
        isNull,
      );
    });
  });

  group('FAQ topics (Profile and Help & Support summaries)', () {
    test('names the live categories in order, once each', () {
      expect(
        faqTopicsLabel(['account', 'booking', 'payments', 'tokens']),
        'Account, booking, payments and tokens',
      );
      expect(faqTopicsLabel(['booking', 'payments']), 'Booking and payments');
      expect(faqTopicsLabel(['account']), 'Account');
      expect(faqTopicsLabel(['account', 'account']), 'Account');
      expect(faqTopicsLabel(['feature_request']), 'Feature request');
    });

    test('is null when there is nothing to name', () {
      expect(faqTopicsLabel(const []), isNull);
    });
  });

  group('legal (§3.2)', () {
    test('maps a published document', () {
      final doc = SupportMappers.legalDocument(const {
        'slug': 'terms',
        'version': 1,
        'title': 'Terms of Service',
        'body_md': '# Terms of Service\n\nDemo terms for the Medibook app.',
        'published_at': '2026-07-31T04:00:00.045861+00:00',
      });
      expect(doc.slug, 'terms');
      expect(doc.version, 1);
      expect(doc.title, 'Terms of Service');
      expect(doc.publishedAt, isNotNull);
    });

    test('a body without body_md throws so nothing is cached', () {
      expect(
        () => SupportMappers.legalDocument(const {'slug': 'terms'}),
        throwsA(isA<ResponseFormatException>()),
      );
    });
  });

  group('faqs (§3.3)', () {
    test('maps categories and sorts entries by sort_order', () {
      final categories = SupportMappers.faqs(const {
        'categories': [
          {
            'category': 'booking',
            'entries': [
              {
                'id': 'b',
                'question': 'Can I reschedule?',
                'answer_md': 'No.',
                'sort_order': 1,
              },
              {
                'id': 'a',
                'question': 'How do I book?',
                'answer_md': 'Pick a slot.',
                'sort_order': 0,
              },
            ],
          },
        ],
      });
      expect(categories, hasLength(1));
      expect(categories.single.category, 'booking');
      expect(categories.single.entries.map((e) => e.id), ['a', 'b']);
      expect(categories.single.entries.first.category, 'booking');
    });

    test('category titles are humanised', () {
      expect(faqCategoryTitle('booking'), 'Booking');
      expect(faqCategoryTitle('feature_request'), 'Feature request');
      expect(faqCategoryTitle(''), 'General');
    });
  });

  group('ambulance (§14)', () {
    test('maps the page with nullable extras', () {
      final providers = SupportMappers.ambulanceProviders(const {
        'results': [
          {
            'id': 'p1',
            'name': 'Lifeline Ambulance Kochi',
            'phone_e164': '+914842660000',
            'eta_minutes': 12,
            'service_area': 'Kadavanthra, Kochi',
            'city': 'Kochi',
            'area': 'Kadavanthra',
          },
          {'id': 'p2', 'name': 'Bare', 'phone_e164': '+910000000000'},
        ],
        'page': 1,
        'page_size': 25,
        'total': 2,
        'has_next': false,
      });
      expect(providers, hasLength(2));
      expect(providers.first.etaLabel, '~12 min');
      expect(providers.first.localityLabel, 'Kadavanthra, Kochi');
      expect(providers.last.etaLabel, isNull);
      expect(providers.last.localityLabel, '');
    });
  });

  group('tickets (§13)', () {
    const detail = {
      'id': 't1',
      'ticket_no': 'TKT-2026-0019',
      'raised_by_kind': 'patient',
      'hospital_id': null,
      'category': 'technical',
      'subject': 'Integration test ticket',
      'description': 'Created by the probe.',
      'priority': 'low',
      'status': 'open',
      'resolved_at': null,
      'closed_at': null,
      'created_at': '2026-09-30T08:08:09.916272Z',
      'updated_at': '2026-09-30T08:09:11.325564Z',
      'version': 1,
      'messages': [
        {
          'id': 'm1',
          'author_kind': 'requester',
          'author_name': 'Anita Menon',
          'body': 'Any update?',
          'attachment_file_ids': [],
          'occurred_at': '2026-09-30T08:09:11.301584Z',
        },
      ],
    };

    test('maps a detail with messages', () {
      final ticket = SupportMappers.ticketFromBody(detail);
      expect(ticket.ticketNo, 'TKT-2026-0019');
      expect(ticket.category, TicketCategory.technical);
      expect(ticket.priority, TicketPriority.low);
      expect(ticket.status, TicketStatus.open);
      expect(ticket.canReply, isTrue);
      expect(ticket.messages.single.isMine, isTrue);
      expect(ticket.messages.single.body, 'Any update?');
    });

    test('a closed ticket cannot be replied to', () {
      final ticket = SupportMappers.ticketFromBody({
        ...detail,
        'status': 'closed',
        'messages': const [],
      });
      expect(ticket.status, TicketStatus.closed);
      expect(ticket.canReply, isFalse);
      expect(ticket.status.isOpen, isFalse);
    });

    test('a row without ticket_no throws', () {
      expect(
        () => SupportMappers.ticket(const {'id': 'x'}),
        throwsA(isA<ResponseFormatException>()),
      );
    });
  });

  group('LegalProseParser (Markdown subset)', () {
    test('renders # and ## as headings, - and * as bullets, and unwraps', () {
      final blocks = LegalProseParser.parse(
        '# Terms of Service\n\n'
        'Demo terms for the\nMedibook app.\n\n'
        '## Your account\n'
        '- You must be **18 or older**.\n'
        '* Be kind.\n',
      );
      expect(blocks.map((b) => b.kind), [
        ProseBlockKind.heading,
        ProseBlockKind.paragraph,
        ProseBlockKind.heading,
        ProseBlockKind.bullet,
        ProseBlockKind.bullet,
      ]);
      expect(blocks[0].plainText, 'Terms of Service');
      expect(blocks[1].plainText, 'Demo terms for the Medibook app.');
      expect(
        blocks[3].runs.any((r) => r.isBold && r.text == '18 or older'),
        isTrue,
      );
    });
  });
}
