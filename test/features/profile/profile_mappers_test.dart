import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/profile/application/providers/profile_provider.dart';
import 'package:medibook/features/profile/domain/entities/account.dart';
import 'package:medibook/features/profile/domain/entities/person.dart';
import 'package:medibook/features/profile/infrastructure/repositories/profile_mappers.dart';

/// Wire → entity for §4.9, §5.6, §5.9 and §6, against the shapes the live
/// backend returned during verification.
void main() {
  group('persons (§6.1)', () {
    const page = {
      'results': [
        {
          'id': '01a0f15b-4563-7be1-a6ab-2cff2f8f3165',
          'is_self': false,
          'first_name': 'Test',
          'last_name': 'Dependant',
          'relation': 'other',
          'date_of_birth': '2015-03-02',
          'gender': 'male',
          'blood_group': 'B+',
          'allergies': ['Peanuts'],
          'phone_e164': null,
          'guardian_note': 'note',
          'version': 2,
          'created_at': '2026-09-30T08:08:05.732089Z',
          'updated_at': '2026-09-30T08:09:05.945294Z',
        },
      ],
      'page': 1,
      'page_size': 25,
      'total': 1,
      'has_next': false,
    };

    test('maps the page and every field', () {
      final persons = ProfileMappers.persons(page);
      expect(persons, hasLength(1));
      final p = persons.single;
      expect(p.id, '01a0f15b-4563-7be1-a6ab-2cff2f8f3165');
      expect(p.isSelf, isFalse);
      expect(p.name, 'Test Dependant');
      expect(p.relation, PersonRelation.other);
      expect(p.dateOfBirth, DateTime(2015, 3, 2));
      expect(p.gender, Gender.male);
      expect(p.bloodGroup, 'B+');
      expect(p.allergies, ['Peanuts']);
      expect(p.phoneE164, isNull);
      expect(p.guardianNote, 'note');
      expect(p.version, 2);
      expect(p.isMinor, isTrue);
      expect(p.canBeReleased, isFalse);
    });

    test('an empty page is an empty list, not an error', () {
      expect(
        ProfileMappers.persons(const {
          'results': [],
          'page': 1,
          'page_size': 25,
          'total': 0,
          'has_next': false,
        }),
        isEmpty,
      );
    });

    test('a row without id/first_name throws so nothing is cached', () {
      expect(
        () => ProfileMappers.person(const {'relation': 'child'}),
        throwsA(isA<ResponseFormatException>()),
      );
    });

    test('an unknown relation falls back to other', () {
      expect(PersonRelation.fromWire('cousin'), PersonRelation.other);
    });
  });

  group('relation labels', () {
    test('are derived from relation + gender', () {
      expect(PersonRelation.child.labelFor(Gender.female), 'Daughter');
      expect(PersonRelation.child.labelFor(Gender.male), 'Son');
      expect(PersonRelation.parent.labelFor(Gender.female), 'Mother');
      expect(PersonRelation.spouse.labelFor(Gender.male), 'Husband');
      expect(PersonRelation.sibling.labelFor(null), 'Sibling');
      expect(PersonRelation.other.labelFor(Gender.female), 'Other');
    });

    test('self is never offered for a dependant', () {
      expect(PersonRelation.selectable, isNot(contains(PersonRelation.self)));
      expect(PersonRelation.selectable, hasLength(5));
    });
  });

  group('addresses (§6.2) and contacts (§6.3)', () {
    test('maps an address with its default flag and version', () {
      final a = ProfileMappers.address(const {
        'id': 'a1',
        'label': 'Home 2',
        'address_line1': '12 MG Road',
        'address_line2': null,
        'address_line3': null,
        'city': 'Kochi',
        'state': 'Kerala',
        'pincode': '682001',
        'phone_e164': null,
        'is_default': true,
        'created_at': '2026-09-30T08:08:00.458217+00:00',
        'version': 2,
      });
      expect(a.label, 'Home 2');
      expect(a.isDefault, isTrue);
      expect(a.version, 2);
      expect(a.lines, ['12 MG Road', 'Kochi, Kerala 682001']);
    });

    test('maps a contact', () {
      final c = ProfileMappers.contact(const {
        'id': 'c1',
        'name': 'Ravi Nair',
        'relation': 'Spouse',
        'phone_e164': '+919800000000',
        'is_primary': true,
        'created_at': '2026-09-30T08:08:04.347756+00:00',
        'version': 2,
      });
      expect(c.name, 'Ravi Nair');
      expect(c.isPrimary, isTrue);
      expect(c.version, 2);
    });
  });

  group('account (§4.9, §5.6, §5.9)', () {
    test('maps a session and derives the device label', () {
      final s = ProfileMappers.session(const {
        'id': 's1',
        'principal': 'patient',
        'device_id': null,
        'user_agent': 'Medibook/1.0 (Android 14)',
        'ip': '203.0.113.7',
        'created_at': '2026-09-30T08:07:17.880036Z',
        'last_seen_at': '2026-09-30T08:07:17.879853Z',
        'absolute_expires_at': '2026-10-30T08:07:17.879853Z',
        'current': true,
      });
      expect(s.isCurrent, isTrue);
      expect(s.deviceLabel, 'Android 14');
      expect(s.lastSeenAt, isNotNull);
    });

    test('names the phone and build from the app user agent', () {
      AccountSession withAgent(String? ua) =>
          AccountSession(id: 's', isCurrent: false, userAgent: ua);

      final current = withAgent('Medibook/1.0.0 (Google Pixel 7; Android 14)');
      expect(current.deviceLabel, 'Google Pixel 7 · Android 14');
      expect(current.appVersionLabel, 'Medibook 1.0.0');

      // Signed in before the app named its device: no fake version.
      final old = withAgent('Medibook/1.0');
      expect(old.deviceLabel, 'Medibook app');
      expect(old.appVersionLabel, isNull);

      // Other clients are shown as they were sent.
      final script = withAgent('Python-urllib/3.9');
      expect(script.deviceLabel, 'Python-urllib/3.9');
      expect(script.appVersionLabel, isNull);
      expect(withAgent(null).deviceLabel, 'Unknown device');
    });

    test('maps a deletion request and knows when it is open', () {
      final r = ProfileMappers.deletionRequest(const {
        'request_no': 'DSR-2026-000012',
        'kind': 'deletion',
        'status': 'cooling_off',
        'requested_at': '2026-09-30T10:00:00Z',
        'cooling_off_ends_at': '2026-10-30T10:00:00Z',
        'completed_at': null,
      });
      expect(r.requestNo, 'DSR-2026-000012');
      expect(r.status, DeletionStatus.coolingOff);
      expect(r.isOpen, isTrue);
      expect(
        ProfileMappers.deletionRequest(const {
          'request_no': 'x',
          'status': 'withdrawn',
          'requested_at': '2026-09-30T10:00:00Z',
        }).isOpen,
        isFalse,
      );
    });

    test('maps a consent', () {
      final c = ProfileMappers.consent(const {
        'id': 'k1',
        'document_slug': 'terms',
        'document_version': 1,
        'accepted_at': '2026-09-30T08:08:08.299478+00:00',
      });
      expect(c.documentSlug, 'terms');
      expect(c.documentVersion, 1);
    });
  });

  group('pendingConsentsFor', () {
    test('lists documents never accepted or accepted at an older version', () {
      final pending = pendingConsentsFor(
        versions: const {'terms': 3, 'privacy': 2, 'guidelines': 1},
        accepted: [
          Consent(
            id: '1',
            documentSlug: 'terms',
            documentVersion: 2,
            acceptedAt: DateTime(2026),
          ),
          Consent(
            id: '2',
            documentSlug: 'privacy',
            documentVersion: 2,
            acceptedAt: DateTime(2026),
          ),
        ],
      );
      expect(pending.map((p) => p.slug), ['terms', 'guidelines']);
      expect(pending.first.acceptedVersion, 2);
      expect(pending.first.currentVersion, 3);
      expect(pending.last.isFirstAcceptance, isTrue);
    });

    test('is empty when everything current is accepted', () {
      expect(
        pendingConsentsFor(
          versions: const {'terms': 1},
          accepted: [
            Consent(
              id: '1',
              documentSlug: 'terms',
              documentVersion: 1,
              acceptedAt: DateTime(2026),
            ),
          ],
        ),
        isEmpty,
      );
    });
  });
}
