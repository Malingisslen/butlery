/// Generic search result with pagination metadata.
class SearchResult<T> {
  final List<T> hits;
  final int totalHits;
  final int page;
  final int totalPages;
  final int processingTimeMs;
  final String? queryId; // For analytics

  /// True when the search provider errored (outage, DNS failure, etc.)
  /// rather than legitimately returning zero hits. Lets callers distinguish a
  /// degraded backend from an empty corpus — e.g. show an offline banner
  /// instead of a neutral "no results" state (BUT-1416). A successful zero-hit search has `failed == false`.
  final bool failed;

  const SearchResult({
    required this.hits,
    required this.totalHits,
    required this.page,
    required this.totalPages,
    required this.processingTimeMs,
    this.queryId,
    this.failed = false,
  });

  /// An empty result flagged as a provider failure (not a legitimate 0-hit
  /// search). Use in `catch` blocks so callers can branch on [failed].
  const SearchResult.failure({this.page = 0})
    : hits = const [],
      totalHits = 0,
      totalPages = 0,
      processingTimeMs = 0,
      queryId = null,
      failed = true;

  bool get hasMore => page < totalPages - 1;
  bool get isEmpty => hits.isEmpty;

  SearchResult<R> map<R>(R Function(T) transform) {
    return SearchResult<R>(
      hits: hits.map(transform).toList(),
      totalHits: totalHits,
      page: page,
      totalPages: totalPages,
      processingTimeMs: processingTimeMs,
      queryId: queryId,
      failed: failed,
    );
  }
}
