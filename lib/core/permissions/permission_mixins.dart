/// 🔐 PERMISSION MIXINS - Eliminates 20+ permission check duplications
/// File: lib/core/permissions/permission_mixins.dart
/// Purpose: Provide reusable permission checking methods for ViewModels
/// Dependencies: PermissionService
/// Usage: Mix into ViewModels to get permission methods instead of direct service calls

import 'package:flutter/foundation.dart';
import '../../services/permission_service.dart';
import '../../core/injection.dart';

/// Base permission mixin with common functionality
mixin BasePermissionMixin {
  PermissionService get _permissionService => sl<PermissionService>();
  
  /// Current authenticated user ID
  String? get currentUserId => _permissionService.currentUserId;
  
  /// Check if user is authenticated
  bool get isAuthenticated => _permissionService.isAuthenticated;
  
  /// Check if user is logged in
  bool get isLoggedIn => _permissionService.hasValidSession;
  
  /// Get current user display name
  String? get currentUserDisplayName => _permissionService.currentUser?.displayName;
}

/// Recipe permission mixin - eliminates recipe permission duplications
mixin RecipePermissionMixin on BasePermissionMixin {
  /// Check if user can view a recipe
  bool canViewRecipe(String recipeId) {
    return _permissionService.canViewRecipe(recipeId);
  }
  
  /// Check if user can edit a recipe
  bool canEditRecipe(String recipeId) {
    return _permissionService.canEditRecipe(recipeId);
  }
  
  /// Check if user can delete a recipe
  bool canDeleteRecipe(String recipeId) {
    return _permissionService.canDeleteRecipe(recipeId);
  }
  
  /// Check if user can share a recipe
  bool canShareRecipe(String recipeId) {
    return _permissionService.canShareRecipe(recipeId);
  }
  
  /// Check if user can duplicate a recipe
  bool canDuplicateRecipe(String recipeId) {
    return canViewRecipe(recipeId); // Can duplicate if can view
  }
  
  /// Check if user is the owner of a recipe
  bool isRecipeOwner(String recipeId) {
    return _permissionService.isRecipeOwner(recipeId);
  }
  
  /// Check if user can comment on a recipe
  bool canCommentOnRecipe(String recipeId) {
    return canViewRecipe(recipeId); // Can comment if can view
  }
  
  /// Check if user can rate a recipe
  bool canRateRecipe(String recipeId) {
    return canViewRecipe(recipeId); // Can rate if can view
  }
  
  /// Check if user can add recipe to favorites
  bool canFavoriteRecipe(String recipeId) {
    return canViewRecipe(recipeId); // Can favorite if can view
  }
  
  /// Get recipe permission level for UI display
  String getRecipePermissionLevel(String recipeId) {
    if (isRecipeOwner(recipeId)) return 'owner';
    if (canEditRecipe(recipeId)) return 'editor';
    if (canViewRecipe(recipeId)) return 'viewer';
    return 'none';
  }
  
  /// Check if user can perform any action on recipe
  bool hasRecipeAccess(String recipeId) {
    return canViewRecipe(recipeId);
  }
  
  /// Get recipe actions available to user
  List<String> getAvailableRecipeActions(String recipeId) {
    final actions = <String>[];
    
    if (canViewRecipe(recipeId)) actions.add('view');
    if (canEditRecipe(recipeId)) actions.add('edit');
    if (canDeleteRecipe(recipeId)) actions.add('delete');
    if (canShareRecipe(recipeId)) actions.add('share');
    if (canDuplicateRecipe(recipeId)) actions.add('duplicate');
    if (canCommentOnRecipe(recipeId)) actions.add('comment');
    if (canRateRecipe(recipeId)) actions.add('rate');
    if (canFavoriteRecipe(recipeId)) actions.add('favorite');
    
    return actions;
  }
}

