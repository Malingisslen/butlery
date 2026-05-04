// lib/services/social/modules/social_participant_resolver_module.dart

import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/shared_content_member.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:clock/clock.dart';

/// Module handling participant resolution for shared content.
/// Provides participant lookup and profile resolution for recipes, menus, and shopping lists.
/// Note (V1-QP-001): Uses denormalized member info from subcollection to avoid N+1 queries.
class SocialParticipantResolverModule {
  final UserService userService;
  final UnifiedShoppingService? Function() getShoppingService;
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
    required this.getShoppingService,
  });

  /// Get recipe participants using denormalized member info (avoids N+1 lookups)
  /// Returns UserProfile objects created from denormalized data in member subcollection.
  Future<List<UserProfile>> getRecipeParticipants(String recipeId) async {
    try {
      final recipe =
          getSharedRecipes().where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) return [];

      // Fast path: use denormalized member info from subcollection
      final members = await sharedRecipeRepository.getMembersWithInfo(recipeId);
      return _buildParticipantList(
        ownerId: recipe.sharedByUserId,
        ownerDisplayName: recipe.sharedByDisplayName,
        members: members,
      );
    } catch (e) {
      AppLogger.error('Failed to get recipe participants', e);
      return [];
    }
  }

  /// Get menu participants using denormalized member info (avoids N+1 lookups)
  Future<List<UserProfile>> getMenuParticipants(String menuId) async {
    try {
      final menu = getSharedMenus().where((m) => m.id == menuId).firstOrNull;
      if (menu == null) return [];

      // Fast path: use denormalized member info from subcollection
      final members = await sharedMenuRepository.getMembersWithInfo(menuId);
      return _buildParticipantList(
        ownerId: menu.sharedByUserId,
        ownerDisplayName: menu.sharedByDisplayName,
        members: members,
      );
    } catch (e) {
      AppLogger.error('Failed to get menu participants', e);
      return [];
    }
  }

  /// Build participant list from owner + denormalized members
  List<UserProfile> _buildParticipantList({
    required String ownerId,
    required String ownerDisplayName,
    required List<SharedContentMember> members,
  }) {
    final participants = <UserProfile>[];

    // Add owner as first participant
    participants.add(UserProfile(
      uid: ownerId,
      displayName: ownerDisplayName,
      email: '',
      joinedAt: clock.now(),
      lastActiveAt: clock.now(),
    ));

    // Add members from denormalized data (no additional fetches needed)
    for (final member in members) {
      participants.add(UserProfile(
        uid: member.userId,
        displayName: member.displayName,
        avatarUrl: member.avatarUrl,
        email: '',
        joinedAt: member.addedAt,
        lastActiveAt: member.addedAt,
      ));
    }

    return participants;
  }

  /// Get shopping list participants
  Future<List<UserProfile>> getShoppingListParticipants(String listId) async {
    try {
      // If shopping service not available, return empty list
      final shoppingService = getShoppingService();
      if (shoppingService == null) {
        AppLogger.warning(
            'Shopping service not available for participant resolution');
        return [];
      }

      // Get collaborative shopping lists
      final collaborativeLists = shoppingService.collaborative.getAllLists();
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
