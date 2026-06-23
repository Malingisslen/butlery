/// Shared Recipe ViewModel providing recipe-specific shared content management.
/// This specialized ViewModel handles all shared recipe operations including loading,
/// importing, dismissing, and copy-on-write collaboration. It extends the base shared
/// content ViewModel to provide recipe-specific functionality while maintaining
/// consistent patterns with other content types.
/// **Responsibilities:**
/// - **Recipe Loading**: Load shared recipes from repository with proper filtering
/// - **Import Operations**: Handle recipe import with copy-on-write support
/// - **Status Management**: Track read/unread status and dismissal state
/// - **Collaboration**: Support copy-on-write collaboration for shared recipes
/// - **Search Integration**: Implement recipe-specific search functionality
/// **Integration Points:**
/// - **SocialRecipeCoordinator**: For invitation and sharing operations
/// - **FirebaseSharedRecipeRepository**: For data persistence and retrieval
/// - **SharedRecipe Model**: With full copy-on-write support
/// **Usage Example:**
/// ```dart
/// final recipeViewModel = SharedRecipeViewModel();
/// await recipeViewModel.loadContent();
/// // Search functionality
/// recipeViewModel.updateSearchQuery('pasta');
/// final searchResults = recipeViewModel.filteredContent;
/// // Recipe operations
/// await recipeViewModel.importSharedRecipe(sharedRecipe);
/// await recipeViewModel.dismissSharedRecipe(sharedRecipe);
/// // Copy-on-write collaboration
/// await recipeViewModel.joinSharedRecipe(sharedRecipe);
/// ```

// lib/viewmodels/shared_content/shared_recipe_viewmodel.dart

import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/viewmodels/shared_content/base_shared_content_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// Specialized ViewModel for shared recipe management and operations.
/// Note (Issue #014): Uses status caching for synchronous filtering/counting.
/// Status loaded from Firestore subcollections and cached for performance.
class SharedRecipeViewModel extends BaseSharedContentViewModel<SharedRecipe> {
  late final SocialRecipeCoordinator _socialRecipeCoordinator;

  SharedRecipeViewModel({
    SocialRecipeCoordinator? socialRecipeCoordinator,
    super.permissionService,
    super.friendsService,
  }) {
    _socialRecipeCoordinator =
        socialRecipeCoordinator ??
        ServiceLocator.get<SocialRecipeCoordinator>();

    AppLogger.info(
      'SharedRecipeViewModel initialized with copy-on-write support',
    );
  }
  @override
  String get contentTypeName => 'recipe';

