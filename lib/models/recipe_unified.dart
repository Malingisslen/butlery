/// Unified recipe data model with multi-type support and modular architecture.

// lib/models/recipe_unified.dart

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/mixins/json_serializable_mixin.dart';
import 'package:butlery/core/utils/serialization_utils.dart' as utils;
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/tagging/recipe_personal_tag.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tag_result.dart';

// Focused modules
import 'package:butlery/models/recipe/recipe_operations.dart';
import 'package:butlery/models/recipe/recipe_factory.dart';
import 'package:butlery/models/recipe/recipe_serialization.dart';

/// Enumeration defining the different types of recipes and their behavior.
/// Recipe types determine the sharing model, editing permissions, and
/// collaboration features available for a recipe:
/// - [personal] - Private recipe owned by a single user
/// - [shared] - Recipe shared with others in read-only mode
/// - [collaborative] - Recipe that can be edited by multiple users
/// - [realtime] - Recipe with live collaborative editing capabilities
enum RecipeType {
  /// Private recipe accessible only to the owner.
  /// Personal recipes are stored in the user's private collection and
  /// cannot be accessed by other users unless explicitly shared.
  personal,

  /// Recipe shared with others in read-only mode.
  /// Shared recipes allow other users to view and copy the recipe
  /// but not modify the original. The owner retains full control.
  shared,

  /// Recipe that can be collaboratively edited by multiple users.
  /// Collaborative recipes allow designated users to modify the recipe
  /// content with proper conflict resolution and change tracking.
  collaborative,

  /// Recipe with real-time collaborative editing capabilities.
  /// Realtime recipes support simultaneous editing by multiple users
  /// with live updates, operational transforms, and presence indicators.
  realtime
}

/// Status of recipe data integrity verification.
/// Used to track checksum validation results without persisting to Firestore.
/// Option A: Track silently for analytics, no user-facing UI.
enum DataIntegrityStatus {
  /// Integrity not verified (legacy recipe without checksum).
  unverified,

  /// Checksum matches computed value.
  valid,

  /// Checksum mismatch detected - possible data corruption.
  invalid,
}

/// Core recipe data model containing common recipe information.
/// This class represents the fundamental recipe data that is shared across
/// all recipe types in the unified recipe system. It includes all the basic
/// recipe information such as title, ingredients, instructions, and metadata.
/// The class is serializable for both local storage (Drift SQLite) and network
/// transmission (JSON), enabling efficient caching and synchronization.
/// Key features:
/// - Immutable ID for unique identification
/// - Mutable content fields for editing
/// - Timestamp tracking for audit and sync
/// - Permission and sharing metadata
/// - Image and media URL storage
/// - Cooking history and analytics data
/// Usage example:
/// ```dart
/// final recipe = RecipeCore(
///   title: 'Pasta Carbonara',
///   description: 'Classic Italian pasta dish',
///   ingredients: ['pasta', 'eggs', 'bacon'],
///   instructions: ['Boil pasta', 'Cook bacon', 'Mix with eggs'],
///   portions: 4,
///   timeMinutes: 30,
/// );
/// ```
class RecipeCore with JsonSerializableMixin {
  /// Unique identifier for this recipe.
  /// This ID is immutable and generated once when the recipe is created.
  /// It's used for database references, sharing, and cache management.
  final String id;

  /// The display name of the recipe.
  /// This is the primary user-visible identifier for the recipe,
  /// shown in lists, search results, and detail views.
  String title;

  /// Detailed description of the recipe.
  /// Provides additional context, cooking tips, origin story,
  /// or other descriptive information about the recipe.
  String description;

  /// Number of servings this recipe produces.
  /// Used for scaling ingredients and nutritional calculations.
  /// Can be null if portion size is not specified.
  int? portions;

  /// Total cooking and preparation time in minutes.
  /// Includes active cooking time and any waiting/resting periods.
  /// Used for meal planning and filtering by available time.
  int? timeMinutes;

  /// List of ingredients required for this recipe.
  /// Each string represents one ingredient with quantity and preparation
  /// instructions (e.g., "2 cups flour, sifted", "1 large onion, diced").
  /// Order typically reflects the sequence of use in cooking.
  List<String> ingredients;

  /// Step-by-step cooking instructions.
  /// Each string represents one cooking step, ordered from first to last.
  /// Instructions should be clear and actionable for the home cook.
  List<String> instructions;

  /// User-created personal tags for custom categorization.
  /// Stores tag UUIDs for efficient Firestore arrayContains queries.
  /// Display names available via [personalTags] rich objects.
  List<String>? personalTagIds;

  /// Rich personal tag data with source tracking.
  /// Stores full [RecipePersonalTag] objects (tagId, name, sources).
  /// Used for display and source tracking. Dual-written alongside personalTagIds.
  List<RecipePersonalTag>? personalTags;

