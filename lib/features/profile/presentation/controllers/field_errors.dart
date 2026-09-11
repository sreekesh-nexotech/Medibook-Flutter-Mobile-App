import 'package:flutter/foundation.dart';

/// Per-field validation state shared by every form in the Profile feature
/// (CM-47 profile edit, CM-48 dependants, CM-49 emergency contacts,
/// CM-50 addresses) and by the Insurance locker's add form (CM-38).
///
/// ## The rule this type exists to enforce
///
/// Audit §3.5.4: a form must validate **on submit**, and must then
/// **re-validate a touched field while the user types**, so the error clears
/// the moment the value is actually fixed rather than on the first keystroke
/// (which hides an error that is still true) or never (which leaves a red
/// field the user has already corrected).
///
/// So the errors map always holds the *truth* about every field, recomputed on
/// every change, and [visible] decides whether the user has earned the right to
/// see it yet:
///
/// * once [submitted] is true, every error shows;
/// * before that, only fields in [touched] show — a field is touched when it
///   loses focus, or when a picker writes a value into it.
///
/// Immutable value type: the form controllers hold one of these in their state
/// so a rebuild cannot lose it.
@immutable
class FieldErrors {
  const FieldErrors({
    this.errors = const <String, String>{},
    this.touched = const <String>{},
    this.submitted = false,
  });

  /// The current error for each invalid field. A field that is valid is absent
  /// rather than mapped to null, so [isValid] is a plain emptiness check.
  final Map<String, String> errors;

  /// Fields the user has interacted with and then left.
  final Set<String> touched;

  /// True once submit has been pressed at least once.
  final bool submitted;

  /// True when nothing is wrong anywhere — the submit gate.
  bool get isValid => errors.isEmpty;

  /// The message to render under [field], or null to render none.
  String? visible(String field) {
    if (!submitted && !touched.contains(field)) return null;
    return errors[field];
  }

  /// Replaces the whole error set (a full re-validation).
  FieldErrors withErrors(Map<String, String?> next) {
    final cleaned = <String, String>{};
    next.forEach((field, message) {
      if (message != null) cleaned[field] = message;
    });
    return FieldErrors(errors: cleaned, touched: touched, submitted: submitted);
  }

  /// Records that [field] has been touched, so its error may now show.
  FieldErrors withTouched(String field) {
    if (touched.contains(field)) return this;
    return FieldErrors(
      errors: errors,
      touched: {...touched, field},
      submitted: submitted,
    );
  }

  /// Marks the form submitted, which reveals every outstanding error.
  FieldErrors withSubmitted() =>
      FieldErrors(errors: errors, touched: touched, submitted: true);
}
