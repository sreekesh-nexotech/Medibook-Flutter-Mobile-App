import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/application/providers/auth_provider.dart';

/// The categories the "raise a request" form offers. Local to this feature —
/// there is no seed for support categories, and the core layer is closed.
abstract final class SupportRequestCategories {
  SupportRequestCategories._();

  static const String booking = 'Booking or appointment';
  static const String payment = 'Payment or refund';
  static const String records = 'Health records';
  static const String account = 'Account and sign-in';
  static const String other = 'Something else';

  static const List<String> all = [booking, payment, records, account, other];
}

/// Field keys for [SupportRequestState.errors].
abstract final class SupportRequestField {
  SupportRequestField._();

  static const String category = 'category';
  static const String subject = 'subject';
  static const String details = 'details';
  static const String email = 'email';
}

/// Form state for the support request form on `/support` (CM-52).
///
/// The values live here rather than in the widget so the controller can own
/// validation, dirtiness and the submit rule, and the screen stays a pure
/// read-and-call surface (Coding Standards §2.2).
@immutable
class SupportRequestState {
  const SupportRequestState({
    required this.email,
    this.category = SupportRequestCategories.booking,
    this.subject = '',
    this.details = '',
    this.errors = const <String, String?>{},
    this.submitted = false,
  });

  final String category;
  final String subject;
  final String details;

  /// Where the reply should go. Seeded from the signed-in account.
  final String email;

  /// Per-field error messages, keyed by [SupportRequestField]. A key is absent
  /// (or null) when the field is valid.
  final Map<String, String?> errors;

  /// True once the user has pressed the submit button at least once — after
  /// that, a touched field re-validates on every keystroke so its error clears
  /// the moment it is actually fixed (audit §3.5.4).
  final bool submitted;

  String? errorFor(String field) => errors[field];

  bool get hasErrors => errors.values.any((e) => e != null);

  bool get isBlank => subject.trim().isEmpty && details.trim().isEmpty;

  SupportRequestState copyWith({
    String? category,
    String? subject,
    String? details,
    String? email,
    Map<String, String?>? errors,
    bool? submitted,
  }) {
    return SupportRequestState(
      category: category ?? this.category,
      subject: subject ?? this.subject,
      details: details ?? this.details,
      email: email ?? this.email,
      errors: errors ?? this.errors,
      submitted: submitted ?? this.submitted,
    );
  }
}

class SupportRequestController extends StateNotifier<SupportRequestState> {
  SupportRequestController({required String email})
    : super(SupportRequestState(email: email));

  void setCategory(String value) {
    state = state.copyWith(category: value);
    _revise(SupportRequestField.category, _categoryError(value));
  }

  void setSubject(String value) {
    state = state.copyWith(subject: value);
    _revise(SupportRequestField.subject, _subjectError(value));
  }

  void setDetails(String value) {
    state = state.copyWith(details: value);
    _revise(SupportRequestField.details, _detailsError(value));
  }

  void setEmail(String value) {
    state = state.copyWith(email: value);
    _revise(SupportRequestField.email, Validators.email(value));
  }

  /// Validates everything and marks the form submitted. Returns true when the
  /// request is complete enough to send.
  bool validate() {
    final errors = <String, String?>{
      SupportRequestField.category: _categoryError(state.category),
      SupportRequestField.subject: _subjectError(state.subject),
      SupportRequestField.details: _detailsError(state.details),
      SupportRequestField.email: Validators.email(state.email),
    };
    state = state.copyWith(errors: errors, submitted: true);
    return !state.hasErrors;
  }

  /// Re-validates one field, but only once the form has been submitted — so a
  /// half-typed subject is not marked wrong while the user is still typing it.
  void _revise(String field, String? error) {
    if (!state.submitted) return;
    final errors = Map<String, String?>.of(state.errors);
    errors[field] = error;
    state = state.copyWith(errors: errors);
  }

  static String? _categoryError(String value) =>
      value.trim().isEmpty ? 'Choose what this is about' : null;

  static String? _subjectError(String value) =>
      Validators.requiredField('a short subject', value);

  static String? _detailsError(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Tell us what happened';
    if (trimmed.length < 20) {
      return 'Add a little more detail so we can help (at least 20 characters)';
    }
    return null;
  }
}

/// autoDispose — the draft belongs to one visit to the support screen.
///
/// The reply address is *read*, not watched: seeding it once is the point, and
/// watching would rebuild the controller (throwing away the user's draft) if
/// the account's email changed while the form was open.
final supportRequestControllerProvider =
    StateNotifierProvider.autoDispose<
      SupportRequestController,
      SupportRequestState
    >((ref) {
      final user = ref.read(currentUserProvider);
      return SupportRequestController(
        email: user?.email ?? ref.read(userEmailProvider),
      );
    });
