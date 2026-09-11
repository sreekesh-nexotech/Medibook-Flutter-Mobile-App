import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/constants.dart';
import '../../domain/entities/appointment_token.dart';
import 'appointments_controller.dart';

/// What the search field holds ([input]) and what the results are computed
/// from ([query], debounced).
///
/// Both are kept because they answer different questions: the empty state
/// echoes what the patient typed, while the list must not re-filter on every
/// keystroke.
class AppointmentSearchState {
  const AppointmentSearchState({this.input = '', this.query = ''});

  /// Raw text in the field.
  final String input;

  /// The debounced, trimmed term the results use.
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
/// the results gone immediately, and waiting 300ms to show the empty state
/// reads as a stutter.
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

/// Appointment search state. autoDispose — a search term is transient UI state
/// and must not survive leaving the screen (QA Prompt 6).
final appointmentSearchProvider =
    StateNotifierProvider.autoDispose<
      AppointmentSearchController,
      AppointmentSearchState
    >((ref) => AppointmentSearchController());

/// Appointment search results (CM-30).
///
/// The audit finding: *"Search covers departments and doctors only.
/// Appointments cannot be searched by doctor, hospital or booking ID."* So the
/// haystack for one appointment is its doctor (name, specialisation,
/// department), its hospital, the patient it was booked for, its canonical
/// token and — the identifier a patient actually quotes on the phone — its
/// booking reference.
///
/// Punctuation is ignored for the two coded fields, so `mb2026000124` finds
/// `MB-2026-000124` and `t025`, `T-025` and plain `25` all find token `T-025`.
final appointmentSearchResultsProvider =
    Provider.autoDispose<List<AppointmentRow>>((ref) {
      final query = ref.watch(appointmentSearchProvider.select((s) => s.query));
      final rows = ref.watch(appointmentRowsProvider);
      if (query.isEmpty) return const <AppointmentRow>[];

      final term = query.toLowerCase();
      final compactTerm = _compact(term);

      return rows.where((row) {
        final appointment = row.appointment;
        final token = AppointmentToken.normalize(appointment.token);
        final words =
            '${row.doctor.name} ${row.doctor.spec} ${row.doctor.department} '
                    '${row.hospitalName} ${appointment.patient} '
                    '${appointment.bookingRef ?? ''} $token'
                .toLowerCase();
        if (words.contains(term)) return true;

        if (compactTerm.isEmpty) return false;
        final codes = _compact(
          '${appointment.bookingRef ?? ''} $token ${appointment.token}'
              .toLowerCase(),
        );
        return codes.contains(compactTerm);
      }).toList();
    });

/// Lowercase alphanumerics only — `'MB-2026-000124'` → `'mb2026000124'`.
String _compact(String value) => value.replaceAll(RegExp('[^a-z0-9]'), '');