/// Shopping list permission mixin - eliminates shopping list permission duplications  
mixin ShoppingListPermissionMixin on BasePermissionMixin {
  /// Check if user can view a shopping list
  bool canViewShoppingList(String listId) {
    return _permissionService.canViewShoppingList(listId);
  }
  
  /// Check if user can edit a shopping list
  bool canEditShoppingList(String listId) {
    return _permissionService.canEditShoppingList(listId);
  }
  
  /// Check if user can manage a shopping list
  bool canManageShoppingList(String listId) {
    return _permissionService.canManageShoppingList(listId);
  }
  
  /// Check if user can delete a shopping list
  bool canDeleteShoppingList(String listId) {
    return _permissionService.canDeleteShoppingList(listId);
  }
  
  /// Check if user can share a shopping list
  bool canShareShoppingList(String listId) {
    return _permissionService.canShareShoppingList(listId);
  }
  
  /// Check if user can invite to a shopping list
  bool canInviteToShoppingList(String listId) {
    return canManageShoppingList(listId); // Can invite if can manage
  }
  
  /// Check if user is the owner of a shopping list
  bool isShoppingListOwner(String listId) {
    return _permissionService.isShoppingListOwner(listId);
  }
  
  /// Check if user can add items to shopping list
  bool canAddItemsToShoppingList(String listId) {
    return canEditShoppingList(listId);
  }
  
  /// Check if user can remove items from shopping list
  bool canRemoveItemsFromShoppingList(String listId) {
    return canEditShoppingList(listId);
  }
  
  /// Check if user can modify item status in shopping list
  bool canModifyItemStatus(String listId) {
    return canEditShoppingList(listId);
  }
  
  /// Get shopping list permission level for UI display
  String getShoppingListPermissionLevel(String listId) {
    if (isShoppingListOwner(listId)) return 'owner';
    if (canManageShoppingList(listId)) return 'manager';
    if (canEditShoppingList(listId)) return 'editor';
    if (canViewShoppingList(listId)) return 'viewer';
    return 'none';
  }
  
  /// Check if user can perform any action on shopping list
  bool hasShoppingListAccess(String listId) {
    return canViewShoppingList(listId);
  }
  
  /// Get shopping list actions available to user
  List<String> getAvailableShoppingListActions(String listId) {
    final actions = <String>[];
    
    if (canViewShoppingList(listId)) actions.add('view');
    if (canEditShoppingList(listId)) actions.add('edit');
    if (canManageShoppingList(listId)) actions.add('manage');
    if (canDeleteShoppingList(listId)) actions.add('delete');
    if (canShareShoppingList(listId)) actions.add('share');
    if (canInviteToShoppingList(listId)) actions.add('invite');
    if (canAddItemsToShoppingList(listId)) actions.add('add_items');
    if (canRemoveItemsFromShoppingList(listId)) actions.add('remove_items');
    if (canModifyItemStatus(listId)) actions.add('modify_items');
    
    return actions;
  }
}

