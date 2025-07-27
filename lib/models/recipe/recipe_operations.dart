// lib/models/recipe/recipe_operations.dart

import 'package:butlery/models/recipe_unified.dart';

/// Focused module for recipe content operations
/// 
/// This module handles ONLY recipe content manipulation:
/// - Ingredient CRUD operations
/// - Instruction CRUD operations
/// - Recipe state changes (mark as cooked)
/// - Content validation and updates
/// 
/// ❌ DOES NOT CONTAIN: Serialization, social features, metadata management
class RecipeOperations {
  
  // ===== INGREDIENT OPERATIONS =====

  /// Add ingredient with user tracking
  static Recipe addIngredient(
    Recipe recipe,
    String ingredient, {
    String? userId,
    String? userDisplayName,
  }) {
    if (ingredient.trim().isEmpty) return recipe;
    
    final updatedIngredients = [...recipe.core.ingredients, ingredient.trim()];
    return recipe.copyWith(
      ingredients: updatedIngredients,
      lastEditedByUserId: userId,
      lastEditedByDisplayName: userDisplayName,
    );
  }

  /// Update ingredient at specific index
  static Recipe updateIngredient(
    Recipe recipe,
    int index,
    String newIngredient, {
    String? userId,
    String? userDisplayName,
  }) {
    if (index < 0 || index >= recipe.core.ingredients.length) return recipe;
    if (newIngredient.trim().isEmpty) return recipe;
    
    final updatedIngredients = [...recipe.core.ingredients];
    updatedIngredients[index] = newIngredient.trim();
    
    return recipe.copyWith(
      ingredients: updatedIngredients,
      lastEditedByUserId: userId,
      lastEditedByDisplayName: userDisplayName,
    );
  }

  /// Remove ingredient at specific index
  static Recipe removeIngredient(
    Recipe recipe,
    int index, {
    String? userId,
    String? userDisplayName,
  }) {
    if (index < 0 || index >= recipe.core.ingredients.length) return recipe;
    
    final updatedIngredients = [...recipe.core.ingredients];
    updatedIngredients.removeAt(index);
    
    return recipe.copyWith(
      ingredients: updatedIngredients,
      lastEditedByUserId: userId,
      lastEditedByDisplayName: userDisplayName,
    );
  }

  /// Replace all ingredients
  static Recipe updateAllIngredients(
    Recipe recipe,
    List<String> newIngredients, {
    String? userId,
    String? userDisplayName,
  }) {
    final cleanedIngredients = newIngredients
        .map((ingredient) => ingredient.trim())
        .where((ingredient) => ingredient.isNotEmpty)
        .toList();
    
    return recipe.copyWith(
      ingredients: cleanedIngredients,
      lastEditedByUserId: userId,
      lastEditedByDisplayName: userDisplayName,
    );
  }

  /// Reorder ingredients
  static Recipe reorderIngredients(
    Recipe recipe,
    int fromIndex,
    int toIndex, {
    String? userId,
    String? userDisplayName,
  }) {
    if (fromIndex < 0 || fromIndex >= recipe.core.ingredients.length ||
        toIndex < 0 || toIndex >= recipe.core.ingredients.length ||
        fromIndex == toIndex) {
      return recipe;
    }
    
    final updatedIngredients = [...recipe.core.ingredients];
    final ingredient = updatedIngredients.removeAt(fromIndex);
    updatedIngredients.insert(toIndex, ingredient);
    
    return recipe.copyWith(
      ingredients: updatedIngredients,
      lastEditedByUserId: userId,
      lastEditedByDisplayName: userDisplayName,
    );
  }

  // ===== INSTRUCTION OPERATIONS =====

  /// Add instruction with user tracking
  static Recipe addInstruction(
    Recipe recipe,
    String instruction, {
    String? userId,
    String? userDisplayName,
  }) {
    if (instruction.trim().isEmpty) return recipe;
    
    final updatedInstructions = [...recipe.core.instructions, instruction.trim()];
    return recipe.copyWith(
      instructions: updatedInstructions,
      lastEditedByUserId: userId,
      lastEditedByDisplayName: userDisplayName,
    );
  }

