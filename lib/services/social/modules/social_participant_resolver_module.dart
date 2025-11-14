// lib/services/social/modules/social_participant_resolver_module.dart

import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/core/utils/logger.dart';

/// Module handling participant resolution for shared content.
///
/// Provides participant lookup and profile resolution for recipes, menus, and shopping lists.
///
/// Note (Issue #014): Updated to use Phase 1 repositories for member tracking via
/// Firestore subcollections instead of model arrays.
class SocialParticipantResolverModule {
  final UserService userService;
  final UnifiedShoppingService? shoppingService;
  final List<SharedRecipe> Function() getSharedRecipes;
  final List<SharedMenu> Function() getSharedMenus;
  final FirebaseSharedRecipeRepository sharedRecipeRepository;
  final FirebaseSharedMenuRepository sharedMenuRepository;

  SocialParticipantResolverModule({
    required this.userService,
    required this.getSharedRecipes,
    required this.getSharedMenus,
    required this.sharedRecipeRepository,
    required this.sharedMenuRepository,
    this.shoppingService,
  });

  /// Get recipe participants
  ///
  /// Note (Issue #014): Uses repository.getMembers() to fetch participants from
  /// Firestore subcollection instead of model's sharedToUserIds array.
  Future<List<UserProfile>> getRecipeParticipants(String recipeId) async {
    try {
      final recipe = getSharedRecipes().where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) return [];

      // Fetch members from Firestore subcollection
      final memberIds = await sharedRecipeRepository.getMembers(recipeId);
      final participantIds = [recipe.sharedByUserId, ...memberIds];
      return await userService.getUserProfiles(participantIds);
    } catch (e) {
      AppLogger.error('Failed to get recipe participants', e);
      return [];
    }
  }

  /// Get menu participants
  ///
  /// Note (Issue #014): Uses repository.getMembers() to fetch participants from
  /// Firestore subcollection instead of model's sharedToUserIds array.
  Future<List<UserProfile>> getMenuParticipants(String menuId) async {
    try {
      final menu = getSharedMenus().where((m) => m.id == menuId).firstOrNull;
      if (menu == null) return [];

      // Fetch members from Firestore subcollection
      final memberIds = await sharedMenuRepository.getMembers(menuId);
      final participantIds = [menu.sharedByUserId, ...memberIds];
      return await userService.getUserProfiles(participantIds);
    } catch (e) {
      AppLogger.error('Failed to get menu participants', e);
      return [];
    }
  }

  /// Get shopping list participants
  Future<List<UserProfile>> getShoppingListParticipants(String listId) async {
    try {
      // If shopping service not available, return empty list
      if (shoppingService == null) {
        AppLogger.warning('Shopping service not available for participant resolution');
        return [];
      }

      // Get collaborative shopping lists
      final collaborativeLists = shoppingService!.collaborative.getAllLists();
      final list = collaborativeLists.where((l) => l.id == listId).firstOrNull;

      if (list == null) {
        AppLogger.debug('Shopping list $listId not found');
        return [];
      }

      // Get all participant IDs (owner + members)
      final participantIds = [
        list.ownerId,
        ...list.memberPermissions.keys,
      ];

      // Resolve user profiles
      return await userService.getUserProfiles(participantIds);
    } catch (e) {
      AppLogger.error('Failed to get shopping list participants', e);
      return [];
    }
  }
}
