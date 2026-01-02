// lib/services/realtime/modules/recipe_content_operations.dart

import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';

/// Recipe operation types for analytics and logging
enum RecipeOperationType {
  createFromExisting,
  updateBasicInfo,
  addIngredient,
  removeIngredient,
  updateIngredients,
  addInstruction,
  removeInstruction,
  updateInstructions,
  addImage,
  removeImage,
  updateImages,
  addParticipant,
  removeParticipant,
  updatePermissions,
}

/// Recipe-specific error handling
class RecipeOperationError {
  final RecipeOperationType operation;
  final String message;
  final String? resourceId;
  final dynamic originalError;

  RecipeOperationError({
    required this.operation,
    required this.message,
    this.resourceId,
    this.originalError,
  });

  @override
  String toString() => 'RecipeOperationError(${operation.name}): $message';
}

/// Focused module for recipe content operations
/// This module handles ONLY recipe content manipulation:
/// - Basic recipe information updates
/// - Ingredient CRUD operations
/// - Instruction CRUD operations
/// - Image/media management
/// - Content validation and utilities
/// ❌ DOES NOT CONTAIN: Participant management, state management, synchronization
class RecipeContentOperations {
  /// Update basic recipe information
  static RealtimeRecipe updateBasicInfo(
    RealtimeRecipe recipe, {
    String? title,
    String? description,
    String? mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    // Validate title
    if (title != null && title.trim().isEmpty) {
      throw RecipeOperationError(
        operation: RecipeOperationType.updateBasicInfo,
        message: 'Recepttitel kan inte vara tom',
        resourceId: recipe.id,
      );
    }

    // Validate cooking time
    if (timeMinutes != null && timeMinutes < 0) {
      throw RecipeOperationError(
        operation: RecipeOperationType.updateBasicInfo,
        message: 'Tillagningstid kan inte vara negativ',
        resourceId: recipe.id,
      );
    }

    AppLogger.info('📝 Updating basic info for recipe: ${recipe.title}');

    return recipe.updateBasicInfo(
      title: title,
      description: description,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      personalTagIds: personalTagIds,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Add ingredient to recipe
  static RealtimeRecipe addIngredient(
    RealtimeRecipe recipe, {
    required String ingredient,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (ingredient.trim().isEmpty) {
      throw RecipeOperationError(
        operation: RecipeOperationType.addIngredient,
        message: 'Ingrediens kan inte vara tom',
        resourceId: recipe.id,
      );
    }

    AppLogger.info('➕ Adding ingredient: "${ingredient.trim()}"');

    return recipe.addIngredient(
      ingredient: ingredient.trim(),
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Remove ingredient at specific index
  static RealtimeRecipe removeIngredient(
    RealtimeRecipe recipe, {
    required int index,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (index < 0 || index >= recipe.ingredientsCount) {
      throw RecipeOperationError(
        operation: RecipeOperationType.removeIngredient,
        message: 'Ogiltigt ingrediensindex: $index',
        resourceId: recipe.id,
      );
    }

    AppLogger.info('➖ Removing ingredient at index: $index');

    return recipe.removeIngredient(
      index: index,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Update all ingredients
  static RealtimeRecipe updateIngredients(
    RealtimeRecipe recipe, {
    required List<String> ingredients,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    // Validate ingredients
    final validIngredients =
        ingredients.map((i) => i.trim()).where((i) => i.isNotEmpty).toList();

    if (validIngredients.isEmpty) {
      throw RecipeOperationError(
        operation: RecipeOperationType.updateIngredients,
        message: 'Minst en ingrediens krävs',
        resourceId: recipe.id,
      );
    }

    AppLogger.info('📋 Updating ${validIngredients.length} ingredients');

    return recipe.updateIngredients(
      ingredients: validIngredients,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Add instruction to recipe
  static RealtimeRecipe addInstruction(
    RealtimeRecipe recipe, {
    required String instruction,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (instruction.trim().isEmpty) {
      throw RecipeOperationError(
        operation: RecipeOperationType.addInstruction,
        message: 'Instruktion kan inte vara tom',
        resourceId: recipe.id,
      );
    }

    AppLogger.info('➕ Adding instruction: "${instruction.trim()}"');

    return recipe.addInstruction(
      instruction: instruction.trim(),
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Remove instruction at specific index
  static RealtimeRecipe removeInstruction(
    RealtimeRecipe recipe, {
    required int index,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (index < 0 || index >= recipe.instructionsCount) {
      throw RecipeOperationError(
        operation: RecipeOperationType.removeInstruction,
        message: 'Ogiltigt instruktionsindex: $index',
        resourceId: recipe.id,
      );
    }

    AppLogger.info('➖ Removing instruction at index: $index');

    return recipe.removeInstruction(
      index: index,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Update all instructions
  static RealtimeRecipe updateInstructions(
    RealtimeRecipe recipe, {
    required List<String> instructions,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    // Validate instructions
    final validInstructions =
        instructions.map((i) => i.trim()).where((i) => i.isNotEmpty).toList();

    if (validInstructions.isEmpty) {
      throw RecipeOperationError(
        operation: RecipeOperationType.updateInstructions,
        message: 'Minst en instruktion krävs',
        resourceId: recipe.id,
      );
    }

    AppLogger.info('📋 Updating ${validInstructions.length} instructions');

    return recipe.updateInstructions(
      instructions: validInstructions,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Add image URL to recipe
  static RealtimeRecipe addImage(
    RealtimeRecipe recipe, {
    required String imageUrl,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (imageUrl.trim().isEmpty) {
      throw RecipeOperationError(
        operation: RecipeOperationType.addImage,
        message: 'Bild-URL kan inte vara tom',
        resourceId: recipe.id,
      );
    }

    // Validate URL format
    final uri = Uri.tryParse(imageUrl.trim());
    if (uri == null || !uri.hasAbsolutePath) {
      throw RecipeOperationError(
        operation: RecipeOperationType.addImage,
        message: 'Ogiltig bild-URL format',
        resourceId: recipe.id,
      );
    }

    // Check image limit (max 5 images)
    if (recipe.imagesCount >= 5) {
      throw RecipeOperationError(
        operation: RecipeOperationType.addImage,
        message: 'Maximalt 5 bilder tillåtna',
        resourceId: recipe.id,
      );
    }

    AppLogger.info('🖼️ Adding image: "${imageUrl.trim()}"');

    return recipe.addImageUrl(
      imageUrl: imageUrl.trim(),
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Remove image at specific index
  static RealtimeRecipe removeImage(
    RealtimeRecipe recipe, {
    required int index,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (index < 0 || index >= recipe.imagesCount) {
      throw RecipeOperationError(
        operation: RecipeOperationType.removeImage,
        message: 'Ogiltigt bildindex: $index',
        resourceId: recipe.id,
      );
    }

    AppLogger.info('🗑️ Removing image at index: $index');

    return recipe.removeImageUrl(
      index: index,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Update all images
  static RealtimeRecipe updateImages(
    RealtimeRecipe recipe, {
    required List<String> imageUrls,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    // Validate image URLs
    final validImageUrls = imageUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();

    AppLogger.info('🖼️ Updating ${validImageUrls.length} images');

    return recipe.updateImageUrls(
      imageUrls: validImageUrls,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Validate recipe content
  static List<String> validateRecipeContent(RealtimeRecipe recipe) {
    final errors = <String>[];

    // Check basic requirements
    if (recipe.title.trim().isEmpty) {
      errors.add('Recepttitel saknas');
    }

    if (recipe.ingredientsCount == 0) {
      errors.add('Recept har inga ingredienser');
    }

    if (recipe.instructionsCount == 0) {
      errors.add('Recipe has no instructions');
    }

    // Check content quality
    if (recipe.description.trim().isEmpty) {
      errors.add('Recipe description is empty');
    }

    return errors;
  }

  /// Check if recipe content is complete
  static bool isRecipeComplete(RealtimeRecipe recipe) {
    return recipe.title.trim().isNotEmpty &&
        recipe.ingredientsCount > 0 &&
        recipe.instructionsCount > 0;
  }

  /// Check if recipe content is publishable
  static bool isRecipePublishable(RealtimeRecipe recipe) {
    return isRecipeComplete(recipe) && recipe.description.trim().isNotEmpty;
  }

  /// Get recipe statistics
  static Map<String, dynamic> getRecipeStatistics(RealtimeRecipe recipe) {
    return {
      'title': recipe.title,
      'ingredientCount': recipe.ingredientsCount,
      'instructionCount': recipe.instructionsCount,
      'imageCount': recipe.imagesCount,
      'portions': recipe.portions,
      'timeMinutes': recipe.timeMinutes,
      'rating': recipe.rating,
      'tagCount': recipe.personalTagIds?.length ?? 0,
      'mealType': recipe.mealType,
      'isComplete': isRecipeComplete(recipe),
      'isPublishable': isRecipePublishable(recipe),
    };
  }

  /// Get estimated complexity score (1-5)
  static int getComplexityScore(RealtimeRecipe recipe) {
    int score = 1;

    // More ingredients increase complexity
    if (recipe.ingredientsCount > 5) score++;
    if (recipe.ingredientsCount > 10) score++;

    // More instructions increase complexity
    if (recipe.instructionsCount > 3) score++;
    if (recipe.instructionsCount > 6) score++;

    // Long cooking time increases complexity
    final timeMinutes = recipe.timeMinutes ?? 0;
    if (timeMinutes > 30) score++;
    if (timeMinutes > 60) score++;

    return score.clamp(1, 5);
  }

  /// Create personal copy of realtime recipe
  static Recipe createPersonalCopy(
    RealtimeRecipe recipe, {
    required String newOwnerId,
  }) {
    AppLogger.info('📋 Creating personal copy of: ${recipe.title}');
    return recipe.createPersonalCopy(newOwnerId: newOwnerId);
  }

  /// Check if recipe has changed since timestamp
  static bool hasRecipeChangedSince(RealtimeRecipe recipe, DateTime timestamp) {
    return recipe.hasChangedSince(timestamp);
  }

  /// Get summary of recent changes
  static String getRecipeChangesSummary(RealtimeRecipe recipe) {
    return recipe.getChangesSummary();
  }

  /// Get content summary for display
  static String getContentSummary(RealtimeRecipe recipe) {
    final parts = <String>[];

    parts.add('${recipe.ingredientsCount} ingredienser');
    parts.add('${recipe.instructionsCount} steg');

    if (recipe.timeMinutes != null) {
      parts.add('${recipe.timeMinutes} minuter');
    }

    if (recipe.portions != null) {
      parts.add('${recipe.portions} portioner');
    }

    return parts.join(' • ');
  }

  /// Get recipe difficulty level
  static String getDifficultyLevel(RealtimeRecipe recipe) {
    final complexity = getComplexityScore(recipe);

    switch (complexity) {
      case 1:
        return 'Mycket lätt';
      case 2:
        return 'Lätt';
      case 3:
        return 'Medel';
      case 4:
        return 'Svår';
      case 5:
        return 'Mycket svår';
      default:
        return 'Okänd';
    }
  }

  /// Check if content needs validation
  static bool needsContentValidation(RealtimeRecipe recipe) {
    final errors = validateRecipeContent(recipe);
    return errors.isNotEmpty;
  }
}