  /// User rating for this recipe (0.0 to 5.0).
  /// Represents the average user rating or personal rating depending
  /// on the recipe type. Used for sorting and recommendation algorithms.
  double? rating;

  String mealType;

  String? sourceUrl;

  List<String> imageUrls;

  final DateTime createdAt;

  DateTime updatedAt;

  String? createdBy;

  bool isPublic;

  DateTime? lastCookedAt;

  /// Normalized ingredient names for search and tagging.
  /// MODUL1 Enhancement: Stores normalized versions of ingredients
  /// with preparation words removed and plural forms normalized.
  /// Used for improved search, filtering, and shopping list grouping.
  /// Examples:
  /// - "2 dl hackad lök" → "lök"
  /// - "3 st stora ägg" → "ägg"
  /// - "glutenfri pasta" → "glutenfri pasta" (diet descriptors preserved)
  /// Optional field for backward compatibility. Null for recipes created
  /// before MODUL1 integration.
  List<String>? ingredientsNormalized;

  /// Total number of ratings this recipe has received.
  /// Denormalized aggregate maintained by Cloud Function on rating changes.
  /// Used for sorting by popularity and displaying rating counts in UI.
  /// Null for recipes without any ratings.
  int? ratingCount;

  /// Average rating value (1.0-5.0).
  /// Denormalized aggregate calculated from all ratings by Cloud Function.
  /// Provides instant access to recipe rating without querying all rating documents.
  /// Null for recipes without any ratings.
  double? averageRating;

  /// Distribution of ratings across star levels.
  /// Map structure: {1: count, 2: count, 3: count, 4: count, 5: count}
  /// Example: {1: 2, 2: 5, 3: 18, 4: 45, 5: 86} = 156 total ratings
  /// Denormalized for instant rating histogram display.
  /// Null for recipes without any ratings.
  Map<int, int>? ratingDistribution;

  /// Timestamp of the most recent rating.
  /// Used for cache freshness detection and sorting by recently rated.
  /// Updated by Cloud Function on every rating change.
  /// Null for recipes that have never been rated.
  DateTime? lastRatedAt;

  /// SHA256 checksum of critical recipe fields for data integrity verification.
  /// Computed from: id, title, ingredients (joined), instructions (joined).
  /// Used to detect data corruption during storage/transmission.
  /// Null for recipes created before checksum feature was added.
  String? dataChecksum;

  /// Automatically generated tags with allergen and dietary status.
  /// Generated by TaggingService when recipe is saved.
  /// Contains tags, allergenStatus (tri-valued), dietaryStatus, coverage.
  /// Null for recipes created before tagging system was added.
  TagResult? tagResult;

  /// User-applied overrides to auto-generated tag results.
  /// Allows users to correct allergen/dietary status when they know better.
  /// Overrides persist across retagging operations to preserve user intent.
  /// Null for recipes that have never been manually edited.
  TagOverrides? tagOverrides;

  /// Version of the personal tag rules when tags were last evaluated.
  /// Stored as epoch milliseconds of the latest tag `updatedAt`.
  /// If any tag's `updatedAt` is newer than this, the recipe is stale.
  /// Null for recipes that haven't been evaluated by the rule engine.
  int? personalTagVersion;

  /// Whether this recipe is marked as a favorite by the user.
  /// Simple boolean flag for quick filtering in recipe list.
  bool isFavorite;

  /// In-memory status of data integrity verification.
  /// Set during deserialization based on checksum validation.
  /// Not persisted to Firestore - tracked silently for analytics.
  DataIntegrityStatus dataIntegrityStatus;

