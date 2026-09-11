import 'package:flutter/material.dart';

import '../utils/date_utils.dart';
import '../utils/money.dart';
import '../widgets/app_icon.dart';
import 'models/app_notification.dart';
import 'models/appointment.dart';
import 'models/department.dart';
import 'models/doctor.dart';
import 'models/fee_breakdown.dart';
import 'models/hospital.dart';
import 'models/insurance_policy.dart';
import 'models/location.dart';
import 'models/medical_record.dart';
import 'models/patient.dart';
import 'models/payment.dart';
import 'models/promo_banner.dart';
import 'models/queue_status.dart';
import 'models/slot.dart';
import 'models/support_content.dart';

/// ============================================================================
/// STATIC SEED DATA — REPLACE WITH API RESPONSES
/// ----------------------------------------------------------------------------
/// Every list below mirrors exactly what the design prototype shows
/// (`Medibook App.dc.html`), extended with the records the contract
/// requirements (CM-xx) need in order to be built against. It is surfaced to
/// screens through the read providers in `seed_providers.dart`, the mutable
/// stores in `stores/`, and the controllers under each feature.
///
/// When the data/domain layers are built, this file is the single swap-point:
/// the read providers change their body to call feature repositories, these
/// UI models are replaced by domain entities, and this file is deleted. No
/// screen references [MedibookSeed] directly — they read providers — so the
/// swap is isolated here.
///
/// ## Typed storage (audit §3.8.2, §3.8.3)
///
/// Money is seeded in **paise** (`feePaise: 90000`) and dates as real
/// [DateTime]s computed relative to `DateTime.now()`, so the seed ages
/// correctly instead of drifting into the past. The display strings the
/// screens read (`doctor.fee`, `appointment.date`, `record.date`,
/// `patient.meta`, `notification.ago`) are derived getters, so nothing in
/// `lib/features/**` had to change.
/// ============================================================================
abstract final class MedibookSeed {
  MedibookSeed._();

  /// Anchor for every relative date below — one `now` per app run, so a list
  /// cannot show two different "today"s.
  static final DateTime _now = DateTime.now();

  static DateTime _at(int dayOffset, int hour, [int minute = 0]) {
    final day = AppDates.startOfDay(_now);
    return DateTime(day.year, day.month, day.day + dayOffset, hour, minute);
  }

  // ---- Current user (Profile / Home greeting) ----
  static const String userName = 'Alexandra Johnson';
  static const String userFirstName = 'Alexandra';
  static const String userEmail = 'alexandra.johnson@example.com';
  static const String userPhone = '+91 98456 58525';

  static const List<({String key, String value})> profileInfo = [
    (key: 'Phone', value: '+91 98456 58525'),
    (key: 'Date of Birth', value: '15/05/1997'),
    (key: 'Gender', value: 'Female'),
    (key: 'Blood Group', value: 'O+'),
  ];

  // ---- Departments ----
  static const List<Department> departments = [
    Department(
      name: 'General',
      sub: 'Primary healthcare',
      iconName: MedIcon.records,
    ),
    Department(
      name: 'Cardiology',
      sub: 'Heart specialists',
      iconName: MedIcon.star,
    ),
    Department(
      name: 'Orthopedics',
      sub: 'Bone & joint care',
      iconName: MedIcon.hospital,
    ),
    Department(
      name: 'Dermatology',
      sub: 'Skin specialists',
      iconName: MedIcon.eye,
    ),
  ];

  // ---- Hospitals (CM-11, CM-25) ----
  //
  // The canonical list lives in `models/hospital.dart` so `Doctor.hospital`
  // can derive its name from `hospitalId` without importing this file.
  static const List<Hospital> hospitals = Hospitals.all;

  // ---- Locations (CM-10: location-first discovery) ----
  static const List<Location> locations = [
    Location(city: 'Kochi', area: 'Kakkanad', isPopular: true),
    Location(city: 'Kochi', area: 'Ernakulam South', isPopular: true),
    Location(city: 'Kochi', area: 'Kaloor'),
    Location(city: 'Kochi', area: 'Maradu'),
    Location(city: 'Kochi', area: 'Panampilly Nagar'),
    Location(city: 'Thrissur', area: 'East Fort', isPopular: true),
    Location(city: 'Thrissur', area: 'Ollur'),
    Location(city: 'Kozhikode', area: 'Mavoor Road'),
    Location(city: 'Thiruvananthapuram', area: 'Pattom', isPopular: true),
    Location(city: 'Thiruvananthapuram', area: 'Kowdiar'),
  ];

