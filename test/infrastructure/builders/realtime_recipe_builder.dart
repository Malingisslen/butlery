/// Test data builder for RealtimeRecipe objects
///
/// Provides fluent API for creating test realtime recipes with Swedish-themed defaults
/// and various preset configurations for different test scenarios.
library;

import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:uuid/uuid.dart';
import 'recipe_builder.dart';

/// Builder pattern for creating test RealtimeRecipe instances
class RealtimeRecipeBuilder {
  String id = const Uuid().v4();
  String ownerId = 'owner_123';
  String ownerDisplayName = 'Test Owner';
  Map<String, ResourcePermission> participants = {};
  DateTime createdAt = DateTime.now();
  DateTime lastEditedAt = DateTime.now();
  String lastEditedBy = 'owner_123';
  String lastEditedByDisplayName = 'Test Owner';
  int editCount = 0;
  bool isActive = true;
  Map<String, dynamic>? metadata;

  // Recipe content
  Recipe? _recipe;
  RecipeBuilder _recipeBuilder = RecipeBuilder();

  RealtimeRecipeBuilder() {
    // Owner is NOT in participants map - tracked separately via ownerId field
  }

  /// Creates a collaborative Swedish dinner recipe
  RealtimeRecipeBuilder asCollaborativeSwedishDinner() {
    _recipeBuilder = RecipeBuilder().asSwedishDinner();

    // Add multiple collaborators
    participants['editor_456'] = ResourcePermission.editor;
    participants['viewer_789'] = ResourcePermission.viewer;
    participants['editor_012'] = ResourcePermission.editor;

    lastEditedBy = 'editor_456';
    lastEditedByDisplayName = 'Erik Eriksson';
    editCount = 25;

    return this;
  }

  /// Creates an actively edited recipe
  RealtimeRecipeBuilder asActivelyEdited() {
    _recipeBuilder = RecipeBuilder().asItalianPasta();

    // Multiple editors actively working
    participants['editor_001'] = ResourcePermission.editor;
    participants['editor_002'] = ResourcePermission.editor;
    participants['editor_003'] = ResourcePermission.editor;

    lastEditedBy = 'editor_003';
    lastEditedByDisplayName = 'Maria Månsson';
    lastEditedAt = DateTime.now().subtract(const Duration(seconds: 30));
    editCount = 150;
    isActive = true;

    metadata = {
      'activeEditors': ['editor_001', 'editor_003'],
      'lastSaveTime': DateTime.now().toIso8601String(),
    };

    return this;
  }

  /// Creates an incomplete recipe for validation testing
  RealtimeRecipeBuilder asIncompleteRecipe() {
    _recipeBuilder = RecipeBuilder()
        .withTitle('Ofullständigt recept')
        .withDescription('En påbörjad receptidé')
        .withIngredients([]) // No ingredients
        .withInstructions([]) // No instructions
        .withTimeMinutes(0);

    editCount = 3;

    return this;
  }

  /// Creates a complex recipe for complexity scoring
  RealtimeRecipeBuilder asComplexRecipe() {
    _recipeBuilder = RecipeBuilder()
        .withTitle('Avancerad Fransk Rätt')
        .withDescription('En mycket komplex rätt som kräver flera tekniker')
        .withIngredients([
      '500g kalvkött',
      '200g foie gras',
      '100ml cognac',
      '50g tryffel',
      '300ml kalvfond',
      '200g smör',
      '4 äggulor',
      '100ml grädde',
      '1 bukett garni',
      '12 små potatiser',
      '200g morötter',
      '150g haricots verts',
    ]).withInstructions([
      'Förbered mise en place för alla ingredienser',
      'Reducera kalvfonden till hälften',
      'Sous vide kalvköttet i 2 timmar vid 56°C',
      'Förbered en klassisk béarnaisesås',
      'Sautera foie gras snabbt i het panna',
      'Flambera med cognac',
      'Montera såsen med kallt smör',
      'Tournera grönsakerna',
      'Glasera grönsakerna i smör',
      'Arrangera på tallrik med precision',
    ]).withTimeMinutes(180);

    editCount = 50;

    return this;
  }

