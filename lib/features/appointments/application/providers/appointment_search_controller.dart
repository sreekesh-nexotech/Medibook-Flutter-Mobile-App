import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/constants.dart';
import '../../domain/entities/appointment_filter.dart';

/// What the search field holds ([input]) and what the results are computed
/// from ([query], debounced).
///
/// Both are kept because they answer different questions: the empty state
/// echoes what the patient typed, while the request must not fire on every
/// keystroke.
class AppointmentSearchState {
  const AppointmentSearchState({this.input = '', this.query = ''});

  /// Raw text in the field.
  final String input;

  /// The debounced, trimmed term the request uses (`q=`).
  final String query;

  bool get hasInput => input.trim().isNotEmpty;

  bool get hasQuery => query.isNotEmpty;

  /// True while the debounce has not caught up — the moment to show a quiet
  /// loader rather than "no results".
  bool get isSettling => input.trim() != query;

  AppointmentSearchState copyWith({String? input, String? query}) =>
      AppointmentSearchState(
        input: input ?? this.input,
        query: query ?? this.query,
      );
}

/// Debounces appointment search input by [AppConstants.searchDebounce].
///
/// Clearing the field is *not* debounced: a patient who empties the box wants
/// the results gone immediately.
class AppointmentSearchController
    extends StateNotifier<AppointmentSearchState> {
  AppointmentSearchController() : super(const AppointmentSearchState());

  Timer? _debounce;

  void onInput(String value) {
    state = state.copyWith(input: value);
    _debounce?.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = const AppointmentSearchState();
      return;
    }

    _debounce = Timer(AppConstants.searchDebounce, () {
      if (!mounted) return;
      state = state.copyWith(query: trimmed);
    });
  }

  void clear() {
    _debounce?.cancel();
    state = const AppointmentSearchState();
  }

  @override
  void dispose() {
    // A pending timer that fires after disposal would touch a dead notifier.
    _debounce?.cancel();
    super.dispose();
  }
}

/// Appointment search state. autoDispose — a search term is transient UI
/// state and must not survive leaving the screen (QA Prompt 6).
final appointmentSearchProvider =
    StateNotifierProvider.autoDispose<
      AppointmentSearchController,
      AppointmentSearchState
    >((ref) => AppointmentSearchController());

/// The request the current search term makes (§10.1 `q`: booking ref,
/// token label, doctor, hospital, or the person's name — matched by the
/// backend across every bucket). Null while there is no settled term.
final appointmentSearchQueryProvider =
    Provider.autoDispose<AppointmentListQuery?>((ref) {
      final query = ref.watch(appointmentSearchProvider.select((s) => s.query));
      return query.isEmpty ? null : AppointmentListQuery(q: query);
    });