  // ---- Doctors ----
  static const List<Doctor> doctors = [
    Doctor(
      id: 'anya',
      name: 'Dr. Anya Sharma',
      department: 'Cardiology',
      spec: 'Cardiologist',
      title: 'Head of Cardiology',
      experience: '12 yrs',
      patients: '6,000+',
      rating: 4.8,
      feePaise: 90000, // ₹900
      hospitalId: 'apollo',
      imageAsset: 'assets/images/doctor-portrait.png',
      about:
          'Heads the cardiology unit at Apollo Hospital. Specialises in '
          'preventive cardiology and echocardiography, with 6,000+ patients '
          'treated across 12 years of practice.',
    ),
    Doctor(
      id: 'rohan',
      name: 'Dr. Rohan Kapoor',
      department: 'Cardiology',
      spec: 'Cardiologist',
      title: 'Consultant Cardiologist',
      experience: '8 yrs',
      patients: '3,200+',
      rating: 4.6,
      feePaise: 70000, // ₹700
      hospitalId: 'city-care',
      about:
          'Consultant cardiologist focused on hypertension and lifestyle-led '
          'heart care. Known for clear, unhurried consultations.',
    ),
    Doctor(
      id: 'anil',
      name: 'Dr. Anil Kumar',
      department: 'General',
      spec: 'General Physician',
      title: 'Senior General Physician',
      experience: '15 yrs',
      patients: '9,500+',
      rating: 4.7,
      feePaise: 50000, // ₹500
      hospitalId: 'apollo',
      about:
          'Senior general physician for everyday illness, diabetes care and '
          'preventive checkups. A trusted family doctor to three generations '
          'of patients.',
    ),
    Doctor(
      id: 'meera',
      name: 'Dr. Meera Nair',
      department: 'General',
      spec: 'General Physician',
      title: 'General Physician',
      experience: '6 yrs',
      patients: '2,100+',
      rating: 4.5,
      feePaise: 45000, // ₹450
      hospitalId: 'city-care',
      about:
          'General physician with a focus on women and child wellness, '
          'vaccinations and seasonal illness.',
    ),
    Doctor(
      id: 'priya',
      name: 'Dr. Priya Mehta',
      department: 'Orthopedics',
      spec: 'Orthopedic Surgeon',
      title: 'Lead, Day-care Orthopedics',
      experience: '10 yrs',
      patients: '4,800+',
      rating: 4.9,
      feePaise: 80000, // ₹800
      hospitalId: 'apollo',
      about:
          'Orthopedic surgeon specialising in joint replacement and sports '
          'injuries. Leads the day-care orthopedic program at Apollo Hospital.',
    ),
    Doctor(
      id: 'sara',
      name: 'Dr. Sara Ali',
      department: 'Dermatology',
      spec: 'Dermatologist',
      title: 'Consultant Dermatologist',
      experience: '7 yrs',
      patients: '2,900+',
      rating: 4.6,
      feePaise: 65000, // ₹650
      hospitalId: 'city-care',
      about:
          'Dermatologist treating acne, hair loss and skin allergies with '
          'evidence-first care plans.',
    ),
  ];

  // ---- Patients (self + dependants; CM-16, CM-48) ----
  static final List<Patient> patients = [
    Patient(
      id: 'p-self',
      name: 'Alexandra Johnson',
      relation: PatientRelations.self,
      dateOfBirth: DateTime(1997, 5, 15),
      gender: 'Female',
      bloodGroup: 'O+',
      allergies: ['Penicillin'],
      isSelf: true,
      phone: '+919845658525',
    ),
    Patient(
      id: 'p-michael',
      name: 'Michael Johnson',
      relation: 'Husband',
      dateOfBirth: DateTime(1992, 2, 9),
      gender: 'Male',
      bloodGroup: 'B+',
    ),
    Patient(
      id: 'p-ava',
      name: 'Ava Johnson',
      relation: 'Daughter',
      dateOfBirth: DateTime(_now.year - 6, 11, 3),
      gender: 'Female',
      bloodGroup: 'O+',
      allergies: ['Peanuts'],
    ),
  ];

  // ---- Time slots (legacy display strings; kept for the current screens) ----
  static const List<String> timeSlots = [
    '09:00 AM',
    '10:00 AM',
    '11:30 AM',
    '12:15 PM',
    '02:00 PM',
    '04:30 PM',
  ];

  /// The clock times a full consulting day is published at.
  static const List<({int hour, int minute})> _slotTimes = [
    (hour: 9, minute: 0),
    (hour: 9, minute: 30),
    (hour: 10, minute: 0),
    (hour: 10, minute: 30),
    (hour: 11, minute: 30),
    (hour: 12, minute: 15),
    (hour: 14, minute: 0),
    (hour: 14, minute: 30),
    (hour: 16, minute: 30),
    (hour: 17, minute: 0),
  ];

