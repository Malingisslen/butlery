// lib/models/realtime/realtime_recipe.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../recipe.dart';
import '../permissions/resource_permission.dart';
import 'realtime_resource.dart';


/// Realtidsresurs för gemensam receptredigering
///
/// Denna klass innehåller BARA:
/// - Recipe data wrapper
/// - Business logic för recipe operations
/// - Serialization methods
/// - Utility methods för recipe manipulation
///
/// ❌ INNEHÅLLER INTE: UI widgets, styling, theme methods, Flutter UI imports
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
    // Skapa participants map
    final participants = <String, ResourcePermission>{};

    // Ägaren får owner-behörighet
    participants[ownerId] = ResourcePermission.owner;

    // Lägg till redigerare
    if (editorUserIds != null) {
      for (final userId in editorUserIds) {
        if (userId != ownerId) {
          participants[userId] = ResourcePermission.editor;
        }
      }
    }

    // Lägg till betraktare
    if (viewerUserIds != null) {
      for (final userId in viewerUserIds) {
        if (userId != ownerId && !participants.containsKey(userId)) {
          participants[userId] = ResourcePermission.viewer;
        }
      }
    }

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

  // ===== RECIPE CONTENT UPDATES =====

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
    final updatedRecipe = recipe.copyWith(
      title: title,
      description: description,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      tags: tags,
      updatedAt: DateTime.now(),
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
    final updatedRecipe = recipe.copyWith(
      ingredients: ingredients,
      updatedAt: DateTime.now(),
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
    final updatedIngredients = List<String>.from(recipe.ingredients);
    updatedIngredients.add(ingredient);

    return updateIngredients(
      ingredients: updatedIngredients,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Ta bort en ingrediens
  RealtimeRecipe removeIngredient({
    required int index,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (index < 0 || index >= recipe.ingredients.length) {
      throw ArgumentError('Ogiltigt ingrediensindex: $index');
    }

    final updatedIngredients = List<String>.from(recipe.ingredients);
    updatedIngredients.removeAt(index);

    return updateIngredients(
      ingredients: updatedIngredients,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Uppdatera instruktioner
  RealtimeRecipe updateInstructions({
    required List<String> instructions,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedRecipe = recipe.copyWith(
      instructions: instructions,
      updatedAt: DateTime.now(),
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
    final updatedInstructions = List<String>.from(recipe.instructions);
    updatedInstructions.add(instruction);

    return updateInstructions(
      instructions: updatedInstructions,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Ta bort en instruktion
  RealtimeRecipe removeInstruction({
    required int index,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (index < 0 || index >= recipe.instructions.length) {
      throw ArgumentError('Ogiltigt instruktionsindex: $index');
    }

    final updatedInstructions = List<String>.from(recipe.instructions);
    updatedInstructions.removeAt(index);

    return updateInstructions(
      instructions: updatedInstructions,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Uppdatera bildurlar
  RealtimeRecipe updateImages({
    required List<String> imageUrls,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedRecipe = recipe.copyWith(
      imageUrls: imageUrls,
      updatedAt: DateTime.now(),
    );

    return copyWith(
      recipe: updatedRecipe,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Lägg till en bild
  RealtimeRecipe addImage({
    required String imageUrl,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedImageUrls = List<String>.from(recipe.imageUrls);
    updatedImageUrls.add(imageUrl);

    return updateImages(
      imageUrls: updatedImageUrls,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Ta bort en bild
  RealtimeRecipe removeImage({
    required int index,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (index < 0 || index >= recipe.imageUrls.length) {
      throw ArgumentError('Ogiltigt bildindex: $index');
    }

    final updatedImageUrls = List<String>.from(recipe.imageUrls);
    updatedImageUrls.removeAt(index);

    return updateImages(
      imageUrls: updatedImageUrls,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  // ===== BUSINESS LOGIC GETTERS =====

  /// Få receptets titel för UI
  String get title => recipe.title;

  /// Få receptets beskrivning
  String get description => recipe.description;

  /// Antal ingredienser
  int get ingredientsCount => recipe.ingredients.length;

  /// Antal instruktioner
  int get instructionsCount => recipe.instructions.length;

  /// Antal bilder
  int get imageCount => recipe.imageUrls.length;

  /// Är receptet komplett? (har titel, ingredienser och instruktioner)
  bool get isComplete {
    return recipe.title.isNotEmpty &&
        recipe.ingredients.isNotEmpty &&
        recipe.instructions.isNotEmpty;
  }

  /// Receptets måltidstyp
  String get mealType => recipe.mealType;

  /// Beräknad tid för receptet
  int? get timeMinutes => recipe.timeMinutes;

  /// Antal portioner
  int? get portions => recipe.portions;

  /// Receptets betyg
  double? get rating => recipe.rating;

  /// Receptets taggar
  List<String> get tags => recipe.tags ?? [];

  /// Har receptet betyg?
  bool get hasRating => rating != null && rating! > 0;

  /// Har receptet taggar?
  bool get hasTags => tags.isNotEmpty;

  /// Har receptet bilder?
  bool get hasImages => imageCount > 0;

  /// Är receptet redo för delning? (komplett med minst grundinfo)
  bool get isReadyForSharing {
    return isComplete && mealType.isNotEmpty;
  }

  /// Få completion percentage (för progress bars)
  double get completionPercentage {
    int completed = 0;
    int total = 5; // title, description, ingredients, instructions, mealType

    if (title.isNotEmpty) completed++;
    if (description.isNotEmpty) completed++;
    if (recipe.ingredients.isNotEmpty) completed++;
    if (recipe.instructions.isNotEmpty) completed++;
    if (mealType.isNotEmpty) completed++;

    return completed / total;
  }

  /// Få completion status text
  String get completionStatus {
    if (completionPercentage >= 1.0) {
      return 'Komplett';
    } else if (completionPercentage >= 0.6) {
      return 'Nästan klar';
    } else if (completionPercentage >= 0.3) {
      return 'Pågående';
    } else {
      return 'Påbörjat';
    }
  }

  /// Få progress color name (för UI widgets att använda med AppTheme)
  String get progressColorName {
    if (completionPercentage >= 1.0) {
      return 'success';
    } else if (completionPercentage >= 0.6) {
      return 'primary';
    } else if (completionPercentage >= 0.3) {
      return 'warning';
    } else {
      return 'error';
    }
  }

  // ===== RECIPE OPERATIONS =====

  /// Skala receptet för ett annat antal portioner
  RealtimeRecipe scaleRecipe({
    required int newPortions,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (recipe.portions == null || newPortions <= 0) {
      throw ArgumentError(
          'Kan inte skala recept utan ursprungligt portionsantal');
    }

    // Här skulle vi implementera intelligent skalning av ingredienser
    // För nu, bara uppdatera portionsantalet
    final updatedRecipe = recipe.copyWith(
      portions: newPortions,
      updatedAt: DateTime.now(),
    );

    return copyWith(
      recipe: updatedRecipe,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Duplikera ingrediens för variation
  RealtimeRecipe duplicateIngredient({
    required int index,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (index < 0 || index >= recipe.ingredients.length) {
      throw ArgumentError('Ogiltigt ingrediensindex: $index');
    }

    final ingredient = recipe.ingredients[index];
    final updatedIngredients = List<String>.from(recipe.ingredients);
    updatedIngredients.insert(index + 1, ingredient);

    return updateIngredients(
      ingredients: updatedIngredients,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Flytta ingrediens upp eller ner i listan
  RealtimeRecipe reorderIngredient({
    required int fromIndex,
    required int toIndex,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (fromIndex < 0 ||
        fromIndex >= recipe.ingredients.length ||
        toIndex < 0 ||
        toIndex >= recipe.ingredients.length) {
      throw ArgumentError('Ogiltiga index för omsortering');
    }

    final updatedIngredients = List<String>.from(recipe.ingredients);
    final ingredient = updatedIngredients.removeAt(fromIndex);
    updatedIngredients.insert(toIndex, ingredient);

    return updateIngredients(
      ingredients: updatedIngredients,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Flytta instruktion upp eller ner i listan
  RealtimeRecipe reorderInstruction({
    required int fromIndex,
    required int toIndex,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (fromIndex < 0 ||
        fromIndex >= recipe.instructions.length ||
        toIndex < 0 ||
        toIndex >= recipe.instructions.length) {
      throw ArgumentError('Ogiltiga index för omsortering');
    }

    final updatedInstructions = List<String>.from(recipe.instructions);
    final instruction = updatedInstructions.removeAt(fromIndex);
    updatedInstructions.insert(toIndex, instruction);

    return updateInstructions(
      instructions: updatedInstructions,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  // ===== OVERRIDE ABSTRACT METHODS =====

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

  @override
  Map<String, dynamic> serializeContent() {
    return {
      'recipe': recipe.toFirestore(isNested: true),
    };
  }

  /// Skapa från Firestore dokument
  factory RealtimeRecipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final metadataMap = RealtimeResource.parseFirestoreMetadata(data, doc.id);

    // Parse recipe data
    final recipeData = data['recipe'] as Map<String, dynamic>? ?? {};

    // Create Recipe from nested data
    final recipe = Recipe(
      title: recipeData['title'] as String? ?? '',
      description: recipeData['description'] as String? ?? '',
      portions: recipeData['portions'] as int?,
      timeMinutes: recipeData['timeMinutes'] as int?,
      ingredients: List<String>.from(recipeData['ingredients'] ?? []),
      instructions: List<String>.from(recipeData['instructions'] ?? []),
      tags: recipeData['tags'] != null
          ? List<String>.from(recipeData['tags'])
          : null,
      rating: (recipeData['rating'] as num?)?.toDouble(),
      imageUrls: List<String>.from(recipeData['imageUrls'] ?? []),
      mealType: recipeData['mealType'] as String? ?? 'Middag',
      sourceUrl: recipeData['sourceUrl'] as String?,
    );

    return RealtimeRecipe(
      id: metadataMap['id'] as String,
      ownerId: metadataMap['ownerId'] as String,
      ownerDisplayName: metadataMap['ownerDisplayName'] as String,
      participants:
          metadataMap['participants'] as Map<String, ResourcePermission>,
      createdAt: metadataMap['createdAt'] as DateTime,
      lastEditedAt: metadataMap['lastEditedAt'] as DateTime,
      lastEditedBy: metadataMap['lastEditedBy'] as String,
      lastEditedByDisplayName: metadataMap['lastEditedByDisplayName'] as String,
      editCount: metadataMap['editCount'] as int,
      isActive: metadataMap['isActive'] as bool,
      metadata: metadataMap['metadata'] as Map<String, dynamic>,
      recipe: recipe,
    );
  }

  /// JSON serialization för caching
  Map<String, dynamic> toJson() {
    final json = toJsonMetadata();
    json['recipe'] = recipe.toJson();
    return json;
  }

  factory RealtimeRecipe.fromJson(Map<String, dynamic> json) {
    final recipe = Recipe.fromJson(json['recipe'] as Map<String, dynamic>);

    // Parse participants
    final participantsData =
        json['participants'] as Map<String, dynamic>? ?? {};
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

    return RealtimeRecipe(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      ownerDisplayName: json['ownerDisplayName'] as String,
      participants: participants,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastEditedAt: DateTime.parse(json['lastEditedAt'] as String),
      lastEditedBy: json['lastEditedBy'] as String,
      lastEditedByDisplayName: json['lastEditedByDisplayName'] as String,
      editCount: json['editCount'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      recipe: recipe,
    );
  }

  // ===== PARTICIPANT MANAGEMENT (OVERRIDE från RealtimeResource) =====

  @override
  RealtimeRecipe addParticipant(
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
      lastEditedBy: ownerId,
      lastEditedByDisplayName: ownerDisplayName,
      editCount: editCount + 1,
    );
  }

  @override
  RealtimeRecipe removeParticipant(String userId) {
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

  @override
  RealtimeRecipe updateParticipantPermission(
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

  // ===== UTILITY METHODS =====

  /// Skapa en personlig kopia av receptet (för "Spara kopia" funktionen)
  Recipe createPersonalCopy({required String newOwnerId}) {
    return recipe.copyWith(
      id: '', // Nytt ID genereras automatiskt
      sourceUrl: 'Delat från $ownerDisplayName',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastCookedAt: null,
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
    if (query.isEmpty) return true;

    final lowerQuery = query.toLowerCase();

    // Sök i titel
    if (title.toLowerCase().contains(lowerQuery)) return true;

    // Sök i beskrivning
    if (description.toLowerCase().contains(lowerQuery)) return true;

    // Sök i ingredienser
    if (recipe.ingredients
        .any((ingredient) => ingredient.toLowerCase().contains(lowerQuery))) {
      return true;
    }

    // Sök i taggar
    if (tags.any((tag) => tag.toLowerCase().contains(lowerQuery))) return true;

    // Sök i måltidstyp
    if (mealType.toLowerCase().contains(lowerQuery)) return true;

    return false;
  }

  @override
  String toString() {
    return 'RealtimeRecipe('
        'id: $id, '
        'title: $title, '
        'participants: $participantCount, '
        'completion: ${(completionPercentage * 100).toInt()}%, '
        'lastEdit: $lastEditedTimeAgo'
        ')';
  }
}
