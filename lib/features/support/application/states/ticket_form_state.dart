import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/support_ticket.dart';

/// Field keys for [TicketFormState.errors]. The values are the **wire** field
/// names, so a server `VALIDATION_ERROR` lands on the matching field with no
/// translation table.
abstract final class TicketFormField {
  TicketFormField._();

  static const String category = 'category';
  static const String subject = 'subject';
  static const String description = 'description';
  static const String priority = 'priority';
}

/// The "raise a request" form (§13 `POST /patient/support/tickets`).
///
/// Validation follows audit §3.5.4: errors are recomputed on every change and
/// shown once submit has been pressed, so an error clears the moment the value
/// is actually right.
@immutable
class TicketFormState {
  const TicketFormState({
    this.category = TicketCategory.other,
    this.subject = '',
    this.description = '',
    this.priority,
    this.errors = const <String, String>{},
    this.submitted = false,
    this.isSending = false,
    this.failure,
    this.created,
  });

  final TicketCategory category;
  final String subject;
  final String description;

  /// Optional; the server defaults to `normal`.
  final TicketPriority? priority;

  /// Field → message for every field that is currently invalid.
  final Map<String, String> errors;

  /// True once submit has been pressed at least once.
  final bool submitted;

  final bool isSending;

  /// The last non-field failure (offline, rate limited, server), or null.
  final Failure? failure;

  /// Set once the ticket exists on the server — the screen navigates to it.
  final SupportTicket? created;

  String? errorFor(String field) => submitted ? errors[field] : null;

  bool get isValid => errors.isEmpty;

  bool get isDirty =>
      subject.trim().isNotEmpty || description.trim().isNotEmpty;

  TicketFormState copyWith({
    TicketCategory? category,
    String? subject,
    String? description,
    TicketPriority? priority,
    bool clearPriority = false,
    Map<String, String>? errors,
    bool? submitted,
    bool? isSending,
    Failure? failure,
    bool clearFailure = false,
    SupportTicket? created,
  }) {
    return TicketFormState(
      category: category ?? this.category,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      priority: clearPriority ? null : (priority ?? this.priority),
      errors: errors ?? this.errors,
      submitted: submitted ?? this.submitted,
      isSending: isSending ?? this.isSending,
      failure: clearFailure ? null : (failure ?? this.failure),
      created: created ?? this.created,
    );
  }
}