  /// Creates a minimal recipe for edge case testing
  RealtimeRecipeBuilder asMinimalRecipe() {
    _recipeBuilder = RecipeBuilder()
        .withTitle('M')
        .withDescription('D')
        .withIngredients(['I']).withInstructions(['S']).withTimeMinutes(1);

    editCount = 0;

    return this;
  }

  /// Set custom ID
  RealtimeRecipeBuilder withId(String id) {
    this.id = id;
    _recipeBuilder.withId(id);
    return this;
  }

  /// Set custom owner
  RealtimeRecipeBuilder withOwner(String ownerId, String displayName) {
    // Remove old owner from participants if it exists (for backwards compatibility)
    participants.remove(this.ownerId);

    this.ownerId = ownerId;
    ownerDisplayName = displayName;

    // Owner is NOT added to participants map - tracked separately via ownerId field

    // Update last edited if owner was last editor
    if (lastEditedBy == this.ownerId) {
      lastEditedBy = ownerId;
      lastEditedByDisplayName = displayName;
    }

    return this;
  }

  /// Add a participant with specific permission
  RealtimeRecipeBuilder withParticipant(
      String userId, ResourcePermission permission) {
    participants[userId] = permission;
    return this;
  }

  /// Set recipe title
  RealtimeRecipeBuilder withTitle(String title) {
    _recipeBuilder.withTitle(title);
    return this;
  }

  /// Set recipe description
  RealtimeRecipeBuilder withDescription(String description) {
    _recipeBuilder.withDescription(description);
    return this;
  }

  /// Set recipe ingredients
  RealtimeRecipeBuilder withIngredients(List<String> ingredients) {
    _recipeBuilder.withIngredients(ingredients);
    return this;
  }

  /// Set recipe instructions
  RealtimeRecipeBuilder withInstructions(List<String> instructions) {
    _recipeBuilder.withInstructions(instructions);
    return this;
  }

  /// Set recipe images
  RealtimeRecipeBuilder withImages(List<String> imageUrls) {
    _recipeBuilder.withImageUrls(imageUrls);
    return this;
  }

  /// Set recipe meal type
  RealtimeRecipeBuilder withMealType(String mealType) {
    _recipeBuilder.withMealType(mealType);
    return this;
  }

  /// Set recipe portions
  RealtimeRecipeBuilder withPortions(int portions) {
    _recipeBuilder.withPortions(portions);
    return this;
  }

  /// Set recipe time in minutes
  RealtimeRecipeBuilder withTimeMinutes(int timeMinutes) {
    _recipeBuilder.withTimeMinutes(timeMinutes);
    return this;
  }

  /// Set recipe rating
  RealtimeRecipeBuilder withRating(double rating) {
    _recipeBuilder.withRating(rating);
    return this;
  }

  /// Set recipe tags
  RealtimeRecipeBuilder withTags(List<String> tags) {
    _recipeBuilder.withTags(tags);
    return this;
  }

  /// Set edit count
  RealtimeRecipeBuilder withEditCount(int count) {
    editCount = count;
    return this;
  }

  /// Set last edited by
  RealtimeRecipeBuilder withLastEditedBy(String userId, String displayName) {
    lastEditedBy = userId;
    lastEditedByDisplayName = displayName;
    lastEditedAt = DateTime.now();
    return this;
  }

  /// Set active status
  RealtimeRecipeBuilder withActiveStatus(bool active) {
    isActive = active;
    return this;
  }

  /// Set metadata
  RealtimeRecipeBuilder withMetadata(Map<String, dynamic> metadata) {
    this.metadata = metadata;
    return this;
  }

  /// Use a custom Recipe instance
  RealtimeRecipeBuilder withRecipe(Recipe recipe) {
    _recipe = recipe;
    return this;
  }

  /// Build the RealtimeRecipe instance
  RealtimeRecipe build() {
    // Use provided recipe or build from builder
    final recipe = _recipe ?? _recipeBuilder.withId(id).build();

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
}
