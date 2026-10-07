import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/booking/presentation/booking_routes.dart';
import 'package:medibook/features/booking/application/providers/booking_draft_provider.dart';
import 'package:medibook/features/booking/domain/entities/department.dart';
import 'package:medibook/features/booking/domain/entities/doctor.dart';
import 'package:medibook/features/booking/domain/entities/person_summary.dart';
import 'package:medibook/features/booking/domain/entities/slots.dart';
import 'package:medibook/features/booking/domain/entities/hospital_clock.dart';

DoctorCard _doctor({String id = 'doc1', String hospitalId = 'h1'}) =>
    DoctorCard(
      id: id,
      slug: id,
      name: 'Dr. Test',
      department: const DepartmentRef(id: 'd1', code: 'cardiology', name: 'C'),
      hospital: DoctorHospitalRef(id: hospitalId, name: 'H', city: 'Kochi'),
      consultationFeePaise: 50000,
      isBookableOnline: true,
    );

Slot _slot({String id = 'slot-a', SlotState state = SlotState.available}) =>
    Slot(
      id: id,
      sessionId: 's1',
      startsAt: DateTime.utc(2026, 10, 1, 3, 30),
      endsAt: DateTime.utc(2026, 10, 1, 3, 45),
      state: state,
    );

void main() {
  late BookingDraftController controller;

  setUp(() => controller = BookingDraftController());

  // BL-BOOK-030: notes are optional.
  test('spaces-only notes count as no notes, and notes are trimmed', () {
    controller.setNotes('   \n  ');
    expect(controller.state.patientNotes, isNull);

    controller.setNotes('  Chest pain since Monday  ');
    expect(controller.state.patientNotes, 'Chest pain since Monday');

    controller.setNotes('');
    expect(controller.state.patientNotes, isNull);
  });

  test('configure seeds the route params and clamps the step', () {
    controller.configure(step: 9, hospitalId: 'h1', departmentCode: 'ent');
    expect(controller.state.step, 4);
    expect(controller.state.hospitalId, 'h1');
    expect(controller.state.departmentCode, 'ent');
  });

  test('picking a doctor scopes the flow to its hospital and department', () {
    controller.pickDoctor(_doctor());
    expect(controller.state.hospitalId, 'h1');
    expect(controller.state.departmentCode, 'cardiology');
    // Step 1 only needs a department code, which the doctor supplied.
    expect(controller.state.canContinue, isTrue);
    controller.goToStep(3);
    // Step 3 still needs a slot and a person.
    expect(controller.state.canContinue, isFalse);
  });

  test('an unavailable slot never lands in the draft', () {
    controller.pickDoctor(_doctor());
    controller.pickSlot(_slot(state: SlotState.booked), date: '2026-10-01');
    expect(controller.state.slot, isNull);
    controller.pickSlot(_slot(), date: '2026-10-01', sessionLabel: 'Morning');
    expect(controller.state.slotId, 'slot-a');
    expect(controller.state.sessionLabel, 'Morning');
  });

  test('changing the department or hospital clears the doctor and slot', () {
    controller.pickDoctor(_doctor());
    controller.pickSlot(_slot(), date: '2026-10-01');
    controller.pickDepartment(code: 'ent', name: 'ENT');
    expect(controller.state.doctor, isNull);
    expect(controller.state.slot, isNull);

    controller.pickDoctor(_doctor(hospitalId: 'h1'));
    controller.pickHospital(id: 'h2', name: 'Other');
    expect(controller.state.doctor, isNull);
    expect(controller.state.hospitalName, 'Other');
  });

  test('bookable only with a slot and a person; never a guessed person', () {
    controller.pickDoctor(_doctor());
    controller.pickSlot(_slot(), date: '2026-10-01');
    expect(controller.state.isBookable, isFalse);
    controller.pickPerson(
      const PersonSummary(
        id: 'p1',
        firstName: 'Arjun',
        relation: 'child',
        isSelf: false,
      ),
    );
    expect(controller.state.isBookable, isTrue);
    expect(controller.state.personId, 'p1');
  });

  test('clearSlot after SLOT_UNAVAILABLE returns to the time step', () {
    controller.pickDoctor(_doctor());
    controller.pickSlot(_slot(), date: '2026-10-01');
    controller.goToStep(4);
    controller.clearSlot();
    expect(controller.state.slot, isNull);
    expect(controller.state.step, 3);
  });

  test('coupon codes are upper-cased and trimmed, never validated locally', () {
    controller.applyCoupon('  welcome10 ');
    expect(controller.state.couponCode, 'WELCOME10');
    controller.removeCoupon();
    expect(controller.state.couponCode, isNull);
  });

  test('back consumes steps down to 1 and then reports false', () {
    controller.goToStep(3);
    expect(controller.back(), isTrue);
    expect(controller.back(), isTrue);
    expect(controller.back(), isFalse);
    expect(controller.state.step, 1);
  });

  test('hospital clock renders UTC instants in Asia/Kolkata', () {
    final wall = HospitalClock.wallClock(
      DateTime.utc(2026, 10, 1, 3, 30),
      timezone: 'Asia/Kolkata',
    );
    expect(wall.hour, 9);
    expect(wall.minute, 0);
    expect(
      HospitalClock.localDate(DateTime.utc(2026, 9, 30, 20, 0)),
      '2026-10-01',
    );
    expect(HospitalClock.parseDate('2026-10-01'), DateTime(2026, 10, 1));
    expect(HospitalClock.parseDate('nope'), isNull);
  });

  // BL-PAY-028: "Book again" after a lapsed payment keeps the booking.
  test('a resume link carries the flag; a normal one does not', () {
    expect(BookingRoutes.booking(step: 2, resume: true), contains('resume=1'));
    expect(BookingRoutes.booking(step: 2), isNot(contains('resume')));
  });

  // Home's service tiles open the flow with a department code only.
  test('a department opened by code is named without losing the picks', () {
    controller
      ..configure(step: 2, departmentCode: 'general_medicine')
      ..pickHospital(id: 'h1', name: 'Lakeshore');
    controller.nameDepartment(code: 'cardiology', name: 'Cardiology');
    expect(controller.state.departmentName, isNull, reason: 'another code');

    controller.nameDepartment(
      code: 'general_medicine',
      name: 'General Medicine',
    );
    expect(controller.state.departmentName, 'General Medicine');
    expect(controller.state.hospitalId, 'h1', reason: 'nothing else changes');

    controller.nameDepartment(code: 'general_medicine', name: 'Other');
    expect(controller.state.departmentName, 'General Medicine');
  });
}
