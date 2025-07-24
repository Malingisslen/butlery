// lib/services/permission/modules/group_permission_engine.dart

import '../../unified/unified_friends_service.dart';
import '../../../models/permissions/resource_permission.dart';
import '../../../core/utils/logger.dart';
import 'auth_permission_engine.dart';

/// Focused module for group permission engine
/// 
/// This module handles ONLY group/friends permission operations:
/// - Group viewing, editing, managing permissions
/// - Group admin and ownership validation
/// - Group member management permissions
/// - Group creation and deletion permissions
/// 
/// ❌ DOES NOT CONTAIN: Recipes, shopping lists, profiles, auth logic
class GroupPermissionEngine {
  final AuthPermissionEngine _authEngine;
  final UnifiedFriendsService _friendsService;
  final Map<String, bool> _groupPermissionCache = {};

  GroupPermissionEngine(this._authEngine, this._friendsService);

  // ===== CORE GROUP PERMISSIONS =====

  /// Check if current user can view a group
  bool canViewGroup(String groupId) {
    return _getCachedGroupPermission('group_view_$groupId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final group = _friendsService.categories.categoriesList.where((g) => g.id == groupId).firstOrNull;
      if (group == null) return false;
      
      // Can view if member or admin
      return group.friendUserIds.contains(_authEngine.currentUserId) || 
             _authEngine.isOwner(group.createdBy);
    });
  }

  /// Check if current user can edit a group
  bool canEditGroup(String groupId) {
    return isGroupAdmin(groupId); // Only admins can edit
  }

  /// Check if current user can manage a group
  bool canManageGroup(String groupId) {
    return isGroupAdmin(groupId); // Only admins can manage
  }

  /// Check if current user can delete a group
  bool canDeleteGroup(String groupId) {
    return isGroupAdmin(groupId); // Only admin can delete
  }

  /// Check if current user can share a group
  bool canShareGroup(String groupId) {
    return canViewGroup(groupId);
  }

  // ===== GROUP ADMIN PERMISSIONS =====

  /// Check if current user is admin of a group
  bool isGroupAdmin(String groupId) {
    return _getCachedGroupPermission('group_admin_$groupId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final group = _friendsService.categories.categoriesList.where((g) => g.id == groupId).firstOrNull;
      if (group == null) return false;
      
      return _authEngine.isOwner(group.createdBy);
    });
  }

  /// Check if current user is owner of a group
  bool isGroupOwner(String groupId) {
    return isGroupAdmin(groupId); // Same as admin in this system
  }

  /// Check if group belongs to current user
  bool isOwnGroup(String groupId) {
    return isGroupOwner(groupId);
  }

  // ===== GROUP MEMBER PERMISSIONS =====

  /// Check if current user is member of a group
  bool isGroupMember(String groupId) {
    return _getCachedGroupPermission('group_member_$groupId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final group = _friendsService.categories.categoriesList.where((g) => g.id == groupId).firstOrNull;
      if (group == null) return false;
      
      return group.friendUserIds.contains(_authEngine.currentUserId);
    });
  }

  /// Check if current user can manage group members
  bool canManageGroupMembers(String groupId) {
    return isGroupAdmin(groupId); // Only admins can manage members
  }

  /// Check if current user can invite to group
  bool canInviteToGroup(String groupId) {
    return isGroupAdmin(groupId); // Only admins can invite
  }

  /// Check if current user can remove members from group
  bool canRemoveMembersFromGroup(String groupId) {
    return isGroupAdmin(groupId); // Only admins can remove members
  }

  /// Check if current user can leave group
  bool canLeaveGroup(String groupId) {
    return _getCachedGroupPermission('group_leave_$groupId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final group = _friendsService.categories.categoriesList.where((g) => g.id == groupId).firstOrNull;
      if (group == null) return false;
      
      // Can leave if member but not owner
      return !_authEngine.isOwner(group.createdBy) && 
             group.friendUserIds.contains(_authEngine.currentUserId);
    });
  }

  /// Check if current user can remove another user from group
  bool canRemoveFromGroup(String groupId, String userId) {
    return _getCachedGroupPermission('group_remove_${groupId}_$userId', () {
      if (!_authEngine.isAuthenticated || userId == _authEngine.currentUserId) return false;
      
      final group = _friendsService.categories.categoriesList.where((g) => g.id == groupId).firstOrNull;
      if (group == null) return false;
      
      final isCurrentUserAdmin = _authEngine.isOwner(group.createdBy);
      final isTargetUserAdmin = userId == group.createdBy;
      
      // Admin can remove non-admin members
      return isCurrentUserAdmin && !isTargetUserAdmin;
    });
  }

  // ===== GROUP CREATION PERMISSIONS =====

  /// Check if current user can create groups
  bool canCreateGroup() {
    return _authEngine.isAuthenticated; // All authenticated users can create groups
  }

  /// Check if current user can duplicate group
  bool canDuplicateGroup(String groupId) {
    return canViewGroup(groupId) && _authEngine.isAuthenticated;
  }

  /// Check if current user can copy group structure
  bool canCopyGroupStructure(String groupId) {
    return canViewGroup(groupId);
  }

  // ===== GROUP ACCESS VALIDATION =====

  /// Check if user has any access to group
  bool hasGroupAccess(String groupId) {
    return canViewGroup(groupId);
  }

  /// Check if user has read access to group
  bool hasReadAccess(String groupId) {
    return canViewGroup(groupId);
  }

  /// Check if user has write access to group
  bool hasWriteAccess(String groupId) {
    return canEditGroup(groupId);
  }

  /// Check if user has admin access to group
  bool hasAdminAccess(String groupId) {
    return isGroupAdmin(groupId);
  }

  /// Check if user has owner access to group
  bool hasOwnerAccess(String groupId) {
    return isGroupOwner(groupId);
  }

  // ===== GROUP SETTINGS PERMISSIONS =====

  /// Check if current user can modify group settings
  bool canModifyGroupSettings(String groupId) {
    return isGroupAdmin(groupId);
  }

  /// Check if current user can change group name
  bool canChangeGroupName(String groupId) {
    return isGroupAdmin(groupId);
  }

  /// Check if current user can change group description
  bool canChangeGroupDescription(String groupId) {
    return isGroupAdmin(groupId);
  }

  /// Check if current user can archive group
  bool canArchiveGroup(String groupId) {
    return isGroupAdmin(groupId);
  }

  /// Check if current user can restore archived group
  bool canRestoreGroup(String groupId) {
    return isGroupAdmin(groupId);
  }

  // ===== GROUP PERMISSION LEVEL =====

  /// Get resource permission level for current user
  ResourcePermission getGroupPermissionLevel(String groupId) {
    if (isGroupAdmin(groupId)) return ResourcePermission.owner;
    if (canInviteToGroup(groupId)) return ResourcePermission.editor;
    if (canViewGroup(groupId)) return ResourcePermission.viewer;
    return ResourcePermission.viewer; // Default fallback
  }

  /// Check if user has minimum required permission
  bool hasMinimumGroupPermission(String groupId, ResourcePermission required) {
    final current = getGroupPermissionLevel(groupId);
    return ResourcePermissionHelper.isHigherPermission(current, required) || current == required;
  }

  // ===== GROUP VALIDATION =====

  /// Validate group ID format
  bool isValidGroupId(String groupId) {
    return groupId.isNotEmpty && groupId.trim().isNotEmpty;
  }

  /// Check if group exists and user has access
  bool validateGroupAccess(String groupId) {
    if (!isValidGroupId(groupId)) return false;
    return hasGroupAccess(groupId);
  }

  /// Get group permission validation result
  Map<String, bool> validateAllGroupPermissions(String groupId) {
    return {
      'canView': canViewGroup(groupId),
      'canEdit': canEditGroup(groupId),
      'canManage': canManageGroup(groupId),
      'canDelete': canDeleteGroup(groupId),
      'canShare': canShareGroup(groupId),
      'isAdmin': isGroupAdmin(groupId),
      'isOwner': isGroupOwner(groupId),
      'isMember': isGroupMember(groupId),
      'canInvite': canInviteToGroup(groupId),
      'canManageMembers': canManageGroupMembers(groupId),
      'canLeave': canLeaveGroup(groupId),
    };
  }

  // ===== GROUP PERMISSION CONTEXT =====

  /// Create permission context for group operations
  Map<String, dynamic> createGroupPermissionContext(String groupId) {
    return {
      'groupId': groupId,
      'userId': _authEngine.currentUserId,
      'permissions': validateAllGroupPermissions(groupId),
      'permissionLevel': getGroupPermissionLevel(groupId).toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Check if user can perform operation on group
  bool canPerformGroupOperation(String groupId, String operation) {
    switch (operation.toLowerCase()) {
      case 'view':
        return canViewGroup(groupId);
      case 'edit':
        return canEditGroup(groupId);
      case 'manage':
        return canManageGroup(groupId);
      case 'delete':
        return canDeleteGroup(groupId);
      case 'share':
        return canShareGroup(groupId);
      case 'invite':
        return canInviteToGroup(groupId);
      case 'manage_members':
        return canManageGroupMembers(groupId);
      case 'remove_members':
        return canRemoveMembersFromGroup(groupId);
      case 'leave':
        return canLeaveGroup(groupId);
      case 'duplicate':
        return canDuplicateGroup(groupId);
      case 'copy_structure':
        return canCopyGroupStructure(groupId);
      default:
        return false;
    }
  }

  // ===== SPECIFIC GROUP MEMBER OPERATIONS =====

  /// Check if user can add specific user to group
  bool canAddUserToGroup(String groupId, String userId) {
    return canInviteToGroup(groupId) && userId != _authEngine.currentUserId;
  }

  /// Check if user can promote member to admin
  bool canPromoteMemberToAdmin(String groupId, String userId) {
    return isGroupOwner(groupId) && userId != _authEngine.currentUserId;
  }

  /// Check if user can demote admin to member
  bool canDemoteAdminToMember(String groupId, String userId) {
    return isGroupOwner(groupId) && userId != _authEngine.currentUserId;
  }

  /// Check if user can transfer ownership
  bool canTransferOwnership(String groupId, String userId) {
    return isGroupOwner(groupId) && userId != _authEngine.currentUserId;
  }

  // ===== CACHE MANAGEMENT =====

  /// Clear group permission cache
  void clearGroupPermissionCache() {
    _groupPermissionCache.clear();
    AppLogger.info('🔐 Group permission cache cleared');
  }

  /// Clear specific group permission from cache
  void clearGroupPermissionFromCache(String key) {
    _groupPermissionCache.remove(key);
    AppLogger.debug('🔐 Group permission cache cleared for key: $key');
  }

  // ===== PRIVATE HELPERS =====

  /// Get cached group permission result or compute and cache it
  bool _getCachedGroupPermission(String key, bool Function() computation) {
    if (_groupPermissionCache.containsKey(key)) {
      return _groupPermissionCache[key]!;
    }
    
    final result = computation();
    _groupPermissionCache[key] = result;
    return result;
  }
}