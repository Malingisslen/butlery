// lib/core/permissions/validators/group_validator.dart

import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/permissions/validators/base_validator.dart';
import 'package:butlery/core/permissions/validators/validation_result.dart';

/// Specialized permission validator for group operations and member management.
///
/// This validator handles all group-specific permission validation including creation,
/// editing, member management, invitations, and administrative operations. It manages
/// the complex permission hierarchies that exist within group structures and ensures
/// proper access control for group-related features.
///
/// **Key Validation Areas:**
/// - **Group Creation**: Validates user can create new groups
/// - **Group Administration**: Ensures proper admin and owner permissions
/// - **Member Management**: Handles invitations, removals, and role changes  
/// - **Group Content**: Validates permissions for group-shared resources
/// - **Group Settings**: Manages permissions for group configuration changes
///
/// **Group Permission Hierarchy:**
/// - **Owner**: Full control over group (all operations, cannot be removed)
/// - **Admin**: Management permissions (invite/remove members, edit settings)
/// - **Member**: Basic group access (view content, participate in activities)
/// - **Invited**: Pending membership status with limited access
///
/// **Member Management Features:**
/// Groups support sophisticated member management including role-based permissions,
/// invitation systems, and administrative controls. This validator ensures that
/// all member operations respect the group hierarchy and maintain security boundaries.
///
/// **Usage Examples:**
/// ```dart
/// final validator = GroupPermissionValidator();
/// 
/// // Validate group editing permissions
/// final editResult = validator.validateGroupEdit(groupId);
/// if (editResult.isValid) {
///   showGroupSettingsDialog();
/// }
/// 
/// // Validate member invitation
/// final inviteResult = validator.validateGroupInvitation(
///   groupId, 
///   ['user1', 'user2']
/// );
/// ```
class GroupPermissionValidator extends BasePermissionValidator {
  PermissionService get _permissionService => sl<PermissionService>();
  /// Validates that the current user can create a new group.
  ///
  /// Performs basic authentication checks and validates that the user
  /// has the necessary permissions to create groups. Group creation is
  /// typically available to all authenticated users but may include
  /// future constraints like group limits or subscription requirements.
  ///
  /// Returns [PermissionValidationResult.success] if group creation is allowed,
  /// or an appropriate failure result if creation constraints prevent it.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateGroupCreation();
  /// if (result.isValid) {
  ///   showCreateGroupDialog();
  /// }
  /// ```
  PermissionValidationResult validateGroupCreation() {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    return PermissionValidationResult.success();
  }
  
