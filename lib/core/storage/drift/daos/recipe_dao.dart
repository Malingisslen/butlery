import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/recipe_revision_record.dart';
import 'package:butlery/core/storage/drift/tables/offline_recipes.dart';

part 'recipe_dao.g.dart';

/// Data Access Object for offline recipe storage
@DriftAccessor(tables: [OfflineRecipes])
class RecipeDao extends DatabaseAccessor<AppDatabase> with _$RecipeDaoMixin {
  RecipeDao(super.db);

  /// Get all recipes for a user
  Future<List<OfflineRecipe>> getRecipesForUser(String userId) {
    return (select(
      offlineRecipes,
    )..where((r) => r.userId.equals(userId))).get();
  }

  /// Get a specific recipe by ID and user
  Future<OfflineRecipe?> getRecipe(String recipeId, String userId) {
    return (select(offlineRecipes)
          ..where((r) => r.id.equals(recipeId) & r.userId.equals(userId)))
        .getSingleOrNull();
  }

  /// Get all recipes that need syncing for a user
  Future<List<OfflineRecipe>> getRecipesNeedingSync(String userId) {
    return (select(
      offlineRecipes,
    )..where((r) => r.userId.equals(userId) & r.needsSync.equals(true))).get();
  }

  /// Insert or update a recipe
  Future<void> upsertRecipe({
    required String id,
    required String userId,
    required String recipeJson,
    required bool needsSync,
  }) {
    return into(offlineRecipes).insertOnConflictUpdate(
      OfflineRecipesCompanion.insert(
        id: id,
        userId: userId,
        recipeJson: recipeJson,
        updatedAt: clock.now(),
        needsSync: Value(needsSync),
      ),
    );
  }

  /// Marks the recipe as synced only while the device still holds
  /// [sentJson], the copy that reached the server. A save made while the
  /// write was on its way keeps `needsSync`, so its own queue entry still
  /// sends it (BUT-2162).
  Future<void> markSyncedIfUnchanged(
    String recipeId,
    String userId,
    String sentJson,
  ) {
    return (update(offlineRecipes)..where(
          (r) =>
              r.id.equals(recipeId) &
              r.userId.equals(userId) &
              r.recipeJson.equals(sentJson),
        ))
        .write(
          OfflineRecipesCompanion(
            needsSync: const Value(false),
            lastSyncedAt: Value(clock.now()),
          ),
        );
  }

  /// BUT-2213: the server took a write built on revision [sentRev] and is now
  /// at [newRev]. The device copy takes [newRev] while it is still built on
  /// [sentRev], and records the revisions the device produced
  /// ([RecipeRevisionRecord]); a copy that has moved on is left as it is.
  Future<void> advanceRev(
    String recipeId,
    String userId, {
    required int? sentRev,
    required int newRev,
    bool created = false,
  }) {
    return transaction(() async {
      final row = await getRecipe(recipeId, userId);
      if (row == null) return;
      final json = jsonDecode(row.recipeJson) as Map<String, dynamic>;
      if (json['rev'] != sentRev) return;
      final advanced = RecipeRevisionRecord.advanced(
        json,
        sentRev: sentRev,
        newRev: newRev,
        created: created,
      );
      await _writeIfUnchanged(recipeId, userId, row.recipeJson, advanced);
    });
  }

  /// BUT-2213: the server's recipe replaces the device copy only while the
  /// copy is still [sentJson], the one whose write met the conflict. A save
  /// made while that write was on its way is kept, with its own queue entry.
  /// Returns whether the copy was replaced.
  Future<bool> replaceIfUnchanged(
    String recipeId,
    String userId, {
    required String sentJson,
    required String serverJson,
  }) async {
    final written =
        await (update(offlineRecipes)..where(
              (r) =>
                  r.id.equals(recipeId) &
                  r.userId.equals(userId) &
                  r.recipeJson.equals(sentJson),
            ))
            .write(
              OfflineRecipesCompanion(
                recipeJson: Value(serverJson),
                needsSync: const Value(false),
                lastSyncedAt: Value(clock.now()),
                updatedAt: Value(clock.now()),
              ),
            );
    return written > 0;
  }

  Future<void> _writeIfUnchanged(
    String recipeId,
    String userId,
    String readJson,
    Map<String, dynamic> json,
  ) =>
      (update(offlineRecipes)..where(
            (r) =>
                r.id.equals(recipeId) &
                r.userId.equals(userId) &
                r.recipeJson.equals(readJson),
          ))
          .write(OfflineRecipesCompanion(recipeJson: Value(jsonEncode(json))));

  /// Mark a recipe as synced
  Future<void> markSynced(String recipeId, String userId) {
    return (update(
      offlineRecipes,
    )..where((r) => r.id.equals(recipeId) & r.userId.equals(userId))).write(
      OfflineRecipesCompanion(
        needsSync: const Value(false),
        lastSyncedAt: Value(clock.now()),
      ),
    );
  }

  /// Delete a recipe
  Future<void> deleteRecipe(String recipeId, String userId) {
    return (delete(
      offlineRecipes,
    )..where((r) => r.id.equals(recipeId) & r.userId.equals(userId))).go();
  }

  /// Delete all recipes for a user
  Future<void> deleteAllForUser(String userId) {
    return (delete(offlineRecipes)..where((r) => r.userId.equals(userId))).go();
  }

  /// Count recipes for a user
  Future<int> countForUser(String userId) async {
    final count = countAll();
    final query = selectOnly(offlineRecipes)
      ..addColumns([count])
      ..where(offlineRecipes.userId.equals(userId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Watch all recipes for a user (reactive stream)
  Stream<List<OfflineRecipe>> watchRecipesForUser(String userId) {
    return (select(
      offlineRecipes,
    )..where((r) => r.userId.equals(userId))).watch();
  }
}
