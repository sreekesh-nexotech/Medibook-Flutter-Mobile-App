import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/constants.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../domain/entities/search_results.dart';
import '../../domain/repositories/search_repository.dart';
import '../../../../core/network/api_client.dart';

/// The search repository — abstract type, so tests override it.
final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) =>
      throw UnimplementedError('searchRepositoryProvider is wired in app/di'),
);

/// The backend's bounds on `q` (§7.9). Anything outside them is never sent.
abstract final class SearchQueryRules {
  SearchQueryRules._();

  static const int minLength = 2;
  static const int maxLength = 100;

  /// The query the endpoint will accept, or null when [input] is too short.
  /// Over-long input is truncated rather than refused.
  static String? normalise(String input) {
    final trimmed = input.trim();
    if (trimmed.length < minLength) return null;
    return trimmed.length > maxLength
        ? trimmed.substring(0, maxLength)
        : trimmed;
  }
}

/// What the search field holds ([input]) and what the results are fetched
/// for ([query], debounced and validated).
class SearchState {
  const SearchState({this.input = '', this.query});

  /// Raw text in the field.
  final String input;

  /// The debounced, normalised term the results use — null when nothing
  /// sendable has settled yet.
  final String? query;

  bool get hasInput => input.trim().isNotEmpty;

  bool get hasQuery => query != null;

  /// The field has text the endpoint would refuse (one character).
  bool get isTooShort => hasInput && SearchQueryRules.normalise(input) == null;

  /// True while the debounce has not caught up — the moment to show a quiet
  /// loader rather than "no results".
  bool get isSettling =>
      hasInput && !isTooShort && SearchQueryRules.normalise(input) != query;

  SearchState copyWith({String? input, String? Function()? query}) =>
      SearchState(
        input: input ?? this.input,
        query: query != null ? query() : this.query,
      );
}

/// Debounces the search input by [AppConstants.searchDebounce] and only
/// publishes a [SearchState.query] the endpoint will accept.
///
/// Clearing the field is *not* debounced: a patient who empties the box
/// wants the idle screen back immediately.
class SearchQueryController extends StateNotifier<SearchState> {
  SearchQueryController({Duration? debounce})
    : _debounce = debounce ?? AppConstants.searchDebounce,
      super(const SearchState());

  final Duration _debounce;
  Timer? _timer;

  void onInput(String value) {
    _timer?.cancel();
    final normalised = SearchQueryRules.normalise(value);
    if (value.trim().isEmpty) {
      state = const SearchState();
      return;
    }
    // Keep the last good query while typing so the list does not flicker.
    state = state.copyWith(input: value);
    if (normalised == null) {
      state = state.copyWith(query: () => null);
      return;
    }
    _timer = Timer(_debounce, () {
      if (!mounted) return;
      state = state.copyWith(query: () => normalised);
    });
  }

  /// Run a term at once (a recent-search chip).
  void submit(String value) {
    _timer?.cancel();
    state = SearchState(input: value, query: SearchQueryRules.normalise(value));
  }

  void clear() {
    _timer?.cancel();
    state = const SearchState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Search state. autoDispose — a search term is transient UI state.
final searchQueryProvider =
    StateNotifierProvider.autoDispose<SearchQueryController, SearchState>(
      (ref) => SearchQueryController(),
    );

/// `GET /patient/search?q=` for the settled query. autoDispose family keyed
/// on the term, so going back to a previous term is instant while the
/// screen is open.
final searchResultsProvider = FutureProvider.autoDispose
    .family<SearchResults, String>(
      (ref, query) => guardedRead(
        'search',
        () => ref.watch(searchRepositoryProvider).search(query),
      ),
    );

/// Recent searches, newest first, at most six. Session state (not
/// autoDispose): kept while the app is open. Starts empty — nothing is
/// invented.
final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesController, List<String>>((ref) {
      // Per account: signing out (or in as someone else) starts empty, so
      // the next person on this phone does not see the last one's searches
      // (QA Prompt 2 #21).
      ref.watch(currentUserProvider.select((u) => u?.id));
      return RecentSearchesController();
    });

class RecentSearchesController extends StateNotifier<List<String>> {
  RecentSearchesController() : super(const []);

  static const int _max = 6;

  void remember(String term) {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    state = [
      trimmed,
      ...state.where((r) => r.toLowerCase() != trimmed.toLowerCase()),
    ].take(_max).toList();
  }

  void clear() => state = const [];
}
