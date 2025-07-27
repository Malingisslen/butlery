// lib/core/permissions/modules/permission_action_builder.dart

import 'package:butlery/core/permissions/modules/recipe_permission_handler.dart';
import 'package:butlery/core/permissions/modules/shopping_permission_handler.dart';
import 'package:butlery/core/permissions/modules/group_permission_handler.dart';
import 'package:butlery/core/permissions/modules/social_permission_handler.dart';

/// Focused module for building permission actions and levels
/// 
/// This module handles ONLY action list building and permission level calculation:
/// - Building available action lists for resources
/// - Calculating permission levels for UI display
/// - Creating permission summaries
/// - Permission level comparisons
/// 
/// ❌ DOES NOT CONTAIN: Core permission checking, resource-specific logic, debug tools
class PermissionActionBuilder {

  // ===== RECIPE ACTION BUILDERS =====

  /// Get recipe actions available to user
  static List<String> getAvailableRecipeActions(String recipeId) {
    final actions = <String>[];
    
    if (RecipePermissionHandler.canViewRecipe(recipeId)) actions.add('view');
    if (RecipePermissionHandler.canEditRecipe(recipeId)) actions.add('edit');
    if (RecipePermissionHandler.canDeleteRecipe(recipeId)) actions.add('delete');
    if (RecipePermissionHandler.canShareRecipe(recipeId)) actions.add('share');
    if (RecipePermissionHandler.canDuplicateRecipe(recipeId)) actions.add('duplicate');
    if (RecipePermissionHandler.canCommentOnRecipe(recipeId)) actions.add('comment');
    if (RecipePermissionHandler.canRateRecipe(recipeId)) actions.add('rate');
    if (RecipePermissionHandler.canFavoriteRecipe(recipeId)) actions.add('favorite');
    if (RecipePermissionHandler.canExportRecipe(recipeId)) actions.add('export');
    if (RecipePermissionHandler.canPrintRecipe(recipeId)) actions.add('print');
    
    return actions;
  }

  /// Get recipe permission level for UI display
  static String getRecipePermissionLevel(String recipeId) {
    if (RecipePermissionHandler.isRecipeOwner(recipeId)) return 'owner';
    if (RecipePermissionHandler.canEditRecipe(recipeId)) return 'editor';
    if (RecipePermissionHandler.canViewRecipe(recipeId)) return 'viewer';
    return 'none';
  }

  /// Get recipe permission summary
  static Map<String, dynamic> getRecipePermissionSummary(String recipeId) {
    final level = getRecipePermissionLevel(recipeId);
    final actions = getAvailableRecipeActions(recipeId);
    
    return {
      'level': level,
      'actions': actions,
      'actionCount': actions.length,
      'hasAccess': actions.isNotEmpty,
      'canModify': actions.contains('edit'),
      'isOwner': level == 'owner',
    };
  }

  // ===== SHOPPING LIST ACTION BUILDERS =====

  /// Get shopping list actions available to user
  static List<String> getAvailableShoppingListActions(String listId) {
    final actions = <String>[];
    
    if (ShoppingPermissionHandler.canViewShoppingList(listId)) actions.add('view');
    if (ShoppingPermissionHandler.canEditShoppingList(listId)) actions.add('edit');
    if (ShoppingPermissionHandler.canManageShoppingList(listId)) actions.add('manage');
    if (ShoppingPermissionHandler.canDeleteShoppingList(listId)) actions.add('delete');
    if (ShoppingPermissionHandler.canShareShoppingList(listId)) actions.add('share');
    if (ShoppingPermissionHandler.canInviteToShoppingList(listId)) actions.add('invite');
    if (ShoppingPermissionHandler.canAddItemsToShoppingList(listId)) actions.add('add_items');
    if (ShoppingPermissionHandler.canRemoveItemsFromShoppingList(listId)) actions.add('remove_items');
    if (ShoppingPermissionHandler.canModifyItemStatus(listId)) actions.add('modify_items');
    if (ShoppingPermissionHandler.canExportShoppingList(listId)) actions.add('export');
    if (ShoppingPermissionHandler.canPrintShoppingList(listId)) actions.add('print');
    
    return actions;
  }

  /// Get shopping list permission level for UI display
  static String getShoppingListPermissionLevel(String listId) {
    if (ShoppingPermissionHandler.isShoppingListOwner(listId)) return 'owner';
    if (ShoppingPermissionHandler.canManageShoppingList(listId)) return 'manager';
    if (ShoppingPermissionHandler.canEditShoppingList(listId)) return 'editor';
    if (ShoppingPermissionHandler.canViewShoppingList(listId)) return 'viewer';
    return 'none';
  }

