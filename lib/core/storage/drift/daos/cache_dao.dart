import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/json_cache.dart';
import 'package:butlery/core/storage/drift/tables/parse_cache.dart';

part 'cache_dao.g.dart';

/// Data Access Object for JSON cache and parse cache operations
@DriftAccessor(tables: [JsonCacheEntries, ParseCacheEntries])
class CacheDao extends DatabaseAccessor<AppDatabase> with _$CacheDaoMixin {
  CacheDao(super.db);

  /// Get a cached value
  Future<String?> getJson(String boxName, String userId, String key) async {
    final result = await (select(jsonCacheEntries)
          ..where((e) =>
              e.boxName.equals(boxName) &
              e.userId.equals(userId) &
              e.key.equals(key)))
        .getSingleOrNull();
    return result?.value;
  }

  /// Get all entries for a box and user
  Future<Map<String, String>> getAllJson(String boxName, String userId) async {
    final results = await (select(jsonCacheEntries)
          ..where((e) => e.boxName.equals(boxName) & e.userId.equals(userId)))
        .get();
    return {for (final e in results) e.key: e.value};
  }

  /// Get all keys for a box and user
  Future<List<String>> getJsonKeys(String boxName, String userId) async {
    final results = await (select(jsonCacheEntries)
          ..where((e) => e.boxName.equals(boxName) & e.userId.equals(userId)))
        .get();
    return results.map((e) => e.key).toList();
  }

  /// Save a JSON value
  Future<void> putJson({
    required String boxName,
    required String userId,
    required String key,
    required String value,
  }) {
    return into(jsonCacheEntries).insertOnConflictUpdate(
      JsonCacheEntriesCompanion.insert(
        boxName: boxName,
        userId: userId,
        key: key,
        value: value,
        cachedAt: clock.now(),
      ),
    );
  }

  /// Save multiple JSON values (batch)
  Future<void> putJsonBatch({
    required String boxName,
    required String userId,
    required Map<String, String> entries,
  }) async {
    await batch((b) {
      for (final entry in entries.entries) {
        b.insert(
          jsonCacheEntries,
          JsonCacheEntriesCompanion.insert(
            boxName: boxName,
            userId: userId,
            key: entry.key,
            value: entry.value,
            cachedAt: clock.now(),
          ),
          onConflict: DoUpdate(
            (old) => JsonCacheEntriesCompanion(
              value: Value(entry.value),
              cachedAt: Value(clock.now()),
            ),
          ),
        );
      }
    });
  }

  /// Delete a JSON entry
  Future<void> deleteJson(String boxName, String userId, String key) {
    return (delete(jsonCacheEntries)
          ..where((e) =>
              e.boxName.equals(boxName) &
              e.userId.equals(userId) &
              e.key.equals(key)))
        .go();
  }

  /// Clear all entries for a box and user
  Future<void> clearJsonBox(String boxName, String userId) {
    return (delete(jsonCacheEntries)
          ..where((e) => e.boxName.equals(boxName) & e.userId.equals(userId)))
        .go();
  }

  /// Count entries in a box for a user
  Future<int> countJsonEntries(String boxName, String userId) async {
    final count = countAll();
    final query = selectOnly(jsonCacheEntries)
      ..addColumns([count])
      ..where(jsonCacheEntries.boxName.equals(boxName) &
          jsonCacheEntries.userId.equals(userId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Get a cached parsed recipe
  Future<ParseCacheEntry?> getParsedRecipe(String cacheKey) {
    return (select(parseCacheEntries)
          ..where((e) => e.cacheKey.equals(cacheKey)))
        .getSingleOrNull();
  }

  /// Save a parsed recipe to cache
  Future<void> putParsedRecipe({
    required String cacheKey,
    required String userId,
    required String recipeJson,
    required String parserVersion,
    required String source,
  }) {
    return into(parseCacheEntries).insertOnConflictUpdate(
      ParseCacheEntriesCompanion.insert(
        cacheKey: cacheKey,
        userId: userId,
        recipeJson: recipeJson,
        parserVersion: parserVersion,
        source: source,
        cachedAt: clock.now(),
      ),
    );
  }

  /// Delete a parse cache entry
  Future<void> deleteParsedRecipe(String cacheKey) {
    return (delete(parseCacheEntries)
          ..where((e) => e.cacheKey.equals(cacheKey)))
        .go();
  }

  /// Clean up old parse cache entries
  Future<int> cleanupParseCacheOlderThan(int maxAgeDays) async {
    final cutoff = clock.now().subtract(Duration(days: maxAgeDays));
    return (delete(parseCacheEntries)
          ..where((e) => e.cachedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Clean up parse cache entries with wrong parser version
  Future<int> cleanupParseCacheWrongVersion(String currentVersion) async {
    return (delete(parseCacheEntries)
          ..where((e) => e.parserVersion.equals(currentVersion).not()))
        .go();
  }

  /// Get all parse cache entries for a user (for stats/debugging)
  Future<List<ParseCacheEntry>> getParseCacheForUser(String userId) {
    return (select(parseCacheEntries)..where((e) => e.userId.equals(userId)))
        .get();
  }

  /// Count parse cache entries for a user
  Future<int> countParseCacheForUser(String userId) async {
    final count = countAll();
    final query = selectOnly(parseCacheEntries)
      ..addColumns([count])
      ..where(parseCacheEntries.userId.equals(userId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Enforce max entries limit for parse cache (per user)
  Future<void> enforceParseCacheLimit(String userId, int maxEntries) async {
    final count = await countParseCacheForUser(userId);
    if (count <= maxEntries) return;

    // Delete oldest entries to get under limit
    final toDelete = count - maxEntries;
    final oldestEntries = await (select(parseCacheEntries)
          ..where((e) => e.userId.equals(userId))
          ..orderBy([(e) => OrderingTerm.asc(e.cachedAt)])
          ..limit(toDelete))
        .get();

    for (final entry in oldestEntries) {
      await deleteParsedRecipe(entry.cacheKey);
    }
  }
}