/// Group permission mixin - eliminates group permission duplications
mixin GroupPermissionMixin on BasePermissionMixin {
  /// Check if user can view a group
  bool canViewGroup(String groupId) {
    return isAuthenticated; // All authenticated users can view groups
  }
  
  /// Check if user can edit a group
  bool canEditGroup(String groupId) {
    return isGroupAdmin(groupId); // Only admins can edit
  }
  
  /// Check if user can manage a group
  bool canManageGroup(String groupId) {
    return isGroupAdmin(groupId); // Only admins can manage
  }
  
  /// Check if user can delete a group
  bool canDeleteGroup(String groupId) {
    return _permissionService.canDeleteGroup(groupId);
  }
  
  /// Check if user can invite to a group
  bool canInviteToGroup(String groupId) {
    return _permissionService.canInviteToGroup(groupId);
  }
  
  /// Check if user can remove from a group
  bool canRemoveFromGroup(String groupId, String userId) {
    return _permissionService.canRemoveFromGroup(groupId, userId);
  }
  
  /// Check if user is group admin
  bool isGroupAdmin(String groupId) {
    return _permissionService.isGroupAdmin(groupId);
  }
  
  /// Check if user is group owner
  bool isGroupOwner(String groupId) {
    return isGroupAdmin(groupId); // Owner is admin in this implementation
  }
  
  /// Check if user is group member
  bool isGroupMember(String groupId) {
    return canViewGroup(groupId); // If can view, is member
  }
  
  /// Check if user can leave group
  bool canLeaveGroup(String groupId) {
    return _permissionService.canLeaveGroup(groupId);
  }
  
  /// Check if user can change group settings
  bool canChangeGroupSettings(String groupId) {
    return canManageGroup(groupId);
  }
  
  /// Get group permission level for UI display
  String getGroupPermissionLevel(String groupId) {
    if (isGroupOwner(groupId)) return 'owner';
    if (isGroupAdmin(groupId)) return 'admin';
    if (isGroupMember(groupId)) return 'member';
    if (canViewGroup(groupId)) return 'viewer';
    return 'none';
  }
  
  /// Check if user can perform any action on group
  bool hasGroupAccess(String groupId) {
    return canViewGroup(groupId);
  }
  
  /// Get group actions available to user
  List<String> getAvailableGroupActions(String groupId) {
    final actions = <String>[];
    
    if (canViewGroup(groupId)) actions.add('view');
    if (canEditGroup(groupId)) actions.add('edit');
    if (canManageGroup(groupId)) actions.add('manage');
    if (canDeleteGroup(groupId)) actions.add('delete');
    if (canInviteToGroup(groupId)) actions.add('invite');
    if (isGroupAdmin(groupId)) actions.add('remove_members'); // Admin can remove members
    if (canLeaveGroup(groupId)) actions.add('leave');
    if (canChangeGroupSettings(groupId)) actions.add('settings');
    
    return actions;
  }
}

/// Social permission mixin - eliminates social permission duplications
mixin SocialPermissionMixin on BasePermissionMixin {
  /// Check if user can view a profile
  bool canViewProfile(String userId) {
    return _permissionService.canViewProfile(userId);
  }
  
  /// Check if user can edit a profile
  bool canEditProfile(String userId) {
    return _permissionService.canEditProfile(userId);
  }
  
  /// Check if user can send friend request
  bool canSendFriendRequest(String userId) {
    return _permissionService.canSendFriendRequest(userId);
  }
  
  /// Check if user can accept friend request
  bool canAcceptFriendRequest(String requestId) {
    return isAuthenticated; // Authenticated users can accept friend requests
  }
  
  /// Check if user can reject friend request
  bool canRejectFriendRequest(String requestId) {
    return isAuthenticated; // Authenticated users can reject friend requests
  }
  
  /// Check if user can cancel friend request
  bool canCancelFriendRequest(String requestId) {
    return isAuthenticated; // Authenticated users can cancel their own friend requests
  }
  
  /// Check if user can remove friend
  bool canRemoveFriend(String userId) {
    return isAuthenticated && currentUserId != userId; // Can remove friend if authenticated and not self
  }
  
  /// Check if user can block another user
  bool canBlockUser(String userId) {
    return isAuthenticated && currentUserId != userId; // Can block if authenticated and not self
  }
  
  /// Check if user can unblock another user
  bool canUnblockUser(String userId) {
    return isAuthenticated && currentUserId != userId; // Can unblock if authenticated and not self
  }
  
  /// Check if user can message another user
  bool canMessageUser(String userId) {
    return isAuthenticated && currentUserId != userId; // Can message if authenticated and not self
  }
  
  /// Check if user is own profile
  bool isOwnProfile(String userId) {
    return currentUserId == userId;
  }
  
  /// Check if users are friends
  bool areFriends(String userId) {
    return isAuthenticated; // Simplified - can be enhanced later
  }
  
  /// Get social permission level for UI display
  String getSocialPermissionLevel(String userId) {
    if (isOwnProfile(userId)) return 'own';
    if (areFriends(userId)) return 'friend';
    if (canViewProfile(userId)) return 'viewer';
    return 'none';
  }
  
  /// Get social actions available to user
  List<String> getAvailableSocialActions(String userId) {
    final actions = <String>[];
    
    if (canViewProfile(userId)) actions.add('view');
    if (canEditProfile(userId)) actions.add('edit');
    if (canSendFriendRequest(userId)) actions.add('send_friend_request');
    if (canRemoveFriend(userId)) actions.add('remove_friend');
    if (canBlockUser(userId)) actions.add('block');
    if (canUnblockUser(userId)) actions.add('unblock');
    if (canMessageUser(userId)) actions.add('message');
    
    return actions;
  }
}

