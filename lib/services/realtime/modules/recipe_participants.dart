// lib/services/realtime/modules/recipe_participants.dart

import '../../../models/realtime/realtime_recipe.dart';
import '../../../models/permissions/resource_permission.dart';
import '../../../core/utils/logger.dart';
import './recipe_content_operations.dart';

/// Focused module for recipe participant management
/// 
/// This module handles ONLY participant-related operations:
/// - Adding and removing participants
/// - Managing participant permissions
/// - Participant validation and utilities
/// - Permission checking and enforcement
/// 
/// ❌ DOES NOT CONTAIN: Recipe content operations, state management, synchronization
class RecipeParticipants {

  // ===== PARTICIPANT MANAGEMENT =====

  /// Add participant to realtime recipe
  static RealtimeRecipe addParticipant(
    RealtimeRecipe recipe, {
    required String userId,
    required String userDisplayName,
    required ResourcePermission permission,
  }) {
    if (userId.trim().isEmpty) {
      throw RecipeOperationError(
        operation: RecipeOperationType.addParticipant,
        message: 'User ID cannot be empty',
        resourceId: recipe.id,
      );
    }

    if (userDisplayName.trim().isEmpty) {
      throw RecipeOperationError(
        operation: RecipeOperationType.addParticipant,
        message: 'User display name cannot be empty',
        resourceId: recipe.id,
      );
    }

    // Check if user is already a participant
    if (isParticipant(recipe, userId)) {
      throw RecipeOperationError(
        operation: RecipeOperationType.addParticipant,
        message: 'User is already a participant: $userDisplayName',
        resourceId: recipe.id,
      );
    }

    AppLogger.info('👥 Adding participant: $userDisplayName ($userId) with permission: ${permission.name}');

    return recipe.addParticipant(userId, userDisplayName, permission);
  }

  /// Remove participant from realtime recipe
  static RealtimeRecipe removeParticipant(
    RealtimeRecipe recipe, {
    required String userId,
  }) {
    if (userId.trim().isEmpty) {
      throw RecipeOperationError(
        operation: RecipeOperationType.removeParticipant,
        message: 'User ID cannot be empty',
        resourceId: recipe.id,
      );
    }

    // Check if user is a participant
    if (!isParticipant(recipe, userId)) {
      throw RecipeOperationError(
        operation: RecipeOperationType.removeParticipant,
        message: 'User is not a participant: $userId',
        resourceId: recipe.id,
      );
    }

    // Cannot remove the owner
    if (userId == recipe.ownerId) {
      throw RecipeOperationError(
        operation: RecipeOperationType.removeParticipant,
        message: 'Cannot remove the recipe owner',
        resourceId: recipe.id,
      );
    }

    AppLogger.info('👥 Removing participant: $userId');

    return recipe.removeParticipant(userId);
  }

  /// Update participant permission
  static RealtimeRecipe updateParticipantPermission(
    RealtimeRecipe recipe, {
    required String userId,
    required ResourcePermission newPermission,
  }) {
    if (userId.trim().isEmpty) {
      throw RecipeOperationError(
        operation: RecipeOperationType.updatePermissions,
        message: 'User ID cannot be empty',
        resourceId: recipe.id,
      );
    }

    // Check if user is a participant
    if (!isParticipant(recipe, userId)) {
      throw RecipeOperationError(
        operation: RecipeOperationType.updatePermissions,
        message: 'User is not a participant: $userId',
        resourceId: recipe.id,
      );
    }

    // Cannot change owner's permission
    if (userId == recipe.ownerId) {
      throw RecipeOperationError(
        operation: RecipeOperationType.updatePermissions,
        message: 'Cannot change owner\'s permission',
        resourceId: recipe.id,
      );
    }

    final currentPermission = getUserPermission(recipe, userId);
    if (currentPermission == newPermission) {
      AppLogger.info('👥 Permission unchanged for user: $userId');
      return recipe; // No change needed
    }

    AppLogger.info('👥 Updating permission for user $userId: ${currentPermission?.name} -> ${newPermission.name}');

    return recipe.updateParticipantPermission(userId, newPermission);
  }

  // ===== PARTICIPANT QUERIES =====

  /// Check if user is a participant
  static bool isParticipant(RealtimeRecipe recipe, String userId) {
    return recipe.participants.containsKey(userId);
  }

  /// Check if user is the owner
  static bool isOwner(RealtimeRecipe recipe, String userId) {
    return recipe.ownerId == userId;
  }

  /// Get user's permission level
  static ResourcePermission? getUserPermission(RealtimeRecipe recipe, String userId) {
    return recipe.participants[userId];
  }

  /// Check if user can view the recipe
  static bool canUserView(RealtimeRecipe recipe, String userId) {
    // All participants can view, check if user is a participant or owner
    return recipe.isParticipant(userId) || recipe.isOwner(userId);
  }

  /// Check if user can edit the recipe
  static bool canUserEdit(RealtimeRecipe recipe, String userId) {
    return recipe.canUserEdit(userId);
  }

  /// Get all participant user IDs
  static List<String> getParticipantIds(RealtimeRecipe recipe) {
    return recipe.participants.keys.toList();
  }

  /// Get participant count
  static int getParticipantCount(RealtimeRecipe recipe) {
    return recipe.participants.length;
  }

