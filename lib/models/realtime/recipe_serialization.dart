// lib/models/realtime/recipe_serialization.dart

// ✅ Firebase DocumentSnapshot dependency abstracted to repository layer
// Note: Repositories handle Firebase-specific parsing and provide clean data maps
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';

/// Focused module for recipe serialization/deserialization
/// 
/// This module handles ONLY Firestore conversion:
/// - Recipe to Firestore serialization
/// - Firestore to Recipe deserialization
/// - Data validation and sanitization
/// - Type conversion and safety
/// 
/// ❌ DOES NOT CONTAIN: Business logic, metadata management, operations
class RecipeSerialization {
  
  // ===== SERIALIZATION =====

  /// Serialize recipe to Firestore format
  static Map<String, dynamic> serializeRecipe(Recipe recipe) {
    return recipe.toFirestore();
  }

  /// Serialize complete realtime recipe content
  static Map<String, dynamic> serializeRealtimeContent(Recipe recipe) {
    return {
      'recipe': serializeRecipe(recipe),
      'activeEditors': [], // Initialize as empty array for realtime collaboration tracking
    };
  }

  /// Serialize recipe with metadata for storage (repository-agnostic)
  /// 
  /// Returns clean data map without Firebase-specific types.
  /// Repositories handle conversion to their specific format (Firestore, etc.)
  static Map<String, dynamic> serializeWithMetadata({
    required Recipe recipe,
    required String id,
    required String ownerId,
    required String ownerDisplayName,
    required Map<String, ResourcePermission> participants,
    DateTime? createdAt,
    DateTime? lastEditedAt,
    required String lastEditedBy,
    required String lastEditedByDisplayName,
    int editCount = 0,
    bool isActive = true,
    Map<String, dynamic>? metadata,
  }) {
    // Create clean serialization without Firebase dependencies
    final result = <String, dynamic>{};
    
    // Add metadata with DateTime objects (repositories handle conversion)
    result.addAll({
      'type': RealtimeResourceType.recipe.value,
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'participants': participants.map(
        (userId, permission) => MapEntry(
            userId, ResourcePermissionHelper.permissionToString(permission)),
      ),
      'createdAt': createdAt ?? DateTime.now(),
      'lastEditedAt': lastEditedAt ?? DateTime.now(),
      'lastEditedBy': lastEditedBy,
      'lastEditedByDisplayName': lastEditedByDisplayName,
      'editCount': editCount,
      'isActive': isActive,
      'metadata': metadata ?? {},
    });
    
    // Add recipe content
    result.addAll(serializeRealtimeContent(recipe));
    
    return result;
  }

  // ===== DESERIALIZATION =====

  /// Deserialize recipe from Firestore data
  static Recipe deserializeRecipe(Map<String, dynamic> recipeData, String fallbackId) {
    // Handle both nested core structure and flat structure
    final coreData = recipeData['core'] as Map<String, dynamic>? ?? recipeData;
    
    return Recipe(
      core: RecipeCore(
        id: coreData['id'] as String? ?? fallbackId,
        title: coreData['title'] as String? ?? '',
        description: coreData['description'] as String? ?? '',
        portions: coreData['portions'] as int?,
        timeMinutes: coreData['timeMinutes'] as int?,
        ingredients: List<String>.from(coreData['ingredients'] ?? []),
        instructions: List<String>.from(coreData['instructions'] ?? []),
        tags: coreData['tags'] != null
            ? List<String>.from(coreData['tags'])
            : null,
        rating: (coreData['rating'] as num?)?.toDouble(),
        imageUrls: List<String>.from(coreData['imageUrls'] ?? []),
        mealType: coreData['mealType'] as String? ?? 'Middag',
        sourceUrl: coreData['sourceUrl'] as String?,
        createdAt: _parseTimestamp(coreData['createdAt']) ?? DateTime.now(),
        updatedAt: _parseTimestamp(coreData['updatedAt']) ?? DateTime.now(),
        createdBy: coreData['createdBy'] as String?,
        isPublic: coreData['isPublic'] as bool? ?? false,
        lastCookedAt: _parseTimestamp(coreData['lastCookedAt']),
      ),
      type: RecipeType.realtime,
      socialData: _deserializeSocialData(recipeData),
    );
  }

  /// Deserialize complete realtime recipe from repository data
  /// 
  /// @deprecated Repositories should use fromData() constructors instead.
  /// This maintains backward compatibility during repository updates.
  static (Recipe recipe, Map<String, dynamic> metadata) deserializeRealtimeRecipe(
    String id, Map<String, dynamic> data
  ) {
    // Parse recipe data
    final recipeData = data['recipe'] as Map<String, dynamic>? ?? {};
    final recipe = deserializeRecipe(recipeData, id);

    // Extract metadata without Firebase-specific parsing
    final metadataMap = {
      'id': id,
      'ownerId': data['ownerId'] as String,
      'ownerDisplayName': data['ownerDisplayName'] as String,
      'participants': data['participants'] as Map<String, dynamic>? ?? {},
      'createdAt': data['createdAt'], // Repository provides DateTime
      'lastEditedAt': data['lastEditedAt'], // Repository provides DateTime
      'lastEditedBy': data['lastEditedBy'] as String,
      'lastEditedByDisplayName': data['lastEditedByDisplayName'] as String,
      'editCount': data['editCount'] as int? ?? 0,
      'isActive': data['isActive'] as bool? ?? true,
      'metadata': data['metadata'] as Map<String, dynamic>? ?? {},
    };

    return (recipe, metadataMap);
  }

  // ===== DATA VALIDATION =====