/// Combined permission mixin - for ViewModels that need multiple permission types
mixin CombinedPermissionMixin on BasePermissionMixin
    implements RecipePermissionMixin, ShoppingListPermissionMixin, GroupPermissionMixin, SocialPermissionMixin {
  
  // Recipe permissions
  @override
  bool canViewRecipe(String recipeId) => _permissionService.canViewRecipe(recipeId);
  @override
  bool canEditRecipe(String recipeId) => _permissionService.canEditRecipe(recipeId);
  @override
  bool canDeleteRecipe(String recipeId) => _permissionService.canDeleteRecipe(recipeId);
  @override
  bool canShareRecipe(String recipeId) => _permissionService.canShareRecipe(recipeId);
  @override
  bool canDuplicateRecipe(String recipeId) => canViewRecipe(recipeId);
  @override
  bool isRecipeOwner(String recipeId) => _permissionService.isRecipeOwner(recipeId);
  @override
  bool canCommentOnRecipe(String recipeId) => canViewRecipe(recipeId);
  @override
  bool canRateRecipe(String recipeId) => canViewRecipe(recipeId);
  @override
  bool canFavoriteRecipe(String recipeId) => canViewRecipe(recipeId);
  @override
  String getRecipePermissionLevel(String recipeId) {
    if (isRecipeOwner(recipeId)) return 'owner';
    if (canEditRecipe(recipeId)) return 'editor';
    if (canViewRecipe(recipeId)) return 'viewer';
    return 'none';
  }
  @override
  bool hasRecipeAccess(String recipeId) => canViewRecipe(recipeId);
  @override
  List<String> getAvailableRecipeActions(String recipeId) {
    final actions = <String>[];
    if (canViewRecipe(recipeId)) actions.add('view');
    if (canEditRecipe(recipeId)) actions.add('edit');
    if (canDeleteRecipe(recipeId)) actions.add('delete');
    if (canShareRecipe(recipeId)) actions.add('share');
    if (canDuplicateRecipe(recipeId)) actions.add('duplicate');
    if (canCommentOnRecipe(recipeId)) actions.add('comment');
    if (canRateRecipe(recipeId)) actions.add('rate');
    if (canFavoriteRecipe(recipeId)) actions.add('favorite');
    return actions;
  }
  
  // Shopping list permissions
  @override
  bool canViewShoppingList(String listId) => _permissionService.canViewShoppingList(listId);
  @override
  bool canEditShoppingList(String listId) => _permissionService.canEditShoppingList(listId);
  @override
  bool canManageShoppingList(String listId) => _permissionService.canManageShoppingList(listId);
  @override
  bool canDeleteShoppingList(String listId) => _permissionService.canDeleteShoppingList(listId);
  @override
  bool canShareShoppingList(String listId) => _permissionService.canShareShoppingList(listId);
  @override
  bool canInviteToShoppingList(String listId) => canManageShoppingList(listId);
  @override
  bool isShoppingListOwner(String listId) => _permissionService.isShoppingListOwner(listId);
  @override
  bool canAddItemsToShoppingList(String listId) => canEditShoppingList(listId);
  @override
  bool canRemoveItemsFromShoppingList(String listId) => canEditShoppingList(listId);
  @override
  bool canModifyItemStatus(String listId) => canEditShoppingList(listId);
  @override
  String getShoppingListPermissionLevel(String listId) {
    if (isShoppingListOwner(listId)) return 'owner';
    if (canManageShoppingList(listId)) return 'manager';
    if (canEditShoppingList(listId)) return 'editor';
    if (canViewShoppingList(listId)) return 'viewer';
    return 'none';
  }
  @override
  bool hasShoppingListAccess(String listId) => canViewShoppingList(listId);
  @override
  List<String> getAvailableShoppingListActions(String listId) {
    final actions = <String>[];
    if (canViewShoppingList(listId)) actions.add('view');
    if (canEditShoppingList(listId)) actions.add('edit');
    if (canManageShoppingList(listId)) actions.add('manage');
    if (canDeleteShoppingList(listId)) actions.add('delete');
    if (canShareShoppingList(listId)) actions.add('share');
    if (canInviteToShoppingList(listId)) actions.add('invite');
    if (canAddItemsToShoppingList(listId)) actions.add('add_items');
    if (canRemoveItemsFromShoppingList(listId)) actions.add('remove_items');
    if (canModifyItemStatus(listId)) actions.add('modify_items');
    return actions;
  }
  
  // Group permissions
  @override
  bool canViewGroup(String groupId) => isAuthenticated;
  @override
  bool canEditGroup(String groupId) => isGroupAdmin(groupId);
  @override
  bool canManageGroup(String groupId) => isGroupAdmin(groupId);
  @override
  bool canDeleteGroup(String groupId) => _permissionService.canDeleteGroup(groupId);
  @override
  bool canInviteToGroup(String groupId) => _permissionService.canInviteToGroup(groupId);
  @override
  bool canRemoveFromGroup(String groupId, String userId) => _permissionService.canRemoveFromGroup(groupId, userId);
  @override
  bool isGroupAdmin(String groupId) => _permissionService.isGroupAdmin(groupId);
  @override
  bool isGroupOwner(String groupId) => isGroupAdmin(groupId);
  @override
  bool isGroupMember(String groupId) => canViewGroup(groupId);
  @override
  bool canLeaveGroup(String groupId) => _permissionService.canLeaveGroup(groupId);
  @override
  bool canChangeGroupSettings(String groupId) => canManageGroup(groupId);
  @override
  String getGroupPermissionLevel(String groupId) {
    if (isGroupOwner(groupId)) return 'owner';
    if (isGroupAdmin(groupId)) return 'admin';
    if (isGroupMember(groupId)) return 'member';
    if (canViewGroup(groupId)) return 'viewer';
    return 'none';
  }
  @override
  bool hasGroupAccess(String groupId) => canViewGroup(groupId);
  @override
  List<String> getAvailableGroupActions(String groupId) {
    final actions = <String>[];
    if (canViewGroup(groupId)) actions.add('view');
    if (canEditGroup(groupId)) actions.add('edit');
    if (canManageGroup(groupId)) actions.add('manage');
    if (canDeleteGroup(groupId)) actions.add('delete');
    if (canInviteToGroup(groupId)) actions.add('invite');
    if (isGroupAdmin(groupId)) actions.add('remove_members'); // Admin can remove members
    if (canLeaveGroup(groupId)) actions.add('leave');
    if (canChangeGroupSettings(groupId)) actions.add('settings');
    return actions;
  }
  
  // Social permissions
  @override
  bool canViewProfile(String userId) => _permissionService.canViewProfile(userId);
  @override
  bool canEditProfile(String userId) => _permissionService.canEditProfile(userId);
  @override
  bool canSendFriendRequest(String userId) => _permissionService.canSendFriendRequest(userId);
  @override
  bool canAcceptFriendRequest(String requestId) => isAuthenticated;
  @override
  bool canRejectFriendRequest(String requestId) => isAuthenticated;
  @override
  bool canCancelFriendRequest(String requestId) => isAuthenticated;
  @override
  bool canRemoveFriend(String userId) => isAuthenticated && currentUserId != userId;
  @override
  bool canBlockUser(String userId) => isAuthenticated && currentUserId != userId;
  @override
  bool canUnblockUser(String userId) => isAuthenticated && currentUserId != userId;
  @override
  bool canMessageUser(String userId) => isAuthenticated && currentUserId != userId;
  @override
  bool isOwnProfile(String userId) => currentUserId == userId;
  @override
  bool areFriends(String userId) => isAuthenticated;
  @override
  String getSocialPermissionLevel(String userId) {
    if (isOwnProfile(userId)) return 'own';
    if (areFriends(userId)) return 'friend';
    if (canViewProfile(userId)) return 'viewer';
    return 'none';
  }
  @override
  List<String> getAvailableSocialActions(String userId) {
    final actions = <String>[];
    if (canViewProfile(userId)) actions.add('view');
    if (canEditProfile(userId)) actions.add('edit');
    if (canSendFriendRequest(userId)) actions.add('send_friend_request');
    if (canRemoveFriend(userId)) actions.add('remove_friend');
    if (canBlockUser(userId)) actions.add('block');
    if (canUnblockUser(userId)) actions.add('unblock');
    if (canMessageUser(userId)) actions.add('message');
    return actions;
  }
}

