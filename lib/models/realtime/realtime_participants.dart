import 'package:butlery/models/permissions/resource_permission.dart';

/// Participant management for realtime resources.
class RealtimeParticipants {
  /// Add participant with permission.
  static Map<String, ResourcePermission> addParticipant(
    Map<String, ResourcePermission> participants,
    String userId,
    ResourcePermission permission,
  ) {
    final updated = Map<String, ResourcePermission>.from(participants);
    updated[userId] = permission;
    return updated;
  }

  /// Remove participant
  static Map<String, ResourcePermission> removeParticipant(
    Map<String, ResourcePermission> participants,
    String userId,
  ) {
    final updated = Map<String, ResourcePermission>.from(participants);
    updated.remove(userId);
    return updated;
  }

  /// Update participant permission
  static Map<String, ResourcePermission> updateParticipantPermission(
    Map<String, ResourcePermission> participants,
    String userId,
    ResourcePermission newPermission,
  ) {
    if (!participants.containsKey(userId)) {
      throw ArgumentError('User $userId is not a participant');
    }

    final updated = Map<String, ResourcePermission>.from(participants);
    updated[userId] = newPermission;
    return updated;
  }

  /// Bulk add participants
  static Map<String, ResourcePermission> addParticipants(
    Map<String, ResourcePermission> participants,
    Map<String, ResourcePermission> newParticipants,
  ) {
    final updated = Map<String, ResourcePermission>.from(participants);
    updated.addAll(newParticipants);
    return updated;
  }

  /// Bulk remove participants
  static Map<String, ResourcePermission> removeParticipants(
    Map<String, ResourcePermission> participants,
    List<String> userIds,
  ) {
    final updated = Map<String, ResourcePermission>.from(participants);
    for (final userId in userIds) {
      updated.remove(userId);
    }
    return updated;
  }

  static bool hasPermission(
    Map<String, ResourcePermission> participants,
    String userId,
    ResourcePermission requiredPermission,
  ) {
    final userPermission = participants[userId];
    if (userPermission == null) return false;

    return _getPermissionLevel(userPermission) >=
        _getPermissionLevel(requiredPermission);
  }

  /// Get numeric level for permission comparison
  static int _getPermissionLevel(ResourcePermission permission) {
    if (permission == ResourcePermission.owner) {
      return 4;
    } else if (permission == ResourcePermission.admin) {
      return 3;
    } else if (permission == ResourcePermission.editor ||
        permission == ResourcePermission.write) {
      return 2;
    } else if (permission == ResourcePermission.viewer ||
        permission == ResourcePermission.read) {
      return 1;
    } else {
      return 0;
    }
  }

  /// Check if user can edit
  static bool canEdit(
    Map<String, ResourcePermission> participants,
    String userId,
  ) {
    return hasPermission(participants, userId, ResourcePermission.editor);
  }

  /// Check if user can view
  static bool canView(
    Map<String, ResourcePermission> participants,
    String userId,
  ) {
    return hasPermission(participants, userId, ResourcePermission.viewer);
  }

  /// Check if user is owner
  static bool isOwner(
    Map<String, ResourcePermission> participants,
    String userId,
  ) {
    return participants[userId] == ResourcePermission.owner;
  }

  /// Check if user is admin
  static bool isAdmin(
    Map<String, ResourcePermission> participants,
    String userId,
  ) {
    return hasPermission(participants, userId, ResourcePermission.admin);
  }

  /// Validate permission change is allowed
  static bool canChangePermission(
    Map<String, ResourcePermission> participants,
    String actorUserId,
    String targetUserId,
    ResourcePermission newPermission,
  ) {
    final actorPermission = participants[actorUserId];
    final targetPermission = participants[targetUserId];

    if (actorPermission == null || targetPermission == null) return false;

    // Only owners can change owner permissions
    if (targetPermission == ResourcePermission.owner) {
      return actorPermission == ResourcePermission.owner;
    }

    // Admins can change permissions below admin level
    if (actorPermission == ResourcePermission.admin) {
      return _getPermissionLevel(newPermission) <
          _getPermissionLevel(ResourcePermission.admin);
    }

    // Owners can change any permission
    return actorPermission == ResourcePermission.owner;
  }

  static Map<String, int> getParticipantStats(
    Map<String, ResourcePermission> participants,
  ) {
    final stats = <String, int>{
      'total': participants.length,
      'owners': 0,
      'admins': 0,
      'editors': 0,
      'viewers': 0,
    };

    for (final permission in participants.values) {
      if (permission == ResourcePermission.owner) {
        stats['owners'] = stats['owners']! + 1;
      } else if (permission == ResourcePermission.admin) {
        stats['admins'] = stats['admins']! + 1;
      } else if (permission == ResourcePermission.editor ||
          permission == ResourcePermission.write) {
        stats['editors'] = stats['editors']! + 1;
      } else if (permission == ResourcePermission.viewer ||
          permission == ResourcePermission.read) {
        stats['viewers'] = stats['viewers']! + 1;
      }
      // Unknown permissions are skipped
    }

    return stats;
  }

