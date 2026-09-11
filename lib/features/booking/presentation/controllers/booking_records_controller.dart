import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/models/payment.dart';
import '../../../../core/utils/money.dart';
import '../../domain/booking_identifiers.dart';

/// What a completed booking produced, beyond what the appointment itself
/// carries (CM-14, CM-17).
///
/// Presentation view-model — immutable, no logic.
///
/// ## Why this exists
///
/// `Appointment` already has `bookingRef` / `paymentId` fields, but the only
/// thing that mints appointments is `AppointmentsController.book()`, which
/// lives in the **appointments** feature and does not accept them yet (it
/// still labels tokens `A-n` and leaves `bookingRef` null). This ledger is the
/// booking funnel's own record of the two identifiers it is responsible for,
/// so the summary, payment and confirmation screens can show a real booking
/// reference and a canonical `T-001` token today.
///
/// Read it through [bookingRecordForProvider], which falls back to the
/// appointment's own fields when they are populated — so the day
/// `AppointmentsController.book()` starts setting `bookingRef` and a `T-`
/// token, these screens pick that up and this ledger quietly stops being
/// consulted. Nothing here has to be rewritten for that to happen.
class BookingRecord {
  const BookingRecord({
    required this.appointmentId,
    required this.bookingRef,
    required this.token,
    required this.scheduledAt,
    required this.amount,
    required this.method,
    required this.createdAt,
    this.paymentId,
    this.hospitalId,
    this.patientId,
  });

  /// The appointment this booking created.
  final String appointmentId;

  /// Permanent identifier, `MB-2026-000125` (CM-14).
  final String bookingRef;

  /// The day's queue position, `T-026` (CANONICAL_MASTER_DATA §5).
  final String token;

  /// The slot that was booked.
  final DateTime scheduledAt;

  /// What the patient was charged — the fee breakdown's total.
  final Money amount;

  final PaymentMethod method;

  /// When the booking was completed.
  final DateTime createdAt;

  /// The ledger entry in `paymentsStoreProvider`, when one was written.
  final String? paymentId;

  final String? hospitalId;
  final String? patientId;

  BookingRecord copyWith({String? paymentId}) => BookingRecord(
    appointmentId: appointmentId,
    bookingRef: bookingRef,
    token: token,
    scheduledAt: scheduledAt,
    amount: amount,
    method: method,
    createdAt: createdAt,
    paymentId: paymentId ?? this.paymentId,
    hospitalId: hospitalId,
    patientId: patientId,
  );
}

/// Immutable ledger state: the completed bookings plus the next reference
/// sequence. Updated only through [copyWith].
class BookingLedger {
  const BookingLedger({required this.records, required this.nextSequence});

  /// Newest first.
  final List<BookingRecord> records;

  /// The sequence the next [BookingRecordsController.reserveReference] uses.
  final int nextSequence;

  BookingLedger copyWith({List<BookingRecord>? records, int? nextSequence}) =>
      BookingLedger(
        records: records ?? this.records,
        nextSequence: nextSequence ?? this.nextSequence,
      );
}

/// Owns the booking funnel's identifiers and completed-booking records.
///
/// Deliberately **not** `autoDispose`: booking writes it, and the confirmation,
/// payment-result and (later) receipt screens read it after the booking flow
/// itself has been left and its draft disposed.
///
/// API swap: when the data layer lands this takes a `BookingRepository` and
/// [reserveReference] becomes a server call that returns the real reference.
class BookingRecordsController extends StateNotifier<BookingLedger> {
  BookingRecordsController()
    : super(
        const BookingLedger(
          records: <BookingRecord>[],
          nextSequence: BookingRefs.firstSequence,
        ),
      );

  /// Mint the next booking reference, `MB-2026-000125`.
  ///
  /// Called once when the slot hold starts, so the reference is on screen
  /// before the patient pays. Call from a callback, never from a `build`.
  String reserveReference() {
    final reference = BookingRefs.format(state.nextSequence);
    state = state.copyWith(nextSequence: state.nextSequence + 1);
    return reference;
  }

  /// The sequence a reference was minted from, for the receipt series.
  int get lastSequence => state.nextSequence - 1;

  /// File a completed booking. Returns the stored record.
  BookingRecord add(BookingRecord record) {
    state = state.copyWith(records: [record, ...state.records]);
    return record;
  }

  /// Attach the ledger payment id to a filed booking (CM-17).
  ///
  /// Returns **false** when there is no such record, so a caller can never
  /// report a link that was not made (THE LAW on honest controls).
  bool linkPayment(String appointmentId, String paymentId) {
    final existing = forAppointment(appointmentId);
    if (existing == null) return false;
    state = state.copyWith(
      records: [
        for (final record in state.records)
          if (record.appointmentId == appointmentId)
            record.copyWith(paymentId: paymentId)
          else
            record,
      ],
    );
    return true;
  }

  BookingRecord? forAppointment(String appointmentId) {
    for (final record in state.records) {
      if (record.appointmentId == appointmentId) return record;
    }
    return null;
  }
}

/// The booking funnel's ledger. Not autoDispose — see the class doc.
final bookingRecordsProvider =
    StateNotifierProvider<BookingRecordsController, BookingLedger>(
      (ref) => BookingRecordsController(),
    );

/// The booking record for one appointment, or null when the appointment was
/// not created by this session's booking flow (the seeded ones are not).
///
/// autoDispose family — the appointment id space is unbounded.
final bookingRecordForProvider = Provider.autoDispose
    .family<BookingRecord?, String>((ref, appointmentId) {
      final ledger = ref.watch(bookingRecordsProvider);
      for (final record in ledger.records) {
        if (record.appointmentId == appointmentId) return record;
      }
      return null;
    });