  /// Get participants with specific permission
  static List<String> getParticipantsWithPermission(
    RealtimeRecipe recipe,
    ResourcePermission permission,
  ) {
    return recipe.participants.entries
        .where((entry) => entry.value == permission)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get editor user IDs (users who can edit content)
  static List<String> getEditorIds(RealtimeRecipe recipe) {
    return recipe.participants.entries
        .where((entry) => ResourcePermissionHelper.canEditContent(entry.value))
        .map((entry) => entry.key)
        .toList();
  }

  /// Get viewer user IDs (read-only users)
  static List<String> getViewerIds(RealtimeRecipe recipe) {
    return recipe.participants.entries
        .where((entry) => entry.value == ResourcePermission.viewer || entry.value == ResourcePermission.read)
        .map((entry) => entry.key)
        .toList();
  }

  // ===== PARTICIPANT UTILITIES =====

  /// Get participant summary for UI display
  static Map<String, dynamic> getParticipantSummary(RealtimeRecipe recipe) {
    final editors = getEditorIds(recipe);
    final viewers = getViewerIds(recipe);
    
    return {
      'totalParticipants': getParticipantCount(recipe),
      'editorsCount': editors.length,
      'viewersCount': viewers.length,
      'ownerUserId': recipe.ownerId,
      'ownerDisplayName': recipe.ownerDisplayName,
      'editorIds': editors,
      'viewerIds': viewers,
    };
  }

  /// Validate participant state
  static List<String> validateParticipantState(RealtimeRecipe recipe) {
    final errors = <String>[];

    // Check owner exists
    if (recipe.ownerId.trim().isEmpty) {
      errors.add('Recipe has no owner');
    }

    if (recipe.ownerDisplayName.trim().isEmpty) {
      errors.add('Recipe owner has no display name');
    }

    // Check participants (Map<String, ResourcePermission>)
    for (final entry in recipe.participants.entries) {
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
    RealtimeRecipe recipe,
  ) {
    final result = <ResourcePermission, List<String>>{};

    for (final entry in recipe.participants.entries) {
      final permission = entry.value;
      if (!result.containsKey(permission)) {
        result[permission] = [];
      }
      result[permission]!.add(entry.key);
    }

    return result;
  }

  /// Check if recipe has any participants (excluding owner)
  static bool hasParticipants(RealtimeRecipe recipe) {
    return recipe.participants.isNotEmpty;
  }

  /// Check if recipe is collaborative (has participants or allows joining)
  static bool isCollaborative(RealtimeRecipe recipe) {
    return hasParticipants(recipe);
  }

  /// Get formatted participant list for display (IDs only, names cached elsewhere)
  static String getParticipantListString(RealtimeRecipe recipe) {
    if (!hasParticipants(recipe)) {
      return 'Endast ägare: ${recipe.ownerDisplayName}';
    }

    final participantIds = recipe.participants.keys
        .where((id) => id != recipe.ownerId) // Exclude owner from participant list
        .toList();

    return 'Ägare: ${recipe.ownerDisplayName}, Deltagare: ${participantIds.length}st';
  }

  /// Find participant permission by user ID
  static ResourcePermission? findParticipantPermission(RealtimeRecipe recipe, String userId) {
    return recipe.participants[userId];
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
    RealtimeRecipe recipe,
    String userId,
    ResourcePermission requiredPermission,
  ) {
    final userPermission = getUserPermission(recipe, userId);
    if (userPermission == null) return false;

    return getPermissionLevel(userPermission) >= 
           getPermissionLevel(requiredPermission);
  }

  // ===== COLLABORATION UTILITIES =====

  /// Get collaboration status for recipe
  static String getCollaborationStatus(RealtimeRecipe recipe) {
    if (!hasParticipants(recipe)) {
      return 'Privat recept';
    }

    final editorCount = getEditorIds(recipe).length;
    final viewerCount = getViewerIds(recipe).length;

    if (editorCount > 0 && viewerCount > 0) {
      return 'Kollaborativt ($editorCount redigerare, $viewerCount betraktare)';
    } else if (editorCount > 0) {
      return 'Kollaborativt ($editorCount redigerare)';
    } else if (viewerCount > 0) {
      return 'Delat ($viewerCount betraktare)';
    }

    return 'Delat recept';
  }

  /// Check if user can invite others
  static bool canUserInvite(RealtimeRecipe recipe, String userId) {
    final permission = getUserPermission(recipe, userId);
    if (permission == null) return false;

    return ResourcePermissionHelper.canInviteParticipants(permission);
  }

  /// Check if user can manage permissions
  static bool canUserManagePermissions(RealtimeRecipe recipe, String userId) {
    final permission = getUserPermission(recipe, userId);
    if (permission == null) return false;

    return ResourcePermissionHelper.canManagePermissions(permission);
  }

  /// Get active collaboration info
  static Map<String, dynamic> getCollaborationInfo(RealtimeRecipe recipe) {
    return {
      'isCollaborative': isCollaborative(recipe),
      'participantCount': getParticipantCount(recipe),
      'editorCount': getEditorIds(recipe).length,
      'viewerCount': getViewerIds(recipe).length,
      'collaborationStatus': getCollaborationStatus(recipe),
      'lastEditedBy': recipe.lastEditedByDisplayName,
      'lastEditedAt': recipe.lastEditedAt,
    };
  }

  /// Check if recipe allows new participants
  static bool allowsNewParticipants(RealtimeRecipe recipe) {
    // This would depend on recipe settings, for now assume all collaborative recipes allow new participants
    return isCollaborative(recipe);
  }

  /// Get suggested permission for new participant
  static ResourcePermission getSuggestedPermissionForNewParticipant() {
    // Default to viewer permission for new participants
    return ResourcePermission.viewer;
  }
}