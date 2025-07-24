// lib/core/permissions/modules/group_permission_handler.dart

import 'base_permission_manager.dart';

/// Focused module for group permission handling
/// 
/// This module handles ONLY group-specific permissions:
/// - Group viewing, editing, managing permissions
/// - Group membership and admin validation
/// - Group member management permissions
/// - Group settings and configuration access
/// 
/// ❌ DOES NOT CONTAIN: Action builders, permission levels, other resource types
class GroupPermissionHandler {

  // ===== CORE GROUP PERMISSIONS =====

  /// Check if user can view a group
  static bool canViewGroup(String groupId) {
    // All authenticated users can view groups
    return BasePermissionManager.isAuthenticated;
  }

  /// Check if user can edit a group
  static bool canEditGroup(String groupId) {
    // Only admins can edit
    return isGroupAdmin(groupId);
  }

  /// Check if user can manage a group
  static bool canManageGroup(String groupId) {
    // Only admins can manage
    return isGroupAdmin(groupId);
  }

  /// Check if user can delete a group
  static bool canDeleteGroup(String groupId) {
    return BasePermissionManager.permissionService.canDeleteGroup(groupId);
  }

  // ===== GROUP MEMBERSHIP =====

  /// Check if user is group admin
  static bool isGroupAdmin(String groupId) {
    return BasePermissionManager.permissionService.isGroupAdmin(groupId);
  }

  /// Check if user is group owner
  static bool isGroupOwner(String groupId) {
    // Owner is admin in this implementation
    return isGroupAdmin(groupId);
  }

  /// Check if user is group member
  static bool isGroupMember(String groupId) {
    // If can view, is member
    return canViewGroup(groupId);
  }

  /// Check if user can leave group
  static bool canLeaveGroup(String groupId) {
    return BasePermissionManager.permissionService.canLeaveGroup(groupId);
  }

  // ===== GROUP MEMBER MANAGEMENT =====

  /// Check if user can invite to a group
  static bool canInviteToGroup(String groupId) {
    return BasePermissionManager.permissionService.canInviteToGroup(groupId);
  }

  /// Check if user can remove from a group
  static bool canRemoveFromGroup(String groupId, String userId) {
    return BasePermissionManager.permissionService.canRemoveFromGroup(groupId, userId);
  }

  /// Check if user can promote group members
  static bool canPromoteGroupMembers(String groupId) {
    return isGroupAdmin(groupId);
  }

  /// Check if user can demote group members
  static bool canDemoteGroupMembers(String groupId) {
    return isGroupAdmin(groupId);
  }

  /// Check if user can manage group roles
  static bool canManageGroupRoles(String groupId) {
    return isGroupAdmin(groupId);
  }

  /// Check if user can approve group join requests
  static bool canApproveJoinRequests(String groupId) {
    return isGroupAdmin(groupId);
  }

  // ===== GROUP SETTINGS =====

  /// Check if user can change group settings
  static bool canChangeGroupSettings(String groupId) {
    return canManageGroup(groupId);
  }

  /// Check if user can change group name
  static bool canChangeGroupName(String groupId) {
    return canManageGroup(groupId);
  }

  /// Check if user can change group description
  static bool canChangeGroupDescription(String groupId) {
    return canManageGroup(groupId);
  }

  /// Check if user can change group visibility
  static bool canChangeGroupVisibility(String groupId) {
    return canManageGroup(groupId);
  }

  /// Check if user can change group privacy settings
  static bool canChangeGroupPrivacy(String groupId) {
    return canManageGroup(groupId);
  }

  // ===== GROUP CONTENT PERMISSIONS =====

  /// Check if user can post in group
  static bool canPostInGroup(String groupId) {
    return isGroupMember(groupId);
  }

  /// Check if user can share content to group
  static bool canShareContentToGroup(String groupId) {
    return isGroupMember(groupId);
  }

  /// Check if user can moderate group content
  static bool canModerateGroupContent(String groupId) {
    return isGroupAdmin(groupId);
  }

  /// Check if user can delete group posts
  static bool canDeleteGroupPosts(String groupId) {
    return isGroupAdmin(groupId);
  }

