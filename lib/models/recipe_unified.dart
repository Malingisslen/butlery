// lib/models/recipe_unified.dart

import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../core/mixins/json_serializable_mixin.dart';
import '../core/types/app_timestamp.dart';
import 'permissions/resource_permission.dart';

// Focused modules
import 'recipe/recipe_operations.dart';
import 'recipe/recipe_factory.dart';
import 'recipe/recipe_serialization.dart';

part 'recipe_unified.g.dart';

/// Recipe type determines how the recipe behaves
enum RecipeType { 
  personal,      // Individual recipe
  shared,        // Recipe shared to others (read-only)
  collaborative, // Recipe that can be co-edited
  realtime       // Recipe with live editing capabilities
}

/// Core recipe data that's common to all types
@HiveType(typeId: 1) // New type ID to avoid conflicts
class RecipeCore extends HiveObject with JsonSerializableMixin {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  int? portions;

  @HiveField(4)
  int? timeMinutes;

  @HiveField(5)
  List<String> ingredients;

  @HiveField(6)
  List<String> instructions;

  @HiveField(7)
  List<String>? tags;

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
  }) : id = id ?? const Uuid().v4(),
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
    );
  }

  // Helper getters
  bool get hasImages => imageUrls.isNotEmpty;
  String? get primaryImageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;
  String get cookTimeText => timeMinutes != null ? '${timeMinutes!} minuter' : '–';
  
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
    'lastCookedAt': lastCookedAt != null ? Timestamp.fromDate(lastCookedAt!) : null,
  };

  factory RecipeCore.fromJson(Map<String, dynamic> json) => RecipeCore(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    portions: json['portions'] as int?,
    timeMinutes: json['timeMinutes'] as int?,
    ingredients: List<String>.from(json['ingredients'] ?? []),
    instructions: List<String>.from(json['instructions'] ?? []),
    tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
    rating: (json['rating'] as num?)?.toDouble(),
    mealType: json['mealType'] as String,
    sourceUrl: json['sourceUrl'] as String?,
    imageUrls: List<String>.from(json['imageUrls'] ?? []),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    createdBy: json['createdBy'] as String?,
    isPublic: json['isPublic'] as bool? ?? false,
    lastCookedAt: json['lastCookedAt'] != null ? DateTime.parse(json['lastCookedAt'] as String) : null,
  );

  /// Create from repository data map (removes Firebase dependency)
  factory RecipeCore.fromMap(String id, Map<String, dynamic> data) {
    return RecipeCore(
      id: id,
      title: data['title'] as String,
      description: data['description'] as String,
      portions: data['portions'] as int?,
      timeMinutes: data['timeMinutes'] as int?,
      ingredients: List<String>.from(data['ingredients'] ?? []),
      instructions: List<String>.from(data['instructions'] ?? []),
      tags: data['tags'] != null ? List<String>.from(data['tags']) : null,
      rating: data['rating']?.toDouble(),
      mealType: data['mealType'] as String,
      sourceUrl: data['sourceUrl'] as String?,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      createdAt: data['createdAt'] is DateTime 
          ? data['createdAt'] as DateTime
          : AppTimestamp.fromFirestore(data['createdAt']).dateTime,
      updatedAt: data['updatedAt'] is DateTime 
          ? data['updatedAt'] as DateTime
          : AppTimestamp.fromFirestore(data['updatedAt']).dateTime,
      createdBy: data['createdBy'] as String?,
      isPublic: data['isPublic'] as bool? ?? false,
      lastCookedAt: data['lastCookedAt'] != null 
          ? (data['lastCookedAt'] is DateTime 
              ? data['lastCookedAt'] as DateTime
              : AppTimestamp.fromFirestore(data['lastCookedAt']).dateTime)
          : null,
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
    'memberPermissions': memberPermissions?.map((k, v) => MapEntry(k, v.index)),
    'allowGuestViewing': allowGuestViewing,
    'allowMemberInvites': allowMemberInvites,
    'categoryIds': categoryIds,
    'descriptionCollaborative': descriptionCollaborative,
  };

  factory RecipeSocialData.fromJson(Map<String, dynamic> json) => RecipeSocialData(
    ownerId: json['ownerId'] as String?,
    ownerDisplayName: json['ownerDisplayName'] as String?,
    memberPermissions: json['memberPermissions'] != null 
        ? Map<String, ResourcePermission>.from(
            (json['memberPermissions'] as Map).map((k, v) => MapEntry(k, ResourcePermission.values[v]))
          )
        : null,
    allowGuestViewing: json['allowGuestViewing'] as bool? ?? false,
    allowMemberInvites: json['allowMemberInvites'] as bool? ?? true,
    categoryIds: json['categoryIds'] != null ? List<String>.from(json['categoryIds']) : null,
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
      descriptionCollaborative: descriptionCollaborative ?? this.descriptionCollaborative,
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
    'lastSeenAt': lastSeenAt?.map((k, v) => MapEntry(k, v.toIso8601String())),
    'lastEditedByUserId': lastEditedByUserId,
    'lastEditedByDisplayName': lastEditedByDisplayName,
    'lastEditedAt': lastEditedAt?.toIso8601String(),
    'editCount': editCount,
    'isActive': isActive,
  };

  factory RecipeRealtimeData.fromJson(Map<String, dynamic> json) => RecipeRealtimeData(
    activeEditorIds: json['activeEditorIds'] != null ? List<String>.from(json['activeEditorIds']) : null,
    lastSeenAt: json['lastSeenAt'] != null 
        ? Map<String, DateTime>.from(
            (json['lastSeenAt'] as Map).map((k, v) => MapEntry(k, DateTime.parse(v)))
          )
        : null,
    lastEditedByUserId: json['lastEditedByUserId'] as String?,
    lastEditedByDisplayName: json['lastEditedByDisplayName'] as String?,
    lastEditedAt: json['lastEditedAt'] != null ? DateTime.parse(json['lastEditedAt']) : null,
    editCount: json['editCount'] as int? ?? 0,
    isActive: json['isActive'] as bool? ?? true,
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

  factory RecipeOfflineData.fromJson(Map<String, dynamic> json) => RecipeOfflineData(
    lastSyncedAt: json['lastSyncedAt'] != null ? DateTime.parse(json['lastSyncedAt']) : null,
    isModifiedOffline: json['isModifiedOffline'] as bool? ?? false,
    pendingChanges: json['pendingChanges'] != null ? List<String>.from(json['pendingChanges']) : null,
  );
}

/// Clean facade for unified recipe using focused modules
///
/// This facade provides a unified API that delegates to focused modules:
/// - RecipeOperations: Content manipulation (ingredients, instructions, etc.)
/// - RecipeFactory: Construction and conversion methods  
/// - RecipeSerialization: JSON/Firestore serialization
///
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
  
  factory Recipe.fromJson(Map<String, dynamic> json) => RecipeSerialization.fromJson(json);
  factory Recipe.fromMap(String id, Map<String, dynamic> data) => RecipeSerialization.fromMap(id, data);
  factory Recipe.fromFirestore(DocumentSnapshot doc) => RecipeSerialization.fromFirestore(doc);

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
        updatedAt: DateTime.now(),
      ),
      type: type ?? this.type,
      socialData: socialData ?? this.socialData,
      realtimeData: realtimeData ?? this.realtimeData,
      offlineData: offlineData ?? this.offlineData,
    );
  }
}