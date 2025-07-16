// lib/services/social_recipe_service.dart
// Simple implementation to replace the stub for shared content functionality

import 'package:flutter/foundation.dart';
import '../models/shared_recipe.dart';
import '../models/shared_menu.dart';
import '../models/user_profile.dart';
import '../services/unified/unified_recipe_service.dart';
import '../services/user_service.dart';
import '../repositories/interfaces/social_recipe_repository.dart';
import '../repositories/interfaces/auth_repository.dart';
import '../core/utils/logger.dart';

class SocialRecipeService extends ChangeNotifier {
  final SocialRecipeRepository _repository;
  final UserService _userService;
  final UnifiedRecipeService _recipeService;
  final AuthRepository _authRepository;

  // State
  List<SharedRecipe> _sharedRecipes = [];
  List<SharedMenu> _sharedMenus = [];
  bool _isLoading = false;
  String? _error;

  SocialRecipeService({
    required SocialRecipeRepository repository,
    required UserService userService,
    required UnifiedRecipeService recipeService,
    required AuthRepository authRepository,
  })  : _repository = repository,
        _userService = userService,
        _recipeService = recipeService,
        _authRepository = authRepository;

  // Getters
  List<SharedRecipe> get sharedRecipes => List.unmodifiable(_sharedRecipes);
  List<SharedMenu> get sharedMenus => List.unmodifiable(_sharedMenus);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  // For compatibility with old code
  List<SharedRecipe> get sharedWithMe => sharedRecipes;

