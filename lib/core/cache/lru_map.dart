/// Bounded LRU map for in-memory caches that would otherwise grow without
/// bound across a session.
///
/// BUT-779: caches like `RealtimeSyncService._cachedResources` and
/// `FirebaseUserIngredientRepository._userCache` previously kept every entry
/// for the lifetime of the process. Long-running power-user sessions saw
/// these grow linearly with activity, eventually triggering low-memory
/// kills on iOS and GC churn on Android.
///
/// Behavior:
/// - Backed by [LinkedHashMap] so insertion order is preserved.
/// - Reads via [touch] (or `[]` with `accessUpdates: true`) move the entry
///   to the end of the access order — classic LRU recency.
/// - On insertion past [maxSize], the eldest entry is removed and
///   [onEvict] is invoked with its key+value.
///
/// Not thread-safe (Dart is single-threaded per isolate; cache callers run
/// on the main isolate).
library;

import 'dart:collection';

/// Eviction callback. Fires once per evicted entry. Use it to log telemetry
/// or release secondary resources (e.g. listeners attached to the value).
typedef LruEvictionCallback<K, V> = void Function(K key, V value);

/// Map with a fixed maximum size that evicts the least-recently-used entry
/// when the bound is exceeded.
class LruMap<K, V> {
  final int maxSize;
  final LruEvictionCallback<K, V>? onEvict;
  final LinkedHashMap<K, V> _entries = LinkedHashMap<K, V>();

  LruMap({required this.maxSize, this.onEvict})
      : assert(maxSize > 0, 'maxSize must be positive');

  /// Number of entries currently held.
  int get length => _entries.length;

  /// True when no entries are held.
  bool get isEmpty => _entries.isEmpty;

  /// True when at least one entry is held.
  bool get isNotEmpty => _entries.isNotEmpty;

  /// Read-only view of the keys (in insertion order).
  Iterable<K> get keys => _entries.keys;

  /// Read-only view of the values (in insertion order).
  Iterable<V> get values => _entries.values;

  /// Read-only view of the entries (in insertion order).
  Iterable<MapEntry<K, V>> get entries => _entries.entries;

  /// Returns true when [key] is present. Does NOT update LRU recency — use
  /// [touch] or `operator []` if the lookup itself counts as access.
  bool containsKey(K key) => _entries.containsKey(key);

  /// Reads the value for [key], moving the entry to the most-recently-used
  /// slot. Returns null when absent.
  V? operator [](K key) {
    if (!_entries.containsKey(key)) return null;
    final value = _entries.remove(key) as V;
    _entries[key] = value;
    return value;
  }

  /// Reads the value for [key] WITHOUT updating LRU recency. Useful for
  /// cheap "is this cached?" lookups that shouldn't promote stale entries.
  V? peek(K key) => _entries[key];

  /// Inserts or updates [key] -> [value]. Promotes the entry to most-recently
  /// used. Evicts the eldest entry if the map is over [maxSize].
  void operator []=(K key, V value) {
    // Remove first so re-insertion lands at the end (most-recent slot).
    _entries.remove(key);
    _entries[key] = value;
    _evictIfNeeded();
  }

  /// Touches [key] without changing its value, moving it to the most-recent
  /// slot. No-op when absent.
  void touch(K key) {
    if (!_entries.containsKey(key)) return;
    final value = _entries.remove(key) as V;
    _entries[key] = value;
  }

  /// Removes and returns the value for [key], or null when absent. Does NOT
  /// fire [onEvict] — that callback is reserved for size-driven evictions.
  V? remove(K key) => _entries.remove(key);

  /// Removes every entry whose `(key, value)` satisfies [test]. Returns the
  /// number of entries removed. Does NOT fire [onEvict] — caller-driven
  /// invalidation, not size-driven eviction.
  int removeWhere(bool Function(K key, V value) test) {
    final toRemove = <K>[];
    _entries.forEach((k, v) {
      if (test(k, v)) toRemove.add(k);
    });
    for (final k in toRemove) {
      _entries.remove(k);
    }
    return toRemove.length;
  }

  /// Clears every entry. Does NOT fire [onEvict].
  void clear() => _entries.clear();

  void _evictIfNeeded() {
    while (_entries.length > maxSize) {
      final eldestKey = _entries.keys.first;
      final eldestValue = _entries.remove(eldestKey) as V;
      onEvict?.call(eldestKey, eldestValue);
    }
  }
}