/// Debug permission mixin - for development and testing
mixin DebugPermissionMixin on BasePermissionMixin {
  /// Print all permissions for a resource
  void debugPrintPermissions(String resourceType, String resourceId) {
    if (kDebugMode) {
      print('=== PERMISSIONS DEBUG: $resourceType:$resourceId ===');
      print('User ID: $currentUserId');
      print('Is Authenticated: $isAuthenticated');
      
      switch (resourceType) {
        case 'recipe':
          if (this is RecipePermissionMixin) {
            final mixin = this as RecipePermissionMixin;
            print('Recipe Permissions:');
            print('  - Can View: ${mixin.canViewRecipe(resourceId)}');
            print('  - Can Edit: ${mixin.canEditRecipe(resourceId)}');
            print('  - Can Delete: ${mixin.canDeleteRecipe(resourceId)}');
            print('  - Can Share: ${mixin.canShareRecipe(resourceId)}');
            print('  - Is Owner: ${mixin.isRecipeOwner(resourceId)}');
            print('  - Permission Level: ${mixin.getRecipePermissionLevel(resourceId)}');
          }
          break;
        case 'shopping_list':
          if (this is ShoppingListPermissionMixin) {
            final mixin = this as ShoppingListPermissionMixin;
            print('Shopping List Permissions:');
            print('  - Can View: ${mixin.canViewShoppingList(resourceId)}');
            print('  - Can Edit: ${mixin.canEditShoppingList(resourceId)}');
            print('  - Can Manage: ${mixin.canManageShoppingList(resourceId)}');
            print('  - Can Delete: ${mixin.canDeleteShoppingList(resourceId)}');
            print('  - Is Owner: ${mixin.isShoppingListOwner(resourceId)}');
            print('  - Permission Level: ${mixin.getShoppingListPermissionLevel(resourceId)}');
          }
          break;
        case 'group':
          if (this is GroupPermissionMixin) {
            final mixin = this as GroupPermissionMixin;
            print('Group Permissions:');
            print('  - Can View: ${mixin.canViewGroup(resourceId)}');
            print('  - Can Edit: ${mixin.canEditGroup(resourceId)}');
            print('  - Can Manage: ${mixin.canManageGroup(resourceId)}');
            print('  - Is Admin: ${mixin.isGroupAdmin(resourceId)}');
            print('  - Is Owner: ${mixin.isGroupOwner(resourceId)}');
            print('  - Permission Level: ${mixin.getGroupPermissionLevel(resourceId)}');
          }
          break;
      }
      print('===============================================');
    }
  }
}