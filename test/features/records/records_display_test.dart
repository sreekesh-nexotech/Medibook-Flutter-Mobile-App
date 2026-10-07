import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/common/attachments/domain/entities/stored_file.dart';
import 'package:medibook/features/common/persons/domain/entities/person_summary.dart';
import 'package:medibook/features/records/application/providers/documents_filter_controller.dart';
import 'package:medibook/features/records/application/providers/linkable_appointments_provider.dart';
import 'package:medibook/features/records/application/providers/records_provider.dart';
import 'package:medibook/features/records/domain/entities/medical_document.dart';

/// What the Records screens show from the server's data (Records audit,
/// 6 Oct 2026): visits that can be told apart, every server sort order, the
/// edit date, readable file states and old enough document dates.
void main() {
  LinkableAppointment visit(
    String id, {
    String bookingRef = 'LKSB-2610-00212',
    String statusLabel = 'Completed',
    bool closed = false,
  }) => LinkableAppointment(
    id: id,
    label: 'Dr. Meera Varghese · 9 Oct 2026',
    doctorName: 'Dr. Meera Varghese',
    hospitalName: 'Lakeshore Multispeciality Hospital',
    scheduledAt: DateTime.utc(2026, 10, 9, 4, 50),
    when: '9 Oct 2026 · 10:20 AM',
    bookingRef: bookingRef,
    statusLabel: statusLabel,
    isClosedWithoutVisit: closed,
    personId: 'tara',
  );

  group('visit picker', () {
    test('names the time, hospital, patient, booking and status', () {
      expect(
        linkableAppointmentDetail(visit('a'), patientName: 'Tara Varma'),
        '9 Oct 2026 · 10:20 AM · Lakeshore Multispeciality Hospital · '
        'for Tara Varma · LKSB-2610-00212 · Completed',
      );
      // The family list still loading: the rest is enough to tell apart.
      expect(
        linkableAppointmentDetail(visit('a', statusLabel: 'Cancelled')),
        '9 Oct 2026 · 10:20 AM · Lakeshore Multispeciality Hospital · '
        'LKSB-2610-00212 · Cancelled',
      );
    });

    test('the full label adds the hospital to the short one', () {
      expect(visit('a').label, 'Dr. Meera Varghese · 9 Oct 2026');
      expect(
        visit('a').fullLabel,
        'Dr. Meera Varghese · 9 Oct 2026 · Lakeshore Multispeciality Hospital',
      );
    });

    test('the visit filter chip names the hospital too', () {
      final container = ProviderContainer(
        overrides: [
          linkableAppointmentsProvider.overrideWithValue([visit('a')]),
        ],
      );
      addTearDown(container.dispose);
      final chips = container.listen(documentFilterChipsProvider, (_, _) {});
      container.read(documentsFilterProvider.notifier).setAppointment('a');
      expect(chips.read().single.field, DocumentFilterField.appointment);
      expect(
        chips.read().single.label,
        'Dr. Meera Varghese · 9 Oct 2026 · Lakeshore Multispeciality Hospital',
      );
    });

    test('a visit that never happened is not offered as a link target', () {
      final visits = [
        visit('done'),
        visit('cancelled', statusLabel: 'Cancelled', closed: true),
      ];
      expect(linkTargets(visits).map((v) => v.id), ['done']);
      // …unless the document is already linked to it.
      expect(linkTargets(visits, currentId: 'cancelled').map((v) => v.id), [
        'done',
        'cancelled',
      ]);
    });
  });

  group('sorting', () {
    test('every order the server offers is available', () {
      expect(DocumentSort.values.map((s) => s.wire), [
        '-document_date',
        'document_date',
        '-created_at',
        'title',
      ]);
      expect(
        kDocumentSorts,
        [DocumentSort.newestFirst, DocumentSort.oldestFirst],
        reason: 'the design keeps two pills; the rest are in the sheet',
      );
    });

    test('the heading says what order the list is in', () {
      expect(DocumentSort.newestFirst.heading, 'Recent Records');
      expect(DocumentSort.oldestFirst.heading, isNot('Recent Records'));
      expect(DocumentSort.recentlyAdded.heading, 'Recently Added');
    });
  });

  group('document detail', () {
    MedicalDocument document({DateTime? created, DateTime? updated}) =>
        MedicalDocument(
          id: 'd1',
          personId: 'self',
          docType: DocumentType.labReport,
          title: 'Blood test — CBC',
          documentDate: DateTime(2026, 9, 5),
          file: const DocumentFile(
            id: 'f1',
            originalName: 'report-11.pdf',
            mime: 'application/pdf',
            sizeBytes: 206,
            status: FileStatus.clean,
          ),
          version: 3,
          createdAt: created,
          updatedAt: updated,
        );

    test('shows when it was last edited, and only if it was', () {
      final added = DateTime.utc(2026, 9, 5, 8);
      expect(
        document(
          created: added,
          updated: DateTime.utc(2026, 10, 1, 9),
        ).lastEditedAt,
        DateTime.utc(2026, 10, 1, 9),
      );
      expect(
        document(
          created: added,
          updated: added.add(const Duration(seconds: 2)),
        ).lastEditedAt,
        isNull,
      );
      expect(document().lastEditedAt, isNull);
    });

    test('a file state reads as words, never the wire value', () {
      for (final status in FileStatus.values) {
        expect(status.label, isNot(contains('_')), reason: status.wire);
        expect(status.label, isNotEmpty);
      }
      expect(FileStatus.scanFailed.label, 'Could not be checked');
    });
  });

  // The server sends each person's relation and gender; the pickers show
  // them as the Family Members screen does, not "Family member" for all.
  test('a person reads as their relation to the account holder', () {
    PersonSummary person(String relation, {String? gender}) => PersonSummary(
      id: relation,
      firstName: 'X',
      relation: relation,
      isSelf: relation == 'self',
      gender: gender,
    );
    expect(person('self').relationLabel, 'You');
    expect(person('spouse', gender: 'female').relationLabel, 'Wife');
    expect(person('child', gender: 'male').relationLabel, 'Son');
    expect(person('parent').relationLabel, 'Parent');
    expect(person('sibling', gender: 'female').relationLabel, 'Sister');
    expect(person('other', gender: 'male').relationLabel, 'Family member');
  });

  test('a document date can be as old as a date of birth', () {
    final now = DateTime(2026, 10, 6);
    expect(earliestDocumentDate(now), DateTime(1906, 1, 1));
  });
}
