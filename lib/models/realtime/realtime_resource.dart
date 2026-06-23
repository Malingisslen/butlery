/// Realtime resource model for collaborative management with permission systems (recipes, menus, shopping lists).
// lib/models/realtime/realtime_resource.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Enumeration defining comprehensive realtime resource types for collaborative system classification and routing.
enum RealtimeResourceType {
  recipe('recipe'),
  menu('menu'),
  shoppingList('shopping_list')
  ;

  const RealtimeResourceType(this.value);

  /// Firestore value for this type
  final String value;

  /// Create from Firestore string value
  static RealtimeResourceType fromString(String value) {
    switch (value) {
      case 'recipe':
        return RealtimeResourceType.recipe;
      case 'menu':
        return RealtimeResourceType.menu;
      case 'shopping_list':
        return RealtimeResourceType.shoppingList;
      default:
        throw ArgumentError('${AppLocale.current.unknownResourceType}: $value');
    }
  }

  /// Get user-readable name
  String get displayName {
    final l = AppLocale.current;
    return switch (this) {
      RealtimeResourceType.recipe => l.resourceTypeRecipe,
      RealtimeResourceType.menu => l.resourceTypeMenu,
      RealtimeResourceType.shoppingList => l.resourceTypeShoppingList,
    };
  }

  /// Get icon for resource type
  String get icon => switch (this) {
    RealtimeResourceType.recipe => '🍳',
    RealtimeResourceType.menu => '📋',
    RealtimeResourceType.shoppingList => '🛒',
  };

  @override
  String toString() => value;
}

/// Abstract base class for all realtime resources
abstract class RealtimeResource {
  /// Unique identifier for the resource
  final String id;

  /// Typ av resurs (recipe, menu, shopping)
  final RealtimeResourceType type;

  /// ID of the user who owns the resource
  final String ownerId;

  /// Display name of the owner (cached for performance)
  final String ownerDisplayName;

  /// Map of all participants and their permissions
  final Map<String, ResourcePermission> participants;

  /// List of participant IDs (denormalized for Firestore queries)
  final List<String> participantIds;

  /// When the resource was created
  final DateTime createdAt;

  /// When the resource was last updated
  final DateTime lastEditedAt;

  /// Who made the last change
  final String lastEditedBy;

  /// Display name of the last modifier (cached)
  final String lastEditedByDisplayName;

  /// Number of times the resource has been edited
  final int editCount;

  /// Whether the resource is active or archived
  final bool isActive;

  /// Extra metadata for future expansion
  final Map<String, dynamic> metadata;

  RealtimeResource({
    required this.id,
    required this.type,
    required this.ownerId,
    required this.ownerDisplayName,
    required this.participants,
    List<String>? participantIds,
    DateTime? createdAt,
    DateTime? lastEditedAt,
    required this.lastEditedBy,
    required this.lastEditedByDisplayName,
    this.editCount = 0,
    this.isActive = true,
    Map<String, dynamic>? metadata,
  }) : participantIds = participantIds ?? participants.keys.toList(),
       createdAt = createdAt ?? clock.now(),
       lastEditedAt = lastEditedAt ?? clock.now(),
       metadata = metadata ?? {};

  /// Check if a user has a specific permission
  bool hasPermission(String userId, ResourcePermission requiredPermission) {
    // Owner always has full permission (even if not in participants map)
    if (isOwner(userId)) return true;

    final userPermission = participants[userId];
    if (userPermission == null) return false;
    // Owner always has full permissions
    if (userPermission == ResourcePermission.owner) return true;
    // Check specific permission
    if (requiredPermission == ResourcePermission.viewer ||
        requiredPermission == ResourcePermission.read) {
      return true; // Alla deltagare kan se
    } else if (requiredPermission == ResourcePermission.editor ||
        requiredPermission == ResourcePermission.write) {
      return userPermission == ResourcePermission.editor ||
          userPermission == ResourcePermission.write ||
          userPermission == ResourcePermission.admin ||
          userPermission == ResourcePermission.owner;
    } else if (requiredPermission == ResourcePermission.admin) {
      return userPermission == ResourcePermission.owner ||
          userPermission == ResourcePermission.admin;
    } else if (requiredPermission == ResourcePermission.owner) {
      return userPermission == ResourcePermission.owner;
    } else {
      return false;
    }
  }