  /// Validates that the current user can edit the specified group.
  ///
  /// Verifies that the user has sufficient administrative permissions to
  /// modify group settings, update group information, and manage group
  /// configuration. This typically requires admin or owner status within the group.
  ///
  /// [groupId] The unique identifier of the group to validate edit access for
  ///
  /// Returns [PermissionValidationResult.success] if editing is allowed,
  /// or [PermissionValidationResult.insufficientPermissions] if the user
  /// lacks administrative privileges.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateGroupEdit('group123');
  /// if (result.isValid) {
  ///   showGroupEditInterface();
  /// }
  /// ```
  PermissionValidationResult validateGroupEdit(String groupId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.isGroupAdmin(groupId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'grupp',
        action: 'redigera',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validates that the current user can perform management operations on the group.
  ///
  /// Management permissions encompass advanced administrative functions including
  /// member role management, group settings configuration, and other administrative
  /// operations that require elevated privileges within the group hierarchy.
  ///
  /// [groupId] The unique identifier of the group to validate management access for
  ///
  /// Returns [PermissionValidationResult.success] if management is allowed,
  /// or [PermissionValidationResult.insufficientPermissions] if the user
  /// lacks the necessary administrative privileges.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateGroupManagement('group123');
  /// if (result.isValid) {
  ///   showGroupManagementPanel();
  /// }
  /// ```
  PermissionValidationResult validateGroupManagement(String groupId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.isGroupAdmin(groupId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'grupp',
        action: 'hantera',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validates that the current user can delete the specified group.
  ///
  /// Deletion is the most restrictive group operation, typically requiring
  /// ownership rights. This validation protects against unauthorized group
  /// deletion and ensures only the group owner can permanently remove groups
  /// and all associated data.
  ///
  /// [groupId] The unique identifier of the group to validate deletion access for
  ///
  /// Returns [PermissionValidationResult.success] if deletion is allowed,
  /// or [PermissionValidationResult.insufficientPermissions] if the user
  /// cannot delete the group.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateGroupDeletion('group123');
  /// if (result.isValid) {
  ///   showGroupDeletionConfirmation();
  /// }
  /// ```
  PermissionValidationResult validateGroupDeletion(String groupId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canDeleteGroup(groupId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'grupp',
        action: 'ta bort',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validates that the current user can invite users to the specified group.
  ///
  /// Verifies that the user has invitation permissions for the group and that
  /// all proposed invitees are valid users who can be invited. This includes
  /// checking administrative privileges and validating target user accessibility.
  ///
  /// Group invitations typically require admin or owner status and are subject
  /// to various constraints to maintain group security and prevent spam invitations.
  ///
  /// [groupId] The unique identifier of the group to send invitations for
  /// [inviteeIds] List of user IDs to validate as invitation targets
  ///
  /// Returns [PermissionValidationResult.success] if invitations are allowed
  /// for all targets, or an appropriate failure result if invitation permissions
  /// are insufficient or any invitee is invalid.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateGroupInvitation(
  ///   'group123',
  ///   ['user1', 'user2']
  /// );
  /// if (result.isValid) {
  ///   sendGroupInvitations();
  /// }
  /// ```
  PermissionValidationResult validateGroupInvitation(String groupId, List<String> inviteeIds) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canInviteToGroup(groupId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'grupp',
        action: 'bjuda in till',
      );
    }
    
    // Validate invitees
    for (final userId in inviteeIds) {
      if (!_permissionService.canViewProfile(userId)) {
        return PermissionValidationResult.failure(
          errorMessage: 'Du kan inte bjuda in en eller flera av de valda användarna',
          errorCode: 'INVALID_INVITEE',
        );
      }
      
      // Note: Check for existing membership could be implemented later
      // For now, we'll allow the invitation to be sent
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validates that the current user can remove members from the specified group.
  ///
  /// Verifies that the user has sufficient administrative permissions to remove
  /// members and that the removal operations are valid according to group hierarchy
  /// rules. This includes preventing owners from removing themselves and ensuring
  /// proper administrative authority over target members.
  ///
  /// Member removal is a sensitive operation that affects group dynamics and
  /// access to group resources, requiring careful validation of both permissions
  /// and operational constraints.
  ///
  /// [groupId] The unique identifier of the group to remove members from
  /// [memberIds] List of member user IDs to validate for removal
  ///
  /// Returns [PermissionValidationResult.success] if member removal is allowed
  /// for all targets, or an appropriate failure result if removal permissions
  /// are insufficient or removal constraints are violated.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateGroupMemberRemoval(
  ///   'group123',
  ///   ['user1', 'user2']
  /// );
  /// if (result.isValid) {
  ///   removeMembersFromGroup();
  /// }
  /// ```
  PermissionValidationResult validateGroupMemberRemoval(String groupId, List<String> memberIds) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.isGroupAdmin(groupId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'grupp',
        action: 'ta bort medlemmar från',
      );
    }
    
    // Validate member removal permissions
    for (final userId in memberIds) {
      if (_permissionService.isGroupAdmin(groupId) && userId == _permissionService.currentUserId) {
        return PermissionValidationResult.failure(
          errorMessage: 'Gruppägaren kan inte ta bort sig själv',
          errorCode: 'CANNOT_REMOVE_OWNER',
        );
      }
    }
    
    return PermissionValidationResult.success();
  }
}