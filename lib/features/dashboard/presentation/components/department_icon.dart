import '../../../../core/widgets/app_icon.dart';

/// The design-system mark for a department code; the generic mark for
/// anything the design has no glyph for.
String departmentIconFor(String code) => switch (code) {
  'cardiology' => DeptIcon.cardiology,
  'orthopaedics' || 'orthopedics' => DeptIcon.orthopedics,
  'dermatology' => DeptIcon.dermatology,
  'gynaecology' || 'gynecology' || 'obstetrics' => DeptIcon.womensHealth,
  'paediatrics' || 'pediatrics' => DeptIcon.paediatrics,
  'ent' => DeptIcon.ent,
  'psychiatry' || 'mental_health' => DeptIcon.mentalWellness,
  'ophthalmology' => DeptIcon.eyeCare,
  'dental' || 'dentistry' => DeptIcon.dental,
  'neurology' => DeptIcon.neurology,
  'pulmonology' => DeptIcon.pulmonology,
  'gastroenterology' => DeptIcon.gastroenterology,
  'nephrology' => DeptIcon.nephrology,
  'urology' => DeptIcon.urology,
  'endocrinology' => DeptIcon.endocrinology,
  _ => DeptIcon.general,
};