  @override
  Future<List<SharedRecipe>> loadContentFromRepository() async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('No authenticated user found');
    }

    AppLogger.info(
      '🔄 Loading shared recipes from coordinator for user: ${userId.maskedUserId}',
    );
    final recipes = await _socialRecipeCoordinator.getSharedRecipesForUser(
      userId,
    );

    // Load status for all recipes to populate cache (Issue #014)
    await _socialRecipeCoordinator.loadStatusForAllRecipes(recipes, userId);

    // Filter out dismissed recipes, imported recipes, and content from blocked users
    final blocked = blockedUsers;
    final visibleRecipes = recipes
        .where(
          (recipe) =>
              !_socialRecipeCoordinator.isRecipeDismissed(recipe.id) &&
              !blocked.contains(recipe.sharedByUserId) &&
              (showImported ||
                  !_socialRecipeCoordinator.isRecipeImported(recipe.id)),
        )
        .toList();

    AppLogger.info(
      '✅ Loaded ${recipes.length} shared recipes (${visibleRecipes.length} visible)',
    );
    return visibleRecipes;
  }

  @override
  String getContentTitle(SharedRecipe content) {
    return content.recipeTitle;
  }

  @override
  bool contentMatchesSearch(SharedRecipe content, String searchQuery) {
    final query = searchQuery.toLowerCase();

    // Use denormalized fields for V2 efficiency
    final titleMatch = content.recipeTitle.toLowerCase().contains(query);
    final descriptionMatch =
        content.recipeDescription?.toLowerCase().contains(query) ?? false;
    final sharedByMatch = content.sharedByDisplayName.toLowerCase().contains(
      query,
    );

    // If full snapshot is available, also search ingredients
    final ingredientMatch =
        content.hasFullSnapshot &&
        content.recipeSnapshot!.ingredients.any(
          (ingredient) => ingredient.toLowerCase().contains(query),
        );

    return titleMatch || descriptionMatch || ingredientMatch || sharedByMatch;
  }

  @override
  Future<List<SharedRecipe>> loadContentWithPagination({
    int limit = 25,
    Object? startAfter,
  }) async {
    // Pagination not used for MVP - delegate to standard loading
    return loadContentFromRepository();
  }

  @override
  Object? getLastDocumentFromContent(List<SharedRecipe> content) {
    // Note: This requires the repository to expose the document snapshot
    // For now, return null - will need to enhance repository to return documents with snapshots
    // This is a known limitation that will be addressed when we refactor to include document metadata
    return null;
  }

  /// Get unread recipes count (using cache - Issue #014)
  /// Respects showImported filter - imported items don't count as unread when hidden
  int get unreadCount {
    final userId = currentUserId;
    if (userId == null) return 0;

    return content
        .where(
          (recipe) =>
              !_socialRecipeCoordinator.isRecipeViewed(recipe.id) &&
              (showImported ||
                  !_socialRecipeCoordinator.isRecipeImported(recipe.id)),
        )
        .length;
  }

  /// Get recipes shared by current user
  List<SharedRecipe> get sharedByCurrentUser {
    final userId = currentUserId;
    if (userId == null) return [];

    return content.where((recipe) => recipe.sharedByUserId == userId).toList();
  }

  /// Get recipes shared by a specific friend with the current user.
  /// Used by the per-friend filtered view (BUT-1000): scopes the already-loaded
  /// shared-recipe inbox to a single sharer, reusing the same content the
  /// "Shared with me" list renders (dismissed/blocked/imported filtering already
  /// applied by [loadContentFromRepository]).
  List<SharedRecipe> recipesSharedBy(String friendId) {
    return content
        .where((recipe) => recipe.sharedByUserId == friendId)
        .toList();
  }

  /// Get recipes that can be imported (using cache - Issue #014)
  List<SharedRecipe> get importableRecipes {
    final userId = currentUserId;
    if (userId == null) return [];

    return content
        .where(
          (recipe) =>
              !_socialRecipeCoordinator.isRecipeImported(recipe.id) &&
              recipe.sharedByUserId != userId,
        )
        .toList();
  }

  /// Get specific shared recipe by ID.
  /// Used for group content view and deep links where the full SharedRecipe is needed.
  Future<SharedRecipe?> getSharedRecipeById(String recipeId) async {
    return await executeOperation(
      'Load shared recipe $recipeId',
      () async {
        return await _socialRecipeCoordinator.getSharedRecipeById(recipeId);
      },
    );
  }

  /// Import shared recipe using copy-on-write pattern: joins as viewer
  /// until the first edit, at which point the coordinator creates the
  /// owning copy.
  Future<String?> importSharedRecipe(
    SharedRecipe sharedRecipe, {
    String? newTitle,
  }) async {
    return await executeOperation(
      'Import recipe "${getContentTitle(sharedRecipe)}"',
      () async {
        return await _socialRecipeCoordinator.joinSharedRecipe(
          sharedRecipeId: sharedRecipe.id,
          newTitle: newTitle,
        );
      },
    );
  }

  /// Start collaborative editing (triggers copy-on-write)
  /// This method triggers copy-on-write when user attempts first edit.
  /// Creates static copy for original owner and enables collaboration.
  Future<String?> startCollaborativeEditing(SharedRecipe sharedRecipe) async {
    return await executeOperation(
      'Start collaborative editing for "${getContentTitle(sharedRecipe)}"',
      () async {
        return await _socialRecipeCoordinator.startCollaborativeEditing(
          sharedRecipeId: sharedRecipe.id,
        );
      },
    );
  }

  /// Dismiss shared recipe from user's list
  Future<bool> dismissSharedRecipe(SharedRecipe sharedRecipe) async {
    final result = await executeOperation(
      'Dismiss recipe "${getContentTitle(sharedRecipe)}"',
      () async {
        return await _socialRecipeCoordinator.dismissSharedRecipe(
          sharedRecipe.id,
        );
      },
    );

    if (result == true) {
      // Remove from local collection
      removeContent(sharedRecipe);
    }

    return result ?? false;
  }

  /// Restore dismissed recipe to user's list
  Future<bool> undismissSharedRecipe(SharedRecipe sharedRecipe) async {
    final result = await executeOperation(
      'Restore recipe "${getContentTitle(sharedRecipe)}"',
      () async {
        return await _socialRecipeCoordinator.undismissSharedRecipe(
          sharedRecipe.id,
        );
      },
    );

    if (result == true) {
      // Add back to local collection if not already present
      if (!content.any((r) => r.id == sharedRecipe.id)) {
        addContent(sharedRecipe);
      }
    }

    return result ?? false;
  }

  /// Mark recipe as viewed/read
  /// Note (Issue #014): Updates cache instead of local model state.
  Future<bool> markAsViewed(SharedRecipe sharedRecipe) async {
    final result = await executeOperation(
      'Mark recipe as viewed "${getContentTitle(sharedRecipe)}"',
      () async {
        final userId = currentUserId;
        if (userId == null) {
          throw Exception('No authenticated user');
        }

        // Check if already viewed to avoid unnecessary operations (using cache)
        if (_socialRecipeCoordinator.isRecipeViewed(sharedRecipe.id)) {
          return true;
        }

        await _socialRecipeCoordinator.markRecipeAsViewed(sharedRecipe.id);

        // Reload status to update coordinator's cache (Issue #014)
        await _socialRecipeCoordinator.loadStatusForRecipe(
          sharedRecipe.id,
          userId,
        );
        notifyListeners(); // Notify UI to refresh

        return true;
      },
    );

    return result ?? false;
  }

  /// Check if recipe is viewed by current user (using cache - Issue #014)
  bool isRecipeViewed(SharedRecipe recipe) {
    final userId = currentUserId;
    if (userId == null) return false;
    return _socialRecipeCoordinator.isRecipeViewed(recipe.id);
  }

  /// Check if recipe is imported by current user (using cache - Issue #014)
  bool isRecipeImported(SharedRecipe recipe) {
    final userId = currentUserId;
    if (userId == null) return false;
    return _socialRecipeCoordinator.isRecipeImported(recipe.id);
  }

  /// Check if recipe is dismissed by current user (using cache - Issue #014)
  bool isRecipeDismissed(SharedRecipe recipe) {
    final userId = currentUserId;
    if (userId == null) return false;
    return _socialRecipeCoordinator.isRecipeDismissed(recipe.id);
  }

  /// Check if recipe can be edited by current user
  /// Note (Issue #014): Simplified version. For accurate collaborator checks,
  /// use repository.isCollaborator(recipeId, userId).
  bool canEditRecipe(SharedRecipe recipe) {
    final userId = currentUserId;
    if (userId == null) return false;

    // Owner can always edit
    if (recipe.sharedByUserId == userId) return true;

    // Check if collaboration is allowed
    return recipe.allowCollaboration && recipe.copyOnWriteTriggered;
  }

  /// Check if recipe is in collaborative mode
  bool isRecipeCollaborative(SharedRecipe recipe) {
    return recipe.isCollaborative;
  }

  /// Mark all recipes as viewed
  /// Note (Issue #014): Uses cache to identify unviewed recipes, then updates cache after marking.
  Future<void> markAllAsViewed() async {
    final userId = currentUserId;
    if (userId == null) return;

    await executeOperation(
      'Mark all recipes as viewed',
      () async {
        final unviewedRecipes = content
            .where(
              (recipe) => !_socialRecipeCoordinator.isRecipeViewed(recipe.id),
            )
            .toList();

        await Future.wait(
          unviewedRecipes.map((recipe) async {
            final success = await _socialRecipeCoordinator.markRecipeAsViewed(
              recipe.id,
            );
            if (success) {
              _socialRecipeCoordinator.setViewedStatus(recipe.id, true);
            }
          }),
        );

        // Notify UI to refresh
        notifyListeners();
      },
      useOperatingState: false, // Use loading state for bulk operations
    );
  }

  /// Get recipes by sharing status (using cache - Issue #014)
  List<SharedRecipe> getRecipesByStatus({
    bool? isViewed,
    bool? isImported,
    bool? isDismissed,
  }) {
    final userId = currentUserId;
    if (userId == null) return [];

    return content.where((recipe) {
      if (isViewed != null &&
          _socialRecipeCoordinator.isRecipeViewed(recipe.id) != isViewed) {
        return false;
      }
      if (isImported != null &&
          _socialRecipeCoordinator.isRecipeImported(recipe.id) != isImported) {
        return false;
      }
      if (isDismissed != null &&
          _socialRecipeCoordinator.isRecipeDismissed(recipe.id) !=
              isDismissed) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Get recipe engagement statistics (using cache - Issue #014)
  Map<String, int> getEngagementStats() {
    final userId = currentUserId;
    if (userId == null) return {};

    return {
      'total': content.length,
      'unread': content
          .where((r) => !_socialRecipeCoordinator.isRecipeViewed(r.id))
          .length,
      'imported': content
          .where((r) => _socialRecipeCoordinator.isRecipeImported(r.id))
          .length,
      'collaborative': content.where((r) => r.isCollaborative).length,
      'sharedByMe': content.where((r) => r.sharedByUserId == userId).length,
    };
  }
}