  /// Slot availability for [doctorId] on [day] (CM-12).
  ///
  /// Deliberately produces every state the booking calendar has to render, so
  /// the feature agents can build "unavailable", "fully booked" and "past"
  /// without inventing data:
  ///
  /// * **day + 0 (today)** — a normal mix, with everything before *now*
  ///   marked [SlotStatus.past].
  /// * **day + 2** — **fully booked**: slots exist, none are available.
  /// * **day + 3** — **no slots at all**: the doctor does not consult
  ///   (`DaySlots.isUnavailable`).
  /// * **Sundays** — no slots, for every doctor.
  /// * every other day — a mix of available, booked and blocked.
  ///
  /// The pattern is derived from the doctor id and the day, so it is stable
  /// across rebuilds (no `Random`) — a slot does not change status because a
  /// widget repainted.
  static DaySlots slotsFor(String doctorId, DateTime day) {
    final target = AppDates.startOfDay(day);
    final offset = target.difference(AppDates.startOfDay(_now)).inDays;

    // The deliberate "fully booked" day wins over the closed-day rules, so it
    // exists no matter which weekday today happens to be — otherwise the state
    // vanishes whenever day+2 lands on a Sunday.
    final fullyBooked = offset == 2;

    // Closed: Sundays, and the deliberate "doctor not consulting" day.
    if (!fullyBooked && (target.weekday == DateTime.sunday || offset == 3)) {
      return DaySlots(day: target, slots: const []);
    }

    final seed = doctorId.codeUnits.fold<int>(0, (a, b) => a + b) + offset;

    final slots = <Slot>[];
    for (var i = 0; i < _slotTimes.length; i++) {
      final time = _slotTimes[i];
      final start = DateTime(
        target.year,
        target.month,
        target.day,
        time.hour,
        time.minute,
      );

      final SlotStatus status;
      if (start.isBefore(_now)) {
        status = SlotStatus.past;
      } else if (fullyBooked) {
        // Half taken, half withheld — a full day that still reads as a real
        // calendar rather than a blank one.
        status = i.isEven ? SlotStatus.booked : SlotStatus.blocked;
      } else if ((seed + i) % 4 == 0) {
        status = SlotStatus.booked;
      } else if ((seed + i) % 7 == 0) {
        status = SlotStatus.blocked;
      } else {
        status = SlotStatus.available;
      }

      slots.add(Slot(start: start, status: status));
    }
    return DaySlots(day: target, slots: slots);
  }

  // ---- Records / documents (CM-32 … CM-36) ----
  static final List<MedicalRecord> records = [
    MedicalRecord(
      id: 'doc-1',
      title: 'Blood Test Report',
      recordedAt: _at(-63, 9, 30),
      status: RecordStatus.completed,
      type: DocumentType.labReport,
      patient: 'Alexandra Johnson',
      patientId: 'p-self',
      hospital: 'Apollo Hospital',
      doctor: 'Dr. Anil Kumar',
      fileName: 'blood-test-report.pdf',
      fileSizeBytes: 412_000,
      notes: 'Fasting sample, collected at home.',
    ),
    MedicalRecord(
      id: 'doc-2',
      title: 'Full Body Checkup',
      recordedAt: _at(-71, 8, 0),
      status: RecordStatus.pending,
      type: DocumentType.labReport,
      patient: 'Michael Johnson',
      patientId: 'p-michael',
      hospital: 'Apollo Hospital',
      doctor: 'Dr. Meera Nair',
      fileName: '',
      fileSizeBytes: 0,
      notes: 'Awaiting the radiology section.',
    ),
    MedicalRecord(
      id: 'doc-3',
      title: 'Lipid Profile',
      recordedAt: _at(-82, 10, 15),
      status: RecordStatus.completed,
      type: DocumentType.labReport,
      patient: 'Alexandra Johnson',
      patientId: 'p-self',
      hospital: 'City Care Clinic',
      doctor: 'Dr. Rohan Kapoor',
      fileName: 'lipid-profile.pdf',
      fileSizeBytes: 268_000,
    ),
    MedicalRecord(
      id: 'doc-4',
      title: 'Prescription — Dr. Anil Kumar',
      recordedAt: _at(-63, 10, 45),
      status: RecordStatus.completed,
      type: DocumentType.prescription,
      patient: 'Alexandra Johnson',
      patientId: 'p-self',
      hospital: 'Apollo Hospital',
      doctor: 'Dr. Anil Kumar',
      appointmentId: '3',
      fileName: 'prescription-10jul.pdf',
      fileSizeBytes: 96_500,
    ),
    MedicalRecord(
      id: 'doc-5',
      title: 'Knee X-Ray (Left)',
      recordedAt: _at(-120, 16, 0),
      status: RecordStatus.completed,
      type: DocumentType.scan,
      patient: 'Michael Johnson',
      patientId: 'p-michael',
      hospital: 'Lakeshore Medical Centre',
      doctor: 'Dr. Priya Mehta',
      fileName: 'knee-xray-left.jpg',
      fileSizeBytes: 2_340_000,
    ),
    MedicalRecord(
      id: 'doc-6',
      title: 'Consultation Invoice',
      recordedAt: _at(-63, 11, 0),
      status: RecordStatus.completed,
      type: DocumentType.invoice,
      patient: 'Alexandra Johnson',
      patientId: 'p-self',
      hospital: 'Apollo Hospital',
      doctor: 'Dr. Anil Kumar',
      appointmentId: '3',
      fileName: 'invoice-MB-RCPT-000118.pdf',
      fileSizeBytes: 74_200,
    ),
  ];

