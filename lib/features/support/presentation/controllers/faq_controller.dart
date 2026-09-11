import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/constants.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/mock_data/models/support_content.dart';
import '../../../../core/mock_data/seed_providers.dart';

/// One FAQ category with the entries that matched the current search.
typedef FaqSection = ({String category, List<FaqEntry> entries});

/// Search + expand/collapse state for the FAQ screen (`/faq`), plus the
/// load/refresh lifecycle the list's loading and error states render.
///
/// ## On [isLoading] and [failure]
///
/// This build has no network: `faqsProvider` is a synchronous read over the
/// seed. The loading and error paths still exist here, and are still on the
/// real path rather than dead branches, because they are the seam the data
/// layer lands on — when `faqsProvider` becomes a repository call, only
/// [_fetch] changes. The one-off delay is what makes the skeleton state
/// reachable today; it is a UI placeholder, and nothing in the screen claims
/// that anything was downloaded.
@immutable
class FaqState {
  const FaqState({
    this.query = '',
    this.expanded = const <String>{},
    this.isLoading = true,
    this.isRefreshing = false,
    this.failure,
  });

  /// The current search text, trimmed on use but stored verbatim so the field
  /// does not fight the user's spaces.
  final String query;

  /// Questions currently expanded, keyed by question text.
  final Set<String> expanded;

  final bool isLoading;
  final bool isRefreshing;

  /// Non-null when the last load or refresh failed.
  final Failure? failure;

  bool get hasQuery => query.trim().isNotEmpty;

  bool isExpanded(String question) => expanded.contains(question);

  FaqState copyWith({
    String? query,
    Set<String>? expanded,
    bool? isLoading,
    bool? isRefreshing,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return FaqState(
      query: query ?? this.query,
      expanded: expanded ?? this.expanded,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class FaqController extends StateNotifier<FaqState> {
  FaqController() : super(const FaqState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      await _fetch();
      if (!mounted) return;
      state = state.copyWith(isLoading: false, clearFailure: true);
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        failure: error.asFailure(stackTrace),
      );
    }
  }

  /// Pull-to-refresh. Re-reads the content and clears any previous failure;
  /// it never reports a success message, because nothing was fetched.
  Future<void> refresh() async {
    if (state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true);
    try {
      await _fetch();
      if (!mounted) return;
      state = state.copyWith(isRefreshing: false, clearFailure: true);
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = state.copyWith(
        isRefreshing: false,
        failure: error.asFailure(stackTrace),
      );
    }
  }

  /// The swap-point for the repository call. See the class doc.
  Future<void> _fetch() => Future<void>.delayed(AppConstants.easeShort);

  void setQuery(String value) {
    if (state.query == value) return;
    // A new search collapses everything, so the first matching answer is not
    // hidden behind a card the user expanded three searches ago.
    state = state.copyWith(query: value, expanded: const <String>{});
  }

  void clearQuery() => setQuery('');

  void toggle(String question) {
    final next = Set<String>.of(state.expanded);
    if (!next.remove(question)) next.add(question);
    state = state.copyWith(expanded: next);
  }

  void collapseAll() => state = state.copyWith(expanded: const <String>{});
}

final faqControllerProvider =
    StateNotifierProvider.autoDispose<FaqController, FaqState>(
      (ref) => FaqController(),
    );

/// The FAQ grouped by category, filtered by the current search.
///
/// Categories keep their seed order (`faqCategoriesProvider`), and a category
/// with no match is dropped rather than rendered empty. autoDispose — it is
/// only interesting while the FAQ screen is open.
final faqSectionsProvider = Provider.autoDispose<List<FaqSection>>((ref) {
  final entries = ref.watch(faqsProvider);
  final categories = ref.watch(faqCategoriesProvider);
  final query = ref
      .watch(faqControllerProvider.select((s) => s.query))
      .trim()
      .toLowerCase();

  bool matches(FaqEntry entry) {
    if (query.isEmpty) return true;
    return entry.question.toLowerCase().contains(query) ||
        entry.answer.toLowerCase().contains(query) ||
        entry.category.toLowerCase().contains(query);
  }

  final sections = <FaqSection>[];
  for (final category in categories) {
    final matched = entries
        .where((e) => e.category == category && matches(e))
        .toList();
    if (matched.isNotEmpty) {
      sections.add((category: category, entries: matched));
    }
  }
  return sections;
});

/// How many entries the current search matched — the "3 of 10 answers" line.
final faqMatchCountProvider = Provider.autoDispose<int>((ref) {
  final sections = ref.watch(faqSectionsProvider);
  return sections.fold<int>(0, (sum, section) => sum + section.entries.length);
});
