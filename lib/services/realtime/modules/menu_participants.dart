// lib/services/realtime/modules/menu_participants.dart

import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/realtime/modules/menu_operations.dart';

/// Focused module for menu participant management
/// 
/// This module handles ONLY participant-related operations:
/// - Adding and removing participants
/// - Managing participant permissions
/// - Participant validation and utilities
/// - Permission checking and enforcement
/// 
/// ❌ DOES NOT CONTAIN: Menu content operations, state management, synchronization
class MenuParticipants {

  // ===== PARTICIPANT MANAGEMENT =====

  /// Add participant to realtime menu
  static RealtimeMenu addParticipant(
    RealtimeMenu menu, {
    required String userId,
    required String userDisplayName,
    required ResourcePermission permission,
  }) {
    if (userId.trim().isEmpty) {
      throw MenuOperationError(
        operation: MenuOperationType.addParticipant,
        message: 'User ID cannot be empty',
        resourceId: menu.id,
      );
    }

    if (userDisplayName.trim().isEmpty) {
      throw MenuOperationError(
        operation: MenuOperationType.addParticipant,
        message: 'User display name cannot be empty',
        resourceId: menu.id,
      );
    }

    // Check if user is already a participant
    if (isParticipant(menu, userId)) {
      throw MenuOperationError(
        operation: MenuOperationType.addParticipant,
        message: 'User is already a participant: $userDisplayName',
        resourceId: menu.id,
      );
    }

    AppLogger.info('👥 Adding participant: $userDisplayName ($userId) with permission: ${permission.name}');

    return menu.addParticipant(userId, userDisplayName, permission);
  }

  /// Remove participant from realtime menu
  static RealtimeMenu removeParticipant(
    RealtimeMenu menu, {
    required String userId,
  }) {
    if (userId.trim().isEmpty) {
      throw MenuOperationError(
        operation: MenuOperationType.removeParticipant,
        message: 'User ID cannot be empty',
        resourceId: menu.id,
      );
    }

    // Check if user is a participant
    if (!isParticipant(menu, userId)) {
      throw MenuOperationError(
        operation: MenuOperationType.removeParticipant,
        message: 'User is not a participant: $userId',
        resourceId: menu.id,
      );
    }

    // Cannot remove the owner
    if (userId == menu.ownerId) {
      throw MenuOperationError(
        operation: MenuOperationType.removeParticipant,
        message: 'Cannot remove the menu owner',
        resourceId: menu.id,
      );
    }

    AppLogger.info('👥 Removing participant: $userId');

    return menu.removeParticipant(userId);
  }

  /// Update participant permission
  static RealtimeMenu updateParticipantPermission(
    RealtimeMenu menu, {
    required String userId,
    required ResourcePermission newPermission,
  }) {
    if (userId.trim().isEmpty) {
      throw MenuOperationError(
        operation: MenuOperationType.updatePermissions,
        message: 'User ID cannot be empty',
        resourceId: menu.id,
      );
    }

    // Check if user is a participant
    if (!isParticipant(menu, userId)) {
      throw MenuOperationError(
        operation: MenuOperationType.updatePermissions,
        message: 'User is not a participant: $userId',
        resourceId: menu.id,
      );
    }

    // Cannot change owner's permission
    if (userId == menu.ownerId) {
      throw MenuOperationError(
        operation: MenuOperationType.updatePermissions,
        message: 'Cannot change owner\'s permission',
        resourceId: menu.id,
      );
    }

    final currentPermission = getUserPermission(menu, userId);
    if (currentPermission == newPermission) {
      AppLogger.info('👥 Permission unchanged for user: $userId');
      return menu; // No change needed
    }

    AppLogger.info('👥 Updating permission for user $userId: ${currentPermission?.name} -> ${newPermission.name}');

    return menu.updateParticipantPermission(userId, newPermission);
  }

  // ===== PARTICIPANT QUERIES =====

  /// Check if user is a participant
  static bool isParticipant(RealtimeMenu menu, String userId) {
    return menu.participants.containsKey(userId);
  }

  /// Check if user is the owner
  static bool isOwner(RealtimeMenu menu, String userId) {
    return menu.ownerId == userId;
  }

  /// Get user's permission level
  static ResourcePermission? getUserPermission(RealtimeMenu menu, String userId) {
    return menu.participants[userId];
  }

  /// Check if user can view the menu
  static bool canUserView(RealtimeMenu menu, String userId) {
    // All participants can view, check if user is a participant or owner
    return menu.isParticipant(userId) || menu.isOwner(userId);
  }

  /// Check if user can edit the menu
  static bool canUserEdit(RealtimeMenu menu, String userId) {
    return menu.canUserEdit(userId);
  }

