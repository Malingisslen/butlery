/// Direct unit tests for [JsonCacheHelper] / [JsonCacheStats] / [JsonCacheFactory]
/// (BUT-1149 coverage burndown — previously zero direct coverage).
///
/// JsonCacheHelper wraps a CacheDao with two contracts worth proving:
///   1. JSON round-trips correctly (encode on save, decode on load), scoped
///      per-user so two users never read each other's cache.
///   2. Every method is failure-tolerant — a DAO error or a decode error is
///      swallowed and reported as a safe default (false / null / [] / 0), never
///      rethrown, because cache misses must degrade gracefully.
///
/// A hand-written in-memory CacheDao stands in for Drift — stateful (so saves
/// are observable on load) with a `fail` switch to simulate storage errors.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/cache/cache_dao_interface.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/services/unified/modules/recipe_cache_module.dart';

/// Stateful in-memory stand-in for the Drift-backed CacheDao. Only the JSON
/// surface JsonCacheHelper uses is implemented; the rest is unreachable here.
class _InMemoryCacheDao implements CacheDao {
  final Map<String, String> store = {};
  bool fail = false;

  String _k(String b, String u, String key) => '$b|$u|$key';
  String _prefix(String b, String u) => '$b|$u|';

  @override
  Future<String?> getJson(String boxName, String userId, String key) async {
    if (fail) throw Exception('storage error');
    return store[_k(boxName, userId, key)];
  }

  @override
  Future<List<String>> getJsonKeys(String boxName, String userId) async {
    if (fail) throw Exception('storage error');
    final p = _prefix(boxName, userId);
    return store.keys
        .where((k) => k.startsWith(p))
        .map((k) => k.substring(p.length))
        .toList();
  }

  @override
  Future<void> putJson({
    required String boxName,
    required String userId,
    required String key,
    required String value,
  }) async {
    if (fail) throw Exception('storage error');
    store[_k(boxName, userId, key)] = value;
  }

  @override
  Future<void> putJsonBatch({
    required String boxName,
    required String userId,
    required Map<String, String> entries,
  }) async {
    if (fail) throw Exception('storage error');
    entries.forEach((k, v) => store[_k(boxName, userId, k)] = v);
  }

  @override
  Future<void> deleteJson(String boxName, String userId, String key) async {
    if (fail) throw Exception('storage error');
    store.remove(_k(boxName, userId, key));
  }

  @override
  Future<void> clearJsonBox(String boxName, String userId) async {
    if (fail) throw Exception('storage error');
    store.removeWhere((k, _) => k.startsWith(_prefix(boxName, userId)));
  }