  /// Compute SHA256 checksum from critical recipe fields.
  /// Critical fields: id, title, ingredients, instructions.
  /// These fields define the recipe's core content and any corruption
  /// would fundamentally alter what the recipe is.
  static String computeChecksum({
    required String id,
    required String title,
    required List<String> ingredients,
    required List<String> instructions,
  }) {
    final data =
        '$id|$title|${ingredients.join('|')}|${instructions.join('|')}';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify data integrity by comparing stored checksum with computed one.
  /// Returns true if checksum matches or if no checksum exists (legacy data).
  bool verifyIntegrity() {
    if (dataChecksum == null) return true; // Legacy data without checksum
    final computed = computeChecksum(
      id: id,
      title: title,
      ingredients: ingredients,
      instructions: instructions,
    );
    return computed == dataChecksum;
  }

  /// Compute and update the checksum for this recipe.
  void updateChecksum() {
    dataChecksum = computeChecksum(
      id: id,
      title: title,
      ingredients: ingredients,
      instructions: instructions,
    );
  }

  RecipeCore({
    String? id,
    required this.title,
    required this.description,
    this.portions,
    this.timeMinutes,
    required this.ingredients,
    required this.instructions,
    this.personalTagIds,
    this.personalTags,
    this.rating,
    required this.mealType,
    this.sourceUrl,
    List<String>? imageUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy,
    this.isPublic = false,
    this.lastCookedAt,
    this.ingredientsNormalized,
    this.ratingCount,
    this.averageRating,
    this.ratingDistribution,
    this.lastRatedAt,
    this.dataChecksum,
    this.tagResult,
    this.tagOverrides,
    this.personalTagVersion,
    this.isFavorite = false,
    this.dataIntegrityStatus = DataIntegrityStatus.unverified,
  })  : id = id ?? const Uuid().v4(),
        imageUrls = imageUrls ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create copy with updated values
  /// Note: If critical fields (title, ingredients, instructions) change,
  /// the checksum is automatically recomputed.
  RecipeCore copyWith({
    String? title,
    String? description,
    int? portions,
    int? timeMinutes,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? personalTagIds,
    List<RecipePersonalTag>? personalTags,
    double? rating,
    String? mealType,
    String? sourceUrl,
    List<String>? imageUrls,
    DateTime? updatedAt,
    String? createdBy,
    bool? isPublic,
    DateTime? lastCookedAt,
    List<String>? ingredientsNormalized,
    int? ratingCount,
    double? averageRating,
    Map<int, int>? ratingDistribution,
    DateTime? lastRatedAt,
    String? dataChecksum,
    TagResult? tagResult,
    TagOverrides? tagOverrides,
    int? personalTagVersion,
    bool? isFavorite,
    DataIntegrityStatus? dataIntegrityStatus,
  }) {
    final newTitle = title ?? this.title;
    final newIngredients = ingredients ?? this.ingredients;
    final newInstructions = instructions ?? this.instructions;

    // Recompute checksum if critical fields changed
    final needsChecksumUpdate =
        title != null || ingredients != null || instructions != null;
    final newChecksum = needsChecksumUpdate
        ? computeChecksum(
            id: id,
            title: newTitle,
            ingredients: newIngredients,
            instructions: newInstructions,
          )
        : (dataChecksum ?? this.dataChecksum);

    // Set status to valid when checksum is recomputed
    final newIntegrityStatus = needsChecksumUpdate
        ? DataIntegrityStatus.valid
        : (dataIntegrityStatus ?? this.dataIntegrityStatus);

    return RecipeCore(
      id: id,
      title: newTitle,
      description: description ?? this.description,
      portions: portions ?? this.portions,
      timeMinutes: timeMinutes ?? this.timeMinutes,
      ingredients: newIngredients,
      instructions: newInstructions,
      personalTagIds: personalTagIds ?? this.personalTagIds,
      personalTags: personalTags ?? this.personalTags,
      rating: rating ?? this.rating,
      mealType: mealType ?? this.mealType,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      createdBy: createdBy ?? this.createdBy,
      isPublic: isPublic ?? this.isPublic,
      lastCookedAt: lastCookedAt ?? this.lastCookedAt,
      ingredientsNormalized:
          ingredientsNormalized ?? this.ingredientsNormalized,
      ratingCount: ratingCount ?? this.ratingCount,
      averageRating: averageRating ?? this.averageRating,
      ratingDistribution: ratingDistribution ?? this.ratingDistribution,
      lastRatedAt: lastRatedAt ?? this.lastRatedAt,
      dataChecksum: newChecksum,
      tagResult: tagResult ?? this.tagResult,
      tagOverrides: tagOverrides ?? this.tagOverrides,
      personalTagVersion: personalTagVersion ?? this.personalTagVersion,
      isFavorite: isFavorite ?? this.isFavorite,
      dataIntegrityStatus: newIntegrityStatus,
    );
  }

  // Helper getters
  bool get hasImages => imageUrls.isNotEmpty;
  String? get primaryImageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;
  String get cookTimeText =>
      timeMinutes != null ? '${timeMinutes!} minuter' : '–';

  String? get lastCookedText {
    if (lastCookedAt == null) return null;
    final now = DateTime.now();
    final difference = now.difference(lastCookedAt!);
    if (difference.inDays == 0) return 'Tillagad idag';
    if (difference.inDays == 1) return 'Tillagad igår';
    return 'Tillagad för ${difference.inDays} dagar sedan';
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'portions': portions,
        'timeMinutes': timeMinutes,
        'ingredients': ingredients,
        'instructions': instructions,
        'personalTagIds': personalTagIds,
        'personalTags': personalTags?.map((t) => t.toMap()).toList(),
        'rating': rating,
        'mealType': mealType,
        'sourceUrl': sourceUrl,
        'imageUrls': imageUrls,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'createdBy': createdBy,
        'isPublic': isPublic,
        'lastCookedAt': lastCookedAt?.toIso8601String(),
        'ingredientsNormalized': ingredientsNormalized,
        'ratingCount': ratingCount,
        'averageRating': averageRating,
        'ratingDistribution': ratingDistribution,
        'lastRatedAt': lastRatedAt?.toIso8601String(),
        'dataChecksum': dataChecksum,
        'tagResult': tagResult?.toJson(),
        'tagOverrides': tagOverrides?.toJson(),
        'personalTagVersion': personalTagVersion,
        'isFavorite': isFavorite,
      };

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'title': title,
        'description': description,
        'portions': portions,
        'timeMinutes': timeMinutes,
        'ingredients': ingredients,
        'instructions': instructions,
        'personalTagIds': personalTagIds,
        'personalTags': personalTags?.map((t) => t.toMap()).toList(),
        'rating': rating,
        'mealType': mealType,
        'sourceUrl': sourceUrl,
        'imageUrls': imageUrls,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'createdBy': createdBy,
        'isPublic': isPublic,
        'lastCookedAt':
            lastCookedAt != null ? Timestamp.fromDate(lastCookedAt!) : null,
        'ingredientsNormalized': ingredientsNormalized,
        'ratingCount': ratingCount,
        'averageRating': averageRating,
        'ratingDistribution': ratingDistribution,
        'lastRatedAt':
            lastRatedAt != null ? Timestamp.fromDate(lastRatedAt!) : null,
        'dataChecksum': dataChecksum,
        'tagResult': tagResult?.toFirestore(),
        'tagOverrides': tagOverrides?.toJson(),
        'personalTagVersion': personalTagVersion,
        'isFavorite': isFavorite,
      };

