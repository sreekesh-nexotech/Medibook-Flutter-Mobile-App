import '../entities/search_results.dart';

/// Directory search (§7.9). Public; `q` must be 2–100 characters — the
/// application layer never sends anything shorter. Throws a `Failure`.
abstract interface class SearchRepository {
  Future<SearchResults> search(String query);
}
