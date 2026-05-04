// lib/models/realtime/realtime_recipe.dart

import 'package:clock/clock.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/recipe_personal_tag.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';

import 'package:butlery/models/realtime/recipe_operations.dart';
import 'package:butlery/models/realtime/recipe_serialization.dart';
import 'package:butlery/models/realtime/realtime_participants.dart';

/// Facade for realtime recipe delegating to focused modules
class RealtimeRecipe extends RealtimeResource {
  final Recipe recipe;

  RealtimeRecipe({
    required super.id,
    required super.ownerId,
    required super.ownerDisplayName,
    required super.participants,
    super.participantIds,
    super.createdAt,
    super.lastEditedAt,
    required super.lastEditedBy,
    required super.lastEditedByDisplayName,
    super.editCount,
    super.isActive,
    super.metadata,
    required this.recipe,
  }) : super(
          type: RealtimeResourceType.recipe,
        );

  factory RealtimeRecipe.fromRecipe({
    required Recipe recipe,
    required String ownerId,
    required String ownerDisplayName,
    List<String>? editorUserIds,
    List<String>? viewerUserIds,
  }) {
    // Use focused participant module to create participants
    final participants = RealtimeParticipants.createDefaultParticipants(
      ownerId: ownerId,
      editorIds: editorUserIds,
      viewerIds: viewerUserIds,
    );

    return RealtimeRecipe(
      id: recipe.id.isNotEmpty
          ? recipe.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      participants: participants,
      lastEditedBy: ownerId,
      lastEditedByDisplayName: ownerDisplayName,
      recipe: recipe,
    );
  }

  RealtimeRecipe updateBasicInfo(
      {String? title,
      String? description,
      String? mealType,
      int? portions,
      int? timeMinutes,
      double? rating,
      List<String>? personalTagIds,
      required String editedBy,
      required String editedByDisplayName}) {
    final updatedRecipe = RecipeOperations.updateBasicInfo(recipe,
        title: title,
        description: description,
        mealType: mealType,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        personalTagIds: personalTagIds,
        editedBy: editedBy,
        editedByDisplayName: editedByDisplayName);
    return copyWith(
        recipe: updatedRecipe,
        lastEditedBy: editedBy,
        lastEditedByDisplayName: editedByDisplayName);
  }

  RealtimeRecipe updateIngredients(
      {required List<String> ingredients,
      required String editedBy,
      required String editedByDisplayName}) {
    final updatedRecipe = RecipeOperations.updateIngredients(recipe,
        ingredients: ingredients,
        editedBy: editedBy,
        editedByDisplayName: editedByDisplayName);
    return copyWith(
        recipe: updatedRecipe,
        lastEditedBy: editedBy,
        lastEditedByDisplayName: editedByDisplayName);
  }

  RealtimeRecipe addIngredient(
      {required String ingredient,
      required String editedBy,
      required String editedByDisplayName}) {
    final updatedRecipe = RecipeOperations.addIngredient(recipe,
        ingredient: ingredient,
        editedBy: editedBy,
        editedByDisplayName: editedByDisplayName);
    return copyWith(
        recipe: updatedRecipe,
        lastEditedBy: editedBy,
        lastEditedByDisplayName: editedByDisplayName);
  }

  RealtimeRecipe removeIngredient(
      {required int index,
      required String editedBy,
      required String editedByDisplayName}) {
    final updatedRecipe = RecipeOperations.removeIngredient(recipe,
        index: index,
        editedBy: editedBy,
        editedByDisplayName: editedByDisplayName);
    return copyWith(
        recipe: updatedRecipe,
        lastEditedBy: editedBy,
        lastEditedByDisplayName: editedByDisplayName);
  }

  RealtimeRecipe updateInstructions(
      {required List<String> instructions,
      required String editedBy,
      required String editedByDisplayName}) {
    final updatedRecipe = RecipeOperations.updateInstructions(recipe,
        instructions: instructions,
        editedBy: editedBy,
        editedByDisplayName: editedByDisplayName);
    return copyWith(
        recipe: updatedRecipe,
        lastEditedBy: editedBy,
        lastEditedByDisplayName: editedByDisplayName);
  }