  /// Update instruction at specific index
  static Recipe updateInstruction(
    Recipe recipe,
    int index,
    String newInstruction, {
    String? userId,
    String? userDisplayName,
  }) {
    if (index < 0 || index >= recipe.core.instructions.length) return recipe;
    if (newInstruction.trim().isEmpty) return recipe;
    
    final updatedInstructions = [...recipe.core.instructions];
    updatedInstructions[index] = newInstruction.trim();
    
    return recipe.copyWith(
      instructions: updatedInstructions,
      lastEditedByUserId: userId,
      lastEditedByDisplayName: userDisplayName,
    );
  }

  /// Remove instruction at specific index
  static Recipe removeInstruction(
    Recipe recipe,
    int index, {
    String? userId,
    String? userDisplayName,
  }) {
    if (index < 0 || index >= recipe.core.instructions.length) return recipe;
    
    final updatedInstructions = [...recipe.core.instructions];
    updatedInstructions.removeAt(index);
    
    return recipe.copyWith(
      instructions: updatedInstructions,
      lastEditedByUserId: userId,
      lastEditedByDisplayName: userDisplayName,
    );
  }

  /// Replace all instructions
  static Recipe updateAllInstructions(
    Recipe recipe,
    List<String> newInstructions, {
    String? userId,
    String? userDisplayName,
  }) {
    final cleanedInstructions = newInstructions
        .map((instruction) => instruction.trim())
        .where((instruction) => instruction.isNotEmpty)
        .toList();
    
    return recipe.copyWith(
      instructions: cleanedInstructions,
      lastEditedByUserId: userId,
      lastEditedByDisplayName: userDisplayName,
    );
  }

  /// Reorder instructions
  static Recipe reorderInstructions(
    Recipe recipe,
    int fromIndex,
    int toIndex, {
    String? userId,
    String? userDisplayName,
  }) {
    if (fromIndex < 0 || fromIndex >= recipe.core.instructions.length ||
        toIndex < 0 || toIndex >= recipe.core.instructions.length ||
        fromIndex == toIndex) {
      return recipe;
    }
    
    final updatedInstructions = [...recipe.core.instructions];
    final instruction = updatedInstructions.removeAt(fromIndex);
    updatedInstructions.insert(toIndex, instruction);
    
    return recipe.copyWith(
      instructions: updatedInstructions,
      lastEditedByUserId: userId,
      lastEditedByDisplayName: userDisplayName,
    );
  }

  // ===== IMAGE OPERATIONS =====

  /// Add image URL
  static Recipe addImageUrl(
    Recipe recipe,
    String imageUrl, {
    String? userId,
    String? userDisplayName,
  }) {
    if (imageUrl.trim().isEmpty) return recipe;
    
    final updatedImageUrls = [...recipe.core.imageUrls, imageUrl.trim()];
    return recipe.copyWith(
      imageUrls: updatedImageUrls,
      lastEditedByUserId: userId,
      lastEditedByDisplayName: userDisplayName,
    );
  }

  /// Remove image URL at specific index
  static Recipe removeImageUrl(
    Recipe recipe,
    int index, {
    String? userId,
    String? userDisplayName,
  }) {
    if (index < 0 || index >= recipe.core.imageUrls.length) return recipe;
    
    final updatedImageUrls = [...recipe.core.imageUrls];
    updatedImageUrls.removeAt(index);
    
    return recipe.copyWith(
      imageUrls: updatedImageUrls,
      lastEditedByUserId: userId,
      lastEditedByDisplayName: userDisplayName,
    );
  }

  /// Update all image URLs
  static Recipe updateImageUrls(
    Recipe recipe,
    List<String> newImageUrls, {
    String? userId,
    String? userDisplayName,
  }) {
    final cleanedImageUrls = newImageUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
    
    return recipe.copyWith(
      imageUrls: cleanedImageUrls,
      lastEditedByUserId: userId,
      lastEditedByDisplayName: userDisplayName,
    );
  }

