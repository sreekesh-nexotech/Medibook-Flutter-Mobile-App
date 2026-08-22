import 'package:flutter/material.dart';

import 'models/app_notification.dart';
import 'models/appointment.dart';
import 'models/department.dart';
import 'models/doctor.dart';
import 'models/medical_record.dart';
import 'models/patient.dart';
import 'models/promo_banner.dart';
import '../widgets/app_icon.dart';

/// ============================================================================
/// STATIC SEED DATA — REPLACE WITH API RESPONSES
/// ----------------------------------------------------------------------------
/// Every list below mirrors exactly what the design prototype shows
/// (`Medibook App.dc.html`). It is surfaced to screens through the read
/// providers in `seed_providers.dart` and the controllers under each feature.
///
/// When the data/domain layers are built, this file is the single swap-point:
/// the read providers change their body to call feature repositories, these
/// UI models are replaced by domain entities, and this file is deleted. No
/// screen references [MedibookSeed] directly — they read providers — so the
/// swap is isolated here.
/// ============================================================================
abstract final class MedibookSeed {
  MedibookSeed._();

  // ---- Current user (Profile / Home greeting) ----
  static const String userName = 'Alexandra Johnson';
  static const String userFirstName = 'Alexandra';
  static const String userEmail = 'alexandra.johnson@example.com';

  static const List<({String key, String value})> profileInfo = [
    (key: 'Phone', value: '+91 98456 58525'),
    (key: 'Date of Birth', value: '15/05/1997'),
    (key: 'Gender', value: 'Female'),
    (key: 'Blood Group', value: 'O+'),
  ];

  // ---- Departments ----
  static const List<Department> departments = [
    Department(name: 'General', sub: 'Primary healthcare', iconName: MedIcon.records),
    Department(name: 'Cardiology', sub: 'Heart specialists', iconName: MedIcon.star),
    Department(name: 'Orthopedics', sub: 'Bone & joint care', iconName: MedIcon.hospital),
    Department(name: 'Dermatology', sub: 'Skin specialists', iconName: MedIcon.eye),
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
      fee: '₹900',
      hospital: 'Apollo Hospital',
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
      fee: '₹700',
      hospital: 'City Care Clinic',
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
      fee: '₹500',
      hospital: 'Apollo Hospital',
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
      fee: '₹450',
      hospital: 'City Care Clinic',
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
      fee: '₹800',
      hospital: 'Apollo Hospital',
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
      fee: '₹650',
      hospital: 'City Care Clinic',
      about:
          'Dermatologist treating acne, hair loss and skin allergies with '
          'evidence-first care plans.',
    ),
  ];

  // ---- Patients (self + family) ----
  static const List<Patient> patients = [
    Patient(name: 'Alexandra Johnson', meta: '29 years · Female', relation: 'Self'),
    Patient(name: 'Michael Johnson', meta: '34 years · Male', relation: 'Husband'),
    Patient(name: 'Ava Johnson', meta: '6 years · Female', relation: 'Daughter'),
  ];

  // ---- Time slots ----
  static const List<String> timeSlots = [
    '09:00 AM',
    '10:00 AM',
    '11:30 AM',
    '12:15 PM',
    '02:00 PM',
    '04:30 PM',
  ];

  // ---- Records ----
  static const List<MedicalRecord> records = [
    MedicalRecord(
      title: 'Blood Test Report',
      date: '10 Jul 2026',
      status: RecordStatus.completed,
      patient: 'Alexandra Johnson',
      hospital: 'Apollo Hospital',
      doctor: 'Dr. Anil Kumar',
    ),
    MedicalRecord(
      title: 'Full Body Checkup',
      date: '02 Jul 2026',
      status: RecordStatus.pending,
      patient: 'Michael Johnson',
      hospital: 'Apollo Hospital',
      doctor: 'Dr. Meera Nair',
    ),
    MedicalRecord(
      title: 'Lipid Profile',
      date: '21 Jun 2026',
      status: RecordStatus.completed,
      patient: 'Alexandra Johnson',
      hospital: 'City Care Clinic',
      doctor: 'Dr. Rohan Kapoor',
    ),
  ];

  // ---- Notifications ----
  static const List<AppNotification> notifications = [
    AppNotification(
      title: 'Fasting Reminder',
      body:
          'Your Full Body Checkup requires fasting. Please avoid food and '
          'drinks (except water) for 8–12 hours before your sample collection '
          'at 8:00 AM tomorrow.',
      ago: '2 hours ago',
    ),
    AppNotification(
      title: 'Appointment Reminder',
      body:
          'Your appointment with Dr. Priya Mehta is scheduled for today at '
          '10:30 AM.',
      ago: '2 hours ago',
      action1Label: 'Reschedule',
      action1: NotificationAction.rescheduleTodayAppt,
      action2Label: 'View Details',
      action2: NotificationAction.viewTodayApptDetail,
    ),
    AppNotification(
      title: 'Prescription Ready',
      body:
          'Your prescription from Dr. Anil Kumar is now available for download.',
      ago: '5 hours ago',
      action1Label: 'View Details',
      action1: NotificationAction.viewRecords,
      action2Label: 'Download',
      action2: NotificationAction.downloadPrescription,
    ),
    AppNotification(
      title: 'Vaccination Due',
      body:
          "Ava's next vaccination is due in 2 weeks. Schedule an appointment "
          'now.',
      ago: '2 days ago',
      action1Label: 'Remind Later',
      action1: NotificationAction.remindLater,
      action2Label: 'Schedule',
      action2: NotificationAction.scheduleBooking,
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
  static List<Appointment> initialAppointments() => const [
    Appointment(
      id: '1',
      doctorId: 'priya',
      patient: 'Alexandra Johnson',
      date: 'Today',
      time: '10:30 AM',
      token: 'A-25',
      status: AppointmentStatus.confirmed,
      bucket: AppointmentBucket.upcoming,
    ),
    Appointment(
      id: '2',
      doctorId: 'anil',
      patient: 'Michael Johnson',
      date: '12 Aug 2026',
      time: '09:00 AM',
      token: 'A-12',
      status: AppointmentStatus.confirmed,
      bucket: AppointmentBucket.upcoming,
    ),
    Appointment(
      id: '3',
      doctorId: 'anya',
      patient: 'Alexandra Johnson',
      date: '21 Jul 2026',
      time: '11:30 AM',
      token: 'A-08',
      status: AppointmentStatus.completed,
      bucket: AppointmentBucket.past,
    ),
    Appointment(
      id: '4',
      doctorId: 'anil',
      patient: 'Ava Johnson',
      date: '02 Jun 2026',
      time: '02:00 PM',
      token: 'A-19',
      status: AppointmentStatus.cancelled,
      bucket: AppointmentBucket.past,
    ),
  ];

  // ---- Lookups ----
  static Doctor doctorById(String id) =>
      doctors.firstWhere((d) => d.id == id, orElse: () => doctors.first);
}