  // ---- Notifications (CM-40 … CM-43) ----
  static final List<AppNotification> notifications = [
    AppNotification(
      id: 'n-1',
      title: 'Fasting Reminder',
      kind: NotificationKind.reminder,
      body:
          'Your Full Body Checkup requires fasting. Please avoid food and '
          'drinks (except water) for 8–12 hours before your sample collection '
          'at 8:00 AM tomorrow.',
      createdAt: _now.subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: 'n-2',
      title: 'Appointment Reminder',
      kind: NotificationKind.reminder,
      body:
          'Your appointment with Dr. Priya Mehta is scheduled for today at '
          '10:30 AM.',
      createdAt: _now.subtract(const Duration(hours: 2)),
      appointmentId: '1',
      action1Label: 'Reschedule',
      action1: NotificationAction.rescheduleTodayAppt,
      action2Label: 'View Details',
      action2: NotificationAction.viewTodayApptDetail,
    ),
    AppNotification(
      id: 'n-3',
      title: 'Prescription Ready',
      kind: NotificationKind.general,
      body:
          'Your prescription from Dr. Anil Kumar is now available for download.',
      createdAt: _now.subtract(const Duration(hours: 5)),
      action1Label: 'View Details',
      action1: NotificationAction.viewRecords,
      action2Label: 'Download',
      action2: NotificationAction.downloadPrescription,
    ),
    AppNotification(
      id: 'n-4',
      title: 'Vaccination Due',
      kind: NotificationKind.general,
      read: true,
      body:
          "Ava's next vaccination is due in 2 weeks. Schedule an appointment "
          'now.',
      createdAt: _now.subtract(const Duration(days: 2)),
      action1Label: 'Remind Later',
      action1: NotificationAction.remindLater,
      action2Label: 'Schedule',
      action2: NotificationAction.scheduleBooking,
    ),
    AppNotification(
      id: 'n-5',
      title: 'Appointment Confirmed',
      kind: NotificationKind.confirmation,
      read: true,
      body:
          'Your appointment with Dr. Anil Kumar on '
          '${AppDates.dayMonthYear(_at(7, 9))} at 9:00 AM is confirmed. '
          'Booking reference MB-2026-000118.',
      createdAt: _now.subtract(const Duration(days: 3)),
      appointmentId: '2',
    ),
    AppNotification(
      id: 'n-6',
      title: 'Appointment Cancelled',
      kind: NotificationKind.cancellation,
      read: true,
      body:
          "Ava's appointment with Dr. Anil Kumar was cancelled. Any amount "
          'paid will be refunded within 5–7 working days.',
      createdAt: _now.subtract(const Duration(days: 9)),
      appointmentId: '4',
    ),
  ];

  // ---- Home promo banners ----
  static const List<PromoBanner> banners = [
    PromoBanner(
      gradient: [Color(0xFF4F7CA8), Color(0xFF3E6A96)],
      title: 'Want to see a doctor today?',
      body: 'Schedule your appointment in just a tap.',
      hasImage: true,
    ),
    PromoBanner(
      gradient: [Color(0xFFC0392B), Color(0xFFA93226)],
      title: 'Lab tests at home',
      body: 'Book a sample collection slot now.',
      hasImage: false,
    ),
  ];

