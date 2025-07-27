// lib/core/permissions/modules/shopping_permission_handler.dart

import 'package:butlery/core/permissions/modules/base_permission_manager.dart';

/// Focused module for shopping list permission handling
/// 
/// This module handles ONLY shopping list-specific permissions:
/// - Shopping list viewing, editing, managing permissions
/// - Shopping list ownership validation
/// - Item-level permissions within shopping lists
/// - Shopping list sharing and collaboration
/// 
/// ❌ DOES NOT CONTAIN: Action builders, permission levels, other resource types
class ShoppingPermissionHandler {

  // ===== CORE SHOPPING LIST PERMISSIONS =====

  /// Check if user can view a shopping list
  static bool canViewShoppingList(String listId) {
    return BasePermissionManager.permissionService.canViewShoppingList(listId);
  }

  /// Check if user can edit a shopping list
  static bool canEditShoppingList(String listId) {
    return BasePermissionManager.permissionService.canEditShoppingList(listId);
  }

  /// Check if user can manage a shopping list
  static bool canManageShoppingList(String listId) {
    return BasePermissionManager.permissionService.canManageShoppingList(listId);
  }

  /// Check if user can delete a shopping list
  static bool canDeleteShoppingList(String listId) {
    return BasePermissionManager.permissionService.canDeleteShoppingList(listId);
  }

  /// Check if user can share a shopping list
  static bool canShareShoppingList(String listId) {
    return BasePermissionManager.permissionService.canShareShoppingList(listId);
  }

  // ===== SHOPPING LIST OWNERSHIP =====

  /// Check if user is the owner of a shopping list
  static bool isShoppingListOwner(String listId) {
    return BasePermissionManager.permissionService.isShoppingListOwner(listId);
  }

  /// Check if shopping list belongs to current user
  static bool isOwnShoppingList(String listId) {
    return isShoppingListOwner(listId);
  }

  // ===== SHOPPING LIST COLLABORATION =====

  /// Check if user can invite to a shopping list
  static bool canInviteToShoppingList(String listId) {
    // Can invite if can manage
    return canManageShoppingList(listId);
  }

  /// Check if user can manage shopping list members
  static bool canManageShoppingListMembers(String listId) {
    return canManageShoppingList(listId);
  }

  /// Check if user can remove members from shopping list
  static bool canRemoveMembersFromShoppingList(String listId) {
    return canManageShoppingList(listId);
  }

  /// Check if user can leave shopping list
  static bool canLeaveShoppingList(String listId) {
    return canViewShoppingList(listId) && !isShoppingListOwner(listId);
  }

  // ===== SHOPPING LIST ITEM PERMISSIONS =====