  /// Check if user can edit content
  bool canUserEdit(String userId) {
    // Owner can always edit their own resource
    if (isOwner(userId)) return true;
    return hasPermission(userId, ResourcePermission.editor);
  }

  /// Check if user can delete the resource
  bool canUserDelete(String userId) {
    // Owner can always delete their own resource
    if (isOwner(userId)) return true;
    return participants[userId] == ResourcePermission.owner;
  }

  /// Check if user can manage permissions
  bool canUserManagePermissions(String userId) {
    // Owner can always manage permissions
    if (isOwner(userId)) return true;
    return participants[userId] == ResourcePermission.owner;
  }

  /// Check if user can invite others
  bool canUserInvite(String userId) {
    // Owner can always invite
    if (isOwner(userId)) return true;
    final permission = participants[userId];
    return permission != null &&
        (permission == ResourcePermission.admin ||
            permission == ResourcePermission.owner);
  }

  /// Check if user can leave the resource
  bool canUserLeave(String userId) {
    final permission = participants[userId];
    return permission != null && permission != ResourcePermission.owner;
  }

  /// Check if user is owner
  bool isOwner(String userId) => ownerId == userId;

  /// Check if user is participant
  bool isParticipant(String userId) => participants.containsKey(userId);

  /// Antal deltagare
  int get participantCount => participants.length;

  /// Number of editors (including owner)
  int get editorCount {
    return participants.values
        .where(
          (p) => ResourcePermissionHelper.canEditContent(
            p,
            ResourcePermission.editor,
          ),
        )
        .length;
  }

  /// Antal betraktare
  int get viewerCount {
    return participants.values
        .where((p) => p == ResourcePermission.viewer)
        .length;
  }

  /// List of all participants who can edit
  List<String> get editorIds {
    return participants.entries
        .where(
          (entry) => ResourcePermissionHelper.canEditContent(
            entry.value,
            ResourcePermission.editor,
          ),
        )
        .map((entry) => entry.key)
        .toList();
  }

  /// List of all participants with view-only access
  List<String> get viewerIds {
    return participants.entries
        .where((entry) => entry.value == ResourcePermission.viewer)
        .map((entry) => entry.key)
        .toList();
  }

  /// How long since the resource was edited
  Duration get timeSinceLastEdit => clock.now().difference(lastEditedAt);

  /// Text for "last edited"
  String get lastEditedTimeAgo {
    final l = AppLocale.current;
    final duration = timeSinceLastEdit;
    if (duration.inMinutes < 1) {
      return l.activityJustNow;
    } else if (duration.inHours < 1) {
      return l.activityMinutesAgo(duration.inMinutes);
    } else if (duration.inDays < 1) {
      return l.activityHoursAgo(duration.inHours);
    } else if (duration.inDays < 7) {
      return l.activityDaysAgo(duration.inDays);
    } else {
      return l.activityWeeksAgo((duration.inDays / 7).floor());
    }
  }

  /// Kontrollera om resursen har redigerats nyligen (senaste timmen)
  bool get hasRecentActivity => timeSinceLastEdit.inHours < 1;

  /// Check if the resource is active (edited within the last week)
  bool get hasWeeklyActivity => timeSinceLastEdit.inDays < 7;

  /// Check if the resource has changed since a specific point in time
  bool hasChangedSince(DateTime timestamp) {
    return lastEditedAt.isAfter(timestamp);
  }

  /// Get summary of recent changes for UI
  String getChangesSummary() {
    final l = AppLocale.current;
    if (editCount == 0) {
      return l.resourceCreatedBy(ownerDisplayName);
    } else {
      return l.resourceLastEditedBy(lastEditedByDisplayName, lastEditedTimeAgo);
    }
  }

  /// Get activity text for UI
  String get activityText {
    final l = AppLocale.current;
    if (hasRecentActivity) {
      return l.activityActiveNow;
    } else if (hasWeeklyActivity) {
      return l.activityActiveThisWeek;
    } else {
      return l.activityInactive;
    }
  }

