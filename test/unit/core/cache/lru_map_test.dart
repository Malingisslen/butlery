/// Unit tests for [LruMap] (BUT-779).
///
/// The LRU map exists to keep long-lived in-memory caches bounded across a
/// session. These tests pin down the bound + recency contract that callers
/// rely on; regressions in either silently re-introduce the unbounded
/// growth that the helper was created to prevent.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/cache/lru_map.dart';

void main() {
  group('LruMap', () {
    test('rejects non-positive maxSize at construction', () {
      // A maxSize of 0 would mean "evict on every insert" — clearly a
      // misconfig. Failing fast at construction is friendlier than silently
      // dropping every value.
      expect(() => LruMap<String, int>(maxSize: 0),
          throwsA(isA<AssertionError>()));
    });

    test('insertion and read round-trip', () {
      final cache = LruMap<String, int>(maxSize: 3);
      cache['a'] = 1;
      cache['b'] = 2;
      expect(cache['a'], 1);
      expect(cache['b'], 2);
      expect(cache['missing'], isNull);
      expect(cache.length, 2);
    });

    test('grows to maxSize then evicts the eldest', () {
      // Most important contract: the bound holds. Without this guarantee,
      // callers re-introduce the unbounded growth pattern.
      final evictions = <String>[];
      final cache = LruMap<String, int>(
        maxSize: 3,
        onEvict: (key, _) => evictions.add(key),
      );
      cache['a'] = 1;
      cache['b'] = 2;
      cache['c'] = 3;
      cache['d'] = 4;
      expect(cache.length, 3);
      expect(cache.containsKey('a'), isFalse);
      expect(evictions, equals(['a']));
    });

    test(
        'reads promote recency — older keys evicted first only when not touched',
        () {
      // Classic LRU: a key read recently must outlive a key written earlier
      // and never read.
      final evictions = <String>[];
      final cache = LruMap<String, int>(
        maxSize: 3,
        onEvict: (key, _) => evictions.add(key),
      );
      cache['a'] = 1;
      cache['b'] = 2;
      cache['c'] = 3;
      // Touch 'a' via read.
      expect(cache['a'], 1);
      cache['d'] = 4;
      expect(cache.containsKey('a'), isTrue,
          reason: 'recently-read entry must survive eviction');
      expect(cache.containsKey('b'), isFalse,
          reason: 'eldest non-touched entry must be evicted');
      expect(evictions, equals(['b']));
    });

    test('peek does NOT promote recency', () {
      // Cheap "is it cached?" lookups shouldn't keep stale entries alive.
      // Without this, telemetry that probes the cache would falsely promote
      // entries on every read.
      final evictions = <String>[];
      final cache = LruMap<String, int>(
        maxSize: 3,
        onEvict: (key, _) => evictions.add(key),
      );
      cache['a'] = 1;
      cache['b'] = 2;
      cache['c'] = 3;
      expect(cache.peek('a'), 1);
      cache['d'] = 4;
      expect(cache.containsKey('a'), isFalse,
          reason: 'peek must not save the eldest from eviction');
      expect(evictions, equals(['a']));
    });

    test('re-assignment moves key to most-recent slot', () {
      final cache = LruMap<String, int>(maxSize: 3);
      cache['a'] = 1;
      cache['b'] = 2;
      cache['c'] = 3;
      cache['a'] = 99; // Update 'a' — should now be most-recent.
      cache['d'] = 4;
      expect(cache.containsKey('b'), isFalse,
          reason: 'after re-assign of a, b is the eldest');
      expect(cache['a'], 99);
    });

    test('touch moves key to most-recent slot without changing value', () {
      final cache = LruMap<String, int>(maxSize: 3);
      cache['a'] = 1;
      cache['b'] = 2;
      cache['c'] = 3;
      cache.touch('a');
      cache['d'] = 4;
      expect(cache.containsKey('b'), isFalse);
      expect(cache['a'], 1);
    });

    test('remove does not fire onEvict', () {
      // onEvict is reserved for size-driven evictions so telemetry can
      // distinguish "the cache is too small" from "we cleared a stale entry
      // ourselves." Conflating the two would make the eviction signal
      // useless for capacity tuning.
      final evictions = <String>[];
      final cache = LruMap<String, int>(
        maxSize: 3,
        onEvict: (key, _) => evictions.add(key),
      );
      cache['a'] = 1;
      cache.remove('a');
      expect(evictions, isEmpty);
    });

    test('clear does not fire onEvict', () {
      final evictions = <String>[];
      final cache = LruMap<String, int>(
        maxSize: 3,
        onEvict: (key, _) => evictions.add(key),
      );
      cache['a'] = 1;
      cache['b'] = 2;
      cache.clear();
      expect(evictions, isEmpty);
      expect(cache.length, 0);
    });

    test('onEvict carries the evicted value, not the surviving one', () {
      // Callers may attach secondary resources (e.g. listeners) to the
      // value and need a chance to release them on eviction. Passing the
      // wrong value would make that release path leak. (MapEntry equality
      // is identity-based in Dart, so compare key/value separately.)
      final evictedKeys = <String>[];
      final evictedValues = <int>[];
      final cache = LruMap<String, int>(
        maxSize: 2,
        onEvict: (key, value) {
          evictedKeys.add(key);
          evictedValues.add(value);
        },
      );
      cache['a'] = 1;
      cache['b'] = 2;
      cache['c'] = 3;
      expect(evictedKeys, equals(['a']));
      expect(evictedValues, equals([1]));
    });

    test('removeWhere removes matching entries and returns the count', () {
      // Caller-driven invalidation (e.g. "drop every entry for user X") needs
      // a bulk path that doesn't fire onEvict — eviction telemetry must stay
      // a clean signal for size-driven evictions only (BUT-817).
      final evictions = <String>[];
      final cache = LruMap<String, int>(
        maxSize: 10,
        onEvict: (key, _) => evictions.add(key),
      );
      cache['a:1'] = 1;
      cache['a:2'] = 2;
      cache['b:1'] = 3;

      final removed = cache.removeWhere((k, _) => k.startsWith('a:'));
      expect(removed, 2);
      expect(cache.length, 1);
      expect(cache.containsKey('b:1'), isTrue);
      expect(evictions, isEmpty,
          reason: 'removeWhere is invalidation, not size-driven eviction');
    });

    test('removeWhere is safe when the predicate matches nothing', () {
      final cache = LruMap<String, int>(maxSize: 3);
      cache['a'] = 1;
      cache['b'] = 2;
      expect(cache.removeWhere((_, __) => false), 0);
      expect(cache.length, 2);
    });

    test('multiple inserts past maxSize evict in FIFO order absent reads', () {
      // Stress check: under a write-only workload an LRU degenerates to a
      // FIFO. Ensures the eviction loop doesn't skip entries.
      final evictions = <int>[];
      final cache = LruMap<int, int>(
        maxSize: 2,
        onEvict: (key, _) => evictions.add(key),
      );
      for (var i = 0; i < 10; i++) {
        cache[i] = i * 10;
      }
      expect(cache.length, 2);
      expect(evictions, equals([0, 1, 2, 3, 4, 5, 6, 7]));
      expect(cache.containsKey(8), isTrue);
      expect(cache.containsKey(9), isTrue);
    });
  });
}