  factory RecipeCore.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final title = json['title'] as String;
    final ingredients =
        List<String>.from((json['ingredients'] as List?).orEmpty());
    final instructions =
        List<String>.from((json['instructions'] as List?).orEmpty());
    final storedChecksum = json['dataChecksum'] as String?;

    // Compute data integrity status
    DataIntegrityStatus integrityStatus;
    if (storedChecksum == null) {
      integrityStatus = DataIntegrityStatus.unverified;
    } else {
      final computedChecksum = computeChecksum(
        id: id,
        title: title,
        ingredients: ingredients,
        instructions: instructions,
      );
      if (computedChecksum == storedChecksum) {
        integrityStatus = DataIntegrityStatus.valid;
      } else {
        integrityStatus = DataIntegrityStatus.invalid;
        AppLogger.warning(
          '⚠️ Data integrity check failed for recipe $id: '
          'stored checksum does not match computed checksum',
        );
      }
    }

    return RecipeCore(
      id: id,
      title: title,
      description: json['description'] as String,
      portions: json['portions'] as int?,
      timeMinutes: json['timeMinutes'] as int?,
      ingredients: ingredients,
      instructions: instructions,
      personalTagIds: json['personalTagIds'] != null
          ? List<String>.from(json['personalTagIds'])
          : null,
      personalTags: _parsePersonalTags(
        json['personalTags'],
        json['personalTagIds'],
      ),
      rating: (json['rating'] as num?)?.toDouble(),
      mealType: json['mealType'] as String,
      sourceUrl: json['sourceUrl'] as String?,
      imageUrls: List<String>.from((json['imageUrls'] as List?).orEmpty()),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      createdBy: json['createdBy'] as String?,
      isPublic: (json['isPublic'] as bool?).orFalse(),
      lastCookedAt: json['lastCookedAt'] != null
          ? DateTime.parse(json['lastCookedAt'] as String)
          : null,
      ingredientsNormalized: json['ingredientsNormalized'] != null
          ? List<String>.from(json['ingredientsNormalized'])
          : null,
      ratingCount: json['ratingCount'] as int?,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      ratingDistribution: json['ratingDistribution'] != null
          ? Map<int, int>.from(json['ratingDistribution'])
          : null,
      lastRatedAt: json['lastRatedAt'] != null
          ? DateTime.parse(json['lastRatedAt'] as String)
          : null,
      dataChecksum: storedChecksum,
      tagResult: _parseTagResult(json['tagResult']),
      tagOverrides: _parseTagOverrides(json['tagOverrides']),
      personalTagVersion: json['personalTagVersion'] as int?,
      isFavorite: (json['isFavorite'] as bool?) ?? false,
      dataIntegrityStatus: integrityStatus,
    );
  }

  /// Parses personalTags from stored data with lazy migration.
  /// If the new field exists, uses it. Otherwise, converts old names
  /// to RecipePersonalTag objects with 'manual' source.
  static List<RecipePersonalTag>? _parsePersonalTags(
    dynamic personalTagsData,
    dynamic personalTagIdsData,
  ) {
    // New field exists - use it
    if (personalTagsData != null && personalTagsData is List) {
      try {
        return personalTagsData
            .whereType<Map>()
            .map((m) => RecipePersonalTag.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      } catch (e) {
        AppLogger.warning('Failed to parse personalTags: $e');
      }
    }

    // Fallback: create RecipePersonalTag objects from personalTagIds UUIDs
    if (personalTagIdsData != null && personalTagIdsData is List) {
      final ids = personalTagIdsData
          .map((e) => e?.toString())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
      if (ids.isNotEmpty) {
        return ids
            .map((id) => RecipePersonalTag.manual(tagId: id, name: id))
            .toList();
      }
    }

    return null;
  }

  /// Safely parses tagResult from dynamic value.
  /// Returns null if parsing fails instead of throwing.
  static TagResult? _parseTagResult(dynamic value) {
    if (value == null) return null;
    try {
      if (value is Map<String, dynamic>) {
        return TagResult.fromFirestore(value);
      }
      // Handle Map<dynamic, dynamic> case from Firestore
      if (value is Map) {
        return TagResult.fromFirestore(Map<String, dynamic>.from(value));
      }
    } catch (e) {
      AppLogger.warning('Failed to parse tagResult: $e');
    }
    return null;
  }

  /// Safely parses tagOverrides from dynamic value.
  /// Returns null if parsing fails instead of throwing.
  static TagOverrides? _parseTagOverrides(dynamic value) {
    if (value == null) return null;
    try {
      if (value is Map<String, dynamic>) {
        return TagOverrides.fromJson(value);
      }
      // Handle Map<dynamic, dynamic> case from Firestore
      if (value is Map) {
        return TagOverrides.fromJson(Map<String, dynamic>.from(value));
      }
    } catch (e) {
      AppLogger.warning('Failed to parse tagOverrides: $e');
    }
    return null;
  }

  /// Create from repository data map (removes Firebase dependency)
  factory RecipeCore.fromMap(String id, Map<String, dynamic> data) {
    final title = utils.SerializationUtils.safeString(data, 'title');
    final ingredients =
        utils.SerializationUtils.safeStringList(data, 'ingredients');
    final instructions =
        utils.SerializationUtils.safeStringList(data, 'instructions');
    final storedChecksum =
        utils.SerializationUtils.safeNullableString(data, 'dataChecksum');

    // Compute data integrity status
    DataIntegrityStatus integrityStatus;
    if (storedChecksum == null) {
      integrityStatus = DataIntegrityStatus.unverified;
    } else {
      final computedChecksum = computeChecksum(
        id: id,
        title: title,
        ingredients: ingredients,
        instructions: instructions,
      );
      if (computedChecksum == storedChecksum) {
        integrityStatus = DataIntegrityStatus.valid;
      } else {
        integrityStatus = DataIntegrityStatus.invalid;
        AppLogger.warning(
          '⚠️ Data integrity check failed for recipe $id: '
          'stored checksum does not match computed checksum',
        );
      }
    }

    return RecipeCore(
      id: id,
      title: title,
      description: utils.SerializationUtils.safeString(data, 'description'),
      portions: utils.SerializationUtils.safeNullableInt(data, 'portions'),
      timeMinutes:
          utils.SerializationUtils.safeNullableInt(data, 'timeMinutes'),
      ingredients: ingredients,
      instructions: instructions,
      personalTagIds:
          utils.SerializationUtils.safeStringList(data, 'personalTagIds')
                  .isNotEmpty
              ? utils.SerializationUtils.safeStringList(data, 'personalTagIds')
              : null,
      personalTags: _parsePersonalTags(
        data['personalTags'],
        data['personalTagIds'],
      ),
      rating: utils.SerializationUtils.safeNullableDouble(data, 'rating'),
      mealType: utils.SerializationUtils.safeString(data, 'mealType',
          defaultValue: 'Middag'),
      sourceUrl: utils.SerializationUtils.safeNullableString(data, 'sourceUrl'),
      imageUrls: utils.SerializationUtils.safeStringList(data, 'imageUrls'),
      createdAt:
          utils.SerializationUtils.safeDateTime(data, 'createdAt').orNow(),
      updatedAt:
          utils.SerializationUtils.safeDateTime(data, 'updatedAt').orNow(),
      createdBy: utils.SerializationUtils.safeNullableString(data, 'createdBy'),
      isPublic: utils.SerializationUtils.safeBool(data, 'isPublic',
          defaultValue: false),
      lastCookedAt: utils.SerializationUtils.safeDateTime(data, 'lastCookedAt'),
      ingredientsNormalized:
          utils.SerializationUtils.safeStringList(data, 'ingredientsNormalized')
                  .isNotEmpty
              ? utils.SerializationUtils.safeStringList(
                  data, 'ingredientsNormalized')
              : null,
      ratingCount:
          utils.SerializationUtils.safeNullableInt(data, 'ratingCount'),
      averageRating:
          utils.SerializationUtils.safeNullableDouble(data, 'averageRating'),
      ratingDistribution: data['ratingDistribution'] != null
          ? Map<int, int>.from(data['ratingDistribution'] as Map)
          : null,
      lastRatedAt: utils.SerializationUtils.safeDateTime(data, 'lastRatedAt'),
      dataChecksum: storedChecksum,
      tagResult: _parseTagResult(data['tagResult']),
      tagOverrides: _parseTagOverrides(data['tagOverrides']),
      personalTagVersion:
          utils.SerializationUtils.safeNullableInt(data, 'personalTagVersion'),
      isFavorite: utils.SerializationUtils.safeBool(data, 'isFavorite',
          defaultValue: false),
      dataIntegrityStatus: integrityStatus,
    );
  }

  factory RecipeCore.fromFirestore(DocumentSnapshot doc) {
    return RecipeCore.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }
}

