// lib/models/realtime/realtime_menu_factory.dart

// TODO: Abstract Firebase DocumentSnapshot dependency to repository layer
import 'package:cloud_firestore/cloud_firestore.dart';
import '../recipe_unified.dart';
import '../permissions/resource_permission.dart';
import 'realtime_resource.dart';
import 'realtime_menu_data.dart';

/// Factory class for creating RealtimeMenu instances
///
/// Handles all complex construction logic to keep the main RealtimeMenu class focused.
/// Extracts creation patterns and reduces the main class size significantly.
class RealtimeMenuFactory {
  
  /// Factory to create new realtime menu from existing MenuViewModel structure
  static Map<String, dynamic> createFromMenuCategories({
    required String menuTitle,
    required Map<String, List<Recipe>> menuSnapshot,
    required String ownerId,
    required String ownerDisplayName,
    List<String>? editorUserIds,
    List<String>? viewerUserIds,
    String? menuNotes,
    List<String>? favoriteRecipeIds,
    String? originalPrompt,
    DateTime? createdForDate,
  }) {
    // Create participants map
    final participants = <String, ResourcePermission>{};

    // Owner gets owner permission
    participants[ownerId] = ResourcePermission.owner;

    // Add editors
    if (editorUserIds != null) {
      for (final userId in editorUserIds) {
        if (userId != ownerId) {
          participants[userId] = ResourcePermission.editor;
        }
      }
    }

    // Add viewers
    if (viewerUserIds != null) {
      for (final userId in viewerUserIds) {
        if (userId != ownerId && !participants.containsKey(userId)) {
          participants[userId] = ResourcePermission.viewer;
        }
      }
    }

    final data = RealtimeMenuData.fromMenuCategories(
      menuTitle: menuTitle,
      menuSnapshot: menuSnapshot,
      menuNotes: menuNotes,
      favoriteRecipeIds: favoriteRecipeIds,
      originalPrompt: originalPrompt,
      createdForDate: createdForDate,
    );

    return {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'participants': participants,
      'lastEditedBy': ownerId,
      'lastEditedByDisplayName': ownerDisplayName,
      'data': data,
    };
  }

  /// Extract metadata from Firestore document for RealtimeMenu creation
  static Map<String, dynamic> parseFirestoreData(DocumentSnapshot doc) {
    final documentData = doc.data() as Map<String, dynamic>;
    final metadataMap = RealtimeResource.parseFirestoreMetadata(documentData, doc.id);
    final data = RealtimeMenuData.fromFirestore(documentData);

    return {
      'id': metadataMap['id'] as String,
      'ownerId': metadataMap['ownerId'] as String,
      'ownerDisplayName': metadataMap['ownerDisplayName'] as String,
      'participants': metadataMap['participants'] as Map<String, ResourcePermission>,
      'createdAt': metadataMap['createdAt'] as DateTime,
      'lastEditedAt': metadataMap['lastEditedAt'] as DateTime,
      'lastEditedBy': metadataMap['lastEditedBy'] as String,
      'lastEditedByDisplayName': metadataMap['lastEditedByDisplayName'] as String,
      'editCount': metadataMap['editCount'] as int,
      'isActive': metadataMap['isActive'] as bool,
      'metadata': metadataMap['metadata'] as Map<String, dynamic>,
      'data': data,
    };
  }

  /// Parse JSON data for RealtimeMenu creation
  static Map<String, dynamic> parseJsonData(Map<String, dynamic> json) {
    // Parse participants
    final participantsData = json['participants'] as Map<String, dynamic>? ?? {};
    final participants = <String, ResourcePermission>{};

    for (final entry in participantsData.entries) {
      try {
        participants[entry.key] = ResourcePermissionHelper.fromString(
          entry.value as String,
        );
      } catch (e) {
        continue;
      }
    }

    final data = RealtimeMenuData.fromJson(json);

    return {
      'id': json['id'] as String,
      'ownerId': json['ownerId'] as String,
      'ownerDisplayName': json['ownerDisplayName'] as String,
      'participants': participants,
      'createdAt': DateTime.parse(json['createdAt'] as String),
      'lastEditedAt': DateTime.parse(json['lastEditedAt'] as String),
      'lastEditedBy': json['lastEditedBy'] as String,
      'lastEditedByDisplayName': json['lastEditedByDisplayName'] as String,
      'editCount': json['editCount'] as int? ?? 0,
      'isActive': json['isActive'] as bool? ?? true,
      'metadata': Map<String, dynamic>.from(json['metadata'] ?? {}),
      'data': data,
    };
  }

  /// Create RealtimeMenu from Firestore document
  static fromFirestore(DocumentSnapshot doc) {
    return parseFirestoreData(doc);
  }

  /// Create construction parameters for copying with updated data
  static Map<String, dynamic> createCopyParameters({
    required String id,
    required String ownerId,
    required String ownerDisplayName,
    required Map<String, ResourcePermission> participants,
    required DateTime createdAt,
    required DateTime lastEditedAt,
    required String lastEditedBy,
    required String lastEditedByDisplayName,
    required int editCount,
    required bool isActive,
    required Map<String, dynamic> metadata,
    required RealtimeMenuData data,
    DateTime? newLastEditedAt,
    String? newLastEditedBy,
    String? newLastEditedByDisplayName,
    int? newEditCount,
    bool? newIsActive,
    Map<String, dynamic>? newMetadata,
  }) {
    return {
      'id': id,
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'participants': participants,
      'createdAt': createdAt,
      'lastEditedAt': newLastEditedAt ?? DateTime.now(),
      'lastEditedBy': newLastEditedBy ?? lastEditedBy,
      'lastEditedByDisplayName': newLastEditedByDisplayName ?? lastEditedByDisplayName,
      'editCount': newEditCount ?? (editCount + 1),
      'isActive': newIsActive ?? isActive,
      'metadata': newMetadata ?? metadata,
      'data': data,
    };
  }
}