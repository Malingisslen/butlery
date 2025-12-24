import 'package:drift/drift.dart';

/// Table for offline recipe storage (replaces Hive recipes_offline box)
/// Stores serialized Recipe objects with user isolation
class OfflineRecipes extends Table {
  /// Recipe ID
  TextColumn get id => text()();

  /// User ID for data isolation
  TextColumn get userId => text()();

  /// JSON-serialized recipe data
  TextColumn get recipeJson => text()();

  /// When the recipe was last updated locally
  DateTimeColumn get updatedAt => dateTime()();

  /// Whether this recipe needs to be synced to Firestore
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();

  /// Last sync timestamp
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  /// Composite primary key: (id, userId)
  @override
  Set<Column> get primaryKey => {id, userId};
}