/// Social/sharing metadata for recipes
class RecipeSocialData {
  final String? ownerId;
  final String? ownerDisplayName;
  final Map<String, ResourcePermission>? memberPermissions;
  final bool allowGuestViewing;
  final bool allowMemberInvites;
  final List<String>? categoryIds;
  final String? descriptionCollaborative;

  const RecipeSocialData({
    this.ownerId,
    this.ownerDisplayName,
    this.memberPermissions,
    this.allowGuestViewing = false,
    this.allowMemberInvites = true,
    this.categoryIds,
    this.descriptionCollaborative,
  });

  Map<String, dynamic> toJson() => {
        'ownerId': ownerId,
        'ownerDisplayName': ownerDisplayName,
        'memberPermissions':
            memberPermissions?.map((k, v) => MapEntry(k, v.index)),
        'allowGuestViewing': allowGuestViewing,
        'allowMemberInvites': allowMemberInvites,
        'categoryIds': categoryIds,
        'descriptionCollaborative': descriptionCollaborative,
      };

  factory RecipeSocialData.fromJson(Map<String, dynamic> json) =>
      RecipeSocialData(
        ownerId: json['ownerId'] as String?,
        ownerDisplayName: json['ownerDisplayName'] as String?,
        memberPermissions: json['memberPermissions'] != null
            ? Map<String, ResourcePermission>.from(
                (json['memberPermissions'] as Map)
                    .map((k, v) => MapEntry(k, ResourcePermission.values[v])))
            : null,
        allowGuestViewing: (json['allowGuestViewing'] as bool?).orFalse(),
        allowMemberInvites: (json['allowMemberInvites'] as bool?).orTrue(),
        categoryIds: json['categoryIds'] != null
            ? List<String>.from(json['categoryIds'])
            : null,
        descriptionCollaborative: json['descriptionCollaborative'] as String?,
      );

