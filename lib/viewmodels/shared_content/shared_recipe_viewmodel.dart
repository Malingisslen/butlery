/// Shared Recipe ViewModel providing recipe-specific shared content management.
///
/// This specialized ViewModel handles all shared recipe operations including loading,
/// importing, dismissing, and copy-on-write collaboration. It extends the base shared
/// content ViewModel to provide recipe-specific functionality while maintaining
/// consistent patterns with other content types.
///
/// **Responsibilities:**
/// - **Recipe Loading**: Load shared recipes from repository with proper filtering
/// - **Import Operations**: Handle recipe import with copy-on-write support
/// - **Status Management**: Track read/unread status and dismissal state
/// - **Collaboration**: Support copy-on-write collaboration for shared recipes
/// - **Search Integration**: Implement recipe-specific search functionality
///
/// **Integration Points:**
/// - **SocialRecipeCoordinator**: For invitation and sharing operations
/// - **FirebaseSharedRecipeRepository**: For data persistence and retrieval
/// - **SharedRecipe Model**: With full copy-on-write support
///
/// **Usage Example:**
/// ```dart
/// final recipeViewModel = SharedRecipeViewModel();
/// await recipeViewModel.loadContent();
///
/// // Search functionality
/// recipeViewModel.updateSearchQuery('pasta');
/// final searchResults = recipeViewModel.filteredContent;
///
/// // Recipe operations
/// await recipeViewModel.importSharedRecipe(sharedRecipe);
/// await recipeViewModel.dismissSharedRecipe(sharedRecipe);
///
/// // Copy-on-write collaboration
/// await recipeViewModel.joinSharedRecipe(sharedRecipe);
/// ```

// lib/viewmodels/shared_content/shared_recipe_viewmodel.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/viewmodels/shared_content/base_shared_content_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

/// Specialized ViewModel for shared recipe management and operations.
///
/// Note (Issue #014): Uses status caching for synchronous filtering/counting.
/// Status loaded from Firestore subcollections and cached for performance.
class SharedRecipeViewModel extends BaseSharedContentViewModel<SharedRecipe> {
  // ===== DEPENDENCIES =====

  late final FirebaseSharedRecipeRepository _sharedRecipeRepository;
  late final SocialRecipeCoordinator _socialRecipeCoordinator;

  // ===== STATUS CACHING (ISSUE #014) =====

  /// Cached viewed status (recipeId → bool)
  final Map<String, bool> _viewedStatusCache = {};

  /// Cached imported status (recipeId → bool)
  final Map<String, bool> _importedStatusCache = {};

  /// Cached dismissed status (recipeId → bool)
  final Map<String, bool> _dismissedStatusCache = {};

  // ===== CONSTRUCTOR =====

  SharedRecipeViewModel({
    FirebaseSharedRecipeRepository? sharedRecipeRepository,
    SocialRecipeCoordinator? socialRecipeCoordinator,
  }) {
    _sharedRecipeRepository =
        sharedRecipeRepository ?? FirebaseSharedRecipeRepository();
    _socialRecipeCoordinator = socialRecipeCoordinator ??
        ServiceLocator.get<SocialRecipeCoordinator>();

    AppLogger.info(
        'SharedRecipeViewModel initialized with copy-on-write support');
  }

  /// Load status for a recipe from repository and cache it
  Future<void> _loadStatusForRecipe(String recipeId, String userId) async {
    try {
      final viewed = await _sharedRecipeRepository.hasViewed(recipeId, userId);
      final imported = await _sharedRecipeRepository.hasEngaged(recipeId, userId);
      final dismissed = await _sharedRecipeRepository.hasDismissed(recipeId, userId);

      _viewedStatusCache[recipeId] = viewed;
      _importedStatusCache[recipeId] = imported;
      _dismissedStatusCache[recipeId] = dismissed;
    } catch (e) {
      AppLogger.error('Failed to load status for recipe $recipeId', e);
    }
  }

  /// Load status for all recipes in bulk
  Future<void> _loadStatusForAllRecipes(List<SharedRecipe> recipes, String userId) async {
    for (final recipe in recipes) {
      await _loadStatusForRecipe(recipe.id, userId);
    }
  }

