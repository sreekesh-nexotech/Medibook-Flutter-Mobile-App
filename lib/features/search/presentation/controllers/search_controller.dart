import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/constants.dart';
import '../../../../core/mock_data/models/department.dart';
import '../../../../core/mock_data/models/doctor.dart';
import '../../../../core/mock_data/models/hospital.dart';
import '../../../../core/mock_data/seed_providers.dart';

/// What the search field holds ([input]) and what the results are computed
/// from ([query], debounced).
///
/// Both are kept because they answer different questions: the empty state
/// echoes what the patient typed, while the result lists must not re-filter on
/// every keystroke.
class SearchState {
  const SearchState({this.input = '', this.query = ''});

  /// Raw text in the field.
  final String input;

  /// The debounced, trimmed term the results use.
  final String query;

  bool get hasInput => input.trim().isNotEmpty;

  bool get hasQuery => query.isNotEmpty;

  /// True while the debounce has not caught up — the moment to show a quiet
  /// loader rather than "no results".
  bool get isSettling => input.trim() != query;

  SearchState copyWith({String? input, String? query}) =>
      SearchState(input: input ?? this.input, query: query ?? this.query);
}

/// Debounces search input by [AppConstants.searchDebounce].
///
/// Clearing the field is *not* debounced: a patient who empties the box wants
/// the full directory back immediately, and waiting 300ms for it reads as a
/// stutter.
class SearchController extends StateNotifier<SearchState> {
  SearchController() : super(const SearchState());

  Timer? _debounce;

  void onInput(String value) {
    state = state.copyWith(input: value);
    _debounce?.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = const SearchState();
      return;
    }

    _debounce = Timer(AppConstants.searchDebounce, () {
      if (!mounted) return;
      state = state.copyWith(query: trimmed);
    });
  }

  void clear() {
    _debounce?.cancel();
    state = const SearchState();
  }

  @override
  void dispose() {
    // A pending timer that fires after disposal would touch a dead notifier.
    _debounce?.cancel();
    super.dispose();
  }
}

/// Search state. `autoDispose` — a search term is transient UI state and must
/// not survive leaving the screen.
final searchProvider =
    StateNotifierProvider.autoDispose<SearchController, SearchState>(
      (ref) => SearchController(),
    );

/// The three result groups, in the order the screen renders them.
///
/// Grouping is explicit rather than one mixed list: "Cardiology" the department
/// and "Apollo Hospital" the facility are different kinds of answer and lead to
/// different next steps (pick a doctor vs. browse a facility), so conflating
/// them makes the list harder to act on.
class SearchResults {
  const SearchResults({
    required this.departments,
    required this.doctors,
    required this.hospitals,
  });

  final List<Department> departments;
  final List<Doctor> doctors;
  final List<Hospital> hospitals;

  int get total => departments.length + doctors.length + hospitals.length;

  bool get isEmpty => total == 0;
}

/// Search results across **departments, doctors and hospitals**.
///
/// The audit finding was *"Search covers departments and doctors only"* — so
/// hospitals are matched here too, on name, area, city, address and the
/// departments they offer, which is what makes a location-first search
/// ("Whitefield", "Mysuru", "Sunrise") work.
///
/// Each haystack is deliberately wider than the obvious field:
///
/// * a **department** matches its name and its sub-label, so "heart" finds
///   Cardiology;
/// * a **doctor** matches name, specialisation, department, that department's
///   sub-label and their hospital, so "skin" finds the dermatologist and
///   "Apollo" finds everyone practising there;
/// * a **hospital** matches name, area, city, address and its department list.
///
/// An empty query returns the whole directory, which is the browse state the
/// screen opens in.
final searchResultsProvider = Provider.autoDispose<SearchResults>((ref) {
  final query = ref.watch(searchProvider.select((s) => s.query)).toLowerCase();
  final departments = ref.watch(departmentsProvider);
  final doctors = ref.watch(doctorsProvider);
  final hospitals = ref.watch(hospitalsProvider);

  if (query.isEmpty) {
    return SearchResults(
      departments: departments,
      doctors: doctors,
      hospitals: hospitals,
    );
  }

  final subByName = {for (final d in departments) d.name: d.sub};

  return SearchResults(
    departments: [
      for (final department in departments)
        if ('${department.name} ${department.sub}'.toLowerCase().contains(
          query,
        ))
          department,
    ],
    doctors: [
      for (final doctor in doctors)
        if ('${doctor.name} ${doctor.spec} ${doctor.department} '
                '${subByName[doctor.department] ?? ''} ${doctor.hospital}'
            .toLowerCase()
            .contains(query))
          doctor,
    ],
    hospitals: [
      for (final hospital in hospitals)
        if ('${hospital.name} ${hospital.area} ${hospital.city} '
                '${hospital.address} ${hospital.departments.join(' ')}'
            .toLowerCase()
            .contains(query))
          hospital,
    ],
  );
});