  RecipeSocialData copyWith({
    String? ownerId,
    String? ownerDisplayName,
    Map<String, ResourcePermission>? memberPermissions,
    bool? allowGuestViewing,
    bool? allowMemberInvites,
    List<String>? categoryIds,
    String? descriptionCollaborative,
  }) {
    return RecipeSocialData(
      ownerId: ownerId ?? this.ownerId,
      ownerDisplayName: ownerDisplayName ?? this.ownerDisplayName,
      memberPermissions: memberPermissions ?? this.memberPermissions,
      allowGuestViewing: allowGuestViewing ?? this.allowGuestViewing,
      allowMemberInvites: allowMemberInvites ?? this.allowMemberInvites,
      categoryIds: categoryIds ?? this.categoryIds,
      descriptionCollaborative:
          descriptionCollaborative ?? this.descriptionCollaborative,
    );
  }
}

/// Realtime collaboration metadata
class RecipeRealtimeData {
  final List<String>? activeEditorIds;
  final Map<String, DateTime>? lastSeenAt;
  final String? lastEditedByUserId;
  final String? lastEditedByDisplayName;
  final DateTime? lastEditedAt;
  final int editCount;
  final bool isActive;

  const RecipeRealtimeData({
    this.activeEditorIds,
    this.lastSeenAt,
    this.lastEditedByUserId,
    this.lastEditedByDisplayName,
    this.lastEditedAt,
    this.editCount = 0,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'activeEditorIds': activeEditorIds,
        'lastSeenAt':
            lastSeenAt?.map((k, v) => MapEntry(k, v.toIso8601String())),
        'lastEditedByUserId': lastEditedByUserId,
        'lastEditedByDisplayName': lastEditedByDisplayName,
        'lastEditedAt': lastEditedAt?.toIso8601String(),
        'editCount': editCount,
        'isActive': isActive,
      };

  factory RecipeRealtimeData.fromJson(Map<String, dynamic> json) =>
      RecipeRealtimeData(
        activeEditorIds: json['activeEditorIds'] != null
            ? List<String>.from(json['activeEditorIds'])
            : null,
        lastSeenAt: json['lastSeenAt'] != null
            ? Map<String, DateTime>.from((json['lastSeenAt'] as Map)
                .map((k, v) => MapEntry(k, DateTime.parse(v))))
            : null,
        lastEditedByUserId: json['lastEditedByUserId'] as String?,
        lastEditedByDisplayName: json['lastEditedByDisplayName'] as String?,
        lastEditedAt: json['lastEditedAt'] != null
            ? DateTime.parse(json['lastEditedAt'])
            : null,
        editCount: (json['editCount'] as int?).orZero(),
        isActive: (json['isActive'] as bool?).orTrue(),
      );
}

/// Offline sync metadata
class RecipeOfflineData {
  final DateTime? lastSyncedAt;
  final bool isModifiedOffline;
  final List<String>? pendingChanges;

