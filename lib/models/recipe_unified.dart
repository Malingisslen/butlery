/// Unified recipe data model with multi-type support and modular architecture.

// lib/models/recipe_unified.dart

import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:butlery/core/mixins/json_serializable_mixin.dart';
import 'package:butlery/core/utils/serialization_utils.dart' as utils;
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

// Focused modules
import 'package:butlery/models/recipe/recipe_operations.dart';
import 'package:butlery/models/recipe/recipe_factory.dart';
import 'package:butlery/models/recipe/recipe_serialization.dart';

part 'recipe_unified.g.dart';

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

/// Core recipe data model containing common recipe information.
/// This class represents the fundamental recipe data that is shared across
/// all recipe types in the unified recipe system. It includes all the basic
/// recipe information such as title, ingredients, instructions, and metadata.
/// The class is serializable for both local storage (Hive) and network
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
@HiveType(typeId: 1) // New type ID to avoid conflicts
class RecipeCore extends HiveObject with JsonSerializableMixin {
  /// Unique identifier for this recipe.
  /// This ID is immutable and generated once when the recipe is created.
  /// It's used for database references, sharing, and cache management.
  @HiveField(0)
  final String id;

  /// The display name of the recipe.
  /// This is the primary user-visible identifier for the recipe,
  /// shown in lists, search results, and detail views.
  @HiveField(1)
  String title;

  /// Detailed description of the recipe.
  /// Provides additional context, cooking tips, origin story,
  /// or other descriptive information about the recipe.
  @HiveField(2)
  String description;

  /// Number of servings this recipe produces.
  /// Used for scaling ingredients and nutritional calculations.
  /// Can be null if portion size is not specified.
  @HiveField(3)
  int? portions;

  /// Total cooking and preparation time in minutes.
  /// Includes active cooking time and any waiting/resting periods.
  /// Used for meal planning and filtering by available time.
  @HiveField(4)
  int? timeMinutes;

  /// List of ingredients required for this recipe.
  /// Each string represents one ingredient with quantity and preparation
  /// instructions (e.g., "2 cups flour, sifted", "1 large onion, diced").
  /// Order typically reflects the sequence of use in cooking.
  @HiveField(5)
  List<String> ingredients;

  /// Step-by-step cooking instructions.
  /// Each string represents one cooking step, ordered from first to last.
  /// Instructions should be clear and actionable for the home cook.
  @HiveField(6)
  List<String> instructions;

  /// Optional tags for categorization and search.
  /// Tags help users discover recipes through filtering and search.
  /// Common tags include dietary restrictions, cuisines, and cooking methods.
  @HiveField(7)
  List<String>? tags;

  /// User rating for this recipe (0.0 to 5.0).
  /// Represents the average user rating or personal rating depending
  /// on the recipe type. Used for sorting and recommendation algorithms.
  @HiveField(8)
  double? rating;

  @HiveField(9)
  String mealType;

  @HiveField(10)
  String? sourceUrl;

  @HiveField(11)
  List<String> imageUrls;

  @HiveField(12)
  final DateTime createdAt;

  @HiveField(13)
  DateTime updatedAt;

  @HiveField(14)
  String? createdBy;

  @HiveField(15)
  bool isPublic;

  @HiveField(16)
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
  @HiveField(17)
  List<String>? ingredientsNormalized;

  /// Total number of ratings this recipe has received.
  /// Denormalized aggregate maintained by Cloud Function on rating changes.
  /// Used for sorting by popularity and displaying rating counts in UI.
  /// Null for recipes without any ratings.
  @HiveField(18)
  int? ratingCount;

  /// Average rating value (1.0-5.0).
  /// Denormalized aggregate calculated from all ratings by Cloud Function.
  /// Provides instant access to recipe rating without querying all rating documents.
  /// Null for recipes without any ratings.
  @HiveField(19)
  double? averageRating;

  /// Distribution of ratings across star levels.
  /// Map structure: {1: count, 2: count, 3: count, 4: count, 5: count}
  /// Example: {1: 2, 2: 5, 3: 18, 4: 45, 5: 86} = 156 total ratings
  /// Denormalized for instant rating histogram display.
  /// Null for recipes without any ratings.
  @HiveField(20)
  Map<int, int>? ratingDistribution;

  /// Timestamp of the most recent rating.
  /// Used for cache freshness detection and sorting by recently rated.
  /// Updated by Cloud Function on every rating change.
  /// Null for recipes that have never been rated.
  @HiveField(21)
  DateTime? lastRatedAt;