  /// Validate recipe data structure
  static bool isValidRecipeData(Map<String, dynamic> data) {
    // Check required fields
    if (data['title'] == null || data['title'].toString().isEmpty) {
      return false;
    }

    // Validate lists
    final ingredients = data['ingredients'];
    if (ingredients != null && ingredients is! List) {
      return false;
    }

    final instructions = data['instructions'];
    if (instructions != null && instructions is! List) {
      return false;
    }

    final imageUrls = data['imageUrls'];
    if (imageUrls != null && imageUrls is! List) {
      return false;
    }

    // Validate numeric fields
    final portions = data['portions'];
    if (portions != null && portions is! int) {
      return false;
    }

    final timeMinutes = data['timeMinutes'];
    if (timeMinutes != null && timeMinutes is! int) {
      return false;
    }

    final rating = data['rating'];
    if (rating != null && rating is! num) {
      return false;
    }

    return true;
  }

  /// Sanitize recipe data
  static Map<String, dynamic> sanitizeRecipeData(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};

    // Required fields with defaults
    sanitized['title'] = data['title']?.toString() ?? '';
    sanitized['description'] = data['description']?.toString() ?? '';
    sanitized['mealType'] = data['mealType']?.toString() ?? 'Middag';

    // List fields
    sanitized['ingredients'] = _sanitizeStringList(data['ingredients']);
    sanitized['instructions'] = _sanitizeStringList(data['instructions']);
    sanitized['imageUrls'] = _sanitizeStringList(data['imageUrls']);
    sanitized['tags'] = data['tags'] != null ? _sanitizeStringList(data['tags']) : null;

    // Numeric fields
    sanitized['portions'] = _sanitizeInt(data['portions']);
    sanitized['timeMinutes'] = _sanitizeInt(data['timeMinutes']);
    sanitized['rating'] = _sanitizeDouble(data['rating']);

    // Timestamp fields
    sanitized['createdAt'] = _parseTimestamp(data['createdAt']) ?? DateTime.now();
    sanitized['updatedAt'] = _parseTimestamp(data['updatedAt']) ?? DateTime.now();
    sanitized['lastCookedAt'] = _parseTimestamp(data['lastCookedAt']);

    // String fields
    sanitized['sourceUrl'] = data['sourceUrl']?.toString();
    sanitized['createdBy'] = data['createdBy']?.toString();
    sanitized['lastEditedByUserId'] = data['lastEditedByUserId']?.toString();
    sanitized['lastEditedByDisplayName'] = data['lastEditedByDisplayName']?.toString();

    // Boolean fields
    sanitized['isPublic'] = data['isPublic'] as bool? ?? false;

    // Preserve additional fields
    for (final entry in data.entries) {
      if (!sanitized.containsKey(entry.key)) {
        sanitized[entry.key] = entry.value;
      }
    }

    return sanitized;
  }

  // ===== HELPER METHODS =====

  /// Parse timestamp from various formats (repository-agnostic)
  /// 
  /// Repositories should provide DateTime objects, but this handles legacy formats.
  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    
    if (timestamp is DateTime) {
      return timestamp;
    }
    
    if (timestamp is String) {
      return DateTime.tryParse(timestamp);
    }
    
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    
    // Note: Firebase Timestamp handling moved to repository layer
    return null;
  }

  /// Sanitize list of strings
  static List<String> _sanitizeStringList(dynamic list) {
    if (list == null) return [];
    if (list is! List) return [];
    
    return list.map((item) => item?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }

  /// Sanitize integer value
  static int? _sanitizeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Sanitize double value
  static double? _sanitizeDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Parse social data from recipe data
  static RecipeSocialData? _deserializeSocialData(Map<String, dynamic> data) {
    // Check if social data exists
    final socialData = data['socialData'] as Map<String, dynamic>?;
    if (socialData == null) return null;

    return RecipeSocialData(
      ownerId: socialData['ownerId'] as String?,
      ownerDisplayName: socialData['ownerDisplayName'] as String?,
      memberPermissions: _parsePermissions(socialData['memberPermissions']),
      allowGuestViewing: socialData['allowGuestViewing'] as bool? ?? false,
      allowMemberInvites: socialData['allowMemberInvites'] as bool? ?? true,
      categoryIds: _sanitizeStringList(socialData['categoryIds']),
      descriptionCollaborative: socialData['description'] as String?,
    );
  }

  /// Parse permissions map
  static Map<String, ResourcePermission>? _parsePermissions(dynamic permissions) {
    if (permissions == null) return null;
    if (permissions is! Map) return null;

    final result = <String, ResourcePermission>{};
    for (final entry in permissions.entries) {
      final permission = ResourcePermission.values.firstWhere(
        (p) => p.name == entry.value.toString(),
        orElse: () => ResourcePermission.viewer,
      );
      result[entry.key.toString()] = permission;
    }
    
    return result;
  }

  // ===== BATCH OPERATIONS =====

  /// Serialize multiple recipes for batch operations
  static List<Map<String, dynamic>> serializeRecipeBatch(List<Recipe> recipes) {
    return recipes.map(serializeRecipe).toList();
  }

  /// Deserialize multiple recipes from batch data
  static List<Recipe> deserializeRecipeBatch(List<Map<String, dynamic>> recipesData) {
    return recipesData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      return deserializeRecipe(data, 'recipe_$index');
    }).toList();
  }

  /// Validate batch recipe data
  static List<String> validateRecipeBatch(List<Map<String, dynamic>> recipesData) {
    final errors = <String>[];
    
    for (int i = 0; i < recipesData.length; i++) {
      if (!isValidRecipeData(recipesData[i])) {
        errors.add('Recipe at index $i has invalid data structure');
      }
    }
    
    return errors;
  }
}