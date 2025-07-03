// lib/models/realtime/realtime_resource.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../permissions/resource_permission.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Realtime Resource Base Model - Grundklass för alla realtidsresurser
/// File: models/realtime/realtime_resource.dart
/// Quick Guide: Abstract base class som definierar gemensam realtidsmetadata - BARA data och business logic
/// Dependencies IN: ResourcePermission, cloud_firestore
/// Dependencies OUT: RealtimeRecipe, RealtimeMenu, RealtimeShoppingList, UI widgets
/// Data flow: Subclasses extend → Shared metadata handling → Firebase sync
/// State management: Immutable base class med common properties
/// Purpose: DRY principle - gemensam realtidslogik för alla resurser
/// Common issues: Säkerställ att subclasses implementerar alla required methods
/// Test coverage: 0% (ny komponent)
/// Performance: ⚡ Minimal overhead, shared efficient serialization
/// Analytics: Tracking av edit frequency och collaboration patterns
/// Code smells: ✅ Clean abstract base - single responsibility för metadata BARA
/// Connected to: Alla realtidsmodeller, RealtimeSyncService, PermissionService
/// Used in phases: Fas 1 (Grundinfrastruktur) - Foundation för all realtidsdata

/// Typ av realtidsresurs för serialization och routing
enum RealtimeResourceType {
  recipe('recipe'),
  menu('menu'),
  shoppingList('shopping_list');

  const RealtimeResourceType(this.value);

  /// Firestore-värde för denna typ
  final String value;

  /// Skapa från Firestore string value
  static RealtimeResourceType fromString(String value) {
    switch (value) {
      case 'recipe':
        return RealtimeResourceType.recipe;
      case 'menu':
        return RealtimeResourceType.menu;
      case 'shopping_list':
        return RealtimeResourceType.shoppingList;
      default:
        throw ArgumentError('Okänd RealtimeResourceType: $value');
    }
  }

  /// Få användarläsbar namn
  String get displayName {
    switch (this) {
      case RealtimeResourceType.recipe:
        return 'Recept';
      case RealtimeResourceType.menu:
        return 'Meny';
      case RealtimeResourceType.shoppingList:
        return 'Inköpslista';
    }
  }

  /// Få ikon för resurstyp
  String get icon {
    switch (this) {
      case RealtimeResourceType.recipe:
        return '🍳';
      case RealtimeResourceType.menu:
        return '📋';
      case RealtimeResourceType.shoppingList:
        return '🛒';
    }
  }

  @override
  String toString() => value;
}

/// Abstract base class för alla realtidsresurser
///
/// Denna klass innehåller BARA:
/// - Metadata för realtidsresurser
/// - Permission logic
/// - Serialization methods
/// - Utility methods för data manipulation
///
/// ❌ INNEHÅLLER INTE: UI widgets, styling, theme methods, Flutter imports
abstract class RealtimeResource {
  /// Unik identifierare för resursen
  final String id;

  /// Typ av resurs (recipe, menu, shopping)
  final RealtimeResourceType type;

  /// ID för användaren som äger resursen
  final String ownerId;

  /// Visningsnamn för ägaren (cached för performance)
  final String ownerDisplayName;

  /// Mapp över alla deltagare och deras behörigheter
  /// Key: userId, Value: ResourcePermission
  final Map<String, ResourcePermission> participants;

  /// När resursen skapades
  final DateTime createdAt;

  /// När resursen senast uppdaterades
  final DateTime lastEditedAt;

  /// Vem som gjorde senaste ändringen
  final String lastEditedBy;

  /// Visningsnamn för den som gjorde senaste ändringen (cached)
  final String lastEditedByDisplayName;

  /// Antal gånger resursen har redigerats
  final int editCount;

  /// Om resursen är aktiv eller arkiverad
  final bool isActive;

  /// Extra metadata för framtida utbyggnad
  final Map<String, dynamic> metadata;

