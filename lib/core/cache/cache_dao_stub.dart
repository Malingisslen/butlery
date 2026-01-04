/// Web stub for CacheDao - provides no-op implementation for web platform
library;

/// Stub implementation of CacheDao for web platform.
/// All operations are no-ops since SQLite is not available on web.
class CacheDao {
  // JSON cache methods used by JsonCacheHelper
  Future<void> putJson({
    required String boxName,
    required String userId,
    required String key,
    required String value,
  }) async {}

  Future<String?> getJson(String boxName, String userId, String key) async =>
      null;

  Future<void> deleteJson(String boxName, String userId, String key) async {}

  Future<List<String>> getJsonKeys(String boxName, String userId) async => [];

  Future<void> clearJsonBox(String boxName, String userId) async {}

  Future<int> countJsonEntries(String boxName, String userId) async => 0;

  Future<void> putJsonBatch({
    required String boxName,
    required String userId,
    required Map<String, String> entries,
  }) async {}

  // Parse cache methods used by LocalRecipeCache
  Future<ParseCacheEntry?> getParsedRecipe(String cacheKey) async => null;

  Future<void> putParsedRecipe({
    required String cacheKey,
    required String userId,
    required String recipeJson,
    required String parserVersion,
    required String source,
  }) async {}

  Future<void> deleteParsedRecipe(String cacheKey) async {}

  Future<int> cleanupParseCacheOlderThan(int maxAgeDays) async => 0;

  Future<int> cleanupParseCacheWrongVersion(String currentVersion) async => 0;

  Future<List<ParseCacheEntry>> getParseCacheForUser(String userId) async => [];

  Future<int> countParseCacheForUser(String userId) async => 0;

  Future<void> enforceParseCacheLimit(String userId, int maxEntries) async {}
}

/// Stub data class for parse cache entries
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