  /// Get user's permission as text
  String? getUserPermissionText(String userId) {
    final l = AppLocale.current;
    final permission = participants[userId];
    if (permission == null) return null;
    if (permission == ResourcePermission.owner) {
      return l.permissionOwner;
    } else if (permission == ResourcePermission.admin) {
      return l.permissionAdmin;
    } else if (permission == ResourcePermission.editor) {
      return l.permissionEditor;
    } else if (permission == ResourcePermission.write) {
      return l.permissionWriter;
    } else if (permission == ResourcePermission.viewer) {
      return l.permissionViewer;
    } else if (permission == ResourcePermission.read) {
      return l.permissionReader;
    } else {
      return l.permissionUnknown;
    }
  }

  /// Subclasses must implement their own copyWith
  RealtimeResource copyWithMetadata({
    Map<String, ResourcePermission>? participants,
    List<String>? participantIds,
    DateTime? lastEditedAt,
    String? lastEditedBy,
    String? lastEditedByDisplayName,
    int? editCount,
    bool? isActive,
    Map<String, dynamic>? metadata,
  });

  /// Subclasses must implement serialization of their content
  Map<String, dynamic> serializeContent();

  /// Serialisera gemensam metadata till Firestore
  Map<String, dynamic> toFirestoreMetadata() {
    return {
      'type': type.value,
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'participants': participants.map(
        (userId, permission) => MapEntry(
          userId,
          ResourcePermissionHelper.permissionToString(permission),
        ),
      ),
      'participantIds': participantIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastEditedAt': Timestamp.fromDate(lastEditedAt),
      'lastEditedBy': lastEditedBy,
      'lastEditedByDisplayName': lastEditedByDisplayName,
      'editCount': editCount,
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  /// Komplett Firestore serialization (metadata + content)
  Map<String, dynamic> toFirestore() {
    final data = toFirestoreMetadata();
    data.addAll(serializeContent());
    return data;
  }

  /// Deserialize common metadata from Firestore
  static Map<String, dynamic> parseFirestoreMetadata(
    Map<String, dynamic> data,
    String documentId,
  ) {
    // Parse participants map
    final participantsData =
        data['participants'] as Map<String, dynamic>? ?? {};
    final participants = <String, ResourcePermission>{};
    for (final entry in participantsData.entries) {
      try {
        participants[entry.key] = ResourcePermissionHelper.fromString(
          entry.value as String,
        );
      } catch (e) {
        // Skip invalid permissions
        continue;
      }
    }

    // Parse participantIds with fallback to participants.keys for migration
    final participantIds = data.containsKey('participantIds')
        ? List<String>.from(data['participantIds'] as List? ?? [])
        : participants.keys.toList();

    return {
      'id': documentId,
      'type': RealtimeResourceType.fromString(
        SerializationUtils.safeString(data, 'type', defaultValue: 'recipe'),
      ),
      'ownerId': (data['ownerId'] as String?).orEmpty(),
      'ownerDisplayName': (data['ownerDisplayName'] as String?).orEmpty(),
      'participants': participants,
      'participantIds': participantIds,
      'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? clock.now(),
      'lastEditedAt':
          (data['lastEditedAt'] as Timestamp?)?.toDate() ?? clock.now(),
      'lastEditedBy': (data['lastEditedBy'] as String?).orEmpty(),
      'lastEditedByDisplayName': (data['lastEditedByDisplayName'] as String?)
          .orEmpty(),
      'editCount': SerializationUtils.safeInt(data, 'editCount'),
      'isActive': SerializationUtils.safeBool(
        data,
        'isActive',
        defaultValue: true,
      ),
      'metadata': Map<String, dynamic>.from(data['metadata'] ?? {}),
    };
  }

  /// JSON serialization for caching
  Map<String, dynamic> toJsonMetadata() {
    return {
      'id': id,
      'type': type.value,
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'participants': participants.map(
        (userId, permission) => MapEntry(
          userId,
          ResourcePermissionHelper.permissionToString(permission),
        ),
      ),
      'participantIds': participantIds,
      'createdAt': createdAt.toIso8601String(),
      'lastEditedAt': lastEditedAt.toIso8601String(),
      'lastEditedBy': lastEditedBy,
      'lastEditedByDisplayName': lastEditedByDisplayName,
      'editCount': editCount,
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  /// Add participant with specific permission
  RealtimeResource addParticipant(
    String userId,
    String userDisplayName,
    ResourcePermission permission,
  ) {
    final updatedParticipants = Map<String, ResourcePermission>.from(
      participants,
    );
    updatedParticipants[userId] = permission;

    // Keep participantIds in sync
    final updatedParticipantIds = List<String>.from(participantIds);
    if (!updatedParticipantIds.contains(userId)) {
      updatedParticipantIds.add(userId);
    }

    return copyWithMetadata(
      participants: updatedParticipants,
      participantIds: updatedParticipantIds,
      lastEditedAt: clock.now(),
      lastEditedBy: ownerId,
      lastEditedByDisplayName: ownerDisplayName,
      editCount: editCount + 1,
    );
  }

  /// Ta bort deltagare
  RealtimeResource removeParticipant(String userId) {
    if (userId == ownerId) {
      throw ArgumentError(AppLocale.current.errorCannotRemoveResourceOwner);
    }

    final updatedParticipants = Map<String, ResourcePermission>.from(
      participants,
    );
    updatedParticipants.remove(userId);

    // Keep participantIds in sync
    final updatedParticipantIds = List<String>.from(participantIds);
    updatedParticipantIds.remove(userId);

    return copyWithMetadata(
      participants: updatedParticipants,
      participantIds: updatedParticipantIds,
      lastEditedAt: clock.now(),
      lastEditedBy: ownerId,
      lastEditedByDisplayName: ownerDisplayName,
      editCount: editCount + 1,
    );
  }

  /// Update participant permission
  RealtimeResource updateParticipantPermission(
    String userId,
    ResourcePermission newPermission,
  ) {
    if (userId == ownerId && newPermission != ResourcePermission.owner) {
      throw ArgumentError(AppLocale.current.errorOwnerMustKeepPermission);
    }

    final updatedParticipants = Map<String, ResourcePermission>.from(
      participants,
    );
    updatedParticipants[userId] = newPermission;

    return copyWithMetadata(
      participants: updatedParticipants,
      lastEditedAt: clock.now(),
      lastEditedBy: ownerId,
      lastEditedByDisplayName: ownerDisplayName,
      editCount: editCount + 1,
    );
  }

  /// Mark as edited by specific user
  RealtimeResource markEditedBy(String userId, String userDisplayName) {
    return copyWithMetadata(
      lastEditedAt: clock.now(),
      lastEditedBy: userId,
      lastEditedByDisplayName: userDisplayName,
      editCount: editCount + 1,
    );
  }

  /// Arkivera resursen
  RealtimeResource archive() {
    return copyWithMetadata(
      isActive: false,
      lastEditedAt: clock.now(),
      editCount: editCount + 1,
    );
  }

  /// Reactivate the resource
  RealtimeResource reactivate() {
    return copyWithMetadata(
      isActive: true,
      lastEditedAt: clock.now(),
      editCount: editCount + 1,
    );
  }

  /// Filter participants based on permission
  Map<String, ResourcePermission> filterParticipantsByPermission(
    ResourcePermission permission,
  ) {
    return Map.fromEntries(
      participants.entries.where((entry) => entry.value == permission),
    );
  }

  /// Get all owners (should be just one, but for safety)
  Map<String, ResourcePermission> get owners {
    return filterParticipantsByPermission(ResourcePermission.owner);
  }

  /// Get all editors
  Map<String, ResourcePermission> get editors {
    return filterParticipantsByPermission(ResourcePermission.editor);
  }

  /// Get all viewers
  Map<String, ResourcePermission> get viewers {
    return filterParticipantsByPermission(ResourcePermission.viewer);
  }

  /// Check if the resource is empty (no one has edited it)
  bool get isEmpty => editCount == 0;

  /// Check if the resource has collaborators (more than the owner)
  bool get hasCollaborators => participantCount > 1;

  /// Get the number of active collaborators (excluding owner)
  int get collaboratorCount => participantCount - 1;

  @override
  String toString() {
    return '$runtimeType('
        'id: $id, '
        'type: $type, '
        'participants: $participantCount, '
        'lastEdit: $lastEditedTimeAgo'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RealtimeResource && other.id == id && other.type == type;
  }

  @override
  int get hashCode => Object.hash(id, type);
}
