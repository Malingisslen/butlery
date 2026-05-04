/// Comprehensive realtime menu factory providing centralized construction logic and specialized parsing for collaborative meal planning.

// lib/models/realtime/realtime_menu_factory.dart

// ✅ Firebase DocumentSnapshot dependency abstracted to repository layer
// Note: Repositories handle Firebase-specific parsing and provide clean data maps

import 'package:clock/clock.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:uuid/uuid.dart';

/// Comprehensive realtime menu factory with centralized construction logic and specialized parsing for collaborative meal planning.
/// Provides complete construction infrastructure for realtime menu instantiation including participant management,
/// data parsing, and parameter organization through focused factory patterns and robust error handling.
/// This class serves as the construction coordination layer for all realtime menu creation scenarios.
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
    final id = const Uuid().v4();
    final now = clock.now();

    // Build participants map
    final participants = <String, ResourcePermission>{
      ownerId: ResourcePermission.owner,
    };

    // Add editors
    if (editorUserIds != null) {
      for (final userId in editorUserIds) {
        participants[userId] = ResourcePermission.editor;
      }
    }

    // Add viewers
    if (viewerUserIds != null) {
      for (final userId in viewerUserIds) {
        participants[userId] = ResourcePermission.viewer;
      }
    }

    // Create menu data
    final data = RealtimeMenuData.fromMenuCategories(
      menuTitle: menuTitle,
      menuSnapshot: menuSnapshot,
      menuNotes: menuNotes,
      favoriteRecipeIds: favoriteRecipeIds,
      originalPrompt: originalPrompt,
      createdForDate: createdForDate ?? now,
    );

    return {
      'id': id,
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'participants': participants,
      'lastEditedBy': ownerId,
      'lastEditedByDisplayName': ownerDisplayName,
      'data': data,
    };
  }

  /// Parse repository document data to construction parameters
  /// @deprecated Use parseJsonData instead. This method will be removed when repositories are updated.
  /// Repositories should provide clean DateTime objects and Map data.
  static Map<String, dynamic> parseRepositoryData(
      String id, Map<String, dynamic> data) {
    // Parse participants
    final participantsData =
        data['participants'] as Map<String, dynamic>? ?? {};
    final participants = <String, ResourcePermission>{};

    for (final entry in participantsData.entries) {
      final permission = ResourcePermission.values.firstWhere(
        (p) => p.name == entry.value,
        orElse: () => ResourcePermission.viewer,
      );
      participants[entry.key] = permission;
    }

    // Parse menu data - repositories should provide clean data
    final menuData = RealtimeMenuData.fromFirestore(data);

    return {
      'id': id,
      'ownerId': SerializationUtils.safeString(data, 'ownerId'),
      'ownerDisplayName':
          SerializationUtils.safeString(data, 'ownerDisplayName'),
      'participants': participants,
      'createdAt':
          data['createdAt'] as DateTime, // Repository provides DateTime
      'lastEditedAt':
          data['lastEditedAt'] as DateTime, // Repository provides DateTime
      'lastEditedBy': SerializationUtils.safeString(data, 'lastEditedBy'),
      'lastEditedByDisplayName':
          SerializationUtils.safeString(data, 'lastEditedByDisplayName'),
      'editCount': SerializationUtils.safeInt(data, 'editCount'),
      'isActive':
          SerializationUtils.safeBool(data, 'isActive', defaultValue: true),
      'metadata': SerializationUtils.safeMap(data, 'metadata'),
      'data': menuData,
    };
  }

  /// Parse JSON data to construction parameters
  static Map<String, dynamic> parseJsonData(Map<String, dynamic> json) {
    // Parse participants
    final participantsData =
        json['participants'] as Map<String, dynamic>? ?? {};
    final participants = <String, ResourcePermission>{};

    for (final entry in participantsData.entries) {
      final permission = ResourcePermission.values.firstWhere(
        (p) => p.name == entry.value,
        orElse: () => ResourcePermission.viewer,
      );
      participants[entry.key] = permission;
    }

    // Parse menu data
    final menuData = RealtimeMenuData.fromJson(json);

    return {
      'id': SerializationUtils.safeString(json, 'id'),
      'ownerId': SerializationUtils.safeString(json, 'ownerId'),
      'ownerDisplayName':
          SerializationUtils.safeString(json, 'ownerDisplayName'),
      'participants': participants,
      'createdAt': SerializationUtils.safeRequiredDateTime(json, 'createdAt'),
      'lastEditedAt':
          SerializationUtils.safeRequiredDateTime(json, 'lastEditedAt'),
      'lastEditedBy': SerializationUtils.safeString(json, 'lastEditedBy'),
      'lastEditedByDisplayName':
          SerializationUtils.safeString(json, 'lastEditedByDisplayName'),
      'editCount': SerializationUtils.safeInt(json, 'editCount'),
      'isActive':
          SerializationUtils.safeBool(json, 'isActive', defaultValue: true),
      'metadata': SerializationUtils.safeMap(json, 'metadata'),
      'data': menuData,
    };
  }

  /// Create copy construction parameters for updates
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
    required String newLastEditedBy,
    required String newLastEditedByDisplayName,
  }) {
    return {
      'id': id,
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'participants': participants,
      'createdAt': createdAt,
      'lastEditedAt': clock.now(),
      'lastEditedBy': newLastEditedBy,
      'lastEditedByDisplayName': newLastEditedByDisplayName,
      'editCount': editCount + 1,
      'isActive': isActive,
      'metadata': metadata,
      'data': data,
    };
  }
}