  RealtimeRecipe addInstruction(
      {required String instruction,
      required String editedBy,
      required String editedByDisplayName}) {
    final updatedRecipe = RecipeOperations.addInstruction(recipe,
        instruction: instruction,
        editedBy: editedBy,
        editedByDisplayName: editedByDisplayName);
    return copyWith(
        recipe: updatedRecipe,
        lastEditedBy: editedBy,
        lastEditedByDisplayName: editedByDisplayName);
  }

  RealtimeRecipe removeInstruction(
      {required int index,
      required String editedBy,
      required String editedByDisplayName}) {
    final updatedRecipe = RecipeOperations.removeInstruction(recipe,
        index: index,
        editedBy: editedBy,
        editedByDisplayName: editedByDisplayName);
    return copyWith(
        recipe: updatedRecipe,
        lastEditedBy: editedBy,
        lastEditedByDisplayName: editedByDisplayName);
  }

  RealtimeRecipe updateImageUrls(
      {required List<String> imageUrls,
      required String editedBy,
      required String editedByDisplayName}) {
    final updatedRecipe = RecipeOperations.updateImageUrls(recipe,
        imageUrls: imageUrls,
        editedBy: editedBy,
        editedByDisplayName: editedByDisplayName);
    return copyWith(
        recipe: updatedRecipe,
        lastEditedBy: editedBy,
        lastEditedByDisplayName: editedByDisplayName);
  }

  RealtimeRecipe addImageUrl(
      {required String imageUrl,
      required String editedBy,
      required String editedByDisplayName}) {
    final updatedRecipe = RecipeOperations.addImageUrl(recipe,
        imageUrl: imageUrl,
        editedBy: editedBy,
        editedByDisplayName: editedByDisplayName);
    return copyWith(
        recipe: updatedRecipe,
        lastEditedBy: editedBy,
        lastEditedByDisplayName: editedByDisplayName);
  }

  RealtimeRecipe removeImageUrl(
      {required int index,
      required String editedBy,
      required String editedByDisplayName}) {
    final updatedRecipe = RecipeOperations.removeImageUrl(recipe,
        index: index,
        editedBy: editedBy,
        editedByDisplayName: editedByDisplayName);
    return copyWith(
        recipe: updatedRecipe,
        lastEditedBy: editedBy,
        lastEditedByDisplayName: editedByDisplayName);
  }

  int get ingredientsCount => recipe.ingredients.length;
  int get instructionsCount => recipe.instructions.length;
  int get imagesCount => recipe.imageUrls.length;
  String get title => recipe.title;
  String get description => recipe.description;
  int? get portions => recipe.portions;
  int? get timeMinutes => recipe.timeMinutes;
  double? get rating => recipe.rating;
  List<String>? get personalTagIds => recipe.personalTagIds;
  List<RecipePersonalTag>? get personalTags => recipe.core.personalTags;
  String get mealType => recipe.mealType;
  bool get hasRating => recipe.rating != null;
  bool get isValidRecipe => RecipeOperations.isValidRecipe(recipe);
  List<String> get validationErrors =>
      RecipeOperations.getValidationErrors(recipe);
  bool get isPublishable => RecipeOperations.isPublishable(recipe);
  Map<String, int> get recipeStats => RecipeOperations.getRecipeStats(recipe);
  int get complexityScore => RecipeOperations.getComplexityScore(recipe);

  @override
  RealtimeRecipe addParticipant(
      String userId, String userDisplayName, ResourcePermission permission) {
    final updatedParticipants = RealtimeParticipants.addParticipant(
      participants,
      userId,
      permission,
    );

    // Keep participantIds in sync
    final updatedParticipantIds = List<String>.from(participantIds);
    if (!updatedParticipantIds.contains(userId)) {
      updatedParticipantIds.add(userId);
    }

    return copyWithMetadata(
      participants: updatedParticipants,
      participantIds: updatedParticipantIds,
    );
  }