  Future<void> initialize() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _loadSharedContent();
      AppLogger.info('✅ SocialRecipeService initialized');
    } catch (e) {
      _error = 'Failed to initialize SocialRecipeService: $e';
      AppLogger.error('❌ SocialRecipeService initialization failed', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSharedContent() async {
    final currentUserId = _authRepository.currentUserId;
    if (currentUserId == null) return;

    try {
      _sharedRecipes = await _repository.getSharedRecipes(currentUserId);
      _sharedMenus = await _repository.getSharedMenus(currentUserId);
    } catch (e) {
      AppLogger.error('Failed to load shared content', e);
      _sharedRecipes = [];
      _sharedMenus = [];
    }
  }

  Future<void> refresh() async {
    await _loadSharedContent();
    notifyListeners();
  }

  // Get visible shared recipes (excluding dismissed ones)
  List<SharedRecipe> getVisibleSharedRecipes(String currentUserId) {
    return _sharedRecipes.where((recipe) => !recipe.isDismissedBy(currentUserId)).toList();
  }

  // Get visible shared menus (excluding dismissed ones)
  List<SharedMenu> getVisibleSharedMenus(String currentUserId) {
    return _sharedMenus.where((menu) => !menu.isDismissedBy(currentUserId)).toList();
  }

  // Mark shared recipe as viewed
  Future<bool> markSharedRecipeAsViewed(String recipeId, String userId) async {
    try {
      await _repository.markSharedRecipeAsViewed(recipeId, userId);
      // Update local state
      final index = _sharedRecipes.indexWhere((r) => r.id == recipeId);
      if (index >= 0) {
        _sharedRecipes[index] = _sharedRecipes[index].markViewedBy(userId);
        notifyListeners();
      }
      return true;
    } catch (e) {
      AppLogger.error('Failed to mark recipe as viewed', e);
      return false;
    }
  }

  // Mark shared menu as viewed
  Future<bool> markSharedMenuAsViewed(String menuId, String userId) async {
    try {
      await _repository.markSharedMenuAsViewed(menuId, userId);
      // Update local state
      final index = _sharedMenus.indexWhere((m) => m.id == menuId);
      if (index >= 0) {
        _sharedMenus[index] = _sharedMenus[index].markViewedBy(userId);
        notifyListeners();
      }
      return true;
    } catch (e) {
      AppLogger.error('Failed to mark menu as viewed', e);
      return false;
    }
  }

  // Import shared recipe
  Future<bool> importSharedRecipe(String recipeId) async {
    try {
      final sharedRecipe = _sharedRecipes.where((r) => r.id == recipeId).firstOrNull;
      if (sharedRecipe == null) return false;

      // Create a personal recipe from the shared one
      final success = await _recipeService.personal.createRecipe(
        name: sharedRecipe.recipeSnapshot.title,
        description: sharedRecipe.recipeSnapshot.description,
        ingredients: sharedRecipe.recipeSnapshot.ingredients,
        instructions: sharedRecipe.recipeSnapshot.instructions,
        portions: sharedRecipe.recipeSnapshot.portions,
        timeMinutes: sharedRecipe.recipeSnapshot.timeMinutes,
        tags: sharedRecipe.recipeSnapshot.tags,
        rating: sharedRecipe.recipeSnapshot.rating,
      );

      if (success != null) {
        // Mark as imported
        final currentUserId = _authRepository.currentUserId;
        if (currentUserId != null) {
          await _repository.markSharedRecipeAsImported(recipeId, currentUserId);
        }
        AppLogger.success('Recipe imported successfully');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Failed to import shared recipe', e);
      return false;
    }
  }

  // Import shared menu
  Future<bool> importSharedMenu(String menuId) async {
    try {
      final sharedMenu = _sharedMenus.where((m) => m.id == menuId).firstOrNull;
      if (sharedMenu == null) return false;

      // Import all recipes from the menu
      bool allImported = true;
      for (final entry in sharedMenu.menuSnapshot.entries) {
        for (final recipe in entry.value) {
          final success = await _recipeService.personal.createRecipe(
            name: recipe.title,
            description: recipe.description,
            ingredients: recipe.ingredients,
            instructions: recipe.instructions,
            portions: recipe.portions,
            timeMinutes: recipe.timeMinutes,
            tags: recipe.tags,
            rating: recipe.rating,
          );
          if (success == null) allImported = false;
        }
      }

      if (allImported) {
        // Mark as imported
        final currentUserId = _authRepository.currentUserId;
        if (currentUserId != null) {
          await _repository.markSharedMenuAsImported(menuId, currentUserId);
        }
        AppLogger.success('Menu imported successfully');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Failed to import shared menu', e);
      return false;
    }
  }

  // Dismiss shared recipe
  Future<bool> dismissSharedRecipe(String recipeId) async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) {
        _error = 'User not authenticated';
        return false;
      }
      await _repository.dismissSharedRecipe(recipeId, currentUserId);
      AppLogger.info('Recipe dismissed');
      return true;
    } catch (e) {
      _error = 'Failed to dismiss recipe: $e';
      AppLogger.error('Failed to dismiss shared recipe', e);
      return false;
    }
  }

  // Dismiss shared menu
  Future<bool> dismissSharedMenu(String menuId) async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) {
        _error = 'User not authenticated';
        return false;
      }
      await _repository.dismissSharedMenu(menuId, currentUserId);
      AppLogger.info('Menu dismissed');
      return true;
    } catch (e) {
      _error = 'Failed to dismiss menu: $e';
      AppLogger.error('Failed to dismiss shared menu', e);
      return false;
    }
  }

  // Undismiss shared recipe
  Future<bool> undismissSharedRecipe(String recipeId) async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) {
        AppLogger.error('User not authenticated');
        return false;
      }
      await _repository.undismissSharedRecipe(recipeId, currentUserId);
      AppLogger.info('Recipe restored');
      return true;
    } catch (e) {
      AppLogger.error('Failed to restore shared recipe', e);
      return false;
    }
  }

  // Undismiss shared menu
  Future<bool> undismissSharedMenu(String menuId) async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) {
        AppLogger.error('User not authenticated');
        return false;
      }
      await _repository.undismissSharedMenu(menuId, currentUserId);
      AppLogger.info('Menu restored');
      return true;
    } catch (e) {
      AppLogger.error('Failed to restore shared menu', e);
      return false;
    }
  }

  // Share content with friend
  Future<void> shareContent({
    required String friendId,
    required String contentType,
    required Map<String, dynamic> contentData,
  }) async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) {
        AppLogger.error('User not authenticated');
        throw Exception('User not authenticated');
      }
      await _repository.shareContent(
        fromUserId: currentUserId,
        toUserId: friendId,
        contentType: contentType,
        contentData: contentData,
      );
      AppLogger.info('Content shared successfully');
    } catch (e) {
      AppLogger.error('Failed to share content', e);
      rethrow;
    }
  }

  // For compatibility with old test code
  void createTestSharedRecipe(String recipeId) {
    // This is a no-op for the real implementation
    AppLogger.info('createTestSharedRecipe called - ignoring in real implementation');
  }

  /// Compatibility getters for legacy code
  List<SharedRecipe> get recipesSharedWithMe => sharedRecipes;
  List<SharedMenu> get menusSharedWithMe => sharedMenus;

  /// Check if recipe is shared by user
  Future<bool> isRecipeSharedByUser(String recipeId, String userId) async {
    try {
      final recipe = _sharedRecipes.where((r) => r.id == recipeId).firstOrNull;
      return recipe != null && recipe.sharedByUserId == userId;
    } catch (e) {
      AppLogger.error('Failed to check if recipe is shared', e);
      return false;
    }
  }

  /// Check if menu is shared by user
  Future<bool> isMenuSharedByUser(String menuId, String userId) async {
    try {
      final menu = _sharedMenus.where((m) => m.id == menuId).firstOrNull;
      return menu != null && menu.sharedByUserId == userId;
    } catch (e) {
      AppLogger.error('Failed to check if menu is shared', e);
      return false;
    }
  }

  /// Check if shopping list is shared by user
  Future<bool> isShoppingListSharedByUser(String listId, String userId) async {
    try {
      // This would need to be implemented with proper shopping list sharing
      AppLogger.info('isShoppingListSharedByUser called - not implemented');
      return false;
    } catch (e) {
      AppLogger.error('Failed to check if shopping list is shared', e);
      return false;
    }
  }

  /// Get recipe participants
  Future<List<UserProfile>> getRecipeParticipants(String recipeId) async {
    try {
      final recipe = _sharedRecipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) return [];
      
      // Get user profiles for all participants
      final participantIds = [recipe.sharedByUserId, ...recipe.sharedToUserIds];
      return await _userService.getUserProfiles(participantIds);
    } catch (e) {
      AppLogger.error('Failed to get recipe participants', e);
      return [];
    }
  }

  /// Get menu participants
  Future<List<UserProfile>> getMenuParticipants(String menuId) async {
    try {
      final menu = _sharedMenus.where((m) => m.id == menuId).firstOrNull;
      if (menu == null) return [];
      
      // Get user profiles for all participants
      final participantIds = [menu.sharedByUserId, ...menu.sharedToUserIds];
      return await _userService.getUserProfiles(participantIds);
    } catch (e) {
      AppLogger.error('Failed to get menu participants', e);
      return [];
    }
  }

  /// Get shopping list participants
  Future<List<UserProfile>> getShoppingListParticipants(String listId) async {
    try {
      // This would need to be implemented with proper participant tracking
      AppLogger.info('getShoppingListParticipants called - not implemented');
      return [];
    } catch (e) {
      AppLogger.error('Failed to get shopping list participants', e);
      return [];
    }
  }

  /// Share recipe to friends
  Future<void> shareRecipeToFriends(String recipeId, List<String> friendIds) async {
    try {
      // This would implement proper recipe sharing
      AppLogger.info('shareRecipeToFriends called - not implemented');
    } catch (e) {
      AppLogger.error('Failed to share recipe to friends', e);
    }
  }

  /// Share menu to friends
  Future<void> shareMenuToFriends(String menuId, List<String> friendIds) async {
    try {
      // This would implement proper menu sharing
      AppLogger.info('shareMenuToFriends called - not implemented');
    } catch (e) {
      AppLogger.error('Failed to share menu to friends', e);
    }
  }
}