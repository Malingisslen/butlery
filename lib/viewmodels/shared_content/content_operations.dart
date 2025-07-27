// lib/viewmodels/shared_content/content_operations.dart

import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/utils/logger.dart';

/// Focused module for content operations
/// 
/// This module handles ONLY content-related operations:
/// - Loading and refreshing shared content
/// - Search and filtering functionality
/// - Content status management (read, import, dismiss)
/// - Content CRUD operations
/// 
/// ❌ DOES NOT CONTAIN: Social features, sharing, friends management
class ContentOperations {

  // ===== CONTENT LOADING =====

  /// Load all shared content
  static Future<void> loadSharedContent(
    SocialRecipeService socialRecipeService,
    Function(bool loading) setLoading,
    Function(String? error) setError,
    Function() updateVisibleContent,
  ) async {
    try {
      setLoading(true);
      setError(null);

      AppLogger.info('🔄 Loading shared content...');

      await socialRecipeService.refresh();
      updateVisibleContent();

      AppLogger.success('✅ Shared content loaded successfully');
    } catch (e) {
      AppLogger.error('Failed to load shared content', e);
      setError('Kunde inte ladda delat innehåll: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }

  /// Update visible content based on user permissions
  static void updateVisibleContent(
    SocialRecipeService socialRecipeService,
    Function(List<SharedRecipe> recipes) setVisibleRecipes,
    Function(List<SharedMenu> menus) setVisibleMenus,
  ) {
    final currentUserId = sl<PermissionService>().currentUserId;
    if (currentUserId == null) {
      setVisibleRecipes([]);
      setVisibleMenus([]);
      return;
    }

    final visibleRecipes = socialRecipeService.getVisibleSharedRecipes(currentUserId);
    final visibleMenus = socialRecipeService.getVisibleSharedMenus(currentUserId);

    setVisibleRecipes(visibleRecipes);
    setVisibleMenus(visibleMenus);

    AppLogger.info(
        '👁️ Visible content updated: ${visibleRecipes.length} recept, ${visibleMenus.length} menyer');
  }

  // ===== SEARCH AND FILTERING =====

  /// Filter recipes based on search query
  static List<SharedRecipe> filterRecipes(
    List<SharedRecipe> recipes,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) return recipes;

    final query = searchQuery.toLowerCase();
    return recipes.where((sharedRecipe) {
      final recipe = sharedRecipe.recipeSnapshot;
      return recipe.title.toLowerCase().contains(query) ||
          recipe.description.toLowerCase().contains(query) ||
          sharedRecipe.sharedByDisplayName.toLowerCase().contains(query) ||
          recipe.ingredients
              .any((ingredient) => ingredient.toLowerCase().contains(query)) ||
          (recipe.tags?.any((tag) => tag.toLowerCase().contains(query)) ??
              false);
    }).toList();
  }

  /// Filter menus based on search query
  static List<SharedMenu> filterMenus(
    List<SharedMenu> menus,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) return menus;

    final query = searchQuery.toLowerCase();
    return menus.where((sharedMenu) {
      return sharedMenu.menuTitle.toLowerCase().contains(query) ||
          sharedMenu.sharedByDisplayName.toLowerCase().contains(query) ||
          sharedMenu.menuSummary.toLowerCase().contains(query) ||
          sharedMenu.categories
              .any((category) => category.toLowerCase().contains(query)) ||
          sharedMenu.menuSnapshot.values.any((recipes) => recipes.any(
              (recipe) =>
                  recipe.title.toLowerCase().contains(query) ||
                  recipe.description.toLowerCase().contains(query)));
    }).toList();
  }

  // ===== READ STATUS MANAGEMENT =====

  /// Check if recipe is marked as read
  static bool isRecipeRead(SharedRecipe sharedRecipe) {
    final currentUserId = sl<PermissionService>().currentUserId;
    return currentUserId != null && sharedRecipe.isViewedBy(currentUserId);
  }

  /// Check if menu is marked as read
  static bool isMenuRead(SharedMenu sharedMenu) {
    final currentUserId = sl<PermissionService>().currentUserId;
    return currentUserId != null && sharedMenu.isViewedBy(currentUserId);
  }

  /// Mark recipe as read
  static Future<void> markRecipeAsRead(
    SharedRecipe sharedRecipe,
    SocialRecipeService socialRecipeService,
    List<SharedRecipe> visibleRecipes,
    Function(List<SharedRecipe>) updateVisibleRecipes,
    Function() notifyListeners,
    Function() updateVisibleContent,
  ) async {
    final currentUserId = sl<PermissionService>().currentUserId;
    if (currentUserId == null || sharedRecipe.isViewedBy(currentUserId)) {
      return;
    }

    try {
      final index = visibleRecipes.indexWhere((r) => r.id == sharedRecipe.id);
      if (index >= 0) {
        final updatedRecipes = [...visibleRecipes];
        updatedRecipes[index] = sharedRecipe.markViewedBy(currentUserId);
        updateVisibleRecipes(updatedRecipes);
        notifyListeners();
      }

      await socialRecipeService.markSharedRecipeAsViewed(
          sharedRecipe.id, currentUserId);

      AppLogger.info(
          '✅ Recipe marked as read: ${sharedRecipe.recipeSnapshot.title}');
    } catch (e) {
      AppLogger.error('Failed to mark recipe as read', e);
      updateVisibleContent();
      notifyListeners();
    }
  }

  /// Mark menu as read
  static Future<void> markMenuAsRead(
    SharedMenu sharedMenu,
    SocialRecipeService socialRecipeService,
    List<SharedMenu> visibleMenus,
    Function(List<SharedMenu>) updateVisibleMenus,
    Function() notifyListeners,
    Function() updateVisibleContent,
  ) async {
    final currentUserId = sl<PermissionService>().currentUserId;
    if (currentUserId == null || sharedMenu.isViewedBy(currentUserId)) {
      return;
    }

    try {
      final index = visibleMenus.indexWhere((m) => m.id == sharedMenu.id);
      if (index >= 0) {
        final updatedMenus = [...visibleMenus];
        updatedMenus[index] = sharedMenu.markViewedBy(currentUserId);
        updateVisibleMenus(updatedMenus);
        notifyListeners();
      }

      await socialRecipeService.markSharedMenuAsViewed(
          sharedMenu.id, currentUserId);

      AppLogger.info('✅ Menu marked as read: ${sharedMenu.menuTitle}');
    } catch (e) {
      AppLogger.error('Failed to mark menu as read', e);
      updateVisibleContent();
      notifyListeners();
    }
  }

  // ===== IMPORT STATUS MANAGEMENT =====

  /// Check if recipe is imported
  static bool isRecipeImported(SharedRecipe sharedRecipe) {
    final currentUserId = sl<PermissionService>().currentUserId;
    return currentUserId != null && sharedRecipe.isImportedBy(currentUserId);
  }

  /// Check if menu is imported
  static bool isMenuImported(SharedMenu sharedMenu) {
    final currentUserId = sl<PermissionService>().currentUserId;
    return currentUserId != null && sharedMenu.isImportedBy(currentUserId);
  }

  /// Import shared recipe
  static Future<bool> importSharedRecipe(
    SharedRecipe sharedRecipe,
    SocialRecipeService socialRecipeService,
    List<SharedRecipe> visibleRecipes,
    Function(List<SharedRecipe>) updateVisibleRecipes,
    Function(bool importing) setImporting,
    Function(String? error) setError,
    Function() notifyListeners,
  ) async {
    try {
      setImporting(true);
      setError(null);

      final success = await socialRecipeService.importSharedRecipe(sharedRecipe.id);

      if (success) {
        final currentUserId = sl<PermissionService>().currentUserId;
        if (currentUserId != null) {
          final index = visibleRecipes.indexWhere((r) => r.id == sharedRecipe.id);
          if (index >= 0) {
            final updatedRecipes = [...visibleRecipes];
            updatedRecipes[index] = sharedRecipe.markImportedBy(currentUserId);
            updateVisibleRecipes(updatedRecipes);
            notifyListeners();
          }
        }

        AppLogger.success(
            '✅ Recipe imported: ${sharedRecipe.recipeSnapshot.title}');
      }

      return success;
    } catch (e) {
      AppLogger.error('Failed to import recipe', e);
      setError('Kunde inte importera recept: ${e.toString()}');
      return false;
    } finally {
      setImporting(false);
    }
  }

  /// Import shared menu
  static Future<bool> importSharedMenu(
    SharedMenu sharedMenu,
    SocialRecipeService socialRecipeService,
    List<SharedMenu> visibleMenus,
    Function(List<SharedMenu>) updateVisibleMenus,
    Function(bool importing) setImporting,
    Function(String? error) setError,
    Function() notifyListeners,
  ) async {
    try {
      setImporting(true);
      setError(null);

      final success = await socialRecipeService.importSharedMenu(sharedMenu.id);

      if (success) {
        final currentUserId = sl<PermissionService>().currentUserId;
        if (currentUserId != null) {
          final index = visibleMenus.indexWhere((m) => m.id == sharedMenu.id);
          if (index >= 0) {
            final updatedMenus = [...visibleMenus];
            updatedMenus[index] = sharedMenu.markImportedBy(currentUserId);
            updateVisibleMenus(updatedMenus);
            notifyListeners();
          }
        }

        AppLogger.success('✅ Menu imported: ${sharedMenu.menuTitle}');
      }

      return success;
    } catch (e) {
      AppLogger.error('Failed to import menu', e);
      setError('Kunde inte importera meny: ${e.toString()}');
      return false;
    } finally {
      setImporting(false);
    }
  }

  // ===== DISMISS FUNCTIONALITY =====

  /// Dismiss shared recipe
  static Future<bool> dismissSharedRecipe(
    SharedRecipe sharedRecipe,
    SocialRecipeService socialRecipeService,
    List<SharedRecipe> visibleRecipes,
    Function(List<SharedRecipe>) updateVisibleRecipes,
    Function(String? error) setError,
    Function() notifyListeners,
    Function() updateVisibleContent,
  ) async {
    try {
      setError(null);

      final updatedRecipes = visibleRecipes.where((r) => r.id != sharedRecipe.id).toList();
      updateVisibleRecipes(updatedRecipes);
      notifyListeners();

      final success = await socialRecipeService.dismissSharedRecipe(sharedRecipe.id);

      if (!success) {
        updateVisibleContent();
        notifyListeners();

        if (socialRecipeService.hasError) {
          setError(socialRecipeService.error!);
        }
      } else {
        AppLogger.success(
            '✅ Recipe dismissed: ${sharedRecipe.recipeSnapshot.title}');
      }

      return success;
    } catch (e) {
      AppLogger.error('Failed to dismiss recipe', e);
      setError('Kunde inte dölja recept: ${e.toString()}');

      updateVisibleContent();
      notifyListeners();

      return false;
    }
  }

  /// Dismiss shared menu
  static Future<bool> dismissSharedMenu(
    SharedMenu sharedMenu,
    SocialRecipeService socialRecipeService,
    List<SharedMenu> visibleMenus,
    Function(List<SharedMenu>) updateVisibleMenus,
    Function(String? error) setError,
    Function() notifyListeners,
    Function() updateVisibleContent,
  ) async {
    try {
      setError(null);

      final updatedMenus = visibleMenus.where((m) => m.id != sharedMenu.id).toList();
      updateVisibleMenus(updatedMenus);
      notifyListeners();

      final success = await socialRecipeService.dismissSharedMenu(sharedMenu.id);

      if (!success) {
        updateVisibleContent();
        notifyListeners();

        if (socialRecipeService.hasError) {
          setError(socialRecipeService.error!);
        }
      } else {
        AppLogger.success('✅ Menu dismissed: ${sharedMenu.menuTitle}');
      }

      return success;
    } catch (e) {
      AppLogger.error('Failed to dismiss menu', e);
      setError('Kunde inte dölja meny: ${e.toString()}');

      updateVisibleContent();
      notifyListeners();

      return false;
    }
  }

  /// Restore dismissed recipe
  static Future<bool> undismissSharedRecipe(
    SharedRecipe sharedRecipe,
    SocialRecipeService socialRecipeService,
    Function() updateVisibleContent,
    Function() notifyListeners,
  ) async {
    try {
      final success = await socialRecipeService.undismissSharedRecipe(sharedRecipe.id);

      if (success) {
        updateVisibleContent();
        notifyListeners();

        AppLogger.success(
            '✅ Recipe restored: ${sharedRecipe.recipeSnapshot.title}');
      }

      return success;
    } catch (e) {
      AppLogger.error('Failed to restore recipe', e);
      return false;
    }
  }

  /// Restore dismissed menu
  static Future<bool> undismissSharedMenu(
    SharedMenu sharedMenu,
    SocialRecipeService socialRecipeService,
    Function() updateVisibleContent,
    Function() notifyListeners,
  ) async {
    try {
      final success = await socialRecipeService.undismissSharedMenu(sharedMenu.id);

      if (success) {
        updateVisibleContent();
        notifyListeners();

        AppLogger.success('✅ Menu restored: ${sharedMenu.menuTitle}');
      }

      return success;
    } catch (e) {
      AppLogger.error('Failed to restore menu', e);
      return false;
    }
  }

  // ===== CONTENT STATISTICS =====

  /// Get unread recipes count
  static int getUnreadRecipesCount(List<SharedRecipe> recipes) {
    final currentUserId = sl<PermissionService>().currentUserId;
    if (currentUserId == null) return 0;

    return recipes
        .where((recipe) => !recipe.isViewedBy(currentUserId))
        .length;
  }

  /// Get unread menus count
  static int getUnreadMenusCount(List<SharedMenu> menus) {
    final currentUserId = sl<PermissionService>().currentUserId;
    if (currentUserId == null) return 0;

    return menus
        .where((menu) => !menu.isViewedBy(currentUserId))
        .length;
  }

  // ===== CONTENT VALIDATION =====

  /// Check if content is available
  static bool hasSharedContent(
    List<SharedRecipe> recipes,
    List<SharedMenu> menus,
  ) {
    return recipes.isNotEmpty || menus.isNotEmpty;
  }

  /// Check if filtered content is available
  static bool hasFilteredContent(
    List<SharedRecipe> filteredRecipes,
    List<SharedMenu> filteredMenus,
  ) {
    return filteredRecipes.isNotEmpty || filteredMenus.isNotEmpty;
  }
}