  RecipeCore({
    String? id,
    required this.title,
    required this.description,
    this.portions,
    this.timeMinutes,
    required this.ingredients,
    required this.instructions,
    this.tags,
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
  })  : id = id ?? const Uuid().v4(),
        imageUrls = imageUrls ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create copy with updated values
  RecipeCore copyWith({
    String? title,
    String? description,
    int? portions,
    int? timeMinutes,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? tags,
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
  }) {
    return RecipeCore(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      portions: portions ?? this.portions,
      timeMinutes: timeMinutes ?? this.timeMinutes,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      tags: tags ?? this.tags,
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
        'tags': tags,
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
      };

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'title': title,
        'description': description,
        'portions': portions,
        'timeMinutes': timeMinutes,
        'ingredients': ingredients,
        'instructions': instructions,
        'tags': tags,
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
      };

  factory RecipeCore.fromJson(Map<String, dynamic> json) => RecipeCore(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        portions: json['portions'] as int?,
        timeMinutes: json['timeMinutes'] as int?,
        ingredients:
            List<String>.from((json['ingredients'] as List?).orEmpty()),
        instructions:
            List<String>.from((json['instructions'] as List?).orEmpty()),
        tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
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
      );

  /// Create from repository data map (removes Firebase dependency)
  factory RecipeCore.fromMap(String id, Map<String, dynamic> data) {
    return RecipeCore(
      id: id,
      title: utils.SerializationUtils.safeString(data, 'title'),
      description: utils.SerializationUtils.safeString(data, 'description'),
      portions: utils.SerializationUtils.safeNullableInt(data, 'portions'),
      timeMinutes:
          utils.SerializationUtils.safeNullableInt(data, 'timeMinutes'),
      ingredients: utils.SerializationUtils.safeStringList(data, 'ingredients'),
      instructions:
          utils.SerializationUtils.safeStringList(data, 'instructions'),
      tags: utils.SerializationUtils.safeStringList(data, 'tags').isNotEmpty
          ? utils.SerializationUtils.safeStringList(data, 'tags')
          : null,
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
  List<String>? get tags => core.tags;
  double? get rating => core.rating;
  String get mealType => core.mealType;
  String? get sourceUrl => core.sourceUrl;
  List<String> get imageUrls => core.imageUrls;
  DateTime get createdAt => core.createdAt;
  DateTime get updatedAt => core.updatedAt;
  String? get createdBy => core.createdBy;
  bool get isPublic => core.isPublic;
  DateTime? get lastCookedAt => core.lastCookedAt;

  // Helper getters
  bool get hasImages => core.hasImages;
  String? get primaryImageUrl => core.primaryImageUrl;
  String get cookTimeText => core.cookTimeText;
  String? get lastCookedText => core.lastCookedText;

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

  // ===== OPERATIONS (DELEGATE TO RECIPE_OPERATIONS) =====

  /// Add ingredient with user tracking
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

  // ===== FACTORY METHODS (DELEGATE TO RECIPE_FACTORY) =====

  /// Create personal recipe
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
    List<String>? tags,
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
      tags: tags,
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
    List<String>? tags,
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
      tags: tags,
      sourceUrl: sourceUrl,
      imageUrls: imageUrls,
    );
  }

  // ===== SERIALIZATION (DELEGATE TO RECIPE_SERIALIZATION) =====

  Map<String, dynamic> toJson() => RecipeSerialization.toJson(this);
  Map<String, dynamic> toFirestore() => RecipeSerialization.toFirestore(this);

  factory Recipe.fromJson(Map<String, dynamic> json) =>
      RecipeSerialization.fromJson(json);
  factory Recipe.fromMap(String id, Map<String, dynamic> data) =>
      RecipeSerialization.fromMap(id, data);
  factory Recipe.fromFirestore(DocumentSnapshot doc) =>
      RecipeSerialization.fromFirestore(doc);

  // ===== CORE COPY METHOD =====

  /// Create copy with updated core data
  Recipe copyWith({
    String? title,
    String? description,
    int? portions,
    int? timeMinutes,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? tags,
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
  }) {
    return Recipe(
      core: core.copyWith(
        title: title,
        description: description,
        portions: portions,
        timeMinutes: timeMinutes,
        ingredients: ingredients,
        instructions: instructions,
        tags: tags,
        rating: rating,
        mealType: mealType,
        sourceUrl: sourceUrl,
        imageUrls: imageUrls,
        createdBy: createdBy,
        isPublic: isPublic,
        lastCookedAt: lastCookedAt,
        ingredientsNormalized: ingredientsNormalized,
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