  @override
  Future<int> countJsonEntries(String boxName, String userId) async {
    if (fail) throw Exception('storage error');
    return store.keys
        .where((k) => k.startsWith(_prefix(boxName, userId)))
        .length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _InMemoryCacheDao dao;
  late JsonCacheHelper cache;

  setUp(() {
    dao = _InMemoryCacheDao();
    cache = JsonCacheHelper('box', dao)..setCurrentUser('u1');
  });

  group('JSON round-trip', () {
    test('saveJson then loadJson returns the same map', () async {
      expect(await cache.saveJson('k', {'a': 1, 'b': 'two'}), isTrue);
      expect(await cache.loadJson('k'), {'a': 1, 'b': 'two'});
    });

    test('loadJson returns null for a missing key', () async {
      expect(await cache.loadJson('absent'), isNull);
    });

    test('saveJsonList then loadJsonList returns the same list', () async {
      final list = [
        {'id': 1},
        {'id': 2},
      ];
      expect(await cache.saveJsonList('k', list), isTrue);
      expect(await cache.loadJsonList('k'), list);
    });

    test('loadJsonList returns null for a missing key', () async {
      expect(await cache.loadJsonList('absent'), isNull);
    });
  });

  group('presence + enumeration', () {
    test('exists reflects whether a key was saved', () async {
      expect(await cache.exists('k'), isFalse);
      await cache.saveJson('k', {'x': 1});
      expect(await cache.exists('k'), isTrue);
    });

    test('delete removes the key', () async {
      await cache.saveJson('k', {'x': 1});
      expect(await cache.delete('k'), isTrue);
      expect(await cache.exists('k'), isFalse);
    });

    test('getAllKeys lists the saved keys', () async {
      await cache.saveJson('a', {'x': 1});
      await cache.saveJson('b', {'x': 2});
      expect(await cache.getAllKeys(), containsAll(<String>['a', 'b']));
    });

    test('clear empties the box', () async {
      await cache.saveJson('a', {'x': 1});
      await cache.saveJson('b', {'x': 2});
      expect(await cache.clear(), isTrue);
      expect(await cache.getAllKeys(), isEmpty);
    });

    test('getStats reports the number of cached entries', () async {
      await cache.saveJson('a', {'x': 1});
      await cache.saveJson('b', {'x': 2});
      final stats = await cache.getStats();
      expect(stats.keyCount, 2);
      expect(stats.userId, 'u1');
    });
  });

  group('per-user isolation', () {
    test('a different user does not see the first user\'s entries', () async {
      await cache.saveJson('k', {'mine': true});
      cache.setCurrentUser('u2');
      expect(await cache.loadJson('k'), isNull);
      expect(await cache.getAllKeys(), isEmpty);
    });
  });

  group('batch operations', () {
    test(
      'saveJsonBatch stores all encodable items and returns the count',
      () async {
        final n = await cache.saveJsonBatch({
          'a': {'x': 1},
          'b': {'y': 2},
        });
        expect(n, 2);
        expect(await cache.loadJson('a'), {'x': 1});
      },
    );

    test(
      'saveJsonBatch skips an un-encodable item but still saves the rest',
      () async {
        final n = await cache.saveJsonBatch({
          'good': {'x': 1},
          'bad': {'obj': Object()}, // not JSON-encodable
        });
        expect(n, 1);
        expect(await cache.loadJson('good'), {'x': 1});
        expect(await cache.loadJson('bad'), isNull);
      },
    );

    test('loadJsonBatch returns only the keys that are present', () async {
      await cache.saveJson('a', {'x': 1});
      final result = await cache.loadJsonBatch(['a', 'missing']);
      expect(result.keys, ['a']);
      expect(result['a'], {'x': 1});
    });
  });

  group('active id', () {
    test(
      'saveActiveId stores a value and loadActiveId reads it back',
      () async {
        expect(await cache.saveActiveId('active', 'item-7'), isTrue);
        expect(await cache.loadActiveId('active'), 'item-7');
      },
    );

    test('saveActiveId with null clears the stored value', () async {
      await cache.saveActiveId('active', 'item-7');
      expect(await cache.saveActiveId('active', null), isTrue);
      expect(await cache.loadActiveId('active'), isNull);
    });
  });

  group('failure tolerance (errors are swallowed, never rethrown)', () {
    setUp(() => dao.fail = true);

    test('saveJson returns false on a storage error', () async {
      expect(await cache.saveJson('k', {'x': 1}), isFalse);
    });

    test('loadJson returns null on a storage error', () async {
      expect(await cache.loadJson('k'), isNull);
    });

    test('delete / clear return false on a storage error', () async {
      expect(await cache.delete('k'), isFalse);
      expect(await cache.clear(), isFalse);
    });

    test('exists returns false and getAllKeys returns [] on error', () async {
      expect(await cache.exists('k'), isFalse);
      expect(await cache.getAllKeys(), isEmpty);
    });
  });

  group('missing user', () {
    test('operations fail-safe (return false) when no user is set', () async {
      final orphan = JsonCacheHelper('box', dao);
      expect(await orphan.saveJson('k', {'x': 1}), isFalse);
    });
  });

  group('JsonCacheStats + JsonCacheFactory', () {
    test('JsonCacheStats.toString is human-readable', () {
      final stats = JsonCacheStats(
        boxName: 'box_u1',
        keyCount: 3,
        userId: 'u1',
      );
      expect(stats.toString(), contains('box_u1'));
      expect(stats.toString(), contains('3 items'));
    });

    test('factory builds helpers with the expected box base names', () async {
      final factory = JsonCacheFactory(dao);
      // Save through each helper for the same user+key, then confirm they land
      // in separate boxes (no cross-talk).
      factory.recipeCache().setCurrentUser('u1');
      final recipes = factory.recipeCache()..setCurrentUser('u1');
      final shopping = factory.shoppingCache()..setCurrentUser('u1');
      await recipes.saveJson('k', {'kind': 'recipe'});
      await shopping.saveJson('k', {'kind': 'shopping'});
      expect(await recipes.loadJson('k'), {'kind': 'recipe'});
      expect(await shopping.loadJson('k'), {'kind': 'shopping'});
    });
  });

  group('sign-out', () {
    test(
      'the recipe cache module empties the cache of the user who left',
      () async {
        final signedOut = _InMemoryCacheDao();
        final helper = JsonCacheHelper('unified_recipes_cache', signedOut)
          ..setCurrentUser('u1');
        final module = RecipeCacheModule(
          cacheHelper: helper,
          getCurrentUserId: () => 'u1',
          setError: (_) {},
          notifyListeners: () {},
        );
        await helper.saveJson('r1', {'title': 'Pannkakor'});
        await helper.saveJson('r2', {'title': 'Soppa'});
        final other = JsonCacheHelper('unified_recipes_cache', signedOut)
          ..setCurrentUser('u2');
        await other.saveJson('r1', {'title': 'Annans'});

        module.onAuthStateChanged(null);
        await Future<void>.delayed(Duration.zero);

        final stored = signedOut.store.keys.toList();
        expect(stored.where((k) => k.contains('|u1|')), isEmpty);
        expect(stored.where((k) => k.contains('|u2|')), isNotEmpty);
      },
    );

    test(
      'a clear started before the user is dropped still completes',
      () async {
        final helper = JsonCacheHelper('box', dao)..setCurrentUser('u1');
        await helper.saveJson('k', {'x': 1});

        final cleared = helper.clear();
        helper.setCurrentUser(null);

        expect(await cleared, isTrue);
        expect(dao.store, isEmpty);
      },
    );
  });
}