  /// Get shopping list permission summary
  static Map<String, dynamic> getShoppingListPermissionSummary(String listId) {
    final level = getShoppingListPermissionLevel(listId);
    final actions = getAvailableShoppingListActions(listId);
    
    return {
      'level': level,
      'actions': actions,
      'actionCount': actions.length,
      'hasAccess': actions.isNotEmpty,
      'canModify': actions.contains('edit'),
      'canManage': actions.contains('manage'),
      'isOwner': level == 'owner',
    };
  }

  // ===== GROUP ACTION BUILDERS =====

  /// Get group actions available to user
  static List<String> getAvailableGroupActions(String groupId) {
    final actions = <String>[];
    
    if (GroupPermissionHandler.canViewGroup(groupId)) actions.add('view');
    if (GroupPermissionHandler.canEditGroup(groupId)) actions.add('edit');
    if (GroupPermissionHandler.canManageGroup(groupId)) actions.add('manage');
    if (GroupPermissionHandler.canDeleteGroup(groupId)) actions.add('delete');
    if (GroupPermissionHandler.canInviteToGroup(groupId)) actions.add('invite');
    if (GroupPermissionHandler.isGroupAdmin(groupId)) actions.add('remove_members');
    if (GroupPermissionHandler.canLeaveGroup(groupId)) actions.add('leave');
    if (GroupPermissionHandler.canChangeGroupSettings(groupId)) actions.add('settings');
    if (GroupPermissionHandler.canPostInGroup(groupId)) actions.add('post');
    if (GroupPermissionHandler.canModerateGroupContent(groupId)) actions.add('moderate');
    
    return actions;
  }

  /// Get group permission level for UI display
  static String getGroupPermissionLevel(String groupId) {
    if (GroupPermissionHandler.isGroupOwner(groupId)) return 'owner';
    if (GroupPermissionHandler.isGroupAdmin(groupId)) return 'admin';
    if (GroupPermissionHandler.isGroupMember(groupId)) return 'member';
    if (GroupPermissionHandler.canViewGroup(groupId)) return 'viewer';
    return 'none';
  }

  /// Get group permission summary
  static Map<String, dynamic> getGroupPermissionSummary(String groupId) {
    final level = getGroupPermissionLevel(groupId);
    final actions = getAvailableGroupActions(groupId);
    
    return {
      'level': level,
      'actions': actions,
      'actionCount': actions.length,
      'hasAccess': actions.isNotEmpty,
      'canModify': actions.contains('edit'),
      'canManage': actions.contains('manage'),
      'isAdmin': level == 'admin' || level == 'owner',
      'isMember': level != 'none' && level != 'viewer',
    };
  }

  // ===== SOCIAL ACTION BUILDERS =====

  /// Get social actions available to user
  static List<String> getAvailableSocialActions(String userId) {
    final actions = <String>[];
    
    if (SocialPermissionHandler.canViewProfile(userId)) actions.add('view');
    if (SocialPermissionHandler.canEditProfile(userId)) actions.add('edit');
    if (SocialPermissionHandler.canSendFriendRequest(userId)) actions.add('send_friend_request');
    if (SocialPermissionHandler.canRemoveFriend(userId)) actions.add('remove_friend');
    if (SocialPermissionHandler.canBlockUser(userId)) actions.add('block');
    if (SocialPermissionHandler.canUnblockUser(userId)) actions.add('unblock');
    if (SocialPermissionHandler.canMessageUser(userId)) actions.add('message');
    if (SocialPermissionHandler.canFollowUser(userId)) actions.add('follow');
    if (SocialPermissionHandler.canMentionUser(userId)) actions.add('mention');
    
    return actions;
  }

  /// Get social permission level for UI display
  static String getSocialPermissionLevel(String userId) {
    if (SocialPermissionHandler.isOwnProfile(userId)) return 'own';
    if (SocialPermissionHandler.areFriends(userId)) return 'friend';
    if (SocialPermissionHandler.canViewProfile(userId)) return 'viewer';
    return 'none';
  }

  /// Get social permission summary
  static Map<String, dynamic> getSocialPermissionSummary(String userId) {
    final level = getSocialPermissionLevel(userId);
    final actions = getAvailableSocialActions(userId);
    
    return {
      'level': level,
      'actions': actions,
      'actionCount': actions.length,
      'hasAccess': actions.isNotEmpty,
      'canInteract': actions.contains('message') || actions.contains('follow'),
      'canEdit': actions.contains('edit'),
      'isOwnProfile': level == 'own',
      'isFriend': level == 'friend',
    };
  }

  // ===== PERMISSION LEVEL COMPARISON =====

