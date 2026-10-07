import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/di/dependencies.dart';
import 'package:medibook/app/di/search_dependencies.dart';
import 'package:medibook/core/network/endpoints.dart';
import 'package:medibook/features/search/application/providers/search_providers.dart';
import 'package:medibook/features/search/domain/entities/search_results.dart';
import 'package:medibook/features/search/domain/repositories/search_repository.dart';
import 'package:medibook/features/search/infrastructure/data_sources/remote/search_api.dart';

/// The search rules the endpoint enforces (§7.9): `q` is 2–100 characters,
/// debounced, and the results provider maps the three groups.
void main() {
  group('SearchQueryRules', () {
    test('refuses one character and truncates past 100', () {
      expect(SearchQueryRules.normalise(' c '), isNull);
      expect(SearchQueryRules.normalise('ca'), 'ca');
      expect(SearchQueryRules.normalise('x' * 150)?.length, 100);
    });
  });

  // Checklist DISC-012: unusual input is trimmed or truncated, never refused
  // with an error.
  test('emoji, Indian scripts, padding and very long input', () {
    expect(SearchQueryRules.normalise('  cardio  '), 'cardio');
    expect(SearchQueryRules.normalise('🩺🩺'), '🩺🩺');
    expect(SearchQueryRules.normalise('ഹൃദയം'), 'ഹൃദയം');
    expect(SearchQueryRules.normalise('हृदय'), 'हृदय');
    expect(SearchQueryRules.normalise('a' * 200), hasLength(100));
    expect(SearchQueryRules.normalise('   '), isNull);
  });

  group('SearchQueryController', () {
    test('debounces and only publishes a sendable query', () async {
      final controller = SearchQueryController(
        debounce: const Duration(milliseconds: 10),
      );
      controller.onInput('c');
      expect(controller.state.isTooShort, isTrue);
      expect(controller.state.hasQuery, isFalse);

      controller.onInput('card');
      expect(controller.state.hasQuery, isFalse);
      expect(controller.state.isSettling, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.state.query, 'card');
      expect(controller.state.isSettling, isFalse);

      controller.onInput('');
      expect(controller.state.hasQuery, isFalse);
      controller.dispose();
    });

    test('submit runs at once', () {
      final controller = SearchQueryController();
      controller.submit('Cardiology');
      expect(controller.state.query, 'Cardiology');
      controller.dispose();
    });
  });

  group('searchResultsProvider', () {
    test('maps the plain (non-paginated) response', () async {
      final api = _FakeSearchApi();
      final container = ProviderContainer(
        overrides: [
          ...appDependencies(),
          searchApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      final results = await container.read(
        searchResultsProvider('card').future,
      );
      expect(api.queries, ['card']);
      expect(results.departments.single.code, 'cardiology');
      expect(results.hospitals, isEmpty);
      expect(results.doctors, isEmpty);
      expect(results.total, 1);
    });

    test('the repository contract is honoured by a fake', () async {
      final container = ProviderContainer(
        overrides: [
          ...appDependencies(),
          searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
        ],
      );
      addTearDown(container.dispose);
      final results = await container.read(
        searchResultsProvider('anything').future,
      );
      expect(results.isEmpty, isTrue);
    });
  });

  test('recent searches are deduplicated, newest first, capped at six', () {
    final recents = RecentSearchesController();
    for (final term in ['a1', 'b2', 'c3', 'd4', 'e5', 'f6', 'g7', 'B2']) {
      recents.remember(term);
    }
    expect(recents.state.first, 'B2');
    expect(recents.state, hasLength(6));
    expect(recents.state.where((r) => r.toLowerCase() == 'b2'), hasLength(1));
  });
}

class _FakeSearchApi implements SearchApi {
  final List<String> queries = [];

  @override
  Future<Map<String, Object?>> search(String query) async {
    queries.add(query);
    // Sanity: the path the real client would use exists.
    expect(Endpoints.search, '/patient/search');
    return {
      'q': query,
      'hospitals': const [],
      'departments': [
        {'code': 'cardiology', 'name': 'Cardiology', 'hospital_count': 1},
      ],
      'doctors': const [],
    };
  }
}

class _FakeSearchRepository implements SearchRepository {
  @override
  Future<SearchResults> search(String query) async =>
      const SearchResults.empty();
}