  /// Get participants by permission level
  static List<String> getParticipantsByPermission(
    Map<String, ResourcePermission> participants,
    ResourcePermission permission,
  ) {
    return participants.entries
        .where((entry) => entry.value == permission)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get all editors (including admins and owners)
  static List<String> getAllEditors(
    Map<String, ResourcePermission> participants,
  ) {
    return participants.entries
        .where(
          (entry) =>
              _getPermissionLevel(entry.value) >=
              _getPermissionLevel(ResourcePermission.editor),
        )
        .map((entry) => entry.key)
        .toList();
  }

  /// Get collaboration level (0-100)
  static int getCollaborationLevel(
    Map<String, ResourcePermission> participants,
  ) {
    final total = participants.length;
    if (total <= 1) return 0;

    final editors = getAllEditors(participants).length;
    final collaborationRatio = editors / total;

    // Score based on number of participants and their editing ability
    final sizeScore = (total.clamp(2, 10) - 1) * 10; // 10-90 points
    final editRatio = (collaborationRatio * 50).round(); // 0-50 points

    return (sizeScore + editRatio).clamp(0, 100);
  }

  static bool isValidParticipants(
    Map<String, ResourcePermission> participants,
  ) {
    if (participants.isEmpty) return false;

    // Must have at least one owner
    final hasOwner = participants.values.contains(ResourcePermission.owner);
    if (!hasOwner) return false;

    // All user IDs must be valid (non-empty strings)
    for (final userId in participants.keys) {
      if (userId.isEmpty) return false;
    }

    return true;
  }

  /// Sanitize participants map
  static Map<String, ResourcePermission> sanitizeParticipants(
    Map<String, ResourcePermission> participants,
  ) {
    final sanitized = <String, ResourcePermission>{};

    for (final entry in participants.entries) {
      final userId = entry.key.trim();
      if (userId.isNotEmpty) {
        sanitized[userId] = entry.value;
      }
    }

    return sanitized;
  }

  /// Ensure owner exists
  static Map<String, ResourcePermission> ensureOwner(
    Map<String, ResourcePermission> participants,
    String ownerId,
  ) {
    final updated = Map<String, ResourcePermission>.from(participants);
    updated[ownerId] = ResourcePermission.owner;
    return updated;
  }

  static ResourcePermission? getHighestPermission(
    List<Map<String, ResourcePermission>> participantsList,
    String userId,
  ) {
    ResourcePermission? highest;

    for (final participants in participantsList) {
      final permission = participants[userId];
      if (permission != null) {
        if (highest == null ||
            _getPermissionLevel(permission) > _getPermissionLevel(highest)) {
          highest = permission;
        }
      }
    }

    return highest;
  }

  /// Merge participant maps (takes highest permission)
  static Map<String, ResourcePermission> mergeParticipants(
    List<Map<String, ResourcePermission>> participantsList,
  ) {
    final merged = <String, ResourcePermission>{};

    for (final participants in participantsList) {
      for (final entry in participants.entries) {
        final userId = entry.key;
        final permission = entry.value;

        final existingPermission = merged[userId];
        if (existingPermission == null ||
            _getPermissionLevel(permission) >
                _getPermissionLevel(existingPermission)) {
          merged[userId] = permission;
        }
      }
    }

    return merged;
  }

  /// Create default participants for new resource
  static Map<String, ResourcePermission> createDefaultParticipants({
    required String ownerId,
    List<String>? editorIds,
    List<String>? viewerIds,
  }) {
    final participants = <String, ResourcePermission>{};

    // Owner is NOT added to participants map - tracked separately via ownerId field

    // Add editors
    if (editorIds != null) {
      for (final editorId in editorIds) {
        if (editorId != ownerId) {
          participants[editorId] = ResourcePermission.editor;
        }
      }
    }

    // Add viewers
    if (viewerIds != null) {
      for (final viewerId in viewerIds) {
        if (viewerId != ownerId && !participants.containsKey(viewerId)) {
          participants[viewerId] = ResourcePermission.viewer;
        }
      }
    }

    return participants;
  }

  static List<String> findParticipants(
    Map<String, ResourcePermission> participants, {
    ResourcePermission? exactPermission,
    ResourcePermission? minPermission,
    ResourcePermission? maxPermission,
  }) {
    return participants.entries
        .where((entry) {
          final permission = entry.value;

          if (exactPermission != null && permission != exactPermission) {
            return false;
          }

          if (minPermission != null &&
              _getPermissionLevel(permission) <
                  _getPermissionLevel(minPermission)) {
            return false;
          }

          if (maxPermission != null &&
              _getPermissionLevel(permission) >
                  _getPermissionLevel(maxPermission)) {
            return false;
          }

          return true;
        })
        .map((entry) => entry.key)
        .toList();
  }

  /// Count participants by criteria
  static int countParticipants(
    Map<String, ResourcePermission> participants, {
    ResourcePermission? exactPermission,
    ResourcePermission? minPermission,
  }) {
    return findParticipants(
      participants,
      exactPermission: exactPermission,
      minPermission: minPermission,
    ).length;
  }
}