  // ---- Initial appointments (2 upcoming, 1 completed, 1 cancelled) ----
  //
  // Ids, doctorIds, patients, tokens and statuses are exactly as they were;
  // only the storage changed — display strings ("Today", "12 Aug 2026") became
  // real instants computed relative to `now`, so the seed stays plausible as
  // time passes instead of showing four past appointments in the Upcoming tab.
  static List<Appointment> initialAppointments() => [
    Appointment.at(
      id: '1',
      doctorId: 'priya',
      patient: 'Alexandra Johnson',
      patientId: 'p-self',
      scheduledAt: _at(0, 10, 30), // was 'Today' / '10:30 AM'
      token: 'A-25',
      status: AppointmentStatus.confirmed,
      bucket: AppointmentBucket.upcoming,
      bookingRef: 'MB-2026-000124',
      hospitalId: 'apollo',
      paymentId: 'pay-1',
    ),
    Appointment.at(
      id: '2',
      doctorId: 'anil',
      patient: 'Michael Johnson',
      patientId: 'p-michael',
      scheduledAt: _at(7, 9), // was '12 Aug 2026' / '09:00 AM'
      token: 'A-12',
      status: AppointmentStatus.confirmed,
      bucket: AppointmentBucket.upcoming,
      bookingRef: 'MB-2026-000118',
      hospitalId: 'apollo',
      paymentId: 'pay-2',
    ),
    Appointment.at(
      id: '3',
      doctorId: 'anya',
      patient: 'Alexandra Johnson',
      patientId: 'p-self',
      scheduledAt: _at(-63, 11, 30), // was '21 Jul 2026' / '11:30 AM'
      token: 'A-08',
      status: AppointmentStatus.completed,
      bucket: AppointmentBucket.past,
      bookingRef: 'MB-2026-000091',
      hospitalId: 'apollo',
      paymentId: 'pay-3',
    ),
    Appointment.at(
      id: '4',
      doctorId: 'anil',
      patient: 'Ava Johnson',
      patientId: 'p-ava',
      scheduledAt: _at(-101, 14), // was '02 Jun 2026' / '02:00 PM'
      token: 'A-19',
      status: AppointmentStatus.cancelled,
      bucket: AppointmentBucket.past,
      bookingRef: 'MB-2026-000074',
      hospitalId: 'apollo',
      paymentId: 'pay-4',
    ),
  ];

  /// Next booking reference, in the CM-14 format `MB-<year>-<6 digits>`.
  static String bookingRef(int sequence) =>
      'MB-${_now.year}-${sequence.toString().padLeft(6, '0')}';

  /// Next receipt number, in the CM-21 format `MB-RCPT-<6 digits>`.
  static String receiptNumber(int sequence) =>
      'MB-RCPT-${sequence.toString().padLeft(6, '0')}';

  // ---- Payments (CM-17, CM-20 … CM-22) ----
  static final List<PaymentRecord> payments = [
    PaymentRecord(
      id: 'pay-1',
      appointmentId: '1',
      method: PaymentMethod.upi,
      amount: feeFor('priya').total,
      status: PaymentStatus.paid,
      receiptNumber: 'MB-RCPT-000124',
      paidAt: _now.subtract(const Duration(days: 1, hours: 3)),
    ),
    PaymentRecord(
      id: 'pay-2',
      appointmentId: '2',
      method: PaymentMethod.payAtHospital,
      amount: feeFor('anil').total,
      status: PaymentStatus.pending,
      receiptNumber: 'MB-RCPT-000118',
    ),
    PaymentRecord(
      id: 'pay-3',
      appointmentId: '3',
      method: PaymentMethod.card,
      amount: feeFor('anya').total,
      status: PaymentStatus.paid,
      receiptNumber: 'MB-RCPT-000091',
      gstNumber: '32ABCDE1234F1Z5',
      paidAt: _at(-63, 11, 2),
    ),
    PaymentRecord(
      id: 'pay-4',
      appointmentId: '4',
      method: PaymentMethod.netBanking,
      amount: feeFor('anil').total,
      status: PaymentStatus.refunded,
      receiptNumber: 'MB-RCPT-000074',
      paidAt: _at(-108, 12),
      refundAmount: feeFor('anil').total,
      refundStatus: RefundStatus.completed,
    ),
    // A failed attempt, so the CM-20 failure screen has real data.
    PaymentRecord(
      id: 'pay-5',
      appointmentId: '2',
      method: PaymentMethod.card,
      amount: feeFor('anil').total,
      status: PaymentStatus.failed,
      receiptNumber: 'MB-RCPT-000117',
      failureReason: 'The bank declined the card (insufficient funds).',
    ),
  ];

  /// The fee breakdown for [doctorId] (CM-13, CM-19) — 18% GST plus a ₹25
  /// convenience fee on the doctor's consultation fee.
  static FeeBreakdown feeFor(String doctorId, {String? couponCode}) {
    final doctor = doctorById(doctorId);
    final discount = couponCode == null
        ? Money.zero
        : DemoCoupons.discountFor(couponCode, doctor.consultationFee) ??
              Money.zero;
    return FeeBreakdown.build(
      consultationFee: doctor.consultationFee,
      discount: discount,
      couponCode: couponCode,
    );
  }

