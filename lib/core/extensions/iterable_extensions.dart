/// Extension methods on Iterable / List for common collection patterns.

/// Firestore's `whereIn` / `arrayContainsAny` / `in` clause cap. Pair with
/// [ChunkExtension.chunked] to fan a large id list out across N batched
/// queries.
const int kFirestoreWhereInLimit = 30;

/// Firestore's max ops per `WriteBatch` (the SDK rejects batches larger
/// than this). Pair with [ChunkExtension.chunked] when batching deletes,
/// updates, or writes across a large doc set.
const int kFirestoreBatchOpLimit = 500;

/// Chunking extension. Returns `[receiver in chunks of [size]]` — the last
/// sublist is shorter if the input length isn't a multiple of [size].
extension ChunkExtension<T> on Iterable<T> {
  /// `[].chunked(30)` → `[]`. `[1,2,3].chunked(30)` → `[[1,2,3]]`.
  /// Throws [ArgumentError] if [size] <= 0.
  List<List<T>> chunked(int size) {
    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'must be > 0');
    }
    final list = this is List<T> ? this as List<T> : toList();
    return [
      for (var i = 0; i < list.length; i += size)
        list.sublist(i, i + size > list.length ? list.length : i + size),
    ];
  }
}