  const RecipeOfflineData({
    this.lastSyncedAt,
    this.isModifiedOffline = false,
    this.pendingChanges,
  });

  bool get needsSync => isModifiedOffline || lastSyncedAt == null;

  Map<String, dynamic> toJson() => {
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
        'isModifiedOffline': isModifiedOffline,
        'pendingChanges': pendingChanges,
      };

  factory RecipeOfflineData.fromJson(Map<String, dynamic> json) =>
      RecipeOfflineData(
        lastSyncedAt: json['lastSyncedAt'] != null
            ? DateTime.parse(json['lastSyncedAt'])
            : null,
        isModifiedOffline: (json['isModifiedOffline'] as bool?).orFalse(),
        pendingChanges: json['pendingChanges'] != null
            ? List<String>.from(json['pendingChanges'])
            : null,
      );
}

/// Clean facade for unified recipe using focused modules
/// This facade provides a unified API that delegates to focused modules:
/// - RecipeOperations: Content manipulation (ingredients, instructions, etc.)
/// - RecipeFactory: Construction and conversion methods
/// - RecipeSerialization: JSON/Firestore serialization
/// ❌ DOES NOT CONTAIN: Complex business logic, direct implementation details
class Recipe {
  final RecipeCore core;
  final RecipeType type;
  final RecipeSocialData? socialData;
  final RecipeRealtimeData? realtimeData;
  final RecipeOfflineData? offlineData;

  const Recipe({
    required this.core,
    required this.type,
    this.socialData,
    this.realtimeData,
    this.offlineData,
  });

  // Convenience getters that delegate to core
  String get id => core.id;
  String get title => core.title;
  String get description => core.description;
  int? get portions => core.portions;
  int? get timeMinutes => core.timeMinutes;
  List<String> get ingredients => core.ingredients;
  List<String> get instructions => core.instructions;
  List<String>? get personalTagIds => core.personalTagIds;
  double? get rating => core.rating;
  String get mealType => core.mealType;
  String? get sourceUrl => core.sourceUrl;
  List<String> get imageUrls => core.imageUrls;
  DateTime get createdAt => core.createdAt;
  DateTime get updatedAt => core.updatedAt;
  String? get createdBy => core.createdBy;
  bool get isPublic => core.isPublic;
  DateTime? get lastCookedAt => core.lastCookedAt;
  bool get isFavorite => core.isFavorite;

  // Helper getters
  bool get hasImages => core.hasImages;
  String? get primaryImageUrl => core.primaryImageUrl;
  String get cookTimeText => core.cookTimeText;
  String? get lastCookedText => core.lastCookedText;
  TagResult? get tagResult => core.tagResult;
  TagOverrides? get tagOverrides => core.tagOverrides;

  /// Check if recipe was cooked recently (within last 7 days)
  bool get wasCookedRecently {
    if (lastCookedAt == null) return false;
    return DateTime.now().difference(lastCookedAt!).inDays < 7;
  }

  // Feature-specific getters
  bool get isPersonal => type == RecipeType.personal;
  bool get isShared => type == RecipeType.shared;
  bool get isCollaborative => type == RecipeType.collaborative;
  bool get isRealtime => type == RecipeType.realtime;
  bool get needsSync => offlineData?.needsSync ?? false;

