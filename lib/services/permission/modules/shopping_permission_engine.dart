// lib/services/permission/modules/shopping_permission_engine.dart

import '../../unified/unified_shopping_service.dart';
import '../../../models/unified/unified_shopping_list.dart';
import '../../../models/permissions/resource_permission.dart';
import '../../../core/utils/logger.dart';
import 'auth_permission_engine.dart';

/// Focused module for shopping list permission engine
/// 
/// This module handles ONLY shopping list permission operations:
/// - Shopping list viewing, editing, managing permissions
/// - Shopping list ownership and collaboration validation
/// - Shopping list sharing and invitation permissions
/// - Shopping list item and member management
/// 
/// ❌ DOES NOT CONTAIN: Recipes, groups, profiles, auth logic
class ShoppingPermissionEngine {
  final AuthPermissionEngine _authEngine;
  final UnifiedShoppingService _shoppingService;
  final Map<String, bool> _shoppingPermissionCache = {};

  ShoppingPermissionEngine(this._authEngine, this._shoppingService);

  // ===== CORE SHOPPING LIST PERMISSIONS =====

  /// Check if current user can view a shopping list
  bool canViewShoppingList(String listId) {
    return _getCachedShoppingPermission('shopping_view_$listId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final list = _shoppingService.lists.where((l) => l.id == listId).firstOrNull;
      if (list == null) return false;
      
      return _hasShoppingListPermission(list, _authEngine.currentUserId!, 'view');
    });
  }

  /// Check if current user can edit a shopping list
  bool canEditShoppingList(String listId) {
    return _getCachedShoppingPermission('shopping_edit_$listId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final list = _shoppingService.lists.where((l) => l.id == listId).firstOrNull;
      if (list == null) return false;
      
      return _hasShoppingListPermission(list, _authEngine.currentUserId!, 'edit');
    });
  }

  /// Check if current user can manage a shopping list
  bool canManageShoppingList(String listId) {
    return _getCachedShoppingPermission('shopping_manage_$listId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final list = _shoppingService.lists.where((l) => l.id == listId).firstOrNull;
      if (list == null) return false;
      
      return _hasShoppingListPermission(list, _authEngine.currentUserId!, 'manage');
    });
  }

  /// Check if current user can delete a shopping list
  bool canDeleteShoppingList(String listId) {
    return _getCachedShoppingPermission('shopping_delete_$listId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final list = _shoppingService.lists.where((l) => l.id == listId).firstOrNull;
      if (list == null) return false;
      
      return _authEngine.isOwner(list.ownerId); // Only owner can delete
    });
  }

  /// Check if current user can share a shopping list
  bool canShareShoppingList(String listId) {
    return canViewShoppingList(listId); // Can share if can view
  }

  // ===== SHOPPING LIST OWNERSHIP VALIDATION =====

  /// Check if current user is owner of a shopping list
  bool isShoppingListOwner(String listId) {
    return _getCachedShoppingPermission('shopping_owner_$listId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final list = _shoppingService.lists.where((l) => l.id == listId).firstOrNull;
      if (list == null) return false;
      
      return _authEngine.isOwner(list.ownerId);
    });
  }

  /// Check if current user is member of a shopping list
  bool isShoppingListMember(String listId) {
    return _getCachedShoppingPermission('shopping_member_$listId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final list = _shoppingService.lists.where((l) => l.id == listId).firstOrNull;
      if (list == null) return false;
      
      return list.isPersonal 
        ? _authEngine.currentUserId == list.ownerId 
        : list.memberPermissions.containsKey(_authEngine.currentUserId);
    });
  }

  /// Check if shopping list belongs to current user
  bool isOwnShoppingList(String listId) {
    return isShoppingListOwner(listId);
  }

  // ===== SHOPPING LIST COLLABORATION PERMISSIONS =====

  /// Check if current user can invite to a shopping list
  bool canInviteToShoppingList(String listId) {
    return canManageShoppingList(listId);
  }

  /// Check if current user can manage shopping list members
  bool canManageShoppingListMembers(String listId) {
    return canManageShoppingList(listId);
  }

  /// Check if current user can remove members from shopping list
  bool canRemoveMembersFromShoppingList(String listId) {
    return canManageShoppingList(listId);
  }

  /// Check if current user can leave shopping list
  bool canLeaveShoppingList(String listId) {
    return canViewShoppingList(listId) && !isShoppingListOwner(listId);
  }

  // ===== SHOPPING LIST ITEM PERMISSIONS =====

  /// Check if current user can add items to shopping list
  bool canAddItemsToShoppingList(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if current user can remove items from shopping list
  bool canRemoveItemsFromShoppingList(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if current user can modify item status in shopping list
  bool canModifyItemStatus(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if current user can modify item quantities
  bool canModifyItemQuantities(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if current user can reorder items in shopping list
  bool canReorderItems(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if current user can check/uncheck items
  bool canCheckItems(String listId) {
    return canEditShoppingList(listId);
  }

  // ===== SHOPPING LIST CREATION PERMISSIONS =====

  /// Check if current user can create shopping lists
  bool canCreateShoppingList() {
    return _authEngine.isAuthenticated; // All authenticated users can create shopping lists
  }

  /// Check if current user can duplicate shopping list
  bool canDuplicateShoppingList(String listId) {
    return canViewShoppingList(listId) && _authEngine.isAuthenticated;
  }

  /// Check if current user can copy shopping list
  bool canCopyShoppingList(String listId) {
    return canViewShoppingList(listId);
  }

  // ===== SHOPPING LIST ACCESS VALIDATION =====

  /// Check if user has any access to shopping list
  bool hasShoppingListAccess(String listId) {
    return canViewShoppingList(listId);
  }

  /// Check if user has read access to shopping list
  bool hasReadAccess(String listId) {
    return canViewShoppingList(listId);
  }

  /// Check if user has write access to shopping list
  bool hasWriteAccess(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if user has admin access to shopping list
  bool hasAdminAccess(String listId) {
    return canManageShoppingList(listId);
  }

  /// Check if user has owner access to shopping list
  bool hasOwnerAccess(String listId) {
    return isShoppingListOwner(listId);
  }

  // ===== SHOPPING LIST SETTINGS PERMISSIONS =====

  /// Check if current user can modify shopping list settings
  bool canModifyShoppingListSettings(String listId) {
    return canManageShoppingList(listId);
  }

  /// Check if current user can change shopping list name
  bool canChangeShoppingListName(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if current user can change shopping list description
  bool canChangeShoppingListDescription(String listId) {
    return canEditShoppingList(listId);
  }

  /// Check if current user can archive shopping list
  bool canArchiveShoppingList(String listId) {
    return canManageShoppingList(listId);
  }

  /// Check if current user can restore archived shopping list
  bool canRestoreShoppingList(String listId) {
    return canManageShoppingList(listId);
  }

  // ===== SHOPPING LIST EXPORT PERMISSIONS =====

  /// Check if current user can export shopping list
  bool canExportShoppingList(String listId) {
    return canViewShoppingList(listId);
  }

  /// Check if current user can print shopping list
  bool canPrintShoppingList(String listId) {
    return canViewShoppingList(listId);
  }

  /// Check if current user can share shopping list via link
  bool canShareShoppingListViaLink(String listId) {
    return canShareShoppingList(listId);
  }

  // ===== SHOPPING LIST PERMISSION LEVEL =====

  /// Get resource permission level for current user
  ResourcePermission getShoppingListPermissionLevel(String listId) {
    if (canManageShoppingList(listId)) return ResourcePermission.owner;
    if (canEditShoppingList(listId)) return ResourcePermission.editor;
    if (canViewShoppingList(listId)) return ResourcePermission.viewer;
    return ResourcePermission.viewer; // Default fallback
  }

  /// Check if user has minimum required permission
  bool hasMinimumShoppingListPermission(String listId, ResourcePermission required) {
    final current = getShoppingListPermissionLevel(listId);
    return ResourcePermissionHelper.isHigherPermission(current, required) || current == required;
  }

  // ===== SHOPPING LIST VALIDATION =====

  /// Validate shopping list ID format
  bool isValidShoppingListId(String listId) {
    return listId.isNotEmpty && listId.trim().isNotEmpty;
  }

  /// Check if shopping list exists and user has access
  bool validateShoppingListAccess(String listId) {
    if (!isValidShoppingListId(listId)) return false;
    return hasShoppingListAccess(listId);
  }

  /// Get shopping list permission validation result
  Map<String, bool> validateAllShoppingListPermissions(String listId) {
    return {
      'canView': canViewShoppingList(listId),
      'canEdit': canEditShoppingList(listId),
      'canManage': canManageShoppingList(listId),
      'canDelete': canDeleteShoppingList(listId),
      'canShare': canShareShoppingList(listId),
      'isOwner': isShoppingListOwner(listId),
      'isMember': isShoppingListMember(listId),
      'canInvite': canInviteToShoppingList(listId),
      'canAddItems': canAddItemsToShoppingList(listId),
      'canRemoveItems': canRemoveItemsFromShoppingList(listId),
      'canModifyItems': canModifyItemStatus(listId),
    };
  }

  // ===== SHOPPING LIST PERMISSION CONTEXT =====

  /// Create permission context for shopping list operations
  Map<String, dynamic> createShoppingListPermissionContext(String listId) {
    return {
      'listId': listId,
      'userId': _authEngine.currentUserId,
      'permissions': validateAllShoppingListPermissions(listId),
      'permissionLevel': getShoppingListPermissionLevel(listId).toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Check if user can perform operation on shopping list
  bool canPerformShoppingListOperation(String listId, String operation) {
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

  // ===== CACHE MANAGEMENT =====

  /// Clear shopping list permission cache
  void clearShoppingPermissionCache() {
    _shoppingPermissionCache.clear();
    AppLogger.info('🔐 Shopping list permission cache cleared');
  }

  /// Clear specific shopping list permission from cache
  void clearShoppingPermissionFromCache(String key) {
    _shoppingPermissionCache.remove(key);
    AppLogger.debug('🔐 Shopping list permission cache cleared for key: $key');
  }

  // ===== PRIVATE HELPERS =====

  /// Get cached shopping list permission result or compute and cache it
  bool _getCachedShoppingPermission(String key, bool Function() computation) {
    if (_shoppingPermissionCache.containsKey(key)) {
      return _shoppingPermissionCache[key]!;
    }
    
    final result = computation();
    _shoppingPermissionCache[key] = result;
    return result;
  }

  /// Check if user has specific permission for a shopping list
  bool _hasShoppingListPermission(UnifiedShoppingList list, String userId, String permission) {
    if (list.isPersonal) return userId == list.ownerId;
    
    final userPermission = list.memberPermissions[userId];
    if (userPermission == null) return false;
    
    switch (permission) {
      case 'view':
        return true; // Any member can view
      case 'edit':
        return userPermission == SharedListPermission.edit || 
               userPermission == SharedListPermission.admin;
      case 'manage':
        return userPermission == SharedListPermission.admin;
      default:
        return false;
    }
  }
}