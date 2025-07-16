// lib/models/unified/unified_recipe.dart
// ✅ FIXAD VERSION: Tar bort _FakeDocumentSnapshot och lägger till proper fromJson

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../recipe.dart';

/// Permissions för collaborative recipes
enum RecipePermission {
  view, // Kan endast se
  edit, // Kan redigera innehåll
  admin // Kan redigera + hantera medlemmar
}

/// Recipe type enum
enum RecipeType { personal, collaborative }

/// ✨ UNIFIED RECIPE - Hanterar BÅDE personal och collaborative recipes
class UnifiedRecipe {
  final String id;
  final String name;
  final String description;
  final List<String> ingredients;
  final List<String> instructions;
  final List<String> imageUrls;
  final String mealType;
  final int? portions;
  final int? timeMinutes;
  final double? rating;
  final List<String>? tags;
  final String? sourceUrl;

  // Ownership & Collaboration
  final String ownerId;
  final String ownerDisplayName;
  final RecipeType type; // personal eller collaborative
  final Map<String, RecipePermission>? memberPermissions;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastCookedAt;
  final String? lastEditedByUserId;
  final String? lastEditedByDisplayName;

  // ✅ FIX: Collaborative features
  final String? descriptionCollaborative;
  final bool allowGuestViewing;
  final bool allowMemberInvites;
  final List<String>? categoryIds;

  // Activity tracking
  final List<String>? activeEditorIds;
  final Map<String, DateTime>? lastSeenAt;

  const UnifiedRecipe({
    required this.id,
    required this.name,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.imageUrls,
    required this.mealType,
    required this.ownerId,
    required this.ownerDisplayName,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.portions,
    this.timeMinutes,
    this.rating,
    this.tags,
    this.sourceUrl,
    this.lastCookedAt,
    this.lastEditedByUserId,
    this.lastEditedByDisplayName,
    this.memberPermissions,
    this.descriptionCollaborative,
    this.allowGuestViewing = false,
    this.allowMemberInvites = true,
    this.categoryIds,
    this.activeEditorIds,
    this.lastSeenAt,
  });

  // ===== FACTORY CONSTRUCTORS =====

  /// Skapa personal recipe
  factory UnifiedRecipe.personal({
    required String name,
    required String ownerId,
    required String ownerDisplayName,
    String description = '',
    List<String> ingredients = const [],
    List<String> instructions = const [],
    List<String> imageUrls = const [],
    String mealType = 'Lunch',
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    String? sourceUrl,
    DateTime? lastCookedAt,
  }) {
    final now = DateTime.now();
    return UnifiedRecipe(
      id: const Uuid().v4(),
      name: name,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      imageUrls: imageUrls,
      mealType: mealType,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      type: RecipeType.personal,
      createdAt: now,
      updatedAt: now,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      tags: tags,
      sourceUrl: sourceUrl,
      lastCookedAt: lastCookedAt,
    );
  }