  Recipe addIngredient(
    String ingredient, {
    String? userId,
    String? userDisplayName,
  }) {
    return RecipeOperations.addIngredient(
      this,
      ingredient,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Update ingredient at index
  Recipe updateIngredient(
    int index,
    String newIngredient, {
    String? userId,
    String? userDisplayName,
  }) {
    return RecipeOperations.updateIngredient(
      this,
      index,
      newIngredient,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Remove ingredient at index
  Recipe removeIngredient(
    int index, {
    String? userId,
    String? userDisplayName,
  }) {
    return RecipeOperations.removeIngredient(
      this,
      index,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Add instruction with user tracking
  Recipe addInstruction(
    String instruction, {
    String? userId,
    String? userDisplayName,
  }) {
    return RecipeOperations.addInstruction(
      this,
      instruction,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Update instruction at index
  Recipe updateInstruction(
    int index,
    String newInstruction, {
    String? userId,
    String? userDisplayName,
  }) {
    return RecipeOperations.updateInstruction(
      this,
      index,
      newInstruction,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Remove instruction at index
  Recipe removeInstruction(
    int index, {
    String? userId,
    String? userDisplayName,
  }) {
    return RecipeOperations.removeInstruction(
      this,
      index,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Mark recipe as cooked
  Recipe markAsCooked({
    String? userId,
    String? userDisplayName,
  }) {
    return RecipeOperations.markAsCooked(
      this,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  factory Recipe.personal({
    required String title,
    required String description,
    required List<String> ingredients,
    required List<String> instructions,
    required String mealType,
    String? createdBy,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
    List<String>? imageUrls,
    bool isPublic = false,
  }) {
    return RecipeFactory.createPersonal(
      title: title,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      mealType: mealType,
      createdBy: createdBy,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      personalTagIds: personalTagIds,
      sourceUrl: sourceUrl,
      imageUrls: imageUrls,
      isPublic: isPublic,
    );
  }

  /// Create collaborative recipe
  factory Recipe.collaborative({
    required String title,
    required String description,
    required List<String> ingredients,
    required List<String> instructions,
    required String mealType,
    required String ownerId,
    required String ownerDisplayName,
    Map<String, ResourcePermission>? memberPermissions,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    String? descriptionCollaborative,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
    List<String>? imageUrls,
  }) {
    return RecipeFactory.createCollaborative(
      title: title,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      mealType: mealType,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      memberPermissions: memberPermissions,
      allowGuestViewing: allowGuestViewing,
      allowMemberInvites: allowMemberInvites,
      descriptionCollaborative: descriptionCollaborative,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      personalTagIds: personalTagIds,
      sourceUrl: sourceUrl,
      imageUrls: imageUrls,
    );
  }

  Map<String, dynamic> toJson() => RecipeSerialization.toJson(this);
  Map<String, dynamic> toFirestore() => RecipeSerialization.toFirestore(this);

  factory Recipe.fromJson(Map<String, dynamic> json) =>
      RecipeSerialization.fromJson(json);
  factory Recipe.fromMap(String id, Map<String, dynamic> data) =>
      RecipeSerialization.fromMap(id, data);
  factory Recipe.fromFirestore(DocumentSnapshot doc) =>
      RecipeSerialization.fromFirestore(doc);

  Recipe copyWith({
    String? title,
    String? description,
    int? portions,
    int? timeMinutes,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? personalTagIds,
    List<RecipePersonalTag>? personalTags,
    double? rating,
    String? mealType,
    String? sourceUrl,
    List<String>? imageUrls,
    String? createdBy,
    bool? isPublic,
    DateTime? lastCookedAt,
    List<String>? ingredientsNormalized,
    String? lastEditedByUserId,
    String? lastEditedByDisplayName,
    RecipeType? type,
    RecipeSocialData? socialData,
    RecipeRealtimeData? realtimeData,
    RecipeOfflineData? offlineData,
    TagOverrides? tagOverrides,
    TagResult? tagResult,
    int? personalTagVersion,
    bool? isFavorite,
  }) {
    return Recipe(
      core: core.copyWith(
        title: title,
        description: description,
        portions: portions,
        timeMinutes: timeMinutes,
        ingredients: ingredients,
        instructions: instructions,
        personalTagIds: personalTagIds,
        personalTags: personalTags,
        rating: rating,
        mealType: mealType,
        sourceUrl: sourceUrl,
        imageUrls: imageUrls,
        createdBy: createdBy,
        isPublic: isPublic,
        lastCookedAt: lastCookedAt,
        ingredientsNormalized: ingredientsNormalized,
        tagOverrides: tagOverrides,
        tagResult: tagResult,
        personalTagVersion: personalTagVersion,
        isFavorite: isFavorite,
        updatedAt: DateTime.now(),
      ),
      type: type ?? this.type,
      // When converting to personal recipe, clear social data
      socialData: (type == RecipeType.personal && type != this.type)
          ? null
          : (socialData ?? this.socialData),
      realtimeData: realtimeData ?? this.realtimeData,
      offlineData: offlineData ?? this.offlineData,
    );
  }
}
