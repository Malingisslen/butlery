import 'dart:async';
import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_change.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

/// Repository interface for recipe data operations.
abstract class RecipeRepository extends Repository<Recipe>
    with StreamManagementMixin {
  /// Stream of recipes for the specified user.
  ///
  /// Returns the most recent [pageSize] recipes ordered by `core.updatedAt` desc
  /// (default 100). Use [loadMoreRecipes] to fetch the next page when the user
  /// scrolls past the initial set. The watcher itself stays bounded so account-
  /// level pagination doesn't multiply listener cost.
  Stream<List<Recipe>> watchRecipes(String userId, {int pageSize = 100});

  /// Subscribe to recipe changes for real-time collaboration.
  ///
  /// Bounded to [pageSize] most recent recipes (default 100) for the same
  /// reason as [watchRecipes]: the live listener should not stream unbounded
  /// history. Older recipes are reachable via [loadMoreRecipes].
  StreamSubscription subscribeToUserRecipes(
    String userId,
    void Function(List<RecipeChange>) onData, {
    Function? onError,
    void Function(bool hasPendingWrites, bool isFromCache)? onSyncStatusChanged,
    int pageSize = 100,
  });

  /// Cursor-paginated next-page fetch for a user's recipe collection.
  ///
  /// Order matches [watchRecipes] (`core.updatedAt` desc). Pass the
  /// `core.updatedAt` of the oldest currently-loaded recipe as
  /// [afterUpdatedAt] (and its id as [afterRecipeId] to disambiguate ties).
  /// Returns up to [pageSize] older recipes; an empty list signals exhaustion.
  ///
  /// Replaces the previous arbitrary 500-cap on [watchRecipes] — callers
  /// stitch the live initial page with this paginated tail.
  Future<List<Recipe>> loadMoreRecipes(
    String userId, {
    required DateTime afterUpdatedAt,
    required String afterRecipeId,
    int pageSize = 100,
  });

  /// Search recipes by query text.
  Future<List<Recipe>> searchRecipes(String query);

  /// Batch add multiple recipes.
  Future<void> addRecipes(List<Recipe> recipes);

  /// Fetch all public archive recipes.
  Future<List<Recipe>> fetchArchiveRecipes();

  /// Fetch specific archive recipe by ID.
  Future<Recipe> fetchArchiveRecipe(String id);

  /// Fetch recipes for a specific user with optional limit.
  Future<List<Recipe>> fetchUserRecipes(String userId, {int limit = 50});

  /// Fetch only public recipes for a specific user.
  /// Used for public profile views where only isPublic == true recipes are shown.
  Future<List<Recipe>> fetchPublicUserRecipes(String userId, {int limit = 50});

  /// Fetch all recipes for a user using cursor-based pagination.
  /// Unlike [fetchUserRecipes], this has no hard limit and will fetch
  /// all recipes in batches. Use for batch operations like statistics.
  Future<List<Recipe>> fetchAllUserRecipes(
    String userId, {
    int batchSize = 500,
  });

  /// Renames a personal tag's denormalized name across all user recipes.
  /// Queries by tag ID in personalTagIds, updates name in personalTags array.
  /// personalTagIds is unchanged since it stores UUIDs.
  /// Returns the number of recipes updated.
  Future<int> renamePersonalTagInRecipes(String tagId, String newName);

  /// Removes a personal tag from all user recipes that contain it.
  /// Removes from both personalTagIds and personalTags arrays.
  /// Returns the number of recipes updated.
  Future<int> removePersonalTagFromRecipes(String tagId);

  /// Fetches recipes that have a specific personal tag ID.
  /// Returns up to [limit] recipes ordered by update date.
  Future<List<Recipe>> fetchRecipesByTagId(String tagId, {int limit = 100});

  /// Counts recipes that have a specific personal tag ID.
  /// Uses Firestore arrayContains query on personalTagIds.
  Future<int> countRecipesByTagId(String tagId);

  /// Find recipes by source URL (exact match).
  /// Used for duplicate detection during import.
  Future<List<Recipe>> findBySourceUrl(String url);

  /// Find recipes by title (normalized, case-insensitive match).
  /// Used for duplicate detection during import when no source URL is available.
  Future<List<Recipe>> findByTitle(String title);
}
