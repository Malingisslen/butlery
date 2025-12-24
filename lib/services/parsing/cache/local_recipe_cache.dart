import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:butlery/core/storage/drift/daos/cache_dao.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/core/utils/logger.dart';

/// P0-1 Security Fix: Local per-user recipe cache with content-hash protection.
/// Now uses Drift database instead of Hive.
///
/// This cache prevents cache poisoning attacks where the same URL returns
/// different content due to:
/// - A/B tests
/// - Geo-targeting
/// - Time-based content changes
/// - Personalization
///
/// The cache key includes a hash of the actual content, so different content
/// from the same URL will not be confused.
class LocalRecipeCache {
  /// Maximum cache age in days.
  final int maxAgeDays;

  /// Maximum cache size in entries.
  final int maxEntries;

  /// Current parser version (entries from old versions are invalid).
  final String parserVersion;

  /// User ID for per-user isolation.
  final String userId;

  /// Drift cache DAO
  final CacheDao _cacheDao;

  bool _initialized = false;

  LocalRecipeCache({
    required this.userId,
    required this.parserVersion,
    required CacheDao cacheDao,
    this.maxAgeDays = 30,
    this.maxEntries = 100,
  }) : _cacheDao = cacheDao;

  /// Initialize the cache.
  Future<void> init() async {
    if (_initialized) return;

    try {
      await _cleanupOldEntries();
      _initialized = true;
    } catch (e) {
      AppLogger.warning('LocalRecipeCache: Failed to init: $e');
    }
  }

  /// P0-1 FIX: Generate cache key with content hash.
  ///
  /// Key = SHA256(userId | urlHash | contentHash | source | version)
  ///
  /// This prevents cache poisoning where:
  /// - Same URL returns different content (A/B tests, geo-targeting)
  /// - Attacker controls URL content at specific time
  String generateCacheKey({
    required String? urlHash,
    required String contentHash,
    required ImportSource source,
  }) {
    final components = [
      userId,
      urlHash ?? 'no-url',
      contentHash,
      source.name,
      parserVersion,
    ];

    final combined = components.join('|');
    final hash = sha256.convert(utf8.encode(combined));
    return hash.toString().substring(0, 32);
  }

  /// Generate content hash from input text.
  ///
  /// Uses first 5000 characters to balance uniqueness vs performance.
  static String hashContent(String content) {
    final normalized = content
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .substring(0, content.length > 5000 ? 5000 : content.length);

    final hash = sha256.convert(utf8.encode(normalized));
    return hash.toString().substring(0, 16);
  }

  /// Get a cached recipe by key.
  Future<ParsedRecipe?> get({
    required String? urlHash,
    required String contentHash,
    required ImportSource source,
  }) async {
    if (!_initialized) {
      await init();
    }

    final key = generateCacheKey(
      urlHash: urlHash,
      contentHash: contentHash,
      source: source,
    );

    try {
      final entry = await _cacheDao.getParsedRecipe(key);
      if (entry == null) return null;

      // Check age
      final age = DateTime.now().difference(entry.cachedAt);
      if (age.inDays > maxAgeDays) {
        await _cacheDao.deleteParsedRecipe(key);
        return null;
      }

      // Check version
      if (entry.parserVersion != parserVersion) {
        await _cacheDao.deleteParsedRecipe(key);
        return null;
      }

      final recipeJson = jsonDecode(entry.recipeJson) as Map<String, dynamic>;

      AppLogger.debug('LocalRecipeCache: Hit for key $key');
      return ParsedRecipe.fromJson(recipeJson);
    } catch (e) {
      AppLogger.warning('LocalRecipeCache: Get failed: $e');
      return null;
    }
  }

  /// Store a recipe in the cache.
  Future<void> set({
    required String? urlHash,
    required String contentHash,
    required ImportSource source,
    required ParsedRecipe recipe,
  }) async {
    if (!_initialized) {
      await init();
    }

    final key = generateCacheKey(
      urlHash: urlHash,
      contentHash: contentHash,
      source: source,
    );

    try {
      await _cacheDao.putParsedRecipe(
        cacheKey: key,
        userId: userId,
        recipeJson: jsonEncode(recipe.toJson()),
        parserVersion: parserVersion,
        source: source.name,
      );
      AppLogger.debug('LocalRecipeCache: Stored key $key');

      // Enforce max entries
      await _cacheDao.enforceParseCacheLimit(userId, maxEntries);
    } catch (e) {
      AppLogger.warning('LocalRecipeCache: Set failed: $e');
    }
  }

  /// Remove old entries to keep cache size bounded.
  Future<void> _cleanupOldEntries() async {
    try {
      // Clean up entries older than maxAgeDays
      final deletedByAge = await _cacheDao.cleanupParseCacheOlderThan(maxAgeDays);

      // Clean up entries with wrong parser version
      final deletedByVersion =
          await _cacheDao.cleanupParseCacheWrongVersion(parserVersion);

      final total = deletedByAge + deletedByVersion;
      if (total > 0) {
        AppLogger.debug(
          'LocalRecipeCache: Cleaned up $total entries (age: $deletedByAge, version: $deletedByVersion)',
        );
      }
    } catch (e) {
      AppLogger.warning('LocalRecipeCache: Cleanup failed: $e');
    }
  }

  /// Clear all cache entries for this user.
  Future<void> clear() async {
    try {
      // Get all entries for user and delete them
      final entries = await _cacheDao.getParseCacheForUser(userId);
      for (final entry in entries) {
        await _cacheDao.deleteParsedRecipe(entry.cacheKey);
      }
      AppLogger.info('LocalRecipeCache: Cleared');
    } catch (e) {
      AppLogger.warning('LocalRecipeCache: Clear failed: $e');
    }
  }

  /// Get cache statistics.
  Future<Map<String, dynamic>> getStats() async {
    try {
      final count = await _cacheDao.countParseCacheForUser(userId);
      return {
        'entries': count,
        'maxEntries': maxEntries,
        'maxAgeDays': maxAgeDays,
        'parserVersion': parserVersion,
        'initialized': _initialized,
      };
    } catch (e) {
      return {'entries': 0, 'initialized': false};
    }
  }

  /// Close the cache (no-op for Drift, connection managed elsewhere).
  Future<void> close() async {
    _initialized = false;
  }
}