  /// Check if recipe is dismissed using cache (falls back to false if not cached)
  bool _isDismissed(String recipeId) {
    return _dismissedStatusCache[recipeId] ?? false;
  }

  /// Check if recipe is viewed using cache (falls back to false if not cached)
  bool _isViewed(String recipeId) {
    return _viewedStatusCache[recipeId] ?? false;
  }

  /// Check if recipe is imported using cache (falls back to false if not cached)
  bool _isImported(String recipeId) {
    return _importedStatusCache[recipeId] ?? false;
  }

  // ===== BASE CLASS IMPLEMENTATIONS =====

  @override
  String get contentTypeName => 'recipe';

  @override
  Future<List<SharedRecipe>> loadContentFromRepository() async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('No authenticated user found');
    }

    AppLogger.info(
        '🔄 Loading shared recipes from repository for user: $userId');
    final recipes =
        await _sharedRecipeRepository.getSharedRecipesForUser(userId);

    // Load status for all recipes to populate cache (Issue #014)
    await _loadStatusForAllRecipes(recipes, userId);

    // Filter out dismissed recipes for main content view using cache
    final visibleRecipes =
        recipes.where((recipe) => !_isDismissed(recipe.id)).toList();

    AppLogger.info(
        '✅ Loaded ${recipes.length} shared recipes (${visibleRecipes.length} visible)');
    return visibleRecipes;
  }

  @override
  String getContentTitle(SharedRecipe content) {
    return content.recipeSnapshot.title;
  }

  @override
  bool contentMatchesSearch(SharedRecipe content, String searchQuery) {
    final query = searchQuery.toLowerCase();
    final recipe = content.recipeSnapshot;

    return recipe.title.toLowerCase().contains(query) ||
        recipe.description.toLowerCase().contains(query) ||
        recipe.ingredients
            .any((ingredient) => ingredient.toLowerCase().contains(query)) ||
        content.sharedByDisplayName.toLowerCase().contains(query);
  }

  @override
  Future<List<SharedRecipe>> loadContentWithPagination({
    int limit = 25,
    DocumentSnapshot? startAfter,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('No authenticated user found');
    }

    AppLogger.info(
        '🔄 Loading shared recipes with pagination (limit: $limit, cursor: ${startAfter != null})');
    final recipes = await _sharedRecipeRepository.getSharedContentForUser(
      userId,
      limit: limit,
      startAfter: startAfter,
    );

    // Load status for all recipes to populate cache (Issue #014)
    await _loadStatusForAllRecipes(recipes, userId);

    // Filter out dismissed recipes for main content view using cache
    final visibleRecipes =
        recipes.where((recipe) => !_isDismissed(recipe.id)).toList();

    AppLogger.info(
        '✅ Loaded ${recipes.length} shared recipes (${visibleRecipes.length} visible)');
    return visibleRecipes;
  }

  @override
  DocumentSnapshot? getLastDocumentFromContent(List<SharedRecipe> content) {
    // Note: This requires the repository to expose the document snapshot
    // For now, return null - will need to enhance repository to return documents with snapshots
    // This is a known limitation that will be addressed when we refactor to include document metadata
    return null;
  }

  // ===== RECIPE-SPECIFIC GETTERS =====

  /// Get unread recipes count (using cache - Issue #014)
  int get unreadCount {
    final userId = currentUserId;
    if (userId == null) return 0;

    return content.where((recipe) => !_isViewed(recipe.id)).length;
  }

  /// Get recipes shared by current user
  List<SharedRecipe> get sharedByCurrentUser {
    final userId = currentUserId;
    if (userId == null) return [];

    return content.where((recipe) => recipe.sharedByUserId == userId).toList();
  }

  /// Get recipes that can be imported (using cache - Issue #014)
  List<SharedRecipe> get importableRecipes {
    final userId = currentUserId;
    if (userId == null) return [];

    return content
        .where((recipe) =>
            !_isImported(recipe.id) && recipe.sharedByUserId != userId)
        .toList();
  }

  // ===== RECIPE OPERATIONS =====

  /// Import shared recipe using copy-on-write pattern
  ///
  /// For new copy-on-write behavior, this joins as viewer until first edit.
  /// For legacy compatibility, creates immediate copy with attribution.
  Future<String?> importSharedRecipe(SharedRecipe sharedRecipe,
      {String? newTitle, bool legacyMode = false}) async {
    return await executeOperation(
      'Import recipe "${getContentTitle(sharedRecipe)}"',
      () async {
        if (legacyMode) {
          // Legacy GitHub fork-style import
          return await _socialRecipeCoordinator.joinSharedRecipe(
            sharedRecipeId: sharedRecipe.id,
            newTitle: newTitle,
          );
        } else {
          // New copy-on-write behavior - join as viewer
          return await _socialRecipeCoordinator.joinSharedRecipe(
            sharedRecipeId: sharedRecipe.id,
            newTitle: newTitle,
          );
        }
      },
    );
  }

  /// Start collaborative editing (triggers copy-on-write)
  ///
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
        final userId = currentUserId;
        if (userId == null) {
          throw Exception('No authenticated user');
        }

        await _sharedRecipeRepository.markAsDismissed(sharedRecipe.id, userId);
        return true;
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
        final userId = currentUserId;
        if (userId == null) {
          throw Exception('No authenticated user');
        }

        await _sharedRecipeRepository.undismiss(sharedRecipe.id, userId);
        return true;
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
  ///
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
        if (_isViewed(sharedRecipe.id)) {
          return true;
        }

        await _sharedRecipeRepository.markAsViewed(sharedRecipe.id, userId);

        // Update cache (Issue #014)
        _viewedStatusCache[sharedRecipe.id] = true;
        notifyListeners(); // Notify UI to refresh

        return true;
      },
    );

    return result ?? false;
  }

  // ===== STATUS CHECKING METHODS =====

  /// Check if recipe is viewed by current user (using cache - Issue #014)
  bool isRecipeViewed(SharedRecipe recipe) {
    final userId = currentUserId;
    if (userId == null) return false;
    return _isViewed(recipe.id);
  }

  /// Check if recipe is imported by current user (using cache - Issue #014)
  bool isRecipeImported(SharedRecipe recipe) {
    final userId = currentUserId;
    if (userId == null) return false;
    return _isImported(recipe.id);
  }

  /// Check if recipe is dismissed by current user (using cache - Issue #014)
  bool isRecipeDismissed(SharedRecipe recipe) {
    final userId = currentUserId;
    if (userId == null) return false;
    return _isDismissed(recipe.id);
  }

  /// Check if recipe can be edited by current user
  ///
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

  // ===== BULK OPERATIONS =====

  /// Mark all recipes as viewed
  ///
  /// Note (Issue #014): Uses cache to identify unviewed recipes, then updates cache after marking.
  Future<void> markAllAsViewed() async {
    final userId = currentUserId;
    if (userId == null) return;

    await executeOperation(
      'Mark all recipes as viewed',
      () async {
        final unviewedRecipes =
            content.where((recipe) => !_isViewed(recipe.id)).toList();

        for (final recipe in unviewedRecipes) {
          await _sharedRecipeRepository.markAsViewed(recipe.id, userId);
          // Update cache (Issue #014)
          _viewedStatusCache[recipe.id] = true;
        }

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
      if (isViewed != null && _isViewed(recipe.id) != isViewed) {
        return false;
      }
      if (isImported != null && _isImported(recipe.id) != isImported) {
        return false;
      }
      if (isDismissed != null && _isDismissed(recipe.id) != isDismissed) {
        return false;
      }
      return true;
    }).toList();
  }

  // ===== ANALYTICS =====

  /// Get recipe engagement statistics (using cache - Issue #014)
  Map<String, int> getEngagementStats() {
    final userId = currentUserId;
    if (userId == null) return {};

    return {
      'total': content.length,
      'unread': content.where((r) => !_isViewed(r.id)).length,
      'imported': content.where((r) => _isImported(r.id)).length,
      'collaborative': content.where((r) => r.isCollaborative).length,
      'sharedByMe': content.where((r) => r.sharedByUserId == userId).length,
    };
  }
}