  /// Check if user can add items to shopping list
  static bool canAddItemsToShoppingList(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if user can remove items from shopping list
  static bool canRemoveItemsFromShoppingList(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if user can modify item status in shopping list
  static bool canModifyItemStatus(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if user can modify item quantities
  static bool canModifyItemQuantities(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if user can reorder items in shopping list
  static bool canReorderItems(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if user can check/uncheck items
  static bool canCheckItems(String listId) {
    return canEditShoppingList(listId);
  }

  // ===== SHOPPING LIST ACCESS VALIDATION =====

  /// Check if user has any access to shopping list
  static bool hasShoppingListAccess(String listId) {
    return canViewShoppingList(listId);
  }

  /// Check if user has read access to shopping list
  static bool hasReadAccess(String listId) {
    return canViewShoppingList(listId);
  }

  /// Check if user has write access to shopping list
  static bool hasWriteAccess(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if user has admin access to shopping list
  static bool hasAdminAccess(String listId) {
    return canManageShoppingList(listId);
  }

  /// Check if user has owner access to shopping list
  static bool hasOwnerAccess(String listId) {
    return isShoppingListOwner(listId);
  }

  // ===== SHOPPING LIST CREATION =====

  /// Check if user can create shopping lists
  static bool canCreateShoppingLists() {
    return BasePermissionManager.isAuthenticated;
  }

  /// Check if user can duplicate shopping list
  static bool canDuplicateShoppingList(String listId) {
    return canViewShoppingList(listId) && BasePermissionManager.isAuthenticated;
  }

  /// Check if user can copy shopping list
  static bool canCopyShoppingList(String listId) {
    return canViewShoppingList(listId);
  }

  // ===== SHOPPING LIST SETTINGS =====

  /// Check if user can modify shopping list settings
  static bool canModifyShoppingListSettings(String listId) {
    return canManageShoppingList(listId);
  }

  /// Check if user can change shopping list name
  static bool canChangeShoppingListName(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if user can change shopping list description
  static bool canChangeShoppingListDescription(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if user can archive shopping list
  static bool canArchiveShoppingList(String listId) {
    return canManageShoppingList(listId);
  }

  /// Check if user can restore archived shopping list
  static bool canRestoreShoppingList(String listId) {
    return canManageShoppingList(listId);
  }

  // ===== SHOPPING LIST CATEGORIES =====

  /// Check if user can create categories in shopping list
  static bool canCreateCategories(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if user can modify categories
  static bool canModifyCategories(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if user can delete categories
  static bool canDeleteCategories(String listId) {
    return canEditShoppingList(listId);
  }

  // ===== SHOPPING LIST EXPORT =====

  /// Check if user can export shopping list
  static bool canExportShoppingList(String listId) {
    return canViewShoppingList(listId);
  }

  /// Check if user can print shopping list
  static bool canPrintShoppingList(String listId) {
    return canViewShoppingList(listId);
  }

  /// Check if user can share shopping list via link
  static bool canShareShoppingListViaLink(String listId) {
    return canShareShoppingList(listId);
  }

  // ===== SHOPPING LIST VALIDATION =====

  /// Validate shopping list ID format
  static bool isValidShoppingListId(String listId) {
    return listId.isNotEmpty && listId.trim().isNotEmpty;
  }

  /// Check if shopping list exists and user has access
  static bool validateShoppingListAccess(String listId) {
    if (!isValidShoppingListId(listId)) return false;
    return hasShoppingListAccess(listId);
  }

  /// Get shopping list permission validation result
  static Map<String, bool> validateAllShoppingListPermissions(String listId) {
    return {
      'canView': canViewShoppingList(listId),
      'canEdit': canEditShoppingList(listId),
      'canManage': canManageShoppingList(listId),
      'canDelete': canDeleteShoppingList(listId),
      'canShare': canShareShoppingList(listId),
      'isOwner': isShoppingListOwner(listId),
      'canInvite': canInviteToShoppingList(listId),
      'canAddItems': canAddItemsToShoppingList(listId),
      'canRemoveItems': canRemoveItemsFromShoppingList(listId),
      'canModifyItems': canModifyItemStatus(listId),
    };
  }

  // ===== SHOPPING LIST PERMISSION CONTEXT =====

  /// Create permission context for shopping list operations
  static Map<String, dynamic> createShoppingListPermissionContext(String listId) {
    return {
      'listId': listId,
      'userId': BasePermissionManager.currentUserId,
      'permissions': validateAllShoppingListPermissions(listId),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Check if user can perform operation on shopping list
  static bool canPerformShoppingListOperation(String listId, String operation) {
    switch (operation.toLowerCase()) {
      case 'view':
        return canViewShoppingList(listId);
      case 'edit':
        return canEditShoppingList(listId);
      case 'manage':
        return canManageShoppingList(listId);
      case 'delete':
        return canDeleteShoppingList(listId);
      case 'share':
        return canShareShoppingList(listId);
      case 'invite':
        return canInviteToShoppingList(listId);
      case 'add_items':
        return canAddItemsToShoppingList(listId);
      case 'remove_items':
        return canRemoveItemsFromShoppingList(listId);
      case 'modify_items':
        return canModifyItemStatus(listId);
      case 'export':
        return canExportShoppingList(listId);
      case 'print':
        return canPrintShoppingList(listId);
      case 'duplicate':
        return canDuplicateShoppingList(listId);
      default:
        return false;
    }
  }
}