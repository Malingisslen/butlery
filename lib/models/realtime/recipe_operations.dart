import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Recipe content operations (ingredients, instructions, validation).
class RecipeOperations {
  /// Update recipe basic information.
  static Recipe updateBasicInfo(
    Recipe recipe, {
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
    return recipe.copyWith(
      title: title,
      description: description,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      personalTagIds: personalTagIds,
      lastEditedByUserId: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Update all ingredients.
  static Recipe updateIngredients(
    Recipe recipe, {
    required List<String> ingredients,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    return recipe.copyWith(
      ingredients: ingredients,
      lastEditedByUserId: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Add a single ingredient
  static Recipe addIngredient(
    Recipe recipe, {
    required String ingredient,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedIngredients = List<String>.from(recipe.ingredients);
    updatedIngredients.add(ingredient);

    return updateIngredients(
      recipe,
      ingredients: updatedIngredients,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Remove ingredient at index
  static Recipe removeIngredient(
    Recipe recipe, {
    required int index,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (index < 0 || index >= recipe.ingredients.length) {
      throw ArgumentError(
        AppLocale.current.validationInvalidIngredientIndex(index),
      );
    }

    final updatedIngredients = List<String>.from(recipe.ingredients);
    updatedIngredients.removeAt(index);

    return updateIngredients(
      recipe,
      ingredients: updatedIngredients,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Update ingredient at index
  static Recipe updateIngredient(
    Recipe recipe, {
    required int index,
    required String ingredient,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (index < 0 || index >= recipe.ingredients.length) {
      throw ArgumentError(
        AppLocale.current.validationInvalidIngredientIndex(index),
      );
    }

    final updatedIngredients = List<String>.from(recipe.ingredients);
    updatedIngredients[index] = ingredient;

    return updateIngredients(
      recipe,
      ingredients: updatedIngredients,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Update all instructions.
  static Recipe updateInstructions(
    Recipe recipe, {
    required List<String> instructions,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    return recipe.copyWith(
      instructions: instructions,
      lastEditedByUserId: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Add a single instruction
  static Recipe addInstruction(
    Recipe recipe, {
    required String instruction,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedInstructions = List<String>.from(recipe.instructions);
    updatedInstructions.add(instruction);

    return updateInstructions(
      recipe,
      instructions: updatedInstructions,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Remove instruction at index
  static Recipe removeInstruction(
    Recipe recipe, {
    required int index,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (index < 0 || index >= recipe.instructions.length) {
      throw ArgumentError(
        AppLocale.current.validationInvalidInstructionIndex(index),
      );
    }

    final updatedInstructions = List<String>.from(recipe.instructions);
    updatedInstructions.removeAt(index);

    return updateInstructions(
      recipe,
      instructions: updatedInstructions,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Update instruction at index
  static Recipe updateInstruction(
    Recipe recipe, {
    required int index,
    required String instruction,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (index < 0 || index >= recipe.instructions.length) {
      throw ArgumentError(
        AppLocale.current.validationInvalidInstructionIndex(index),
      );
    }

    final updatedInstructions = List<String>.from(recipe.instructions);
    updatedInstructions[index] = instruction;

    return updateInstructions(
      recipe,
      instructions: updatedInstructions,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Update all image URLs.
  static Recipe updateImageUrls(
    Recipe recipe, {
    required List<String> imageUrls,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    return recipe.copyWith(
      imageUrls: imageUrls,
      lastEditedByUserId: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Add a single image URL
  static Recipe addImageUrl(
    Recipe recipe, {
    required String imageUrl,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedImageUrls = List<String>.from(recipe.imageUrls);
    updatedImageUrls.add(imageUrl);

    return updateImageUrls(
      recipe,
      imageUrls: updatedImageUrls,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Remove image URL at index
  static Recipe removeImageUrl(
    Recipe recipe, {
    required int index,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (index < 0 || index >= recipe.imageUrls.length) {
      throw ArgumentError(AppLocale.current.validationInvalidImageIndex(index));
    }

    final updatedImageUrls = List<String>.from(recipe.imageUrls);
    updatedImageUrls.removeAt(index);

    return updateImageUrls(
      recipe,
      imageUrls: updatedImageUrls,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Validate recipe content.
  static bool isValidRecipe(Recipe recipe) {
    return recipe.title.isNotEmpty &&
        recipe.ingredients.isNotEmpty &&
        recipe.instructions.isNotEmpty;
  }

  /// Get recipe validation errors
  static List<String> getValidationErrors(Recipe recipe) {
    final l = AppLocale.current;
    final errors = <String>[];

    if (recipe.title.isEmpty) {
      errors.add(l.validationTitleCannotBeEmpty);
    }

    if (recipe.ingredients.isEmpty) {
      errors.add(l.validationIngredientRequired);
    }

    if (recipe.instructions.isEmpty) {
      errors.add(l.validationInstructionRequired);
    }

    if (recipe.portions != null && recipe.portions! <= 0) {
      errors.add(l.validationPortionsMustBePositive);
    }

    if (recipe.timeMinutes != null && recipe.timeMinutes! <= 0) {
      errors.add(l.validationTimeMustBePositive);
    }

    if (recipe.rating != null && (recipe.rating! < 0 || recipe.rating! > 5)) {
      errors.add(l.validationRatingRange);
    }

    return errors;
  }

  /// Check if recipe has required fields for publication
  static bool isPublishable(Recipe recipe) {
    return isValidRecipe(recipe) &&
        recipe.description.isNotEmpty &&
        recipe.portions != null &&
        recipe.timeMinutes != null;
  }

  /// Get recipe statistics.
  static Map<String, int> getRecipeStats(Recipe recipe) {
    return {
      'ingredientCount': recipe.ingredients.length,
      'instructionCount': recipe.instructions.length,
      'imageCount': recipe.imageUrls.length,
      'tagCount': recipe.personalTagIds?.length ?? 0,
      'estimatedMinutes': recipe.timeMinutes ?? 0,
      'portions': recipe.portions ?? 0,
    };
  }

  /// Calculate recipe complexity score (1-5)
  static int getComplexityScore(Recipe recipe) {
    final stats = getRecipeStats(recipe);
    int score = 1;

    // More ingredients = more complex
    if (stats['ingredientCount']! > 10) score++;
    if (stats['ingredientCount']! > 15) score++;

    // More instructions = more complex
    if (stats['instructionCount']! > 8) score++;
    if (stats['instructionCount']! > 12) score++;

    // Longer time = more complex
    if (stats['estimatedMinutes']! > 60) score++;
    if (stats['estimatedMinutes']! > 120) score++;

    return score.clamp(1, 5);
  }
}
