import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
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
