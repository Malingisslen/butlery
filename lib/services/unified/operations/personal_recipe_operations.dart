import '../../../models/recipe_unified.dart';
import '../../../core/utils/logger.dart';
import '../types/recipe_types.dart';

/// Personal recipe operations feature interface
/// Handles create, read, update, delete operations for personal recipes
class PersonalRecipeOperations {
  final dynamic _parent;

  PersonalRecipeOperations(this._parent);

  /// Add unified recipe
  Future<RecipeOperationResult> addUnifiedRecipe(Recipe unifiedRecipe) async {
    try {
      final recipeId = await createRecipe(
        title: unifiedRecipe.title,
        description: unifiedRecipe.description,
        ingredients: unifiedRecipe.ingredients,
        instructions: unifiedRecipe.instructions,
        imageUrls: unifiedRecipe.imageUrls,
        mealType: unifiedRecipe.mealType,
        portions: unifiedRecipe.portions,
        timeMinutes: unifiedRecipe.timeMinutes,
        rating: unifiedRecipe.rating,
        tags: unifiedRecipe.tags,
        sourceUrl: unifiedRecipe.sourceUrl,
      );
      
      return recipeId != null 
          ? RecipeOperationResult.success('Recipe added successfully')
          : RecipeOperationResult.failure('Failed to add recipe');
    } catch (e) {
      return RecipeOperationResult.failure('Failed to add recipe: ${e.toString()}');
    }
  }

  /// Update unified recipe
  Future<RecipeOperationResult> updateUnifiedRecipe(Recipe unifiedRecipe) async {
    try {
      final success = await updateRecipe(unifiedRecipe);
      
      return success 
          ? RecipeOperationResult.success('Recipe updated successfully')
          : RecipeOperationResult.failure('Failed to update recipe');
    } catch (e) {
      return RecipeOperationResult.failure('Failed to update recipe: ${e.toString()}');
    }
  }

  /// Add multiple unified recipes
  Future<RecipeOperationResult> addMultipleUnifiedRecipes(List<Recipe> recipes) async {
    try {
      int successCount = 0;
      final failures = <String>[];

      for (final recipe in recipes) {
        final result = await addUnifiedRecipe(recipe);
        if (result.isSuccess) {
          successCount++;
        } else {
          failures.add('${recipe.title}: ${result.message}');
        }
      }

      if (successCount == recipes.length) {
        return RecipeOperationResult.success('Alla ${recipes.length} recept importerade');
      } else if (successCount > 0) {
        return RecipeOperationResult.success(
          '$successCount av ${recipes.length} recept importerade. Fel: ${failures.join(', ')}'
        );
      } else {
        return RecipeOperationResult.failure(
          'Kunde inte importera några recept. Fel: ${failures.join(', ')}'
        );
      }
    } catch (e) {
      AppLogger.error('Failed to add multiple unified recipes', e);
      return RecipeOperationResult.failure('Batch import fel: $e');
    }
  }

  // Delegate methods to parent service
  Future<String?> createRecipe({
    required String title,
    required String description,
    required List<String> ingredients,
    required List<String> instructions,
    required List<String> imageUrls,
    required String mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    String? sourceUrl,
  }) async {
    return await _parent.createRecipe(
      title: title,
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
    );
  }

  Future<bool> updateRecipe(Recipe recipe) async {
    return await _parent.updateRecipe(recipe);
  }

  // Additional methods needed by ViewModels
  Future<bool> deleteRecipe(String id) async {
    return await _parent.deleteRecipe(id);
  }

  Future<bool> updateRecipeContent({
    required String recipeId,
    String? title,
    String? description,
    String? mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? tags,
    String? sourceUrl,
  }) async {
    return await _parent.updateRecipeContent(
      recipeId: recipeId,
      title: title,
      description: description,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      ingredients: ingredients,
      instructions: instructions,
      tags: tags,
      sourceUrl: sourceUrl,
    );
  }

  Future<bool> addIngredient(String recipeId, String ingredient) async {
    return await _parent.addIngredient(recipeId, ingredient);
  }

  Future<bool> updateIngredient(String recipeId, int index, String ingredient) async {
    return await _parent.updateIngredient(recipeId, index, ingredient);
  }

  Future<bool> removeIngredient(String recipeId, int index) async {
    return await _parent.removeIngredient(recipeId, index);
  }

  Future<bool> addInstruction(String recipeId, String instruction) async {
    return await _parent.addInstruction(recipeId, instruction);
  }

  Future<bool> updateInstruction(String recipeId, int index, String instruction) async {
    return await _parent.updateInstruction(recipeId, index, instruction);
  }

  Future<bool> removeInstruction(String recipeId, int index) async {
    return await _parent.removeInstruction(recipeId, index);
  }

  Future<bool> markAsCooked(String recipeId) async {
    return await _parent.markAsCooked(recipeId);
  }

  // Legacy compatibility methods for ViewModel
  Future<RecipeOperationResult> addLegacyRecipe(Recipe recipe) async {
    return await addUnifiedRecipe(recipe);
  }

  Future<RecipeOperationResult> updateLegacyRecipe(Recipe recipe) async {
    return await updateUnifiedRecipe(recipe);
  }
}