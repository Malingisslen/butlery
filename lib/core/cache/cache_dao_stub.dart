/// Web CacheDao backed by IndexedDB via sembast_web.
/// Replaces the previous no-op stub so web users retain cache across refreshes.
library;

import 'package:clock/clock.dart';
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

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // JSON cache

  String _jsonKey(String boxName, String userId, String key) =>
      '$boxName/$userId/$key';

  String _jsonPrefix(String boxName, String userId) => '$boxName/$userId/';

  Filter _keyPrefixFilter(String prefix) =>
      Filter.custom((record) => (record.key as String).startsWith(prefix));

  Future<String?> getJson(String boxName, String userId, String key) async {
    final db = await _database;
    final record = _jsonStore.record(_jsonKey(boxName, userId, key));
    final snapshot = await record.get(db);
    return snapshot?['value'] as String?;
  }

  Future<Map<String, String>> getAllJson(String boxName, String userId) async {
    final db = await _database;
    final prefix = _jsonPrefix(boxName, userId);
    final finder = Finder(filter: _keyPrefixFilter(prefix));
    final snapshots = await _jsonStore.find(db, finder: finder);
    return {
      for (final s in snapshots)
        s.key.substring(prefix.length): s.value['value'] as String,
    };
  }

  Future<List<String>> getJsonKeys(String boxName, String userId) async {
    final db = await _database;
    final prefix = _jsonPrefix(boxName, userId);
    final finder = Finder(filter: _keyPrefixFilter(prefix));
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
      'cachedAt': clock.now().toIso8601String(),
    });
  }

  Future<void> putJsonBatch({
    required String boxName,
    required String userId,
    required Map<String, String> entries,
  }) async {
    final db = await _database;
    final now = clock.now().toIso8601String();
    await db.transaction((txn) async {
      for (final entry in entries.entries) {
        final record = _jsonStore.record(_jsonKey(boxName, userId, entry.key));
        await record.put(txn, {
          'value': entry.value,
          'cachedAt': now,
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
    await _jsonStore.delete(db,
        finder: Finder(filter: _keyPrefixFilter(prefix)));
  }

  Future<int> countJsonEntries(String boxName, String userId) async {
    final db = await _database;
    final prefix = _jsonPrefix(boxName, userId);
    return _jsonStore.count(db, filter: _keyPrefixFilter(prefix));
  }

  // Parse cache

  Future<ParseCacheEntry?> getParsedRecipe(String cacheKey) async {
    final db = await _database;
    final record = _parseStore.record(cacheKey);
    final snapshot = await record.get(db);
    if (snapshot == null) return null;
    return ParseCacheEntry._fromMap(cacheKey, snapshot);
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
      'cachedAt': clock.now().toIso8601String(),
    });
  }

  Future<void> deleteParsedRecipe(String cacheKey) async {
    final db = await _database;
    final record = _parseStore.record(cacheKey);
    await record.delete(db);
  }

  Future<int> cleanupParseCacheOlderThan(int maxAgeDays) async {
    final db = await _database;
    final cutoff = clock.now().subtract(Duration(days: maxAgeDays));
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
        .map((s) => ParseCacheEntry._fromMap(s.key, s.value))
        .toList();
  }

  Future<int> countParseCacheForUser(String userId) async {
    final db = await _database;
    return _parseStore.count(db, filter: Filter.equals('userId', userId));
  }

  Future<void> enforceParseCacheLimit(String userId, int maxEntries) async {
    final db = await _database;
    final finder = Finder(
      filter: Filter.equals('userId', userId),
      sortOrders: [SortOrder('cachedAt')],
    );
    final all = await _parseStore.find(db, finder: finder);
    if (all.length <= maxEntries) return;

    final toDelete = all.sublist(0, all.length - maxEntries);
    await db.transaction((txn) async {
      for (final entry in toDelete) {
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

  factory ParseCacheEntry._fromMap(String key, Map<String, Object?> map) =>
      ParseCacheEntry(
        cacheKey: key,
        userId: map['userId'] as String,
        recipeJson: map['recipeJson'] as String,
        parserVersion: map['parserVersion'] as String,
        source: map['source'] as String,
        cachedAt: DateTime.parse(map['cachedAt'] as String),
      );
}
