import 'dart:convert';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/daos/recipe_dao.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// Handles user-specific storage operations for offline service
/// Now uses Drift database instead of Hive
class OfflineUserStorage {
  final RecipeDao _recipeDao;
  final SyncQueueDao _syncQueueDao;

  OfflineUserStorage({
    required AppDatabase database,
  }) : _recipeDao = database.recipeDao,
       _syncQueueDao = database.syncQueueDao;

  /// Get recipes for specific user
  Future<List<Recipe>> getRecipesForUser(String userId) async {
    try {
      final offlineRecipes = await _recipeDao.getRecipesForUser(userId);
      final recipes = <Recipe>[];

      for (final offlineRecipe in offlineRecipes) {
        try {
          final json =
              jsonDecode(offlineRecipe.recipeJson) as Map<String, dynamic>;
          recipes.add(Recipe.fromJson(json));
        } catch (e) {
          AppLogger.warning('Failed to parse recipe ${offlineRecipe.id}: $e');
        }
      }

      AppLogger.info(
        '📦 Found ${recipes.length} offline recipes for user: ${userId.maskedUserId}',
      );
      return recipes;
    } catch (e) {
      AppLogger.error('❌ Error getting user recipes: $e');
      return [];
    }
  }

  /// Save recipe with user-specific key
  Future<void> saveRecipeForUser(
    Recipe recipe,
    String userId, {
    required bool isOnline,
  }) async {
    try {
      final recipeJson = jsonEncode(recipe.toJson());

      await _recipeDao.upsertRecipe(
        id: recipe.id,
        userId: userId,
        recipeJson: recipeJson,
        needsSync: !isOnline,
      );

      if (!isOnline) {
        await _syncQueueDao.enqueue(
          userId: userId,
          recipeId: recipe.id,
          operation: SyncOperation.update,
        );

        // H9: Queue for tagging if recipe has failed/pending tagging
        final tagResult = recipe.core.tagResult;
        if (tagResult != null && _needsRetagging(tagResult)) {
          await _syncQueueDao.enqueue(
            userId: userId,
            recipeId: recipe.id,
            operation: SyncOperation.tag,
          );
          AppLogger.debug(
            '📋 Queued offline tagging for recipe: ${recipe.title}',
          );
        }
      }

      AppLogger.info(
        '💾 Recipe saved offline for user ${userId.maskedUserId}: ${recipe.title}',
      );
    } catch (e) {
      AppLogger.error('❌ Error saving recipe offline: $e');
      rethrow;
    }
  }

  /// H9: Check if a recipe needs retagging based on its tagResult.
  ///
  /// The marker set must stay in sync with every PRODUCER that writes one —
  /// the two ingredient cascades AND the bulk-retag drain callable, which is
  /// where `outdated` comes from. "Cascade" alone under-described the list
  /// it heads.
  /// `stale-properties` (written by `on-ingredient-properties-changed.ts`) was
  /// missing: those recipes were marked and then never retagged, and the
  /// `coverage == 0.0` fallback does not rescue them because the existing
  /// tagResult keeps its coverage. That cascade exists to keep ALLERGEN data
  /// current when an ingredient's properties change, so the silently-skipped
  /// recipes were the allergen-relevant ones. It was dormant only because the
  /// cascade's query read a collection that does not exist (BUT-1781).
  bool _needsRetagging(TagResult tagResult) {
    // Check for explicit failure markers
    final version = tagResult.generatorVersion;
    if (version == 'failed' ||
        version == 'pending' ||
        version == 'stale-ingredient' ||
        version == 'stale-properties' ||
        // Written by the bulk-retag drain callable. `STALE_TAG_MARKERS` in
        // cleanup-deleted-ingredients.ts names all three and says this list is
        // its counterpart — so omitting it made that comment false. The online
        // path catches it anyway via TagResult's version-mismatch branch; this
        // is the offline enqueue, which matches on the literal.
        version == 'outdated') {
      return true;
    }

    // Zero coverage also indicates needs retagging
    if (tagResult.coverage == 0.0) {
      return true;
    }

    return false;
  }

  /// Get specific offline recipe for user
  Future<Recipe?> getRecipeForUser(String recipeId, String userId) async {
    try {
      final offlineRecipe = await _recipeDao.getRecipe(recipeId, userId);
      if (offlineRecipe == null) return null;

      final json = jsonDecode(offlineRecipe.recipeJson) as Map<String, dynamic>;
      return Recipe.fromJson(json);
    } catch (e) {
      AppLogger.error('❌ Error getting recipe $recipeId: $e');
      return null;
    }
  }

  /// Delete recipe for specific user
  Future<void> deleteRecipeForUser(String recipeId, String userId) async {
    await _recipeDao.deleteRecipe(recipeId, userId);
    await _syncQueueDao.removeForRecipe(userId, recipeId);
    AppLogger.info(
      '🗑️ Recipe deleted offline for user ${userId.maskedUserId}: $recipeId',
    );
  }

  /// Clear data for specific user
  Future<void> clearUserData(String userId) async {
    try {
      final count = await _recipeDao.countForUser(userId);
      await _recipeDao.deleteAllForUser(userId);
      await _syncQueueDao.clearForUser(userId);

      AppLogger.success(
        '✅ Cleared offline data for user: ${userId.maskedUserId} ($count recipes)',
      );
    } catch (e) {
      AppLogger.error('❌ Error clearing user data: $e');
    }
  }

  /// Get count of offline recipes for user
  Future<int> getRecipeCountForUser(String userId) async {
    return await _recipeDao.countForUser(userId);
  }

  /// Watch recipes for a user (reactive stream)
  Stream<List<Recipe>> watchRecipesForUser(String userId) {
    return _recipeDao.watchRecipesForUser(userId).map((offlineRecipes) {
      final recipes = <Recipe>[];
      for (final offlineRecipe in offlineRecipes) {
        try {
          final json =
              jsonDecode(offlineRecipe.recipeJson) as Map<String, dynamic>;
          recipes.add(Recipe.fromJson(json));
        } catch (e) {
          AppLogger.warning('Failed to parse recipe ${offlineRecipe.id}: $e');
        }
      }
      return recipes;
    });
  }
}
