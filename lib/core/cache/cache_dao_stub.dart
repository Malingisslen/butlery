/// Web CacheDao backed by IndexedDB via sembast_web.
/// Replaces the previous no-op stub so web users retain cache across refreshes.
library;

import 'package:sembast_web/sembast_web.dart';

const _dbName = 'butlery_cache.db';

final _jsonStore = stringMapStoreFactory.store('json_cache');
final _parseStore = stringMapStoreFactory.store('parse_cache');

/// IndexedDB-backed CacheDao for the web platform.
///
/// The [databaseFactory] parameter defaults to [databaseFactoryWeb] (IndexedDB)
/// but can be overridden with an in-memory factory for unit tests.
class CacheDao {
  final DatabaseFactory _factory;
  Database? _db;

  CacheDao({DatabaseFactory? databaseFactory})
      : _factory = databaseFactory ?? databaseFactoryWeb;

  Future<Database> get _database async {
    return _db ??= await _factory.openDatabase(_dbName);
  }

  // JSON cache

  String _jsonKey(String boxName, String userId, String key) =>
      '$boxName/$userId/$key';

  String _jsonPrefix(String boxName, String userId) => '$boxName/$userId/';

  Future<String?> getJson(String boxName, String userId, String key) async {
    final db = await _database;
    final record = _jsonStore.record(_jsonKey(boxName, userId, key));
    final snapshot = await record.get(db);
    return snapshot?['value'] as String?;
  }

  Future<Map<String, String>> getAllJson(String boxName, String userId) async {
    final db = await _database;
    final prefix = _jsonPrefix(boxName, userId);
    final finder = Finder(
      filter: Filter.custom((record) {
        return (record.key as String).startsWith(prefix);
      }),
    );
    final snapshots = await _jsonStore.find(db, finder: finder);
    return {
      for (final s in snapshots)
        s.key.substring(prefix.length): s.value['value'] as String,
    };
  }

  Future<List<String>> getJsonKeys(String boxName, String userId) async {
    final db = await _database;
    final prefix = _jsonPrefix(boxName, userId);
    final finder = Finder(
      filter: Filter.custom((record) {
        return (record.key as String).startsWith(prefix);
      }),
    );
    final keys = await _jsonStore.findKeys(db, finder: finder);
    return keys.map((k) => k.substring(prefix.length)).toList();
  }

  Future<void> putJson({
    required String boxName,
    required String userId,
    required String key,
    required String value,
  }) async {
    final db = await _database;
    final record = _jsonStore.record(_jsonKey(boxName, userId, key));
    await record.put(db, {
      'value': value,
      'cachedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> putJsonBatch({
    required String boxName,
    required String userId,
    required Map<String, String> entries,
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      for (final entry in entries.entries) {
        final record = _jsonStore.record(_jsonKey(boxName, userId, entry.key));
        await record.put(txn, {
          'value': entry.value,
          'cachedAt': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<void> deleteJson(String boxName, String userId, String key) async {
    final db = await _database;
    final record = _jsonStore.record(_jsonKey(boxName, userId, key));
    await record.delete(db);
  }

  Future<void> clearJsonBox(String boxName, String userId) async {
    final db = await _database;
    final prefix = _jsonPrefix(boxName, userId);
    final finder = Finder(
      filter: Filter.custom((record) {
        return (record.key as String).startsWith(prefix);
      }),
    );
    await _jsonStore.delete(db, finder: finder);
  }

  Future<int> countJsonEntries(String boxName, String userId) async {
    final db = await _database;
    final prefix = _jsonPrefix(boxName, userId);
    return _jsonStore.count(
      db,
      filter: Filter.custom((record) {
        return (record.key as String).startsWith(prefix);
      }),
    );
  }

  // Parse cache

  Future<ParseCacheEntry?> getParsedRecipe(String cacheKey) async {
    final db = await _database;
    final record = _parseStore.record(cacheKey);
    final snapshot = await record.get(db);
    if (snapshot == null) return null;
    return ParseCacheEntry(
      cacheKey: cacheKey,
      userId: snapshot['userId'] as String,
      recipeJson: snapshot['recipeJson'] as String,
      parserVersion: snapshot['parserVersion'] as String,
      source: snapshot['source'] as String,
      cachedAt: DateTime.parse(snapshot['cachedAt'] as String),
    );
  }

  Future<void> putParsedRecipe({
    required String cacheKey,
    required String userId,
    required String recipeJson,
    required String parserVersion,
    required String source,
  }) async {
    final db = await _database;
    final record = _parseStore.record(cacheKey);
    await record.put(db, {
      'userId': userId,
      'recipeJson': recipeJson,
      'parserVersion': parserVersion,
      'source': source,
      'cachedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteParsedRecipe(String cacheKey) async {
    final db = await _database;
    final record = _parseStore.record(cacheKey);
    await record.delete(db);
  }

  Future<int> cleanupParseCacheOlderThan(int maxAgeDays) async {
    final db = await _database;
    final cutoff = DateTime.now().subtract(Duration(days: maxAgeDays));
    final finder = Finder(
      filter: Filter.custom((record) {
        final cachedAt = DateTime.parse(record['cachedAt'] as String);
        return cachedAt.isBefore(cutoff);
      }),
    );
    return _parseStore.delete(db, finder: finder);
  }

  Future<int> cleanupParseCacheWrongVersion(String currentVersion) async {
    final db = await _database;
    final finder = Finder(
      filter: Filter.not(Filter.equals('parserVersion', currentVersion)),
    );
    return _parseStore.delete(db, finder: finder);
  }

  Future<List<ParseCacheEntry>> getParseCacheForUser(String userId) async {
    final db = await _database;
    final finder = Finder(filter: Filter.equals('userId', userId));
    final snapshots = await _parseStore.find(db, finder: finder);
    return snapshots
        .map((s) => ParseCacheEntry(
              cacheKey: s.key,
              userId: s.value['userId'] as String,
              recipeJson: s.value['recipeJson'] as String,
              parserVersion: s.value['parserVersion'] as String,
              source: s.value['source'] as String,
              cachedAt: DateTime.parse(s.value['cachedAt'] as String),
            ))
        .toList();
  }

  Future<int> countParseCacheForUser(String userId) async {
    final db = await _database;
    return _parseStore.count(db, filter: Filter.equals('userId', userId));
  }

  Future<void> enforceParseCacheLimit(String userId, int maxEntries) async {
    final count = await countParseCacheForUser(userId);
    if (count <= maxEntries) return;

    final db = await _database;
    final toDelete = count - maxEntries;

    final finder = Finder(
      filter: Filter.equals('userId', userId),
      sortOrders: [SortOrder('cachedAt')],
      limit: toDelete,
    );
    final oldest = await _parseStore.find(db, finder: finder);

    await db.transaction((txn) async {
      for (final entry in oldest) {
        await _parseStore.record(entry.key).delete(txn);
      }
    });
  }
}

/// Data class for parse cache entries (used by web callers via conditional export)
class ParseCacheEntry {
  final String cacheKey;
  final String userId;
  final String recipeJson;
  final String parserVersion;
  final String source;
  final DateTime cachedAt;

  ParseCacheEntry({
    required this.cacheKey,
    required this.userId,
    required this.recipeJson,
    required this.parserVersion,
    required this.source,
    required this.cachedAt,
  });
}
