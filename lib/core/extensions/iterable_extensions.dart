/// Extension methods on Iterable / List for common collection patterns.

/// Firestore's `whereIn` / `arrayContainsAny` / `in` clause cap. Pair with
/// [ChunkExtension.chunked] to fan a large id list out across N batched
/// queries.
const int kFirestoreWhereInLimit = 30;

/// Firestore's max ops per `WriteBatch` (the SDK rejects batches larger
/// than this). Use as a boundary check; for chunking, prefer
/// [kFirestoreBatchSafeChunkSize] which leaves headroom.
const int kFirestoreBatchOpLimit = 500;

/// Recommended chunk size when splitting a large doc set into multiple
/// batches. The 50-op safety margin under [kFirestoreBatchOpLimit] absorbs
/// (a) any auxiliary writes the caller adds inside the loop and (b) the
/// SDK's own off-by-one strictness near the boundary. Pair with
/// [ChunkExtension.chunked]. (BUT-592)
const int kFirestoreBatchSafeChunkSize = 450;

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