  // ---- Insurance (CM-37 … CM-39) ----
  static final List<InsurancePolicy> insurancePolicies = [
    InsurancePolicy(
      id: 'ins-1',
      provider: 'Star Health & Allied Insurance',
      policyNumber: 'P/181234/01/2026/004521',
      holderName: 'Alexandra Johnson',
      planName: 'Family Health Optima',
      sumInsured: Money.rupees(500000),
      validFrom: _at(-160, 0),
      validTo: _at(205, 0),
      documents: ['doc-6'],
      tpaName: 'Medi Assist',
    ),
    InsurancePolicy(
      id: 'ins-2',
      provider: 'HDFC ERGO',
      policyNumber: 'HE/2026/PA/889102',
      holderName: 'Michael Johnson',
      planName: 'Optima Secure',
      sumInsured: Money.rupees(1000000),
      validFrom: _at(-330, 0),
      // Expires inside the 30-day window, so the CM-39 renewal nudge has data.
      validTo: _at(18, 0),
    ),
  ];

  // ---- Live queue (CM-09, CM-24) ----
  static final List<QueueStatus> queueStatuses = [
    QueueStatus(
      doctorId: 'priya',
      currentToken: 'A-23',
      lastCalledToken: 'A-23',
      estimatedWaitMinutes: 8,
      updatedAt: _now.subtract(const Duration(minutes: 2)),
    ),
    QueueStatus(
      doctorId: 'anil',
      currentToken: 'A-09',
      lastCalledToken: 'A-10',
      estimatedWaitMinutes: 12,
      updatedAt: _now.subtract(const Duration(minutes: 6)),
    ),
    QueueStatus(
      doctorId: 'anya',
      currentToken: 'A-04',
      lastCalledToken: 'A-04',
      estimatedWaitMinutes: 15,
      updatedAt: _now.subtract(const Duration(minutes: 14)),
      isPaused: true,
    ),
  ];

  /// Queue status for [doctorId], or null when the clinic publishes none.
  static QueueStatus? queueFor(String doctorId) {
    for (final status in queueStatuses) {
      if (status.doctorId == doctorId) return status;
    }
    return null;
  }

  // ---- Emergency contacts (CM-49) ----
  static const List<EmergencyContact> emergencyContacts = [
    EmergencyContact(
      id: 'ec-1',
      name: 'Michael Johnson',
      relation: 'Husband',
      phone: '+919845612345',
      isPrimary: true,
    ),
    EmergencyContact(
      id: 'ec-2',
      name: 'Sheila Johnson',
      relation: 'Mother',
      phone: '+919847754321',
    ),
  ];

  // ---- Addresses (CM-50) ----
  static const List<Address> addresses = [
    Address(
      id: 'addr-1',
      label: 'Home',
      line1: '12 Marine Drive',
      line2: 'Apartment 4B',
      city: 'Kochi',
      state: 'Kerala',
      pincode: '682031',
      isDefault: true,
    ),
    Address(
      id: 'addr-2',
      label: 'Work',
      line1: 'Infopark Phase 1, Athulya Building',
      city: 'Kochi',
      state: 'Kerala',
      pincode: '682042',
    ),
  ];

  // ---- Ambulance providers (CM-44 … CM-46) ----
  static const List<AmbulanceProvider> ambulanceProviders = [
    AmbulanceProvider(
      name: 'Kerala 108 Ambulance Service',
      phone: '108',
      etaMinutes: 12,
      area: 'Statewide',
      isGovernment: true,
      supportsAdvancedLifeSupport: true,
    ),
    AmbulanceProvider(
      name: 'Apollo Emergency Response',
      phone: '+914842345000',
      etaMinutes: 9,
      area: 'Kakkanad',
      supportsAdvancedLifeSupport: true,
    ),
    AmbulanceProvider(
      name: 'City Care Ambulance',
      phone: '+914842456111',
      etaMinutes: 15,
      area: 'Ernakulam South',
    ),
    AmbulanceProvider(
      name: 'Lakeshore Critical Care Transport',
      phone: '+914842567222',
      etaMinutes: 18,
      area: 'Maradu',
      supportsAdvancedLifeSupport: true,
    ),
  ];