  // ===== RECIPE STATE OPERATIONS =====

  /// Mark recipe as cooked
  static Recipe markAsCooked(
    Recipe recipe, {
    String? userId,
    String? userDisplayName,
  }) {
    return recipe.copyWith(
      lastCookedAt: DateTime.now(),
      lastEditedByUserId: userId,
      lastEditedByDisplayName: userDisplayName,
    );
  }

  /// Update basic recipe information
  static Recipe updateBasicInfo(
    Recipe recipe, {
    String? title,
    String? description,
    String? mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    String? sourceUrl,
    bool? isPublic,
    String? userId,
    String? userDisplayName,
  }) {
    return recipe.copyWith(
      title: title,
      description: description,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      tags: tags,
      sourceUrl: sourceUrl,
      isPublic: isPublic,
      lastEditedByUserId: userId,
      lastEditedByDisplayName: userDisplayName,
    );
  }

  // ===== VALIDATION =====

  /// Validate recipe for completeness
  static bool isValidRecipe(Recipe recipe) {
    if (recipe.core.title.trim().isEmpty) return false;
    if (recipe.core.ingredients.isEmpty) return false;
    if (recipe.core.instructions.isEmpty) return false;
    if (recipe.core.mealType.trim().isEmpty) return false;
    return true;
  }

  /// Get validation errors
  static List<String> getValidationErrors(Recipe recipe) {
    final errors = <String>[];
    
    if (recipe.core.title.trim().isEmpty) {
      errors.add('Titel saknas');
    }
    if (recipe.core.ingredients.isEmpty) {
      errors.add('Ingredienser saknas');
    }
    if (recipe.core.instructions.isEmpty) {
      errors.add('Instruktioner saknas');
    }
    if (recipe.core.mealType.trim().isEmpty) {
      errors.add('Måltidstyp saknas');
    }
    
    return errors;
  }

  /// Check if recipe is ready for publishing
  static bool isPublishable(Recipe recipe) {
    if (!isValidRecipe(recipe)) return false;
    if (recipe.core.description.trim().isEmpty) return false;
    if (recipe.core.portions == null || recipe.core.portions! <= 0) return false;
    return true;
  }

  // ===== STATISTICS =====

  /// Get recipe statistics
  static Map<String, int> getRecipeStats(Recipe recipe) {
    return {
      'ingredientCount': recipe.core.ingredients.length,
      'instructionCount': recipe.core.instructions.length,
      'imageCount': recipe.core.imageUrls.length,
      'tagCount': recipe.core.tags?.length ?? 0,
      'estimatedMinutes': recipe.core.timeMinutes ?? 0,
      'portions': recipe.core.portions ?? 0,
    };
  }

  /// Get complexity score (1-5)
  static int getComplexityScore(Recipe recipe) {
    int score = 1;
    
    // More ingredients increase complexity
    if (recipe.core.ingredients.length > 5) score++;
    if (recipe.core.ingredients.length > 10) score++;
    
    // More instructions increase complexity
    if (recipe.core.instructions.length > 3) score++;
    if (recipe.core.instructions.length > 6) score++;
    
    // Long cooking time increases complexity
    final timeMinutes = recipe.core.timeMinutes ?? 0;
    if (timeMinutes > 30) score++;
    if (timeMinutes > 60) score++;
    
    return score.clamp(1, 5);
  }

  /// Estimate preparation time based on content
  static int estimatePreparationTime(Recipe recipe) {
    int baseTime = 15; // Base preparation time
    
    // Add time based on ingredient count
    baseTime += recipe.core.ingredients.length * 2;
    
    // Add time based on instruction complexity
    for (final instruction in recipe.core.instructions) {
      if (instruction.toLowerCase().contains('chop') || 
          instruction.toLowerCase().contains('dice') ||
          instruction.toLowerCase().contains('mince')) {
        baseTime += 5;
      }
      if (instruction.toLowerCase().contains('marinate') ||
          instruction.toLowerCase().contains('rest')) {
        baseTime += 10;
      }
    }
    
    return baseTime;
  }
}