  RealtimeResource({
    required this.id,
    required this.type,
    required this.ownerId,
    required this.ownerDisplayName,
    required this.participants,
    DateTime? createdAt,
    DateTime? lastEditedAt,
    required this.lastEditedBy,
    required this.lastEditedByDisplayName,
    this.editCount = 0,
    this.isActive = true,
    Map<String, dynamic>? metadata,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastEditedAt = lastEditedAt ?? DateTime.now(),
        metadata = metadata ?? {};

  // ===== PERMISSION HELPERS =====

  /// Kontrollera om en användare har en specifik behörighet
  bool hasPermission(String userId, ResourcePermission requiredPermission) {
    final userPermission = participants[userId];
    if (userPermission == null) return false;

    // Ägare har alltid full behörighet
    if (userPermission == ResourcePermission.owner) return true;

    // Kontrollera specifik behörighet
    switch (requiredPermission) {
      case ResourcePermission.viewer:
        return true; // Alla deltagare kan se
      case ResourcePermission.editor:
        return ResourcePermissionHelper.canEditContent(userPermission);
      case ResourcePermission.owner:
        return userPermission == ResourcePermission.owner;
    }
  }

  /// Kontrollera om användare kan redigera innehåll
  bool canUserEdit(String userId) {
    return hasPermission(userId, ResourcePermission.editor);
  }

  /// Kontrollera om användare kan ta bort resursen
  bool canUserDelete(String userId) {
    return participants[userId] == ResourcePermission.owner;
  }

  /// Kontrollera om användare kan hantera behörigheter
  bool canUserManagePermissions(String userId) {
    return participants[userId] == ResourcePermission.owner;
  }

  /// Kontrollera om användare kan bjuda in andra
  bool canUserInvite(String userId) {
    final permission = participants[userId];
    return permission != null &&
        ResourcePermissionHelper.canInviteParticipants(permission);
  }

  /// Kontrollera om användare kan lämna resursen
  bool canUserLeave(String userId) {
    final permission = participants[userId];
    return permission != null &&
        ResourcePermissionHelper.canLeaveResource(permission);
  }

  /// Kontrollera om användare är ägare
  bool isOwner(String userId) => ownerId == userId;

  /// Kontrollera om användare är deltagare
  bool isParticipant(String userId) => participants.containsKey(userId);

  // ===== STATISTICS =====

  /// Antal deltagare
  int get participantCount => participants.length;

  /// Antal redigerare (inklusive ägare)
  int get editorCount {
    return participants.values
        .where(ResourcePermissionHelper.canEditContent)
        .length;
  }

  /// Antal betraktare
  int get viewerCount {
    return participants.values
        .where((p) => p == ResourcePermission.viewer)
        .length;
  }

  /// Lista över alla deltagare som kan redigera
  List<String> get editorIds {
    return participants.entries
        .where((entry) => ResourcePermissionHelper.canEditContent(entry.value))
        .map((entry) => entry.key)
        .toList();
  }

  /// Lista över alla deltagare som bara kan se
  List<String> get viewerIds {
    return participants.entries
        .where((entry) => entry.value == ResourcePermission.viewer)
        .map((entry) => entry.key)
        .toList();
  }

  // ===== TIME HELPERS =====

  /// Hur länge sedan resursen redigerades
  Duration get timeSinceLastEdit => DateTime.now().difference(lastEditedAt);

  /// Text för "senast redigerad"
  String get lastEditedTimeAgo {
    final duration = timeSinceLastEdit;

    if (duration.inMinutes < 1) {
      return 'Just nu';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes} min sedan';
    } else if (duration.inDays < 1) {
      return '${duration.inHours} tim sedan';
    } else if (duration.inDays < 7) {
      return '${duration.inDays} dagar sedan';
    } else {
      return '${(duration.inDays / 7).floor()} veckor sedan';
    }
  }

  /// Kontrollera om resursen har redigerats nyligen (senaste timmen)
  bool get hasRecentActivity => timeSinceLastEdit.inHours < 1;

  /// Kontrollera om resursen är aktiv (redigerats senaste veckan)
  bool get hasWeeklyActivity => timeSinceLastEdit.inDays < 7;

  /// Kontrollera om resursen har ändrats sedan specifik tidpunkt
  bool hasChangedSince(DateTime timestamp) {
    return lastEditedAt.isAfter(timestamp);
  }

  /// Få sammanfattning av senaste ändringar för UI
  String getChangesSummary() {
    if (editCount == 0) {
      return 'Skapades av $ownerDisplayName';
    } else {
      return 'Senast redigerad av $lastEditedByDisplayName $lastEditedTimeAgo';
    }
  }

  /// Få aktivitetstext för UI
  String get activityText {
    if (hasRecentActivity) {
      return 'Aktiv nu';
    } else if (hasWeeklyActivity) {
      return 'Aktiv denna veckan';
    } else {
      return 'Inaktiv';
    }
  }

  /// Få användares permission som text
  String? getUserPermissionText(String userId) {
    final permission = participants[userId];
    if (permission == null) return null;

    switch (permission) {
      case ResourcePermission.owner:
        return 'Ägare';
      case ResourcePermission.editor:
        return 'Redigerare';
      case ResourcePermission.viewer:
        return 'Betraktare';
    }
  }

  // ===== ABSTRACT METHODS =====

  /// Subclasses måste implementera sin egen copyWith
  RealtimeResource copyWithMetadata({
    Map<String, ResourcePermission>? participants,
    DateTime? lastEditedAt,
    String? lastEditedBy,
    String? lastEditedByDisplayName,
    int? editCount,
    bool? isActive,
    Map<String, dynamic>? metadata,
  });

  /// Subclasses måste implementera serialization av sitt innehåll
  Map<String, dynamic> serializeContent();

  // ===== COMMON SERIALIZATION =====

  /// Serialisera gemensam metadata till Firestore
  Map<String, dynamic> toFirestoreMetadata() {
    return {
      'type': type.value,
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'participants': participants.map(
        (userId, permission) => MapEntry(
            userId, ResourcePermissionHelper.permissionToString(permission)),
      ),
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

  /// Deserialiserare gemensam metadata från Firestore
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

    return {
      'id': documentId,
      'type': RealtimeResourceType.fromString(
        data['type'] as String? ?? 'recipe',
      ),
      'ownerId': data['ownerId'] as String? ?? '',
      'ownerDisplayName': data['ownerDisplayName'] as String? ?? '',
      'participants': participants,
      'createdAt':
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      'lastEditedAt':
          (data['lastEditedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      'lastEditedBy': data['lastEditedBy'] as String? ?? '',
      'lastEditedByDisplayName':
          data['lastEditedByDisplayName'] as String? ?? '',
      'editCount': data['editCount'] as int? ?? 0,
      'isActive': data['isActive'] as bool? ?? true,
      'metadata': Map<String, dynamic>.from(data['metadata'] ?? {}),
    };
  }

  // ===== JSON SERIALIZATION =====

  /// JSON serialization för caching
  Map<String, dynamic> toJsonMetadata() {
    return {
      'id': id,
      'type': type.value,
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'participants': participants.map(
        (userId, permission) => MapEntry(
            userId, ResourcePermissionHelper.permissionToString(permission)),
      ),
      'createdAt': createdAt.toIso8601String(),
      'lastEditedAt': lastEditedAt.toIso8601String(),
      'lastEditedBy': lastEditedBy,
      'lastEditedByDisplayName': lastEditedByDisplayName,
      'editCount': editCount,
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  // ===== UTILITY METHODS =====

  /// Lägg till deltagare med specifik behörighet
  RealtimeResource addParticipant(
    String userId,
    String userDisplayName,
    ResourcePermission permission,
  ) {
    final updatedParticipants =
        Map<String, ResourcePermission>.from(participants);
    updatedParticipants[userId] = permission;

    return copyWithMetadata(
      participants: updatedParticipants,
      lastEditedAt: DateTime.now(),
      lastEditedBy: ownerId, // Owner adds participants
      lastEditedByDisplayName: ownerDisplayName,
      editCount: editCount + 1,
    );
  }

  /// Ta bort deltagare
  RealtimeResource removeParticipant(String userId) {
    if (userId == ownerId) {
      throw ArgumentError('Kan inte ta bort ägaren från resursen');
    }

    final updatedParticipants =
        Map<String, ResourcePermission>.from(participants);
    updatedParticipants.remove(userId);

    return copyWithMetadata(
      participants: updatedParticipants,
      lastEditedAt: DateTime.now(),
      lastEditedBy: ownerId,
      lastEditedByDisplayName: ownerDisplayName,
      editCount: editCount + 1,
    );
  }

  /// Uppdatera deltagares behörighet
  RealtimeResource updateParticipantPermission(
    String userId,
    ResourcePermission newPermission,
  ) {
    if (userId == ownerId && newPermission != ResourcePermission.owner) {
      throw ArgumentError('Ägaren måste behålla owner-behörighet');
    }

    final updatedParticipants =
        Map<String, ResourcePermission>.from(participants);
    updatedParticipants[userId] = newPermission;

    return copyWithMetadata(
      participants: updatedParticipants,
      lastEditedAt: DateTime.now(),
      lastEditedBy: ownerId,
      lastEditedByDisplayName: ownerDisplayName,
      editCount: editCount + 1,
    );
  }

  /// Markera som redigerad av specifik användare
  RealtimeResource markEditedBy(String userId, String userDisplayName) {
    return copyWithMetadata(
      lastEditedAt: DateTime.now(),
      lastEditedBy: userId,
      lastEditedByDisplayName: userDisplayName,
      editCount: editCount + 1,
    );
  }

  /// Arkivera resursen
  RealtimeResource archive() {
    return copyWithMetadata(
      isActive: false,
      lastEditedAt: DateTime.now(),
      editCount: editCount + 1,
    );
  }

  /// Återaktivera resursen
  RealtimeResource reactivate() {
    return copyWithMetadata(
      isActive: true,
      lastEditedAt: DateTime.now(),
      editCount: editCount + 1,
    );
  }

  /// Filtrera deltagare baserat på permission
  Map<String, ResourcePermission> filterParticipantsByPermission(
    ResourcePermission permission,
  ) {
    return Map.fromEntries(
      participants.entries.where((entry) => entry.value == permission),
    );
  }

  /// Få alla ägare (borde bara vara en, men för säkerhet)
  Map<String, ResourcePermission> get owners {
    return filterParticipantsByPermission(ResourcePermission.owner);
  }

  /// Få alla redigerare
  Map<String, ResourcePermission> get editors {
    return filterParticipantsByPermission(ResourcePermission.editor);
  }

  /// Få alla betraktare
  Map<String, ResourcePermission> get viewers {
    return filterParticipantsByPermission(ResourcePermission.viewer);
  }

  /// Kontrollera om resursen är tom (ingen har redigerat den)
  bool get isEmpty => editCount == 0;

  /// Kontrollera om resursen har collaborators (fler än ägaren)
  bool get hasCollaborators => participantCount > 1;

  /// Få antalet aktiva collaborators (exclude owner)
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
