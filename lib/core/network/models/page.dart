import '../network_exceptions.dart';

/// One page of a list endpoint (§1.6).
///
/// Every list is wrapped in this envelope; [Page.parse] decodes it and hands
/// each row to [fromJson], throwing [ResponseFormatException] when the body
/// is not the envelope — a partial page is never mistaken for an empty one.
class Page<T> {
  const Page({
    required this.results,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasNext,
  });

  factory Page.parse(
    Object? body,
    T Function(Map<String, Object?> json) fromJson,
  ) {
    if (body is! Map) {
      throw ResponseFormatException(
        message: 'expected a page envelope, got ${body.runtimeType}',
      );
    }
    final map = body.cast<String, Object?>();
    final results = map['results'];
    if (results is! List) {
      throw const ResponseFormatException(message: 'page has no results[]');
    }
    return Page<T>(
      results: [
        for (final row in results)
          if (row is Map) fromJson(row.cast<String, Object?>()),
      ],
      page: (map['page'] as num?)?.toInt() ?? 1,
      pageSize: (map['page_size'] as num?)?.toInt() ?? results.length,
      total: (map['total'] as num?)?.toInt() ?? results.length,
      hasNext: map['has_next'] == true,
    );
  }

  /// A page with nothing in it — the safe initial value for a list state.
  const Page.empty()
    : results = const [],
      page = 1,
      pageSize = 0,
      total = 0,
      hasNext = false;

  final List<T> results;
  final int page;
  final int pageSize;
  final int total;
  final bool hasNext;

  bool get isEmpty => results.isEmpty;

  /// This page followed by [next] — for infinite scrolling.
  Page<T> append(Page<T> next) => Page<T>(
    results: [...results, ...next.results],
    page: next.page,
    pageSize: next.pageSize,
    total: next.total,
    hasNext: next.hasNext,
  );

  Page<R> map<R>(R Function(T item) convert) => Page<R>(
    results: [for (final item in results) convert(item)],
    page: page,
    pageSize: pageSize,
    total: total,
    hasNext: hasNext,
  );
}