  /// Compare permission levels (returns higher level)
  static String comparePermissionLevels(String level1, String level2, String resourceType) {
    final hierarchy = _getPermissionHierarchy(resourceType);
    final index1 = hierarchy.indexOf(level1);
    final index2 = hierarchy.indexOf(level2);
    
    if (index1 == -1) return level2;
    if (index2 == -1) return level1;
    
    return index1 < index2 ? level1 : level2; // Lower index = higher permission
  }

  /// Check if permission level is sufficient
  static bool isPermissionLevelSufficient(String currentLevel, String requiredLevel, String resourceType) {
    final hierarchy = _getPermissionHierarchy(resourceType);
    final currentIndex = hierarchy.indexOf(currentLevel);
    final requiredIndex = hierarchy.indexOf(requiredLevel);
    
    if (currentIndex == -1 || requiredIndex == -1) return false;
    
    return currentIndex <= requiredIndex; // Lower index = higher permission
  }

  /// Get permission hierarchy for resource type
  static List<String> _getPermissionHierarchy(String resourceType) {
    switch (resourceType) {
      case 'recipe':
        return ['owner', 'editor', 'viewer', 'none'];
      case 'shopping_list':
        return ['owner', 'manager', 'editor', 'viewer', 'none'];
      case 'group':
        return ['owner', 'admin', 'member', 'viewer', 'none'];
      case 'social':
        return ['own', 'friend', 'viewer', 'none'];
      default:
        return ['admin', 'editor', 'viewer', 'none'];
    }
  }

  // ===== MULTI-RESOURCE ACTION BUILDERS =====

  /// Get combined actions for multiple resources
  static Map<String, List<String>> getCombinedActions({
    String? recipeId,
    String? shoppingListId,
    String? groupId,
    String? userId,
  }) {
    final result = <String, List<String>>{};
    
    if (recipeId != null) {
      result['recipe'] = getAvailableRecipeActions(recipeId);
    }
    if (shoppingListId != null) {
      result['shopping_list'] = getAvailableShoppingListActions(shoppingListId);
    }
    if (groupId != null) {
      result['group'] = getAvailableGroupActions(groupId);
    }
    if (userId != null) {
      result['social'] = getAvailableSocialActions(userId);
    }
    
    return result;
  }

  /// Get combined permission summary for multiple resources
  static Map<String, Map<String, dynamic>> getCombinedPermissionSummary({
    String? recipeId,
    String? shoppingListId,
    String? groupId,
    String? userId,
  }) {
    final result = <String, Map<String, dynamic>>{};
    
    if (recipeId != null) {
      result['recipe'] = getRecipePermissionSummary(recipeId);
    }
    if (shoppingListId != null) {
      result['shopping_list'] = getShoppingListPermissionSummary(shoppingListId);
    }
    if (groupId != null) {
      result['group'] = getGroupPermissionSummary(groupId);
    }
    if (userId != null) {
      result['social'] = getSocialPermissionSummary(userId);
    }
    
    return result;
  }

  // ===== PERMISSION STATISTICS =====

  /// Get permission statistics across resources
  static Map<String, dynamic> getPermissionStatistics({
    List<String>? recipeIds,
    List<String>? shoppingListIds,
    List<String>? groupIds,
    List<String>? userIds,
  }) {
    final stats = <String, dynamic>{
      'total_resources': 0,
      'accessible_resources': 0,
      'owned_resources': 0,
      'editable_resources': 0,
    };
    
    // Recipe statistics
    if (recipeIds != null) {
      for (final recipeId in recipeIds) {
        stats['total_resources']++;
        if (RecipePermissionHandler.hasRecipeAccess(recipeId)) {
          stats['accessible_resources']++;
        }
        if (RecipePermissionHandler.isRecipeOwner(recipeId)) {
          stats['owned_resources']++;
        }
        if (RecipePermissionHandler.canEditRecipe(recipeId)) {
          stats['editable_resources']++;
        }
      }
    }
    
    // Shopping list statistics
    if (shoppingListIds != null) {
      for (final listId in shoppingListIds) {
        stats['total_resources']++;
        if (ShoppingPermissionHandler.hasShoppingListAccess(listId)) {
          stats['accessible_resources']++;
        }
        if (ShoppingPermissionHandler.isShoppingListOwner(listId)) {
          stats['owned_resources']++;
        }
        if (ShoppingPermissionHandler.canEditShoppingList(listId)) {
          stats['editable_resources']++;
        }
      }
    }
    
    // Group statistics
    if (groupIds != null) {
      for (final groupId in groupIds) {
        stats['total_resources']++;
        if (GroupPermissionHandler.hasGroupAccess(groupId)) {
          stats['accessible_resources']++;
        }
        if (GroupPermissionHandler.isGroupOwner(groupId)) {
          stats['owned_resources']++;
        }
        if (GroupPermissionHandler.canEditGroup(groupId)) {
          stats['editable_resources']++;
        }
      }
    }
    
    return stats;
  }
}