  // ===== GROUP ACCESS VALIDATION =====

  /// Check if user has any access to group
  static bool hasGroupAccess(String groupId) {
    return canViewGroup(groupId);
  }

  /// Check if user has read access to group
  static bool hasReadAccess(String groupId) {
    return canViewGroup(groupId);
  }

  /// Check if user has write access to group
  static bool hasWriteAccess(String groupId) {
    return canPostInGroup(groupId);
  }

  /// Check if user has admin access to group
  static bool hasAdminAccess(String groupId) {
    return isGroupAdmin(groupId);
  }

  /// Check if user has management access to group
  static bool hasManagementAccess(String groupId) {
    return canManageGroup(groupId);
  }

  // ===== GROUP CREATION =====

  /// Check if user can create groups
  static bool canCreateGroups() {
    return BasePermissionManager.isAuthenticated;
  }

  /// Check if user can join groups
  static bool canJoinGroups() {
    return BasePermissionManager.isAuthenticated;
  }

  /// Check if user can request to join group
  static bool canRequestToJoinGroup(String groupId) {
    return BasePermissionManager.isAuthenticated && !isGroupMember(groupId);
  }

  // ===== GROUP COMMUNICATION =====

  /// Check if user can send group messages
  static bool canSendGroupMessages(String groupId) {
    return isGroupMember(groupId);
  }

  /// Check if user can create group events
  static bool canCreateGroupEvents(String groupId) {
    return isGroupMember(groupId);
  }

  /// Check if user can manage group events
  static bool canManageGroupEvents(String groupId) {
    return isGroupAdmin(groupId);
  }

  /// Check if user can send group announcements
  static bool canSendGroupAnnouncements(String groupId) {
    return isGroupAdmin(groupId);
  }

  // ===== GROUP VALIDATION =====

  /// Validate group ID format
  static bool isValidGroupId(String groupId) {
    return groupId.isNotEmpty && groupId.trim().isNotEmpty;
  }

  /// Check if group exists and user has access
  static bool validateGroupAccess(String groupId) {
    if (!isValidGroupId(groupId)) return false;
    return hasGroupAccess(groupId);
  }

  /// Get group permission validation result
  static Map<String, bool> validateAllGroupPermissions(String groupId) {
    return {
      'canView': canViewGroup(groupId),
      'canEdit': canEditGroup(groupId),
      'canManage': canManageGroup(groupId),
      'canDelete': canDeleteGroup(groupId),
      'isAdmin': isGroupAdmin(groupId),
      'isOwner': isGroupOwner(groupId),
      'isMember': isGroupMember(groupId),
      'canInvite': canInviteToGroup(groupId),
      'canLeave': canLeaveGroup(groupId),
      'canChangeSettings': canChangeGroupSettings(groupId),
      'canPost': canPostInGroup(groupId),
    };
  }

  // ===== GROUP PERMISSION CONTEXT =====

  /// Create permission context for group operations
  static Map<String, dynamic> createGroupPermissionContext(String groupId) {
    return {
      'groupId': groupId,
      'userId': BasePermissionManager.currentUserId,
      'permissions': validateAllGroupPermissions(groupId),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Check if user can perform operation on group
  static bool canPerformGroupOperation(String groupId, String operation) {
    switch (operation.toLowerCase()) {
      case 'view':
        return canViewGroup(groupId);
      case 'edit':
        return canEditGroup(groupId);
      case 'manage':
        return canManageGroup(groupId);
      case 'delete':
        return canDeleteGroup(groupId);
      case 'invite':
        return canInviteToGroup(groupId);
      case 'remove_members':
        return isGroupAdmin(groupId);
      case 'leave':
        return canLeaveGroup(groupId);
      case 'settings':
        return canChangeGroupSettings(groupId);
      case 'post':
        return canPostInGroup(groupId);
      case 'moderate':
        return canModerateGroupContent(groupId);
      case 'events':
        return canCreateGroupEvents(groupId);
      case 'announcements':
        return canSendGroupAnnouncements(groupId);
      default:
        return false;
    }
  }
}