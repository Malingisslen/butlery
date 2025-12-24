import 'package:drift/drift.dart';

/// Table for recipe parse cache (replaces Hive local_recipe_cache box)
/// Includes content-hash security to prevent cache poisoning
class ParseCacheEntries extends Table {
  /// SHA256 cache key (hash of userId + urlHash + contentHash + source + version)
  TextColumn get cacheKey => text()();

  /// User ID for data isolation
  TextColumn get userId => text()();

  /// JSON-serialized ParsedRecipe
  TextColumn get recipeJson => text()();

  /// Parser version that created this cache entry
  TextColumn get parserVersion => text()();

  /// Import source type (url, text, ocr, etc.)
  TextColumn get source => text()();

  /// When the entry was cached
  DateTimeColumn get cachedAt => dateTime()();

  /// Primary key is the SHA256 cache key
  @override
  Set<Column> get primaryKey => {cacheKey};
}
