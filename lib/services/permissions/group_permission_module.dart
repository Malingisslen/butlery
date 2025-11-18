// lib/services/permissions/group_permission_module.dart

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/utils/logger.dart';

/// Module handling group (friend category) permission checks and admin validation.
/// Provides comprehensive permission validation for group management, admin privileges, and invitations.
class GroupPermissionModule {
  final String? Function() getCurrentUserId;

  GroupPermissionModule({
    required this.getCurrentUserId,
  });

  /// Validates whether the current user has administrative privileges for a specific group.
  /// Returns `true` if user has admin privileges for the group, `false` otherwise
  /// **Admin Privileges:**
  /// - Managing group membership (adding/removing members)
  /// - Modifying group settings and description
  /// - Controlling content sharing and visibility
  /// - Delegating admin privileges to other members
  bool isGroupAdmin(String groupId) {
    // Security: Must be authenticated to have admin privileges
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    // Security: Validate group ID
    if (groupId.isEmpty) return false;

    try {
      // FIXED: Properly check group ownership by querying the group
      // Get the group data from UnifiedFriendsService
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      final group = friendsService.getCategoryById(groupId);

      if (group == null) {
        return false;
      }

      // Check if current user is the group owner
      final isOwner = group.ownerId == currentUserId;

      return isOwner;
    } catch (e) {
      AppLogger.error('Error checking group admin status', e);
      return false;
    }
  }

  /// Validates user permission to permanently delete a specific group.
  /// Returns `true` if user can delete the group, `false` otherwise
  /// **Deletion Authority:**
  /// - Group creators typically have deletion privileges
  /// - Designated admins may be granted deletion permissions
  /// - Regular members cannot delete groups
  /// - Requires confirmation and affects all group content
  bool canDeleteGroup(String groupId) {
    // Security: Must be authenticated to delete groups
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    // Security: Validate group ID
    if (groupId.isEmpty) return false;

    // Check if user is a group admin (which includes creators)
    return isGroupAdmin(groupId);
  }

  /// Validates user permission to invite others to join a specific group.
  /// Returns `true` if user can invite others to the group, `false` otherwise
  /// **Invitation Authority:**
  /// - Group admins can typically invite new members
  /// - Regular members may have invitation privileges based on group settings
  /// - Some groups may restrict invitations to creators only
  /// - Open groups may allow broader invitation permissions
  bool canInviteToGroup(String groupId) {
    // Security: Must be authenticated to invite to groups
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    // Security: Validate group ID
    if (groupId.isEmpty) return false;

    // Check if user is a group admin
    if (isGroupAdmin(groupId)) return true;

    // In production, also check if group.settings.allowMemberInvites
    // and if user is a member of the group
    return false;
  }
}