  @override
  RealtimeRecipe removeParticipant(String userId) {
    final updatedParticipants = RealtimeParticipants.removeParticipant(
      participants,
      userId,
    );

    // Keep participantIds in sync
    final updatedParticipantIds = List<String>.from(participantIds);
    updatedParticipantIds.remove(userId);

    return copyWithMetadata(
      participants: updatedParticipants,
      participantIds: updatedParticipantIds,
    );
  }

  @override
  RealtimeRecipe updateParticipantPermission(
      String userId, ResourcePermission newPermission) {
    final updatedParticipants =
        RealtimeParticipants.updateParticipantPermission(
      participants,
      userId,
      newPermission,
    );

    return copyWithMetadata(participants: updatedParticipants);
  }

  bool canEdit(String userId) {
    return RealtimeParticipants.canEdit(participants, userId);
  }

  bool canView(String userId) {
    return RealtimeParticipants.canView(participants, userId);
  }

  // isOwner is correctly implemented in the base class RealtimeResource
  // It checks the ownerId field, not the participants map

  @override
  Map<String, dynamic> serializeContent() {
    return RecipeSerialization.serializeRealtimeContent(recipe);
  }

  /// eliminating Firebase-specific types from the model layer.
  factory RealtimeRecipe.fromData({
    required String id,
    required String ownerId,
    required String ownerDisplayName,
    required Map<String, ResourcePermission> participants,
    required DateTime createdAt,
    required DateTime lastEditedAt,
    required String lastEditedBy,
    required String lastEditedByDisplayName,
    required Recipe recipe,
    int editCount = 0,
    bool isActive = true,
    Map<String, dynamic> metadata = const {},
  }) {
    return RealtimeRecipe(
      id: id,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      participants: participants,
      createdAt: createdAt,
      lastEditedAt: lastEditedAt,
      lastEditedBy: lastEditedBy,
      lastEditedByDisplayName: lastEditedByDisplayName,
      editCount: editCount,
      isActive: isActive,
      metadata: metadata,
      recipe: recipe,
    );
  }

  /// @deprecated Use fromData() constructor instead. This maintains backward compatibility.
  factory RealtimeRecipe.fromMap(String id, Map<String, dynamic> data) {
    // Parse recipe data from the nested structure
    final recipeData =
        SerializationUtils.safeNullableMap(data, 'recipe') ?? data;
    final recipe = RecipeSerialization.deserializeRecipe(recipeData, id);

    // Parse participants
    final participantsData = SerializationUtils.safeMap(data, 'participants');
    final participants = participantsData.map(
      (userId, permissionString) => MapEntry(
        userId,
        ResourcePermissionHelper.fromString(
            permissionString as String? ?? 'viewer'),
      ),
    );

    // Parse participantIds with fallback to participants.keys for migration
    final participantIds = data.containsKey('participantIds')
        ? SerializationUtils.safeStringList(data, 'participantIds')
        : participants.keys.toList();

    return RealtimeRecipe(
      id: id,
      ownerId: SerializationUtils.safeString(data, 'ownerId'),
      ownerDisplayName: SerializationUtils.safeString(data, 'ownerDisplayName'),
      participants: participants,
      participantIds: participantIds,
      createdAt: data['createdAt'] is DateTime
          ? data['createdAt'] as DateTime
          : SerializationUtils.safeRequiredDateTime(data, 'createdAt'),
      lastEditedAt: data['lastEditedAt'] is DateTime
          ? data['lastEditedAt'] as DateTime
          : SerializationUtils.safeRequiredDateTime(data, 'lastEditedAt'),
      lastEditedBy: SerializationUtils.safeString(data, 'lastEditedBy'),
      lastEditedByDisplayName:
          SerializationUtils.safeString(data, 'lastEditedByDisplayName'),
      editCount: SerializationUtils.safeInt(data, 'editCount'),
      isActive:
          SerializationUtils.safeBool(data, 'isActive', defaultValue: true),
      metadata: SerializationUtils.safeNullableMap(data, 'metadata'),
      recipe: recipe,
    );
  }

  factory RealtimeRecipe.fromFirestore(dynamic doc) {
    final id = doc.id as String;
    final data = doc.data() as Map<String, dynamic>;
    return RealtimeRecipe.fromMap(id, data);
  }

