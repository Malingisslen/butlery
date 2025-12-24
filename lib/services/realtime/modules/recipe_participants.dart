// lib/services/realtime/modules/recipe_participants.dart

import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/realtime/modules/recipe_content_operations.dart';

/// Focused module for recipe participant management
/// This module handles ONLY participant-related operations:
/// - Adding and removing participants
/// - Managing participant permissions
/// - Participant validation and utilities
/// - Permission checking and enforcement
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
        message: 'Användar-ID kan inte vara tomt',
        resourceId: recipe.id,
      );
    }

    if (userDisplayName.trim().isEmpty) {
      throw RecipeOperationError(
        operation: RecipeOperationType.addParticipant,
        message: 'Användarnamn kan inte vara tomt',
        resourceId: recipe.id,
      );
    }

    // Check if user is already a participant
    if (isParticipant(recipe, userId)) {
      throw RecipeOperationError(
        operation: RecipeOperationType.addParticipant,
        message: 'Användaren är redan deltagare: $userDisplayName',
        resourceId: recipe.id,
      );
    }

    // Check maximum participant limit (50 participants max)
    if (recipe.participants.length >= 50) {
      throw RecipeOperationError(
        operation: RecipeOperationType.addParticipant,
        message: 'Maxgräns för deltagare nådd (50)',
        resourceId: recipe.id,
      );
    }

    AppLogger.info(
        '👥 Adding participant: $userDisplayName ($userId) with permission: ${permission.name}');

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
        message: 'Användar-ID kan inte vara tomt',
        resourceId: recipe.id,
      );
    }

    // Cannot remove the owner - check this FIRST
    if (userId == recipe.ownerId) {
      throw RecipeOperationError(
        operation: RecipeOperationType.removeParticipant,
        message: 'Kan inte ta bort receptägaren',
        resourceId: recipe.id,
      );
    }

    // Check if user is a participant
    if (!isParticipant(recipe, userId)) {
      throw RecipeOperationError(
        operation: RecipeOperationType.removeParticipant,
        message: 'Användaren är inte deltagare: $userId',
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
        message: 'Användar-ID kan inte vara tomt',
        resourceId: recipe.id,
      );
    }

    // Check if user is a participant
    if (!isParticipant(recipe, userId)) {
      throw RecipeOperationError(
        operation: RecipeOperationType.updatePermissions,
        message: 'Användaren är inte deltagare: $userId',
        resourceId: recipe.id,
      );
    }

    // Cannot change owner's permission
    if (userId == recipe.ownerId) {
      throw RecipeOperationError(
        operation: RecipeOperationType.updatePermissions,
        message: 'Kan inte ändra ägarens behörighet',
        resourceId: recipe.id,
      );
    }

    final currentPermission = getUserPermission(recipe, userId);
    if (currentPermission == newPermission) {
      AppLogger.info('👥 Permission unchanged for user: $userId');
      return recipe; // No change needed
    }

    AppLogger.info(
        '👥 Updating permission for user $userId: ${currentPermission?.name} -> ${newPermission.name}');

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
  static ResourcePermission? getUserPermission(
      RealtimeRecipe recipe, String userId) {
    // Owner has highest permission, check first
    if (recipe.ownerId == userId) {
      return ResourcePermission.owner;
    }
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
    // Owner is not in participants map anymore
    return recipe.participants.entries
        .where((entry) =>
            entry.value == ResourcePermission.editor ||
            entry.value == ResourcePermission.write ||
            entry.value == ResourcePermission.admin)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get viewer user IDs (read-only users)
  static List<String> getViewerIds(RealtimeRecipe recipe) {
    return recipe.participants.entries
        .where((entry) =>
            entry.value == ResourcePermission.viewer ||
            entry.value == ResourcePermission.read)
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
      errors.add('Recept saknar ägare');
    }

    if (recipe.ownerDisplayName.trim().isEmpty) {
      errors.add('Receptägare saknar visningsnamn');
    }

    // Check participants (Map<String, ResourcePermission>)
    for (final entry in recipe.participants.entries) {
      if (entry.key.trim().isEmpty) {
        errors.add('Deltagare har tomt användar-ID');
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
    // Since owner is not in participants map, empty means no participants
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
        .where(
            (id) => id != recipe.ownerId) // Exclude owner from participant list
        .toList();

    return 'Ägare: ${recipe.ownerDisplayName}, Deltagare: ${participantIds.length}st';
  }

  /// Find participant permission by user ID
  static ResourcePermission? findParticipantPermission(
      RealtimeRecipe recipe, String userId) {
    return recipe.participants[userId];
  }

  /// Get permission hierarchy level (higher number = more permissions)
  static int getPermissionLevel(ResourcePermission permission) {
    if (permission == ResourcePermission.read) {
      return 1;
    } else if (permission == ResourcePermission.viewer) {
      return 2;
    } else if (permission == ResourcePermission.write) {
      return 3;
    } else if (permission == ResourcePermission.editor) {
      return 4;
    } else if (permission == ResourcePermission.admin) {
      return 5;
    } else if (permission == ResourcePermission.owner) {
      return 6;
    } else {
      return 0;
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

    return permission == ResourcePermission.admin ||
        permission == ResourcePermission.owner;
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
