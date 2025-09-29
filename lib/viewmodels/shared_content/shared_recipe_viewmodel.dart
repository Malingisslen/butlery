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

import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/viewmodels/shared_content/base_shared_content_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

/// Specialized ViewModel for shared recipe management and operations.
class SharedRecipeViewModel extends BaseSharedContentViewModel<SharedRecipe> {
  
  // ===== DEPENDENCIES =====
  
  late final FirebaseSharedRecipeRepository _sharedRecipeRepository;
  late final SocialRecipeCoordinator _socialRecipeCoordinator;

  // ===== CONSTRUCTOR =====
  
  SharedRecipeViewModel({
    FirebaseSharedRecipeRepository? sharedRecipeRepository,
    SocialRecipeCoordinator? socialRecipeCoordinator,
  }) {
    _sharedRecipeRepository = sharedRecipeRepository ?? FirebaseSharedRecipeRepository();
    _socialRecipeCoordinator = socialRecipeCoordinator ?? ServiceLocator.get<SocialRecipeCoordinator>();
    
    AppLogger.info('SharedRecipeViewModel initialized with copy-on-write support');
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
    
    AppLogger.info('🔄 Loading shared recipes from repository for user: $userId');
    final recipes = await _sharedRecipeRepository.getSharedRecipesForUser(userId);
    
    // Filter out dismissed recipes for main content view
    final visibleRecipes = recipes.where((recipe) => !recipe.isDismissedBy(userId)).toList();
    
    AppLogger.info('✅ Loaded ${recipes.length} shared recipes (${visibleRecipes.length} visible)');
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
           recipe.ingredients.any((ingredient) => ingredient.toLowerCase().contains(query)) ||
           content.sharedByDisplayName.toLowerCase().contains(query);
  }

  // ===== RECIPE-SPECIFIC GETTERS =====
  
  /// Get unread recipes count
  int get unreadCount {
    final userId = currentUserId;
    if (userId == null) return 0;
    
    return content.where((recipe) => !recipe.isViewedBy(userId)).length;
  }
  
  /// Get recipes shared by current user
  List<SharedRecipe> get sharedByCurrentUser {
    final userId = currentUserId;
    if (userId == null) return [];
    
    return content.where((recipe) => recipe.sharedByUserId == userId).toList();
  }
  
  /// Get recipes that can be imported
  List<SharedRecipe> get importableRecipes {
    final userId = currentUserId;
    if (userId == null) return [];
    
    return content.where((recipe) => 
        !recipe.isImportedBy(userId) && 
        recipe.sharedByUserId != userId
    ).toList();
  }

  // ===== RECIPE OPERATIONS =====
  
  /// Import shared recipe using copy-on-write pattern
  /// 
  /// For new copy-on-write behavior, this joins as viewer until first edit.
  /// For legacy compatibility, creates immediate copy with attribution.
  Future<String?> importSharedRecipe(SharedRecipe sharedRecipe, {String? newTitle, bool legacyMode = false}) async {
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
  Future<bool> markAsViewed(SharedRecipe sharedRecipe) async {
    final result = await executeOperation(
      'Mark recipe as viewed "${getContentTitle(sharedRecipe)}"',
      () async {
        final userId = currentUserId;
        if (userId == null) {
          throw Exception('No authenticated user');
        }
        
        // Check if already viewed to avoid unnecessary operations
        if (sharedRecipe.isViewedBy(userId)) {
          return true;
        }
        
        await _sharedRecipeRepository.markAsViewed(sharedRecipe.id, userId);
        
        // Update local state
        final updatedRecipe = sharedRecipe.markViewedBy(userId);
        updateContent(sharedRecipe, updatedRecipe);
        
        return true;
      },
    );
    
    return result ?? false;
  }

  // ===== STATUS CHECKING METHODS =====
  
  /// Check if recipe is viewed by current user
  bool isRecipeViewed(SharedRecipe recipe) {
    final userId = currentUserId;
    if (userId == null) return false;
    return recipe.isViewedBy(userId);
  }
  
  /// Check if recipe is imported by current user
  bool isRecipeImported(SharedRecipe recipe) {
    final userId = currentUserId;
    if (userId == null) return false;
    return recipe.isImportedBy(userId);
  }
  
  /// Check if recipe is dismissed by current user
  bool isRecipeDismissed(SharedRecipe recipe) {
    final userId = currentUserId;
    if (userId == null) return false;
    return recipe.isDismissedBy(userId);
  }
  
  /// Check if recipe can be edited by current user
  bool canEditRecipe(SharedRecipe recipe) {
    final userId = currentUserId;
    if (userId == null) return false;
    return recipe.canBeEditedBy(userId);
  }
  
  /// Check if recipe is in collaborative mode
  bool isRecipeCollaborative(SharedRecipe recipe) {
    return recipe.isCollaborative;
  }

  // ===== BULK OPERATIONS =====
  
  /// Mark all recipes as viewed
  Future<void> markAllAsViewed() async {
    final userId = currentUserId;
    if (userId == null) return;
    
    await executeOperation(
      'Mark all recipes as viewed',
      () async {
        final unviewedRecipes = content.where((recipe) => !recipe.isViewedBy(userId)).toList();
        
        for (final recipe in unviewedRecipes) {
          await _sharedRecipeRepository.markAsViewed(recipe.id, userId);
        }
        
        // Refresh content to update local state
        await loadContent();
      },
      useOperatingState: false, // Use loading state for bulk operations
    );
  }
  
  /// Get recipes by sharing status
  List<SharedRecipe> getRecipesByStatus({
    bool? isViewed,
    bool? isImported, 
    bool? isDismissed,
  }) {
    final userId = currentUserId;
    if (userId == null) return [];
    
    return content.where((recipe) {
      if (isViewed != null && recipe.isViewedBy(userId) != isViewed) return false;
      if (isImported != null && recipe.isImportedBy(userId) != isImported) return false;
      if (isDismissed != null && recipe.isDismissedBy(userId) != isDismissed) return false;
      return true;
    }).toList();
  }

  // ===== ANALYTICS =====
  
  /// Get recipe engagement statistics
  Map<String, int> getEngagementStats() {
    final userId = currentUserId;
    if (userId == null) return {};
    
    return {
      'total': content.length,
      'unread': content.where((r) => !r.isViewedBy(userId)).length,
      'imported': content.where((r) => r.isImportedBy(userId)).length,
      'collaborative': content.where((r) => r.isCollaborative).length,
      'sharedByMe': content.where((r) => r.sharedByUserId == userId).length,
    };
  }
}