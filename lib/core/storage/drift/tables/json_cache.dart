import 'package:drift/drift.dart';

/// Table for generic JSON cache storage (replaces Hive JSON cache boxes)
/// Used for: unified_recipes_cache, unified_shopping_lists_cache, unified_friends_cache
class JsonCacheEntries extends Table {
  /// Box name identifier (e.g., 'unified_recipes_cache')
  TextColumn get boxName => text()();

  /// User ID for data isolation
  TextColumn get userId => text()();

  /// Cache key
  TextColumn get key => text()();

  /// JSON-encoded value
  TextColumn get value => text()();

  /// When the entry was cached
  DateTimeColumn get cachedAt => dateTime()();

  /// Composite primary key: (boxName, userId, key)
  @override
  Set<Column> get primaryKey => {boxName, userId, key};
}
