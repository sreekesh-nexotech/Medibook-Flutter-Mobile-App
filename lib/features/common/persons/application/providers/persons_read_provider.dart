import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/error/failure.dart';
import '../../domain/entities/person_summary.dart';
import '../../domain/repositories/persons_read_repository.dart';

/// The read-only persons repository. Returns the abstract type so tests can
/// `overrideWithValue(FakePersonsReadRepository())`.
final personsReadRepositoryProvider = Provider<PersonsReadRepository>(
  (ref) => throw UnimplementedError(
    'personsReadRepositoryProvider is wired in app/di',
  ),
);

/// Everyone on the account, "self" first — for the "whose document" and
/// "whose policy" pickers. `autoDispose`: only pickers watch it, and a family
/// member added on Profile must show on the next visit.
///
/// Throws the mapped [Failure]; `AsyncValue.error` carries it to the UI.
final personSummariesProvider = FutureProvider.autoDispose<List<PersonSummary>>(
  (ref) async {
    try {
      return await ref.watch(personsReadRepositoryProvider).persons();
    } catch (error, stackTrace) {
      throw error.asFailure(stackTrace);
    }
  },
);