  /// Get all participant user IDs
  static List<String> getParticipantIds(RealtimeMenu menu) {
    return menu.participants.keys.toList();
  }

  /// Get participant count
  static int getParticipantCount(RealtimeMenu menu) {
    return menu.participants.length;
  }

  /// Get participants with specific permission
  static List<String> getParticipantsWithPermission(
    RealtimeMenu menu,
    ResourcePermission permission,
  ) {
    return menu.participants.entries
        .where((entry) => entry.value == permission)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get editor user IDs (including owner)
  static List<String> getEditorIds(RealtimeMenu menu) {
    return menu.participants.entries
        .where((entry) => ResourcePermissionHelper.canEditContent(entry.value))
        .map((entry) => entry.key)
        .toList();
  }

  /// Get viewer user IDs (read-only users)
  static List<String> getViewerIds(RealtimeMenu menu) {
    return menu.participants.entries
        .where((entry) => entry.value == ResourcePermission.viewer || entry.value == ResourcePermission.read)
        .map((entry) => entry.key)
        .toList();
  }

  // ===== PARTICIPANT UTILITIES =====

  /// Get participant summary for UI display
  static Map<String, dynamic> getParticipantSummary(RealtimeMenu menu) {
    final editors = getEditorIds(menu);
    final viewers = getViewerIds(menu);
    
    return {
      'totalParticipants': getParticipantCount(menu),
      'editorsCount': editors.length,
      'viewersCount': viewers.length,
      'ownerUserId': menu.ownerId,
      'ownerDisplayName': menu.ownerDisplayName,
      'editorIds': editors,
      'viewerIds': viewers,
    };
  }

  /// Validate participant state
  static List<String> validateParticipantState(RealtimeMenu menu) {
    final errors = <String>[];

    // Check owner exists
    if (menu.ownerId.trim().isEmpty) {
      errors.add('Menu has no owner');
    }

    if (menu.ownerDisplayName.trim().isEmpty) {
      errors.add('Menu owner has no display name');
    }

    // Check participants (Map<String, ResourcePermission>)
    for (final entry in menu.participants.entries) {
      if (entry.key.trim().isEmpty) {
        errors.add('Participant has empty user ID');
      }

      // Note: Display names are not stored in participants map, 
      // they are cached separately in the UI layer
    }

    return errors;
  }

  /// Get participant user IDs grouped by permission
  static Map<ResourcePermission, List<String>> getParticipantIdsByPermission(
    RealtimeMenu menu,
  ) {
    final result = <ResourcePermission, List<String>>{};

    for (final entry in menu.participants.entries) {
      final permission = entry.value;
      if (!result.containsKey(permission)) {
        result[permission] = [];
      }
      result[permission]!.add(entry.key);
    }

    return result;
  }

  /// Check if menu has any participants (excluding owner)
  static bool hasParticipants(RealtimeMenu menu) {
    return menu.participants.isNotEmpty;
  }

  /// Check if menu is collaborative (has participants or allows joining)
  static bool isCollaborative(RealtimeMenu menu) {
    return hasParticipants(menu);
  }

  /// Get formatted participant list for display (IDs only, names cached elsewhere)
  static String getParticipantListString(RealtimeMenu menu) {
    if (!hasParticipants(menu)) {
      return 'Endast ägare: ${menu.ownerDisplayName}';
    }

    final participantIds = menu.participants.keys
        .where((id) => id != menu.ownerId) // Exclude owner from participant list
        .toList();

    return 'Ägare: ${menu.ownerDisplayName}, Deltagare: ${participantIds.length}st';
  }

  /// Find participant permission by user ID
  static ResourcePermission? findParticipantPermission(RealtimeMenu menu, String userId) {
    return menu.participants[userId];
  }

  /// Get permission hierarchy level (higher number = more permissions)
  static int getPermissionLevel(ResourcePermission permission) {
    switch (permission) {
      case ResourcePermission.read:
        return 1;
      case ResourcePermission.viewer:
        return 2;
      case ResourcePermission.write:
        return 3;
      case ResourcePermission.editor:
        return 4;
      case ResourcePermission.admin:
        return 5;
      case ResourcePermission.owner:
        return 6;
    }
  }

  /// Check if user has sufficient permission level
  static bool hasMinimumPermission(
    RealtimeMenu menu,
    String userId,
    ResourcePermission requiredPermission,
  ) {
    final userPermission = getUserPermission(menu, userId);
    if (userPermission == null) return false;

    return getPermissionLevel(userPermission) >= 
           getPermissionLevel(requiredPermission);
  }
}