  @override
  RealtimeRecipe copyWithMetadata({
    Map<String, ResourcePermission>? participants,
    List<String>? participantIds,
    DateTime? lastEditedAt,
    String? lastEditedBy,
    String? lastEditedByDisplayName,
    int? editCount,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return RealtimeRecipe(
      id: id,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      participants: participants ?? this.participants,
      participantIds: participantIds ?? this.participantIds,
      createdAt: createdAt,
      lastEditedAt: lastEditedAt ?? clock.now(),
      lastEditedBy: lastEditedBy ?? this.lastEditedBy,
      lastEditedByDisplayName:
          lastEditedByDisplayName ?? this.lastEditedByDisplayName,
      editCount: editCount ?? (this.editCount + 1),
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      recipe: recipe,
    );
  }

  RealtimeRecipe copyWith({
    Recipe? recipe,
    Map<String, ResourcePermission>? participants,
    List<String>? participantIds,
    DateTime? lastEditedAt,
    String? lastEditedBy,
    String? lastEditedByDisplayName,
    int? editCount,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return RealtimeRecipe(
      id: id,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      participants: participants ?? this.participants,
      participantIds: participantIds ?? this.participantIds,
      createdAt: createdAt,
      lastEditedAt: lastEditedAt ?? clock.now(),
      lastEditedBy: lastEditedBy ?? this.lastEditedBy,
      lastEditedByDisplayName:
          lastEditedByDisplayName ?? this.lastEditedByDisplayName,
      editCount: editCount ?? (this.editCount + 1),
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      recipe: recipe ?? this.recipe,
    );
  }

  Recipe createPersonalCopy({required String newOwnerId}) {
    return Recipe(
      core: RecipeCore(
        id: '', // Nytt ID genereras automatiskt
        title: AppLocale.current.realtimeRecipeCopyTitle(recipe.title),
        description: recipe.description,
        ingredients: [...recipe.ingredients],
        instructions: [...recipe.instructions],
        mealType: recipe.mealType,
        portions: recipe.portions,
        timeMinutes: recipe.timeMinutes,
        rating: recipe.rating,
        personalTagIds:
            recipe.personalTagIds != null ? [...recipe.personalTagIds!] : null,
        personalTags: recipe.core.personalTags != null
            ? [...recipe.core.personalTags!]
            : null,
        sourceUrl: AppLocale.current.realtimeRecipeSharedFrom(ownerDisplayName),
        imageUrls: [...recipe.imageUrls],
        createdAt: clock.now(),
        updatedAt: clock.now(),
        createdBy: newOwnerId,
        isPublic: false,
        lastCookedAt: null,
        tagResult: recipe.core.tagResult,
        tagOverrides: recipe.core.tagOverrides,
        ingredientsNormalized: recipe.core.ingredientsNormalized != null
            ? [...recipe.core.ingredientsNormalized!]
            : null,
      ),
      type: RecipeType.personal,
    );
  }

  String get recipeSummary {
    final parts = <String>[];

    if (portions != null) {
      parts.add('$portions ${AppLocale.current.portionsUnit}');
    }

    if (timeMinutes != null) {
      parts.add('$timeMinutes min');
    }

    parts.add('$ingredientsCount ingredienser');
    parts.add('$instructionsCount steg');

    if (hasRating) {
      parts.add('${rating!.toStringAsFixed(1)} ⭐');
    }

    return parts.join(' • ');
  }

  bool matchesSearchQuery(String query) {
    final lowerQuery = query.toLowerCase();

    if (title.toLowerCase().contains(lowerQuery)) return true;
    if (description.toLowerCase().contains(lowerQuery)) return true;
    if (mealType.toLowerCase().contains(lowerQuery)) return true;

    for (final ingredient in recipe.ingredients) {
      if (ingredient.toLowerCase().contains(lowerQuery)) return true;
    }

    for (final instruction in recipe.instructions) {
      if (instruction.toLowerCase().contains(lowerQuery)) return true;
    }

    if (personalTags != null) {
      for (final pt in personalTags!) {
        if (pt.name.toLowerCase().contains(lowerQuery)) return true;
      }
    }

    return false;
  }
}