  // ---- FAQ (CM-52) ----
  static const List<FaqEntry> faqs = [
    FaqEntry(
      category: 'Booking',
      question: 'How do I book an appointment?',
      answer:
          'Pick your city and area, choose a department, then a doctor, then a '
          'date and time. Confirm the patient the appointment is for and pay, '
          'and you will get a token number and a booking reference.',
    ),
    FaqEntry(
      category: 'Booking',
      question: 'Can I book for a family member?',
      answer:
          'Yes. Add them once under Profile → Family Members, then choose them '
          'at the patient step of any booking. Their records stay under their '
          'own name.',
    ),
    FaqEntry(
      category: 'Booking',
      question: 'What does my token number mean?',
      answer:
          'Your token is your place in the doctor\'s queue for that session. '
          'The app shows which token the doctor is currently seeing, so you '
          'can judge when to leave for the clinic.',
    ),
    FaqEntry(
      category: 'Booking',
      question: 'How do I reschedule or cancel?',
      answer:
          'Open the appointment from the Appointments tab and choose '
          'Reschedule or Cancel. Rescheduling keeps your booking reference; '
          'cancelling starts a refund if you had paid online.',
    ),
    FaqEntry(
      category: 'Payments',
      question: 'Which payment methods can I use?',
      answer:
          'UPI, credit and debit cards, net banking and wallets. You can also '
          'choose Pay at Hospital and settle at the reception desk.',
    ),
    FaqEntry(
      category: 'Payments',
      question: 'When will I get my refund?',
      answer:
          'Refunds are raised as soon as a paid appointment is cancelled and '
          'usually reach your account in 5–7 working days. You can follow the '
          'status on the appointment.',
    ),
    FaqEntry(
      category: 'Payments',
      question: 'Can I get a GST invoice?',
      answer:
          'Yes. Enter your GSTIN at the payment step and the receipt will be '
          'issued with it. Receipts are available from the appointment for as '
          'long as the account exists.',
    ),
    FaqEntry(
      category: 'Records',
      question: 'How do I add a report from another hospital?',
      answer:
          'Go to Records → Upload, pick the file, choose the patient and the '
          'document type, and add a note if it helps. Uploaded documents sit '
          'alongside the ones your Medibook doctors add.',
    ),
    FaqEntry(
      category: 'Records',
      question: 'Who can see my health records?',
      answer:
          'You, and the doctor you are consulting for the duration of that '
          'appointment. Records are never shared with anyone else without your '
          'explicit consent.',
    ),
    FaqEntry(
      category: 'Account',
      question: 'How do I change my mobile number?',
      answer:
          'Profile → Edit Profile. You will be asked to verify the new number '
          'with a one-time code before the change is saved.',
    ),
  ];

