import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/auth/application/providers/auth_provider.dart';
import 'package:medibook/features/profile/application/providers/profile_mutations_provider.dart';
import 'package:medibook/features/profile/application/providers/profile_provider.dart';
import 'package:medibook/features/profile/domain/entities/address.dart';
import 'package:medibook/features/profile/domain/entities/emergency_contact.dart';
import 'package:medibook/features/profile/domain/entities/person.dart';

import 'profile_test_support.dart';

/// The cached lists (§6) and their mutation controllers.
void main() {
  late FakeAuthRepository auth;

  setUp(() {
    auth = FakeAuthRepository();
  });

  group('personsProvider', () {
    test(
      'loads through the repository and publishes the self person id',
      () async {
        final family = FakeFamilyRepository(
          rows: const [
            Person(
              id: 'self-1',
              firstName: 'Anita',
              relation: PersonRelation.self,
              isSelf: true,
            ),
            Person(
              id: 'kid-1',
              firstName: 'Arjun',
              relation: PersonRelation.child,
            ),
          ],
        );
        final container = await authenticatedContainer(
          auth: auth,
          family: family,
        );
        addTearDown(container.dispose);

        container.read(personsProvider);
        await settle();

        final state = container.read(personsProvider);
        expect(state.isLoading, isFalse);
        expect(state.value, hasLength(2));
        expect(container.read(selfPersonProvider)?.id, 'self-1');
        expect(container.read(dependantsProvider).single.id, 'kid-1');
        expect(container.read(selfPersonIdProvider), 'self-1');
      },
    );

    test(
      'an account with no self person publishes null (test account)',
      () async {
        final family = FakeFamilyRepository(
          rows: const [
            Person(
              id: 'kid-1',
              firstName: 'Arjun',
              relation: PersonRelation.child,
            ),
          ],
        );
        final container = await authenticatedContainer(
          auth: auth,
          family: family,
        );
        addTearDown(container.dispose);

        container.read(personsProvider);
        await settle();

        expect(container.read(selfPersonProvider), isNull);
        expect(container.read(selfPersonIdProvider), isNull);
        expect(container.read(dependantsProvider), hasLength(1));
      },
    );
  });

  group('PersonMutationController', () {
    test('create appends the returned row to the list', () async {
      final family = FakeFamilyRepository();
      final container = await authenticatedContainer(
        auth: auth,
        family: family,
      );
      addTearDown(container.dispose);
      container.read(personsProvider);
      await settle();

      final failure = await container
          .read(personMutationControllerProvider.notifier)
          .create(
            PersonDraft(
              firstName: 'Arjun',
              relation: PersonRelation.child,
              dateOfBirth: DateTime(2015, 3, 2),
              gender: Gender.male,
            ),
          );

      expect(failure, isNull);
      expect(family.drafts.single.relation, PersonRelation.child);
      expect(container.read(personsProvider).value?.single.name, 'Arjun');
    });

    test('update sends If-Match and replaces the row', () async {
      final family = FakeFamilyRepository(
        rows: const [
          Person(
            id: 'kid-1',
            firstName: 'Arjun',
            relation: PersonRelation.child,
            version: 3,
          ),
        ],
      );
      final container = await authenticatedContainer(
        auth: auth,
        family: family,
      );
      addTearDown(container.dispose);
      container.read(personsProvider);
      await settle();

      final failure = await container
          .read(personMutationControllerProvider.notifier)
          .update('kid-1', const PersonDraft(bloodGroup: 'B+'), ifMatch: 3);

      expect(failure, isNull);
      expect(family.ifMatches, [3]);
      final row = container.read(personsProvider).value?.single;
      expect(row?.bloodGroup, 'B+');
      expect(row?.version, 4);
    });

    test('delete surfaces PERSON_HAS_APPOINTMENTS and keeps the row', () async {
      final family = FakeFamilyRepository(
        rows: const [
          Person(
            id: 'kid-1',
            firstName: 'Arjun',
            relation: PersonRelation.child,
          ),
        ],
      );
      final container = await authenticatedContainer(
        auth: auth,
        family: family,
      );
      addTearDown(container.dispose);
      container.read(personsProvider);
      await settle();
      family.nextFailure = const ConflictFailure(
        apiCode: ApiErrorCodes.personHasAppointments,
      );

      final failure = await container
          .read(personMutationControllerProvider.notifier)
          .delete('kid-1');

      expect(failure?.apiCode, ApiErrorCodes.personHasAppointments);
      expect(container.read(personsProvider).value, hasLength(1));
    });

    test('a stale If-Match reloads the list and asks for a retry', () async {
      final family = FakeFamilyRepository(
        rows: const [
          Person(
            id: 'kid-1',
            firstName: 'Arjun',
            relation: PersonRelation.child,
            version: 1,
          ),
        ],
      );
      final container = await authenticatedContainer(
        auth: auth,
        family: family,
      );
      addTearDown(container.dispose);
      container.read(personsProvider);
      await settle();
      family.nextFailure = const ConflictFailure(
        apiCode: ApiErrorCodes.conflictVersion,
        meta: {'current': 2},
      );
      family.rows = const [
        Person(
          id: 'kid-1',
          firstName: 'Arjun',
          relation: PersonRelation.child,
          version: 2,
        ),
      ];

      final failure = await container
          .read(personMutationControllerProvider.notifier)
          .update('kid-1', const PersonDraft(bloodGroup: 'B+'), ifMatch: 1);

      expect(failure?.apiCode, ApiErrorCodes.conflictVersion);
      expect(failure?.userMessage, contains('reloaded'));
      await settle();
      expect(container.read(personsProvider).value?.single.version, 2);
    });
  });

  group('addresses and contacts', () {
    test('creating the first address makes it the default', () async {
      final contacts = FakeContactsRepository();
      final container = await authenticatedContainer(
        auth: auth,
        contacts: contacts,
      );
      addTearDown(container.dispose);
      keepAlive(container, addressesProvider);
      await settle();

      final failure = await container
          .read(addressMutationControllerProvider.notifier)
          .create(
            const AddressDraft(
              label: 'Home',
              addressLine1: '12 MG Road',
              city: 'Kochi',
              state: 'Kerala',
              pincode: '682001',
            ),
          );

      expect(failure, isNull);
      expect(container.read(defaultAddressProvider)?.label, 'Home');
    });

    test('setDefault leaves exactly one default', () async {
      final contacts = FakeContactsRepository()
        ..addressRows = const [
          Address(
            id: 'a1',
            label: 'Home',
            addressLine1: '1',
            city: 'Kochi',
            state: 'Kerala',
            pincode: '682001',
            isDefault: true,
          ),
          Address(
            id: 'a2',
            label: 'Work',
            addressLine1: '2',
            city: 'Kochi',
            state: 'Kerala',
            pincode: '682002',
          ),
        ];
      final container = await authenticatedContainer(
        auth: auth,
        contacts: contacts,
      );
      addTearDown(container.dispose);
      keepAlive(container, addressesProvider);
      await settle();

      await container
          .read(addressMutationControllerProvider.notifier)
          .setDefault('a2');

      final rows = container.read(addressesProvider).value!;
      expect(rows.where((a) => a.isDefault).map((a) => a.id), ['a2']);
    });

    test('the primary contact is what the ambulance screen reads', () async {
      final contacts = FakeContactsRepository()
        ..contactRows = const [
          EmergencyContact(
            id: 'c1',
            name: 'Ravi',
            relation: 'Husband',
            phoneE164: '+919800000000',
            isPrimary: true,
          ),
          EmergencyContact(
            id: 'c2',
            name: 'Maya',
            relation: 'Sister',
            phoneE164: '+919800000001',
          ),
        ];
      final container = await authenticatedContainer(
        auth: auth,
        contacts: contacts,
      );
      addTearDown(container.dispose);
      keepAlive(container, emergencyContactsProvider);
      await settle();

      expect(container.read(primaryEmergencyContactProvider)?.name, 'Ravi');

      await container
          .read(contactMutationControllerProvider.notifier)
          .setPrimary('c2');

      expect(container.read(primaryEmergencyContactProvider)?.name, 'Maya');
      expect(contacts.calls, ['setPrimaryContact:c2']);
    });

    test('a server field error is returned as a ValidationFailure', () async {
      final contacts = FakeContactsRepository()
        ..nextFailure = const ValidationFailure(
          fieldErrors: {'pincode': 'This value does not match the pattern.'},
        );
      final container = await authenticatedContainer(
        auth: auth,
        contacts: contacts,
      );
      addTearDown(container.dispose);
      keepAlive(container, addressesProvider);
      await settle();

      final failure = await container
          .read(addressMutationControllerProvider.notifier)
          .create(
            const AddressDraft(
              label: 'Home',
              addressLine1: '12 MG Road',
              city: 'Kochi',
              state: 'Kerala',
              pincode: '12',
            ),
          );

      expect(failure, isA<ValidationFailure>());
      expect((failure! as ValidationFailure).forField('pincode'), isNotNull);
      expect(container.read(addressesProvider).value, isEmpty);
    });
  });
}
