/// Social recipe sharing service for collaborative cooking and meal planning.
/// Manages recipe/menu sharing, importing, dismissal, and participant tracking with reactive state management.

import 'package:flutter/foundation.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/repositories/interfaces/social_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/services/social/modules/social_participant_resolver_module.dart';

class SocialRecipeService extends ChangeNotifier
    with StreamManagementMixin, ErrorHandlingMixin {
  final SocialRecipeRepository _repository;
  final UserService _userService;
  final UnifiedRecipeService _recipeService;
  final UnifiedShoppingService? _shoppingService;
  final PermissionService _permissionService;
  final FirebaseSharedRecipeRepository _sharedRecipeRepository;
  final FirebaseSharedMenuRepository _sharedMenuRepository;

  // Modules
  late final SocialParticipantResolverModule _participantResolver;

  // State
  List<SharedRecipe> _sharedRecipes = [];
  List<SharedMenu> _sharedMenus = [];
  bool _isLoading = false;
  String? _error;

  SocialRecipeService({
    required SocialRecipeRepository repository,
    required UserService userService,
    required UnifiedRecipeService recipeService,
    required PermissionService permissionService,
    required FirebaseSharedRecipeRepository sharedRecipeRepository,
    required FirebaseSharedMenuRepository sharedMenuRepository,
    UnifiedShoppingService? shoppingService,
  })  : _repository = repository,
        _userService = userService,
        _recipeService = recipeService,
        _shoppingService = shoppingService,
        _permissionService = permissionService,
        _sharedRecipeRepository = sharedRecipeRepository,
        _sharedMenuRepository = sharedMenuRepository {
    _participantResolver = SocialParticipantResolverModule(
      userService: _userService,
      getSharedRecipes: () => _sharedRecipes,
      getSharedMenus: () => _sharedMenus,
      sharedRecipeRepository: _sharedRecipeRepository,
      sharedMenuRepository: _sharedMenuRepository,
      shoppingService: _shoppingService,
    );
  }

  // Getters
  List<SharedRecipe> get sharedRecipes => List.unmodifiable(_sharedRecipes);
  List<SharedMenu> get sharedMenus => List.unmodifiable(_sharedMenus);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  // For compatibility with old code
  List<SharedRecipe> get sharedWithMe => sharedRecipes;

  /// Initialize the service and load shared content
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
    if (!_permissionService.isAuthenticated) return;
    final currentUserId = _permissionService.currentUserId!;

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

  // Get visible shared recipes (already filtered by repository - no dismissed items)
  /// Note (Issue #014): Repository queries already filter out dismissed items using
  /// subcollection-based shouldShowToUser() checks. No additional filtering needed.
  List<SharedRecipe> getVisibleSharedRecipes(String currentUserId) {
    return _sharedRecipes;
  }

  // Get visible shared menus (already filtered by repository - no dismissed items)
  /// Note (Issue #014): Repository queries already filter out dismissed items using
  /// subcollection-based shouldShowToUser() checks. No additional filtering needed.
  List<SharedMenu> getVisibleSharedMenus(String currentUserId) {
    return _sharedMenus;
  }

  // Mark shared recipe as viewed
  /// Note (Issue #014): Repository handles status tracking in subcollections.
  /// Local state update removed - status now managed server-side only.
  Future<bool> markSharedRecipeAsViewed(String recipeId, String userId) async {
    try {
      await _repository.markSharedRecipeAsViewed(recipeId, userId);
      // Status tracking now handled by repository subcollections (Issue #014)
      // Optionally refresh to get updated viewCount, or rely on next load
      return true;
    } catch (e) {
      AppLogger.error('Failed to mark recipe as viewed', e);
      return false;
    }
  }

  // Mark shared menu as viewed
  /// Note (Issue #014): Repository handles status tracking in subcollections.
  /// Local state update removed - status now managed server-side only.
  Future<bool> markSharedMenuAsViewed(String menuId, String userId) async {
    try {
      await _repository.markSharedMenuAsViewed(menuId, userId);
      // Status tracking now handled by repository subcollections (Issue #014)
      // Optionally refresh to get updated viewCount, or rely on next load
      return true;
    } catch (e) {
      AppLogger.error('Failed to mark menu as viewed', e);
      return false;
    }
  }

  /// Import shared recipe into user's personal collection
  Future<bool> importSharedRecipe(String recipeId) async {
    try {
      final sharedRecipe =
          _sharedRecipes.where((r) => r.id == recipeId).firstOrNull;
      if (sharedRecipe == null) return false;

      // Create a personal recipe from the shared one
      final success = await _recipeService.personal.createRecipe(
        title: sharedRecipe.recipeSnapshot.title,
        description: sharedRecipe.recipeSnapshot.description,
        ingredients: sharedRecipe.recipeSnapshot.ingredients,
        instructions: sharedRecipe.recipeSnapshot.instructions,
        imageUrls: sharedRecipe.recipeSnapshot.imageUrls,
        mealType: sharedRecipe.recipeSnapshot.mealType,
        portions: sharedRecipe.recipeSnapshot.portions,
        timeMinutes: sharedRecipe.recipeSnapshot.timeMinutes,
        tags: sharedRecipe.recipeSnapshot.tags,
        rating: sharedRecipe.recipeSnapshot.rating,
      );

      if (success != null) {
        // Mark as imported
        if (_permissionService.isAuthenticated) {
          await _repository.markSharedRecipeAsImported(
              recipeId, _permissionService.currentUserId!);
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
            title: recipe.title,
            description: recipe.description,
            ingredients: recipe.ingredients,
            instructions: recipe.instructions,
            imageUrls: recipe.imageUrls,
            mealType: recipe.mealType,
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
        if (_permissionService.isAuthenticated) {
          await _repository.markSharedMenuAsImported(
              menuId, _permissionService.currentUserId!);
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
      if (!_permissionService.isAuthenticated) {
        _error = 'User not authenticated';
        return false;
      }
      await _repository.dismissSharedRecipe(
          recipeId, _permissionService.currentUserId!);
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
      if (!_permissionService.isAuthenticated) {
        _error = 'User not authenticated';
        return false;
      }
      await _repository.dismissSharedMenu(
          menuId, _permissionService.currentUserId!);
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
      if (!_permissionService.isAuthenticated) {
        AppLogger.error('User not authenticated');
        return false;
      }
      await _repository.undismissSharedRecipe(
          recipeId, _permissionService.currentUserId!);
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
      if (!_permissionService.isAuthenticated) {
        AppLogger.error('User not authenticated');
        return false;
      }
      await _repository.undismissSharedMenu(
          menuId, _permissionService.currentUserId!);
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
      if (!_permissionService.isAuthenticated) {
        AppLogger.error('User not authenticated');
        throw Exception('User not authenticated');
      }
      await _repository.shareContent(
        fromUserId: _permissionService.currentUserId!,
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
    AppLogger.info(
        'createTestSharedRecipe called - ignoring in real implementation');
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
      // If shopping service not available, return false
      if (_shoppingService == null) {
        AppLogger.warning(
            'Shopping service not available - cannot check sharing status');
        return false;
      }

      // Get all collaborative shopping lists
      final collaborativeLists = _shoppingService.collaborative.getAllLists();
      final list = collaborativeLists.where((l) => l.id == listId).firstOrNull;

      if (list == null) {
        AppLogger.debug('Shopping list $listId not found');
        return false;
      }

      // List is shared if:
      // 1. The user is the owner AND
      // 2. The list has at least one member (shared with someone)
      final isOwner = list.ownerId == userId;
      final hasMembers = list.memberPermissions.isNotEmpty;

      return isOwner && hasMembers;
    } catch (e) {
      AppLogger.error('Failed to check if shopping list is shared', e);
      return false;
    }
  }

  Future<List<UserProfile>> getRecipeParticipants(String recipeId) =>
      _participantResolver.getRecipeParticipants(recipeId);

  Future<List<UserProfile>> getMenuParticipants(String menuId) =>
      _participantResolver.getMenuParticipants(menuId);

  Future<List<UserProfile>> getShoppingListParticipants(String listId) =>
      _participantResolver.getShoppingListParticipants(listId);

  /// Share recipe with multiple friends
  Future<void> shareRecipeToFriends(
      String recipeId, List<String> friendIds) async {
    try {
      if (!_permissionService.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      for (final friendId in friendIds) {
        await shareContent(
          friendId: friendId,
          contentType: 'recipe',
          contentData: {'recipeId': recipeId},
        );
      }

      AppLogger.success('Recipe shared to ${friendIds.length} friends');
    } catch (e) {
      AppLogger.error('Failed to share recipe to friends', e);
      rethrow;
    }
  }

  /// @deprecated Use UnifiedMenuService.shareMenuWithFriends() instead
  @Deprecated('Use UnifiedMenuService.shareMenuWithFriends() instead')
  Future<void> shareMenuToFriends(String menuId, List<String> friendIds) async {
    try {
      if (!_permissionService.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      for (final friendId in friendIds) {
        await shareContent(
          friendId: friendId,
          contentType: 'menu',
          contentData: {'menuId': menuId},
        );
      }

      AppLogger.success('Menu shared to ${friendIds.length} friends');
    } catch (e) {
      AppLogger.error('Failed to share menu to friends', e);
      rethrow;
    }
  }

  /// Share recipe to groups
  Future<void> shareRecipeToGroups(
      String recipeId, List<String> groupIds) async {
    try {
      if (!_permissionService.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      // For each group, resolve members and share to them
      for (final groupId in groupIds) {
        // This would use the UnifiedFriendsService to resolve group members
        // For now, we'll log the action as the group member resolution
        // would be handled by the calling service
        AppLogger.info('Sharing recipe $recipeId to group $groupId');

        await shareContent(
          friendId:
              groupId, // Using groupId as friendId for now - this would be resolved differently
          contentType: 'recipe',
          contentData: {
            'recipeId': recipeId,
            'sharedToGroup': true,
            'groupId': groupId
          },
        );
      }

      AppLogger.success('Recipe shared to ${groupIds.length} groups');
    } catch (e) {
      AppLogger.error('Failed to share recipe to groups', e);
      rethrow;
    }
  }

  /// @deprecated Use UnifiedMenuService.shareMenuWithFriends() instead
  @Deprecated('Use UnifiedMenuService.shareMenuWithFriends() instead')
  Future<void> shareMenuToGroups(String menuId, List<String> groupIds) async {
    try {
      if (!_permissionService.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      // For each group, resolve members and share to them
      for (final groupId in groupIds) {
        // This would use the UnifiedFriendsService to resolve group members
        // For now, we'll log the action as the group member resolution
        // would be handled by the calling service
        AppLogger.info('Sharing menu $menuId to group $groupId');

        await shareContent(
          friendId:
              groupId, // Using groupId as friendId for now - this would be resolved differently
          contentType: 'menu',
          contentData: {
            'menuId': menuId,
            'sharedToGroup': true,
            'groupId': groupId
          },
        );
      }

      AppLogger.success('Menu shared to ${groupIds.length} groups');
    } catch (e) {
      AppLogger.error('Failed to share menu to groups', e);
      rethrow;
    }
  }

  @override
  void dispose() {
    disposeStreamResources();
    super.dispose();
  }
}
