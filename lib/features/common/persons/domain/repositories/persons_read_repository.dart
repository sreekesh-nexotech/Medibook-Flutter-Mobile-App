import '../entities/person_summary.dart';

/// Read-only access to the account's persons (§6.1) for pickers.
///
/// Errors are thrown as `Failure` (`core/error/failure.dart`) — never a raw
/// exception. Writes live in the profile feature, not here.
abstract interface class PersonsReadRepository {
  /// `GET /patient/me/persons`, "self" first. Served through the three-layer
  /// cache; [forceRefresh] skips the cached copy for the first answer.
  Future<List<PersonSummary>> persons({bool forceRefresh = false});
}