  // ---- Legal documents (CM-02) ----
  //
  // Placeholder prose written to be readable and structurally complete, so the
  // legal screens can be designed and reviewed. It is NOT approved legal copy —
  // the client's counsel supplies the final text before release.
  static final List<LegalDocument> legalDocuments = [
    LegalDocument(
      slug: 'terms',
      title: 'Terms of Service',
      version: '2026.1',
      lastUpdated: _at(-45, 0),
      bodyMarkdownish: '''
These terms govern your use of the Medibook patient app. By creating an
account you agree to them. Please read them alongside our Privacy Policy.

## 1. What Medibook does
Medibook helps you find doctors and hospitals, book and manage appointments,
pay consultation fees, and keep your health records in one place. Medibook is
a booking and records platform. It does not provide medical advice, diagnosis
or treatment, and it is not a substitute for seeing a clinician.

## 2. Your account
- You must be 18 or older to hold an account. You may add family members of any
  age as dependants under your own account.
- The information you give us must be accurate. Clinical decisions may be made
  on the basis of it.
- You are responsible for keeping your password and one-time codes to yourself.
  Tell us immediately if you think someone else has used your account.

## 3. Appointments and payments
- A confirmed booking is an appointment with the doctor at the stated date,
  time and facility. Clinics run late; your token position is the authority on
  when you will be seen.
- Fees are shown in full, including taxes and any convenience fee, before you
  pay. What you see at the payment step is what is charged.
- Cancellation and refund terms are shown on the appointment before you confirm
  a cancellation.

## 4. Emergencies
Medibook is not an emergency service. If you or someone near you needs urgent
help, call 108 or go to the nearest emergency department. The ambulance numbers
in the app are provided for convenience and are not operated by Medibook.

## 5. Acceptable use
- Do not use the app to harass clinicians or other patients.
- Do not upload documents that are not yours to share.
- Do not attempt to access another person's records.

## 6. Changes
We may change these terms. If a change materially affects you we will tell you
in the app and ask you to accept the new version before you continue.

## 7. Contact
Questions about these terms: legal@medibook.app
''',
    ),
    LegalDocument(
      slug: 'privacy',
      title: 'Privacy Policy',
      version: '2026.1',
      lastUpdated: _at(-45, 0),
      bodyMarkdownish: '''
Your health data is the most sensitive information you will ever give an app.
This policy explains exactly what we collect, why, and what we will never do.

## What we collect
- **Account details** — your name, mobile number, email, date of birth and
  gender.
- **Health information** — appointments, prescriptions, lab reports and any
  document you upload, plus the allergies and blood group you record.
- **Payment information** — the amount, method and status of each payment. Card
  and UPI credentials are handled by our payment provider and never stored by
  Medibook.
- **Device information** — app version, device model and crash diagnostics.

## Why we collect it
- To book and manage your appointments and to show your token position.
- To give the doctor you are consulting the records relevant to that
  consultation.
- To take payment and issue receipts.
- To fix crashes and improve the app.

## What we never do
- We never sell your data.
- We never share your health records with advertisers, insurers or employers.
- We never put your name, contact details or health information into analytics
  events.

## Who can see your records
You, and the clinician you are consulting, for that consultation. A dependant's
records are visible to the account holder who added them. Nobody else sees your
records without your explicit, per-request consent.

## How long we keep it
Health records are kept for as long as your account exists, and for the period
Indian medical-records rules require after that. You can ask us to delete your
account at any time from Profile → Delete Account.

## Security
Data is encrypted in transit. Access tokens are held in the device keystore,
never in ordinary app storage. Access to production data is restricted and
logged.

## Your rights
You can see, correct, export or delete your data. Write to
privacy@medibook.app and we will respond within 30 days.

## Contact
Data Protection Officer: privacy@medibook.app
''',
    ),
    LegalDocument(
      slug: 'guidelines',
      title: 'User Guidelines',
      version: '2026.1',
      lastUpdated: _at(-45, 0),
      bodyMarkdownish: '''
Medibook works best when patients and clinicians can rely on each other. These
guidelines are what we ask of you.

## Before your appointment
- Arrive a little before your token is called. The app shows which token is
  being seen now.
- Bring or upload any previous reports the doctor should see.
- If your appointment requires fasting or a prepared sample, the app will tell
  you in advance — please follow it, or the test will have to be repeated.

## If you cannot make it
Cancel or reschedule as early as you can. An empty slot at short notice is a
slot another patient could not use.

## Uploading records
- Upload only documents about you or a dependant on your account.
- Photograph reports flat, in good light, with the whole page in frame.
- Do not upload anything you were asked to keep confidential by someone else.

## Talking to clinicians
Be straightforward about symptoms, medication and history, including anything
that feels embarrassing — it changes clinical decisions. Please treat clinic
staff with the courtesy you would want.

## Reviews and ratings
Rate the consultation you actually had. Do not name other patients, and do not
use a review to raise a clinical complaint — contact support instead, where it
can be acted on.

## Reporting a problem
Profile → Help & Support, or support@medibook.app. For anything urgent and
clinical, contact the facility directly or call 108.
''',
    ),
  ];

  /// A legal document by slug, or null when the slug is unknown (the
  /// `/legal/:slug` route renders the not-found state for that).
  static LegalDocument? legalBySlug(String slug) {
    for (final document in legalDocuments) {
      if (document.slug == slug) return document;
    }
    return null;
  }

  // ---- Lookups ----
  static Doctor doctorById(String id) =>
      doctors.firstWhere((d) => d.id == id, orElse: () => doctors.first);

  static Hospital hospitalById(String id) => Hospitals.byId(id);

  /// Doctors practising at [hospitalId].
  static List<Doctor> doctorsAtHospital(String hospitalId) =>
      doctors.where((d) => d.hospitalId == hospitalId).toList();

  /// Hospitals in [city], optionally narrowed to one [area].
  static List<Hospital> hospitalsIn(String city, {String? area}) => hospitals
      .where((h) => h.city == city && (area == null || h.area == area))
      .toList();

  /// A patient by id, or null.
  static Patient? patientById(String id) {
    for (final patient in patients) {
      if (patient.id == id) return patient;
    }
    return null;
  }

  /// Documents belonging to [patientId].
  static List<MedicalRecord> recordsForPatient(String patientId) =>
      records.where((r) => r.patientId == patientId).toList();

  /// The payment for [appointmentId] that matters — the settled one if there
  /// is one, otherwise the most recent attempt.
  static PaymentRecord? paymentForAppointment(String appointmentId) {
    PaymentRecord? fallback;
    for (final payment in payments) {
      if (payment.appointmentId != appointmentId) continue;
      if (payment.status.isSettled ||
          payment.status == PaymentStatus.refunded) {
        return payment;
      }
      fallback ??= payment;
    }
    return fallback;
  }
}
