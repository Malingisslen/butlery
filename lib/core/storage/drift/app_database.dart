import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:butlery/core/storage/drift/tables/offline_recipes.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/core/storage/drift/tables/json_cache.dart';
import 'package:butlery/core/storage/drift/tables/parse_cache.dart';
import 'package:butlery/core/storage/drift/daos/recipe_dao.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart';
import 'package:butlery/core/storage/drift/daos/cache_dao.dart';

part 'app_database.g.dart';

/// Main Drift database for Butlery app
/// Replaces Hive for local storage with SQL-based persistence
@DriftDatabase(
  tables: [
    OfflineRecipes,
    SyncQueueEntries,
    JsonCacheEntries,
    ParseCacheEntries,
  ],
  daos: [
    RecipeDao,
    SyncQueueDao,
    CacheDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing: create an in-memory database
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Add migration logic here for future schema changes
        // Example:
        // if (from < 2) {
        //   await m.addColumn(offlineRecipes, offlineRecipes.newColumn);
        // }
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Clear all data (for testing or user logout)
  Future<void> clearAllData() async {
    await delete(offlineRecipes).go();
    await delete(syncQueueEntries).go();
    await delete(jsonCacheEntries).go();
    await delete(parseCacheEntries).go();
  }

  /// Clear all data for a specific user
  Future<void> clearUserData(String userId) async {
    await (delete(offlineRecipes)..where((t) => t.userId.equals(userId))).go();
    await (delete(syncQueueEntries)..where((t) => t.userId.equals(userId)))
        .go();
    await (delete(jsonCacheEntries)..where((t) => t.userId.equals(userId)))
        .go();
    await (delete(parseCacheEntries)..where((t) => t.userId.equals(userId)))
        .go();
  }

  /// Get database statistics
  Future<Map<String, int>> getStats() async {
    final recipes = await (selectOnly(offlineRecipes)..addColumns([countAll()]))
        .getSingle();
    final syncQueue = await (selectOnly(syncQueueEntries)
          ..addColumns([countAll()]))
        .getSingle();
    final jsonCache = await (selectOnly(jsonCacheEntries)
          ..addColumns([countAll()]))
        .getSingle();
    final parseCache = await (selectOnly(parseCacheEntries)
          ..addColumns([countAll()]))
        .getSingle();

    return {
      'offlineRecipes': recipes.read(countAll()) ?? 0,
      'syncQueue': syncQueue.read(countAll()) ?? 0,
      'jsonCache': jsonCache.read(countAll()) ?? 0,
      'parseCache': parseCache.read(countAll()) ?? 0,
    };
  }
}

/// Opens a connection to the SQLite database
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'butlery_drift.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Creates an in-memory database for testing
QueryExecutor createInMemoryDatabase() {
  return NativeDatabase.memory();
}