  /// Skapa collaborative recipe
  factory UnifiedRecipe.collaborative({
    required String name,
    required String ownerId,
    required String ownerDisplayName,
    required Map<String, RecipePermission> memberPermissions,
    String description = '',
    List<String> ingredients = const [],
    List<String> instructions = const [],
    List<String> imageUrls = const [],
    String mealType = 'Lunch',
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    String? sourceUrl,
    String? descriptionCollaborative,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) {
    final now = DateTime.now();
    return UnifiedRecipe(
      id: const Uuid().v4(),
      name: name,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      imageUrls: imageUrls,
      mealType: mealType,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      type: RecipeType.collaborative,
      memberPermissions: memberPermissions,
      createdAt: now,
      updatedAt: now,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      tags: tags,
      sourceUrl: sourceUrl,
      descriptionCollaborative: descriptionCollaborative,
      allowGuestViewing: allowGuestViewing,
      allowMemberInvites: allowMemberInvites,
      categoryIds: categoryIds,
    );
  }

  // ===== GETTERS =====

  bool get isPersonal => type == RecipeType.personal;
  bool get isCollaborative => type == RecipeType.collaborative;
  bool get hasImages => imageUrls.isNotEmpty;
  bool get hasMultipleImages => imageUrls.length > 1;
  bool get hasTags => tags != null && tags!.isNotEmpty;
  bool get hasRating => rating != null;
  bool get wasCookedRecently =>
      lastCookedAt != null &&
      DateTime.now().difference(lastCookedAt!).inDays < 7;

  /// Get all member IDs (owner + members)
  List<String> get allMemberIds {
    if (isPersonal) return [ownerId];
    return [ownerId, ...?memberPermissions?.keys];
  }

  /// Get currently active editors
  List<String> get currentActiveEditors => activeEditorIds ?? [];

  // ===== PERMISSION METHODS - REMOVED: Use PermissionService instead =====
  // All permission methods have been migrated to PermissionService for centralized permission management

  // ===== CONTENT MANIPULATION =====

  /// Add ingredient (with user tracking for collaborative)
  UnifiedRecipe addIngredient(String ingredient,
      {String? userId, String? userDisplayName}) {
    final updatedIngredients = [...ingredients, ingredient];
    return _updateContent(
      ingredients: updatedIngredients,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Update ingredient at index
  UnifiedRecipe updateIngredient(int index, String newIngredient,
      {String? userId, String? userDisplayName}) {
    if (index < 0 || index >= ingredients.length) return this;

    final updatedIngredients = [...ingredients];
    updatedIngredients[index] = newIngredient;

    return _updateContent(
      ingredients: updatedIngredients,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Remove ingredient at index
  UnifiedRecipe removeIngredient(int index,
      {String? userId, String? userDisplayName}) {
    if (index < 0 || index >= ingredients.length) return this;

    final updatedIngredients = [...ingredients];
    updatedIngredients.removeAt(index);

    return _updateContent(
      ingredients: updatedIngredients,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Add instruction
  UnifiedRecipe addInstruction(String instruction,
      {String? userId, String? userDisplayName}) {
    final updatedInstructions = [...instructions, instruction];
    return _updateContent(
      instructions: updatedInstructions,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Update instruction at index
  UnifiedRecipe updateInstruction(int index, String newInstruction,
      {String? userId, String? userDisplayName}) {
    if (index < 0 || index >= instructions.length) return this;

    final updatedInstructions = [...instructions];
    updatedInstructions[index] = newInstruction;

    return _updateContent(
      instructions: updatedInstructions,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Remove instruction at index
  UnifiedRecipe removeInstruction(int index,
      {String? userId, String? userDisplayName}) {
    if (index < 0 || index >= instructions.length) return this;

    final updatedInstructions = [...instructions];
    updatedInstructions.removeAt(index);

    return _updateContent(
      instructions: updatedInstructions,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Mark as cooked
  UnifiedRecipe markAsCooked({String? userId, String? userDisplayName}) {
    return _updateContent(
      lastCookedAt: DateTime.now(),
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  // ===== COLLABORATIVE MEMBER MANAGEMENT =====

  /// Add member to collaborative recipe
  UnifiedRecipe addMember(String userId, RecipePermission permission) {
    if (isPersonal) return this;

    final updatedPermissions =
        Map<String, RecipePermission>.from(memberPermissions ?? {});
    updatedPermissions[userId] = permission;

    return copyWith(
      memberPermissions: updatedPermissions,
      updatedAt: DateTime.now(),
    );
  }

  /// Remove member from collaborative recipe
  UnifiedRecipe removeMember(String userId) {
    if (isPersonal || userId == ownerId) return this;

    final updatedPermissions =
        Map<String, RecipePermission>.from(memberPermissions ?? {});
    updatedPermissions.remove(userId);

    return copyWith(
      memberPermissions: updatedPermissions,
      updatedAt: DateTime.now(),
    );
  }

  /// Update member permission
  UnifiedRecipe updateMemberPermission(
      String userId, RecipePermission permission) {
    if (isPersonal || userId == ownerId) return this;

    final updatedPermissions =
        Map<String, RecipePermission>.from(memberPermissions ?? {});
    updatedPermissions[userId] = permission;

    return copyWith(
      memberPermissions: updatedPermissions,
      updatedAt: DateTime.now(),
    );
  }

  /// Set user as active editor (for collaborative editing)
  UnifiedRecipe setUserActive(String userId) {
    if (isPersonal) return this;

    final updatedActiveEditors = <String>[...(activeEditorIds ?? [])];
    if (!updatedActiveEditors.contains(userId)) {
      updatedActiveEditors.add(userId);
    }

    final updatedLastSeen = Map<String, DateTime>.from(lastSeenAt ?? {});
    updatedLastSeen[userId] = DateTime.now();

    return copyWith(
      activeEditorIds: updatedActiveEditors,
      lastSeenAt: updatedLastSeen,
    );
  }

  /// Set user as inactive editor
  UnifiedRecipe setUserInactive(String userId) {
    if (isPersonal) return this;

    final updatedActiveEditors = <String>[...(activeEditorIds ?? [])];
    updatedActiveEditors.remove(userId);

    return copyWith(
      activeEditorIds: updatedActiveEditors,
    );
  }

  // ===== CONVERSION METHODS =====

  /// Convert to legacy Recipe model (for backwards compatibility)
  Recipe toLegacyRecipe() {
    return Recipe(
      id: id,
      title: name,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      imageUrls: imageUrls,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      tags: tags,
      sourceUrl: sourceUrl,
      lastCookedAt: lastCookedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // ===== PRIVATE HELPERS =====

  UnifiedRecipe _updateContent({
    String? name,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? imageUrls,
    String? mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    String? sourceUrl,
    DateTime? lastCookedAt,
    String? userId,
    String? userDisplayName,
  }) {
    return copyWith(
      name: name,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      imageUrls: imageUrls,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      tags: tags,
      sourceUrl: sourceUrl,
      lastCookedAt: lastCookedAt,
      updatedAt: DateTime.now(),
      lastEditedByUserId: userId,
      lastEditedByDisplayName: userDisplayName,
    );
  }

  // ===== SERIALIZATION =====

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'ingredients': ingredients,
      'instructions': instructions,
      'imageUrls': imageUrls,
      'mealType': mealType,
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (portions != null) 'portions': portions,
      if (timeMinutes != null) 'timeMinutes': timeMinutes,
      if (rating != null) 'rating': rating,
      if (tags != null) 'tags': tags,
      if (sourceUrl != null) 'sourceUrl': sourceUrl,
      if (lastCookedAt != null)
        'lastCookedAt': Timestamp.fromDate(lastCookedAt!),
      if (lastEditedByUserId != null) 'lastEditedByUserId': lastEditedByUserId,
      if (lastEditedByDisplayName != null)
        'lastEditedByDisplayName': lastEditedByDisplayName,
      if (memberPermissions != null)
        'memberPermissions':
            memberPermissions!.map((k, v) => MapEntry(k, v.name)),
      if (descriptionCollaborative != null)
        'descriptionCollaborative': descriptionCollaborative,
      'allowGuestViewing': allowGuestViewing,
      'allowMemberInvites': allowMemberInvites,
      if (categoryIds != null) 'categoryIds': categoryIds,
      if (activeEditorIds != null) 'activeEditorIds': activeEditorIds,
      if (lastSeenAt != null)
        'lastSeenAt':
            lastSeenAt!.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
    };
  }

  factory UnifiedRecipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UnifiedRecipe(
      id: data['id'] ?? doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      ingredients: List<String>.from(data['ingredients'] ?? []),
      instructions: List<String>.from(data['instructions'] ?? []),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      mealType: data['mealType'] ?? 'Lunch',
      ownerId: data['ownerId'] ?? '',
      ownerDisplayName: data['ownerDisplayName'] ?? '',
      type: RecipeType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => RecipeType.personal,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      portions: data['portions'],
      timeMinutes: data['timeMinutes'],
      rating: data['rating']?.toDouble(),
      tags: data['tags'] != null ? List<String>.from(data['tags']) : null,
      sourceUrl: data['sourceUrl'],
      lastCookedAt: (data['lastCookedAt'] as Timestamp?)?.toDate(),
      lastEditedByUserId: data['lastEditedByUserId'],
      lastEditedByDisplayName: data['lastEditedByDisplayName'],
      memberPermissions: data['memberPermissions'] != null
          ? Map<String, RecipePermission>.from(
              (data['memberPermissions'] as Map<String, dynamic>).map(
                (k, v) => MapEntry(
                    k, RecipePermission.values.firstWhere((e) => e.name == v)),
              ),
            )
          : null,
      descriptionCollaborative: data['descriptionCollaborative'],
      allowGuestViewing: data['allowGuestViewing'] ?? false,
      allowMemberInvites: data['allowMemberInvites'] ?? true,
      categoryIds: data['categoryIds'] != null
          ? List<String>.from(data['categoryIds'])
          : null,
      activeEditorIds: data['activeEditorIds'] != null
          ? List<String>.from(data['activeEditorIds'])
          : null,
      lastSeenAt: data['lastSeenAt'] != null
          ? Map<String, DateTime>.from(
              (data['lastSeenAt'] as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, (v as Timestamp).toDate()),
              ),
            )
          : null,
    );
  }

  // ✅ FIX: Direkt JSON-hantering utan fake DocumentSnapshot
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'ingredients': ingredients,
      'instructions': instructions,
      'imageUrls': imageUrls,
      'mealType': mealType,
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'type': type.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      if (portions != null) 'portions': portions,
      if (timeMinutes != null) 'timeMinutes': timeMinutes,
      if (rating != null) 'rating': rating,
      if (tags != null) 'tags': tags,
      if (sourceUrl != null) 'sourceUrl': sourceUrl,
      if (lastCookedAt != null)
        'lastCookedAt': lastCookedAt!.millisecondsSinceEpoch,
      if (lastEditedByUserId != null) 'lastEditedByUserId': lastEditedByUserId,
      if (lastEditedByDisplayName != null)
        'lastEditedByDisplayName': lastEditedByDisplayName,
      if (memberPermissions != null)
        'memberPermissions':
            memberPermissions!.map((k, v) => MapEntry(k, v.name)),
      if (descriptionCollaborative != null)
        'descriptionCollaborative': descriptionCollaborative,
      'allowGuestViewing': allowGuestViewing,
      'allowMemberInvites': allowMemberInvites,
      if (categoryIds != null) 'categoryIds': categoryIds,
      if (activeEditorIds != null) 'activeEditorIds': activeEditorIds,
      if (lastSeenAt != null)
        'lastSeenAt':
            lastSeenAt!.map((k, v) => MapEntry(k, v.millisecondsSinceEpoch)),
    };
  }

  factory UnifiedRecipe.fromJson(Map<String, dynamic> json) {
    return UnifiedRecipe(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      instructions: List<String>.from(json['instructions'] ?? []),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      mealType: json['mealType'] ?? 'Lunch',
      ownerId: json['ownerId'] ?? '',
      ownerDisplayName: json['ownerDisplayName'] ?? '',
      type: RecipeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => RecipeType.personal,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] ?? 0),
      portions: json['portions'],
      timeMinutes: json['timeMinutes'],
      rating: json['rating']?.toDouble(),
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      sourceUrl: json['sourceUrl'],
      lastCookedAt: json['lastCookedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastCookedAt'])
          : null,
      lastEditedByUserId: json['lastEditedByUserId'],
      lastEditedByDisplayName: json['lastEditedByDisplayName'],
      memberPermissions: json['memberPermissions'] != null
          ? Map<String, RecipePermission>.from(
              (json['memberPermissions'] as Map<String, dynamic>).map(
                (k, v) => MapEntry(
                    k, RecipePermission.values.firstWhere((e) => e.name == v)),
              ),
            )
          : null,
      descriptionCollaborative: json['descriptionCollaborative'],
      allowGuestViewing: json['allowGuestViewing'] ?? false,
      allowMemberInvites: json['allowMemberInvites'] ?? true,
      categoryIds: json['categoryIds'] != null
          ? List<String>.from(json['categoryIds'])
          : null,
      activeEditorIds: json['activeEditorIds'] != null
          ? List<String>.from(json['activeEditorIds'])
          : null,
      lastSeenAt: json['lastSeenAt'] != null
          ? Map<String, DateTime>.from(
              (json['lastSeenAt'] as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, DateTime.fromMillisecondsSinceEpoch(v)),
              ),
            )
          : null,
    );
  }

  // ===== COPY WITH =====

  UnifiedRecipe copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? imageUrls,
    String? mealType,
    String? ownerId,
    String? ownerDisplayName,
    RecipeType? type,
    Map<String, RecipePermission>? memberPermissions,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    String? sourceUrl,
    DateTime? lastCookedAt,
    String? lastEditedByUserId,
    String? lastEditedByDisplayName,
    String? descriptionCollaborative,
    bool? allowGuestViewing,
    bool? allowMemberInvites,
    List<String>? categoryIds,
    List<String>? activeEditorIds,
    Map<String, DateTime>? lastSeenAt,
  }) {
    return UnifiedRecipe(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      imageUrls: imageUrls ?? this.imageUrls,
      mealType: mealType ?? this.mealType,
      ownerId: ownerId ?? this.ownerId,
      ownerDisplayName: ownerDisplayName ?? this.ownerDisplayName,
      type: type ?? this.type,
      memberPermissions: memberPermissions ?? this.memberPermissions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      portions: portions ?? this.portions,
      timeMinutes: timeMinutes ?? this.timeMinutes,
      rating: rating ?? this.rating,
      tags: tags ?? this.tags,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      lastCookedAt: lastCookedAt ?? this.lastCookedAt,
      lastEditedByUserId: lastEditedByUserId ?? this.lastEditedByUserId,
      lastEditedByDisplayName:
          lastEditedByDisplayName ?? this.lastEditedByDisplayName,
      descriptionCollaborative:
          descriptionCollaborative ?? this.descriptionCollaborative,
      allowGuestViewing: allowGuestViewing ?? this.allowGuestViewing,
      allowMemberInvites: allowMemberInvites ?? this.allowMemberInvites,
      categoryIds: categoryIds ?? this.categoryIds,
      activeEditorIds: activeEditorIds ?? this.activeEditorIds,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnifiedRecipe &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => id.hashCode ^ updatedAt.hashCode;
}
