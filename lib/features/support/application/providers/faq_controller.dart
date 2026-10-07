import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'support_provider.dart';
import '../../domain/entities/faq.dart';

/// One FAQ category with the entries that matched the current search.
typedef FaqSection = ({String category, String title, List<FaqEntry> entries});

/// Search + expand/collapse state for the FAQ screen (`/faq`).
///
/// Pure UI state. The content itself comes from `supportFaqsProvider`
/// (`GET /patient/faqs`, cached), whose `CachedState` the screen renders for
/// loading / stale / error; this controller only remembers what the user
/// typed and which cards are open.
@immutable
class FaqState {
  const FaqState({this.query = '', this.expanded = const <String>{}});

  /// The current search text, trimmed on use but stored verbatim so the field
  /// does not fight the user's spaces.
  final String query;

  /// Entry ids currently expanded.
  final Set<String> expanded;

  bool get hasQuery => query.trim().isNotEmpty;

  bool isExpanded(String id) => expanded.contains(id);

  FaqState copyWith({String? query, Set<String>? expanded}) =>
      FaqState(query: query ?? this.query, expanded: expanded ?? this.expanded);
}

class FaqController extends StateNotifier<FaqState> {
  FaqController() : super(const FaqState());

  void setQuery(String value) {
    if (state.query == value) return;
    // A new search collapses everything, so the first matching answer is not
    // hidden behind a card the user expanded three searches ago.
    state = state.copyWith(query: value, expanded: const <String>{});
  }

  void clearQuery() => setQuery('');

  void toggle(String id) {
    final next = Set<String>.of(state.expanded);
    if (!next.remove(id)) next.add(id);
    state = state.copyWith(expanded: next);
  }

  void collapseAll() => state = state.copyWith(expanded: const <String>{});
}

/// autoDispose — search and expansion belong to one visit to the screen.
final faqControllerProvider =
    StateNotifierProvider.autoDispose<FaqController, FaqState>(
      (ref) => FaqController(),
    );

/// The FAQ grouped by category, filtered by the current search.
///
/// Categories keep the server's order, and a category with no match is
/// dropped rather than rendered empty. Empty until the content has loaded.
final faqSectionsProvider = Provider.autoDispose<List<FaqSection>>((ref) {
  final categories =
      ref.watch(supportFaqsProvider.select((s) => s.value)) ??
      const <FaqCategory>[];
  final query = ref
      .watch(faqControllerProvider.select((s) => s.query))
      .trim()
      .toLowerCase();

  bool matches(FaqEntry entry) {
    if (query.isEmpty) return true;
    return entry.question.toLowerCase().contains(query) ||
        entry.answerMd.toLowerCase().contains(query) ||
        entry.category.toLowerCase().contains(query);
  }

  return [
    for (final category in categories)
      if (category.entries.where(matches).toList() case final matched
          when matched.isNotEmpty)
        (
          category: category.category,
          title: faqCategoryTitle(category.category),
          entries: matched,
        ),
  ];
});

/// How many entries the current search matched — the "3 answers matched" line.
final faqMatchCountProvider = Provider.autoDispose<int>((ref) {
  final sections = ref.watch(faqSectionsProvider);
  return sections.fold<int>(0, (sum, section) => sum + section.entries.length);
});

/// `booking` → "Booking", `feature_request` → "Feature request".
String faqCategoryTitle(String key) {
  final words = key.replaceAll('_', ' ').trim();
  if (words.isEmpty) return 'General';
  return words[0].toUpperCase() + words.substring(1);
}

/// What the FAQ covers, from the live categories — "Account, booking,
/// payments and tokens" — for the one-line summaries on Profile and Help &
/// Support. Null until the FAQ has loaded or when it has no categories, so
/// the caller shows its own neutral line instead of naming topics the
/// server does not have.
final faqTopicsProvider = Provider.autoDispose<String?>((ref) {
  final categories = ref.watch(supportFaqsProvider.select((s) => s.value));
  if (categories == null) return null;
  return faqTopicsLabel([for (final c in categories) c.category]);
});

/// Pure: category keys → "Account, booking, payments and tokens", in the
/// server's order, each named once. Null for an empty list. Exposed for tests.
String? faqTopicsLabel(List<String> categoryKeys) {
  final names = <String>[];
  for (final key in categoryKeys) {
    final title = faqCategoryTitle(key);
    final name = names.isEmpty ? title : title.toLowerCase();
    if (!names.any((n) => n.toLowerCase() == name.toLowerCase())) {
      names.add(name);
    }
  }
  if (names.isEmpty) return null;
  if (names.length == 1) return names.single;
  return '${names.sublist(0, names.length - 1).join(', ')} '
      'and ${names.last}';
}
