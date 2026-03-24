import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

// Import the web stub directly (not via conditional export) for unit testing.
// This works because the stub file has no dart:html dependency — it only uses
// sembast types which are available on all platforms.
import 'package:butlery/core/cache/cache_dao_stub.dart';

void main() {
  late CacheDao cacheDao;

  setUp(() async {
    // Each test gets a fresh in-memory database
    cacheDao = CacheDao(
      databaseFactory: newDatabaseFactoryMemory(),
    );
  });

  group('JSON cache', () {
    const box = 'recipes';
    const userId = 'user1';

    test('getJson returns null for missing key', () async {
      final result = await cacheDao.getJson(box, userId, 'missing');
      expect(result, isNull);
    });

    test('putJson + getJson round-trip', () async {
      await cacheDao.putJson(
        boxName: box,
        userId: userId,
        key: 'k1',
        value: '{"hello":"world"}',
      );
      final result = await cacheDao.getJson(box, userId, 'k1');
      expect(result, '{"hello":"world"}');
    });

    test('putJson overwrites existing value', () async {
      await cacheDao.putJson(
        boxName: box,
        userId: userId,
        key: 'k1',
        value: 'v1',
      );
      await cacheDao.putJson(
        boxName: box,
        userId: userId,
        key: 'k1',
        value: 'v2',
      );
      expect(await cacheDao.getJson(box, userId, 'k1'), 'v2');
    });

    test('putJsonBatch stores multiple entries atomically', () async {
      await cacheDao.putJsonBatch(
        boxName: box,
        userId: userId,
        entries: {'a': '1', 'b': '2', 'c': '3'},
      );
      expect(await cacheDao.getJson(box, userId, 'a'), '1');
      expect(await cacheDao.getJson(box, userId, 'b'), '2');
      expect(await cacheDao.getJson(box, userId, 'c'), '3');
    });

    test('deleteJson removes entry', () async {
      await cacheDao.putJson(
        boxName: box,
        userId: userId,
        key: 'k1',
        value: 'v1',
      );
      await cacheDao.deleteJson(box, userId, 'k1');
      expect(await cacheDao.getJson(box, userId, 'k1'), isNull);
    });

    test('deleteJson is no-op for missing key', () async {
      // Should not throw
      await cacheDao.deleteJson(box, userId, 'nonexistent');
    });

    test('clearJsonBox removes all entries for box+user', () async {
      await cacheDao.putJson(
        boxName: box,
        userId: userId,
        key: 'k1',
        value: 'v1',
      );
      await cacheDao.putJson(
        boxName: box,
        userId: userId,
        key: 'k2',
        value: 'v2',
      );
      // Different box — should not be affected
      await cacheDao.putJson(
        boxName: 'other_box',
        userId: userId,
        key: 'k3',
        value: 'v3',
      );

      await cacheDao.clearJsonBox(box, userId);

      expect(await cacheDao.getJson(box, userId, 'k1'), isNull);
      expect(await cacheDao.getJson(box, userId, 'k2'), isNull);
      expect(await cacheDao.getJson('other_box', userId, 'k3'), 'v3');
    });

    test('clearJsonBox does not affect other users', () async {
      await cacheDao.putJson(
        boxName: box,
        userId: userId,
        key: 'k1',
        value: 'v1',
      );
      await cacheDao.putJson(
        boxName: box,
        userId: 'user2',
        key: 'k1',
        value: 'v2',
      );

      await cacheDao.clearJsonBox(box, userId);

      expect(await cacheDao.getJson(box, userId, 'k1'), isNull);
      expect(await cacheDao.getJson(box, 'user2', 'k1'), 'v2');
    });

    test('getJsonKeys returns all keys for box+user', () async {
      await cacheDao.putJson(
        boxName: box,
        userId: userId,
        key: 'alpha',
        value: '1',
      );
      await cacheDao.putJson(
        boxName: box,
        userId: userId,
        key: 'beta',
        value: '2',
      );
      // Different user — not included
      await cacheDao.putJson(
        boxName: box,
        userId: 'user2',
        key: 'gamma',
        value: '3',
      );

      final keys = await cacheDao.getJsonKeys(box, userId);
      expect(keys, unorderedEquals(['alpha', 'beta']));
    });

    test('getJsonKeys returns empty list when no entries', () async {
      final keys = await cacheDao.getJsonKeys(box, userId);
      expect(keys, isEmpty);
    });

    test('countJsonEntries counts entries for box+user', () async {
      expect(await cacheDao.countJsonEntries(box, userId), 0);

      await cacheDao.putJson(
        boxName: box,
        userId: userId,
        key: 'k1',
        value: 'v1',
      );
      await cacheDao.putJson(
        boxName: box,
        userId: userId,
        key: 'k2',
        value: 'v2',
      );
      // Different box — not counted
      await cacheDao.putJson(
        boxName: 'other',
        userId: userId,
        key: 'k3',
        value: 'v3',
      );

      expect(await cacheDao.countJsonEntries(box, userId), 2);
      expect(await cacheDao.countJsonEntries('other', userId), 1);
    });

    test('getAllJson returns all entries for box+user', () async {
      await cacheDao.putJson(
        boxName: box,
        userId: userId,
        key: 'x',
        value: 'vx',
      );
      await cacheDao.putJson(
        boxName: box,
        userId: userId,
        key: 'y',
        value: 'vy',
      );

      final result = await cacheDao.getAllJson(box, userId);
      expect(result, {'x': 'vx', 'y': 'vy'});
    });

    test('getAllJson returns empty map when no entries', () async {
      final result = await cacheDao.getAllJson(box, userId);
      expect(result, isEmpty);
    });

    test('user isolation — different users see their own data', () async {
      await cacheDao.putJson(
        boxName: box,
        userId: 'alice',
        key: 'name',
        value: 'Alice',
      );
      await cacheDao.putJson(
        boxName: box,
        userId: 'bob',
        key: 'name',
        value: 'Bob',
      );

      expect(await cacheDao.getJson(box, 'alice', 'name'), 'Alice');
      expect(await cacheDao.getJson(box, 'bob', 'name'), 'Bob');
    });
  });

  group('Parse cache', () {
    const userId = 'user1';

    Future<void> insertEntry({
      required String key,
      String user = userId,
      String version = '1.0',
      String source = 'url',
      DateTime? cachedAt,
    }) async {
      // For deterministic cachedAt values we put directly; otherwise
      // putParsedRecipe uses DateTime.now() which we cannot control in plain
      // async tests. Here we reach through the public API, which is fine for
      // most tests. When an explicit cachedAt is needed we use a small helper
      // that writes to the underlying store.
      await cacheDao.putParsedRecipe(
        cacheKey: key,
        userId: user,
        recipeJson: '{"title":"Recipe $key"}',
        parserVersion: version,
        source: source,
      );
    }

    test('getParsedRecipe returns null for missing key', () async {
      final result = await cacheDao.getParsedRecipe('missing');
      expect(result, isNull);
    });

    test('putParsedRecipe + getParsedRecipe round-trip', () async {
      await cacheDao.putParsedRecipe(
        cacheKey: 'abc',
        userId: userId,
        recipeJson: '{"title":"Pasta"}',
        parserVersion: '2.0',
        source: 'url',
      );

      final entry = await cacheDao.getParsedRecipe('abc');
      expect(entry, isNotNull);
      expect(entry!.cacheKey, 'abc');
      expect(entry.userId, userId);
      expect(entry.recipeJson, '{"title":"Pasta"}');
      expect(entry.parserVersion, '2.0');
      expect(entry.source, 'url');
      expect(entry.cachedAt.isBefore(DateTime.now().add(Duration(seconds: 1))),
          isTrue);
    });

    test('putParsedRecipe overwrites on same key', () async {
      await insertEntry(key: 'dup');
      await cacheDao.putParsedRecipe(
        cacheKey: 'dup',
        userId: userId,
        recipeJson: '{"title":"Updated"}',
        parserVersion: '1.0',
        source: 'url',
      );

      final entry = await cacheDao.getParsedRecipe('dup');
      expect(entry!.recipeJson, '{"title":"Updated"}');
    });

    test('deleteParsedRecipe removes entry', () async {
      await insertEntry(key: 'del');
      await cacheDao.deleteParsedRecipe('del');
      expect(await cacheDao.getParsedRecipe('del'), isNull);
    });

    test('deleteParsedRecipe is no-op for missing key', () async {
      await cacheDao.deleteParsedRecipe('nonexistent');
    });

    test('cleanupParseCacheWrongVersion deletes mismatched entries', () async {
      await insertEntry(key: 'old', version: '0.9');
      await insertEntry(key: 'cur', version: '1.0');
      await insertEntry(key: 'also_old', version: '0.8');

      final deleted = await cacheDao.cleanupParseCacheWrongVersion('1.0');

      expect(deleted, 2);
      expect(await cacheDao.getParsedRecipe('cur'), isNotNull);
      expect(await cacheDao.getParsedRecipe('old'), isNull);
      expect(await cacheDao.getParsedRecipe('also_old'), isNull);
    });

    test('cleanupParseCacheWrongVersion returns 0 when all match', () async {
      await insertEntry(key: 'a', version: '1.0');
      await insertEntry(key: 'b', version: '1.0');

      final deleted = await cacheDao.cleanupParseCacheWrongVersion('1.0');
      expect(deleted, 0);
    });

    test('getParseCacheForUser returns only entries for that user', () async {
      await insertEntry(key: 'u1a', user: 'user1');
      await insertEntry(key: 'u1b', user: 'user1');
      await insertEntry(key: 'u2a', user: 'user2');

      final user1Entries = await cacheDao.getParseCacheForUser('user1');
      expect(user1Entries, hasLength(2));
      expect(
        user1Entries.map((e) => e.cacheKey),
        unorderedEquals(['u1a', 'u1b']),
      );

      final user2Entries = await cacheDao.getParseCacheForUser('user2');
      expect(user2Entries, hasLength(1));
    });

    test('getParseCacheForUser returns empty for unknown user', () async {
      final result = await cacheDao.getParseCacheForUser('nobody');
      expect(result, isEmpty);
    });

    test('countParseCacheForUser counts per-user entries', () async {
      expect(await cacheDao.countParseCacheForUser(userId), 0);

      await insertEntry(key: 'a');
      await insertEntry(key: 'b');
      await insertEntry(key: 'other_user', user: 'user2');

      expect(await cacheDao.countParseCacheForUser(userId), 2);
      expect(await cacheDao.countParseCacheForUser('user2'), 1);
    });

    test('enforceParseCacheLimit keeps newest entries', () async {
      // Insert entries with staggered timestamps by using slight delays
      for (var i = 0; i < 5; i++) {
        await insertEntry(key: 'entry_$i');
        // Small delay to ensure distinct timestamps
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(await cacheDao.countParseCacheForUser(userId), 5);

      // Enforce limit of 3 — should delete the 2 oldest
      await cacheDao.enforceParseCacheLimit(userId, 3);

      expect(await cacheDao.countParseCacheForUser(userId), 3);

      // The oldest 2 (entry_0, entry_1) should be gone; newest 3 remain
      expect(await cacheDao.getParsedRecipe('entry_0'), isNull);
      expect(await cacheDao.getParsedRecipe('entry_1'), isNull);
      expect(await cacheDao.getParsedRecipe('entry_2'), isNotNull);
      expect(await cacheDao.getParsedRecipe('entry_3'), isNotNull);
      expect(await cacheDao.getParsedRecipe('entry_4'), isNotNull);
    });

    test('enforceParseCacheLimit is no-op when under limit', () async {
      await insertEntry(key: 'a');
      await insertEntry(key: 'b');

      await cacheDao.enforceParseCacheLimit(userId, 5);

      expect(await cacheDao.countParseCacheForUser(userId), 2);
    });

    test('enforceParseCacheLimit only affects target user', () async {
      for (var i = 0; i < 5; i++) {
        await insertEntry(key: 'u1_$i', user: 'user1');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await insertEntry(key: 'u2_0', user: 'user2');

      await cacheDao.enforceParseCacheLimit('user1', 2);

      expect(await cacheDao.countParseCacheForUser('user1'), 2);
      expect(await cacheDao.countParseCacheForUser('user2'), 1);
    });

    test('cleanupParseCacheOlderThan removes old entries', () async {
      // Insert an entry that will appear "old" — we can't easily control
      // DateTime.now() in the production code, so instead we insert, then
      // call cleanup with maxAgeDays=0 which makes the cutoff = now,
      // meaning any entry cached before now should be deleted.
      await insertEntry(key: 'old1');
      await insertEntry(key: 'old2');

      // A tiny delay ensures the cutoff is strictly after the entries
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final deleted = await cacheDao.cleanupParseCacheOlderThan(0);
      expect(deleted, 2);
      expect(await cacheDao.getParsedRecipe('old1'), isNull);
      expect(await cacheDao.getParsedRecipe('old2'), isNull);
    });

    test('cleanupParseCacheOlderThan returns 0 when nothing to delete',
        () async {
      await insertEntry(key: 'fresh');

      // 365 days — entry just created is well within range
      final deleted = await cacheDao.cleanupParseCacheOlderThan(365);
      expect(deleted, 0);
      expect(await cacheDao.getParsedRecipe('fresh'), isNotNull);
    });
  });

  group('Cross-store isolation', () {
    test('JSON and parse stores are independent', () async {
      await cacheDao.putJson(
        boxName: 'box',
        userId: 'u1',
        key: 'test',
        value: 'json_value',
      );
      await cacheDao.putParsedRecipe(
        cacheKey: 'test',
        userId: 'u1',
        recipeJson: '{}',
        parserVersion: '1.0',
        source: 'url',
      );

      // Clearing JSON cache should not affect parse cache
      await cacheDao.clearJsonBox('box', 'u1');

      expect(await cacheDao.getJson('box', 'u1', 'test'), isNull);
      expect(await cacheDao.getParsedRecipe('test'), isNotNull);
    });
  });
}
