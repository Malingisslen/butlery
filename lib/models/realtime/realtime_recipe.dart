// lib/models/realtime/realtime_recipe.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';

// Focused modules
import 'package:butlery/models/realtime/recipe_operations.dart';
import 'package:butlery/models/realtime/recipe_serialization.dart';
import 'package:butlery/models/realtime/realtime_participants.dart';

/// Clean facade for realtime recipe using focused modules
///
/// This facade provides a unified API that delegates to focused modules:
/// - RecipeOperations: Recipe content manipulation (CRUD operations)
/// - RealtimeMetadata: Edit tracking and activity management
/// - RecipeSerialization: Firestore conversion and data validation
/// - RealtimeParticipants: Permission and participant management
///
/// ❌ DOES NOT CONTAIN: Complex business logic, direct Firestore operations, UI concerns
class RealtimeRecipe extends RealtimeResource {
  /// Det underliggande receptet som alla redigerar tillsammans
  final Recipe recipe;

  RealtimeRecipe({
    required super.id,
    required super.ownerId,
    required super.ownerDisplayName,
    required super.participants,
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

  /// Factory för att skapa ny realtidsrecept från befintligt recept
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

  // ===== RECIPE CONTENT OPERATIONS (DELEGATE TO RECIPE_OPERATIONS) =====

  /// Uppdatera receptets grundläggande information
  RealtimeRecipe updateBasicInfo({
    String? title,
    String? description,
    String? mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedRecipe = RecipeOperations.updateBasicInfo(
      recipe,
      title: title,
      description: description,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      tags: tags,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );

    return copyWith(
      recipe: updatedRecipe,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Uppdatera ingredienser
  RealtimeRecipe updateIngredients({
    required List<String> ingredients,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedRecipe = RecipeOperations.updateIngredients(
      recipe,
      ingredients: ingredients,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );

    return copyWith(
      recipe: updatedRecipe,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Lägg till en ingrediens
  RealtimeRecipe addIngredient({
    required String ingredient,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedRecipe = RecipeOperations.addIngredient(
      recipe,
      ingredient: ingredient,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );

    return copyWith(
      recipe: updatedRecipe,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Ta bort en ingrediens
  RealtimeRecipe removeIngredient({
    required int index,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedRecipe = RecipeOperations.removeIngredient(
      recipe,
      index: index,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );

    return copyWith(
      recipe: updatedRecipe,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Uppdatera instruktioner
  RealtimeRecipe updateInstructions({
    required List<String> instructions,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedRecipe = RecipeOperations.updateInstructions(
      recipe,
      instructions: instructions,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );

    return copyWith(
      recipe: updatedRecipe,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Lägg till en instruktion
  RealtimeRecipe addInstruction({
    required String instruction,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedRecipe = RecipeOperations.addInstruction(
      recipe,
      instruction: instruction,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );

    return copyWith(
      recipe: updatedRecipe,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Ta bort en instruktion
  RealtimeRecipe removeInstruction({
    required int index,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedRecipe = RecipeOperations.removeInstruction(
      recipe,
      index: index,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );

    return copyWith(
      recipe: updatedRecipe,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Uppdatera bildurlar
  RealtimeRecipe updateImageUrls({
    required List<String> imageUrls,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedRecipe = RecipeOperations.updateImageUrls(
      recipe,
      imageUrls: imageUrls,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );

    return copyWith(
      recipe: updatedRecipe,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Lägg till en bild
  RealtimeRecipe addImageUrl({
    required String imageUrl,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedRecipe = RecipeOperations.addImageUrl(
      recipe,
      imageUrl: imageUrl,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );

    return copyWith(
      recipe: updatedRecipe,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Ta bort en bild
  RealtimeRecipe removeImageUrl({
    required int index,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedRecipe = RecipeOperations.removeImageUrl(
      recipe,
      index: index,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );

    return copyWith(
      recipe: updatedRecipe,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  // ===== BUSINESS LOGIC GETTERS (DELEGATE TO RECIPE_OPERATIONS) =====

  int get ingredientsCount => recipe.ingredients.length;
  int get instructionsCount => recipe.instructions.length;
  int get imagesCount => recipe.imageUrls.length;
  String get title => recipe.title;
  String get description => recipe.description;
  int? get portions => recipe.portions;
  int? get timeMinutes => recipe.timeMinutes;
  double? get rating => recipe.rating;
  List<String>? get tags => recipe.tags;
  String get mealType => recipe.mealType;
  bool get hasRating => recipe.rating != null;
  bool get isValidRecipe => RecipeOperations.isValidRecipe(recipe);
  List<String> get validationErrors => RecipeOperations.getValidationErrors(recipe);
  bool get isPublishable => RecipeOperations.isPublishable(recipe);
  Map<String, int> get recipeStats => RecipeOperations.getRecipeStats(recipe);
  int get complexityScore => RecipeOperations.getComplexityScore(recipe);

  // ===== PARTICIPANT OPERATIONS (DELEGATE TO REALTIME_PARTICIPANTS) =====

  /// Lägg till deltagare
  @override
  RealtimeRecipe addParticipant(String userId, String userDisplayName, ResourcePermission permission) {
    final updatedParticipants = RealtimeParticipants.addParticipant(
      participants,
      userId,
      permission,
    );

    return copyWithMetadata(participants: updatedParticipants);
  }

  /// Ta bort deltagare
  @override
  RealtimeRecipe removeParticipant(String userId) {
    final updatedParticipants = RealtimeParticipants.removeParticipant(
      participants,
      userId,
    );

    return copyWithMetadata(participants: updatedParticipants);
  }

  /// Uppdatera deltagarebehörighet
  @override
  RealtimeRecipe updateParticipantPermission(String userId, ResourcePermission permission) {
    final updatedParticipants = RealtimeParticipants.updateParticipantPermission(
      participants,
      userId,
      permission,
    );

    return copyWithMetadata(participants: updatedParticipants);
  }

  /// Kontrollera om användare kan redigera
  bool canEdit(String userId) {
    return RealtimeParticipants.canEdit(participants, userId);
  }

  /// Kontrollera om användare kan visa
  bool canView(String userId) {
    return RealtimeParticipants.canView(participants, userId);
  }

  /// Kontrollera om användare är ägare
  @override
  bool isOwner(String userId) {
    return RealtimeParticipants.isOwner(participants, userId);
  }

  // ===== SERIALIZATION (DELEGATE TO RECIPE_SERIALIZATION) =====

  @override
  Map<String, dynamic> serializeContent() {
    return RecipeSerialization.serializeRealtimeContent(recipe);
  }

  /// Create from repository data map (removes Firebase dependency)
  factory RealtimeRecipe.fromMap(String id, Map<String, dynamic> data) {
    // Parse recipe data from the nested structure
    final recipeData = data['recipe'] as Map<String, dynamic>? ?? data;
    final recipe = RecipeSerialization.deserializeRecipe(recipeData, id);
    
    // Parse participants
    final participantsData = data['participants'] as Map<String, dynamic>? ?? {};
    final participants = participantsData.map(
      (userId, permissionString) => MapEntry(
        userId,
        ResourcePermissionHelper.stringToPermission(permissionString as String),
      ),
    );

    return RealtimeRecipe(
      id: id,
      ownerId: data['ownerId'] as String,
      ownerDisplayName: data['ownerDisplayName'] as String,
      participants: participants,
      createdAt: data['createdAt'] is DateTime 
          ? data['createdAt'] as DateTime
          : _parseTimestamp(data['createdAt']),
      lastEditedAt: data['lastEditedAt'] is DateTime 
          ? data['lastEditedAt'] as DateTime
          : _parseTimestamp(data['lastEditedAt']),
      lastEditedBy: data['lastEditedBy'] as String,
      lastEditedByDisplayName: data['lastEditedByDisplayName'] as String,
      editCount: data['editCount'] as int? ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      metadata: data['metadata'] as Map<String, dynamic>?,
      recipe: recipe,
    );
  }

  /// Helper method to parse timestamps from different sources
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  /// Skapa från Firestore dokument
  factory RealtimeRecipe.fromFirestore(DocumentSnapshot doc) {
    return RealtimeRecipe.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  // ===== COPY METHODS =====

  @override
  RealtimeRecipe copyWithMetadata({
    Map<String, ResourcePermission>? participants,
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
      createdAt: createdAt,
      lastEditedAt: lastEditedAt ?? DateTime.now(),
      lastEditedBy: lastEditedBy ?? this.lastEditedBy,
      lastEditedByDisplayName:
          lastEditedByDisplayName ?? this.lastEditedByDisplayName,
      editCount: editCount ?? (this.editCount + 1),
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      recipe: recipe,
    );
  }

  /// Skapa kopia med uppdaterat recept och metadata
  RealtimeRecipe copyWith({
    Recipe? recipe,
    Map<String, ResourcePermission>? participants,
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
      createdAt: createdAt,
      lastEditedAt: lastEditedAt ?? DateTime.now(),
      lastEditedBy: lastEditedBy ?? this.lastEditedBy,
      lastEditedByDisplayName:
          lastEditedByDisplayName ?? this.lastEditedByDisplayName,
      editCount: editCount ?? (this.editCount + 1),
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      recipe: recipe ?? this.recipe,
    );
  }

  // ===== UTILITY METHODS =====

  /// Skapa en personlig kopia av receptet (för "Spara kopia" funktionen)
  Recipe createPersonalCopy({required String newOwnerId}) {
    return Recipe(
      core: RecipeCore(
        id: '', // Nytt ID genereras automatiskt  
        title: recipe.title,
        description: recipe.description,
        ingredients: recipe.ingredients,
        instructions: recipe.instructions,
        mealType: recipe.mealType,
        portions: recipe.portions,
        timeMinutes: recipe.timeMinutes,
        rating: recipe.rating,
        tags: recipe.tags,
        sourceUrl: 'Delat från $ownerDisplayName',
        imageUrls: recipe.imageUrls,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: newOwnerId,
        isPublic: false,
        lastCookedAt: null,
      ),
      type: RecipeType.personal,
    );
  }

  /// Få recept-sammanfattning för UI
  String get recipeSummary {
    final parts = <String>[];

    if (portions != null) {
      parts.add('$portions portioner');
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

  /// Kontrollera om receptet matchar söktermer
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
    
    if (tags != null) {
      for (final tag in tags!) {
        if (tag.toLowerCase().contains(lowerQuery)) return true;
      }
    }
    
    return false;
  }
}