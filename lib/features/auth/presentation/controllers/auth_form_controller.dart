import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';

/// Validation state for one auth form.
///
/// Field *text* still lives in the screen's [TextEditingController]s (the house
/// rule the original controllers set out); this holds only the transient error
/// strings, which fields the user has already dealt with, whether a submit is
/// in flight, and the form-level [failure].
///
/// ## Why [touched] exists (audit §3.5.4)
///
/// The audit found that *"validation runs only on submit, then gives up. The
/// error clears on the first keystroke and is never rechecked, so the user is
/// never told they have fixed it."* Clearing the error blindly is what made
/// that happen. The fix is to remember that a field has been dealt with — by
/// submitting the form or by leaving the field with something typed in it —
/// and from then on re-run that field's validator on every keystroke. The
/// error then disappears the moment the value is actually valid, and not
/// before.
@immutable
class AuthFormState {
  const AuthFormState({
    this.errors = const <String, String>{},
    this.touched = const <String>{},
    this.submitted = false,
    this.isBusy = false,
    this.failure,
  });

  /// Field name → message. Only failing fields appear, so a missing key means
  /// "valid", and [errorOf] can hand the value straight to an `errorText` slot.
  final Map<String, String> errors;

  /// Fields whose validator is now live on every keystroke.
  final Set<String> touched;

  /// True once the form has been submitted at least once.
  final bool submitted;

  /// True while the submit action is running — the button's `loading` flag,
  /// which is also what blocks a second tap (audit §3.5.6).
  final bool isBusy;

  /// A form-level problem: a rejected credential, a network error, a lockout.
  /// Rendered once above the fields, not against any single field.
  final Failure? failure;

  /// The message for [field], or null when it is valid.
  String? errorOf(String field) => errors[field];

  /// Whether [field]'s validator should run on every keystroke now.
  bool isTouched(String field) => submitted || touched.contains(field);

  bool get hasErrors => errors.isNotEmpty;

  AuthFormState copyWith({
    Map<String, String>? errors,
    Set<String>? touched,
    bool? submitted,
    bool? isBusy,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AuthFormState(
      errors: errors ?? this.errors,
      touched: touched ?? this.touched,
      submitted: submitted ?? this.submitted,
      isBusy: isBusy ?? this.isBusy,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuthFormState &&
      mapEquals(other.errors, errors) &&
      setEquals(other.touched, touched) &&
      other.submitted == submitted &&
      other.isBusy == isBusy &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(
      errors.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(touched),
    submitted,
    isBusy,
    failure,
  );

  @override
  String toString() =>
      'AuthFormState(errors: $errors, touched: $touched, '
      'submitted: $submitted, busy: $isBusy, failure: ${failure?.code})';
}

/// Base class for every auth form controller.
///
/// Subclasses supply two things and nothing else:
///
/// * [validateField] — the `Validators` call for each of their field keys;
/// * a typed `validate(...)` entry point that assembles the submitted values
///   and calls [validateAll], so screens never pass loose maps around.
///
/// Everything the five auth forms share — the touched/re-validate rule, the
/// busy flag, the form-level failure slot — lives here once. Keeping it in one
/// place is the point: the audit finding was a *pattern*, so a per-screen fix
/// would have left the next form free to repeat it.
abstract class AuthFormController extends StateNotifier<AuthFormState> {
  AuthFormController() : super(const AuthFormState());

  /// Validate [field]'s current [value]; null when valid.
  @protected
  String? validateField(String field, String value);

  /// Call from `onChanged`. Re-checks the field only once it has been dealt
  /// with, so the user is not corrected mid-word on their first attempt but is
  /// told as soon as an existing error is fixed.
  void onChanged(String field, String value) {
    if (!state.isTouched(field)) return;
    _setError(field, validateField(field, value));
  }

  /// Call when [field] loses focus.
  ///
  /// A field the user merely tabbed through and left empty is not an error
  /// yet — only a submit makes emptiness a problem — so an untouched empty
  /// field is left alone. Anything with content is validated on the way out.
  void onBlur(String field, String value) {
    if (value.trim().isEmpty &&
        !state.submitted &&
        state.errorOf(field) == null) {
      return;
    }
    state = state.copyWith(touched: <String>{...state.touched, field});
    _setError(field, validateField(field, value));
  }

  /// Validate every submitted field at once. Returns true when the form is
  /// valid. Marks the form submitted, so from here on every one of these
  /// fields re-validates as it is edited.
  @protected
  bool validateAll(Map<String, String> values) {
    final errors = <String, String>{};
    for (final entry in values.entries) {
      final error = validateField(entry.key, entry.value);
      if (error != null) errors[entry.key] = error;
    }
    state = state.copyWith(
      errors: errors,
      touched: <String>{...state.touched, ...values.keys},
      submitted: true,
      clearFailure: true,
    );
    return errors.isEmpty;
  }

  /// Attach a message to [field] from outside the validators — a server's
  /// field-level rejection, or a rule only the submit path knows (a wrong
  /// current password, an unknown email).
  void setFieldError(String field, String message) {
    state = state.copyWith(touched: <String>{...state.touched, field});
    _setError(field, message);
  }

  /// True while the submit action runs; drives `AppButton.loading`.
  void setBusy(bool value) {
    if (state.isBusy == value) return;
    state = state.copyWith(isBusy: value);
  }

  /// Show (or clear, with null) the form-level failure.
  void setFailure(Failure? failure) {
    state = failure == null
        ? state.copyWith(clearFailure: true)
        : state.copyWith(failure: failure);
  }

  /// Drop the form-level failure only — field errors survive, because the user
  /// editing one field does not make the others correct.
  void clearFailure() {
    if (state.failure == null) return;
    state = state.copyWith(clearFailure: true);
  }

  /// Back to a pristine form. Used when a screen switches between two sets of
  /// fields (the Email / Mobile tabs on sign-in and reset), where leaving the
  /// other tab's errors on screen would be nonsense.
  void reset() => state = const AuthFormState();

  void _setError(String field, String? message) {
    final next = Map<String, String>.of(state.errors);
    if (message == null) {
      if (next.remove(field) == null) return;
    } else {
      if (next[field] == message) return;
      next[field] = message;
    }
    state = state.copyWith(errors: next);
  }
}
