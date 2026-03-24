import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Delegate interface for personal recipe CRUD operations
abstract class PersonalRecipeDelegate {
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
    List<String>? personalTagIds,
    String? sourceUrl,
  });
  Future<List<Recipe>> fetchAllUserRecipes(String userId);
  Future<void> saveRecipeRaw(Recipe recipe);
  Future<bool> updateRecipe(Recipe recipe);
  Future<bool> deleteRecipe(String id);
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
    List<String>? personalTagIds,
    String? sourceUrl,
  });
  Future<bool> addIngredient(String recipeId, String ingredient);
  Future<bool> updateIngredient(String recipeId, int index, String ingredient);
  Future<bool> removeIngredient(String recipeId, int index);
  Future<bool> addInstruction(String recipeId, String instruction);
  Future<bool> updateInstruction(
      String recipeId, int index, String instruction);
  Future<bool> removeInstruction(String recipeId, int index);
  Future<bool> markAsCooked(String recipeId);
}

class PersonalRecipeOperations {
  final PersonalRecipeDelegate _delegate;

  PersonalRecipeOperations(this._delegate);

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
        personalTagIds: unifiedRecipe.personalTagIds,
        sourceUrl: unifiedRecipe.sourceUrl,
      );

      return recipeId != null
          ? RecipeOperationResult.success('Recipe added successfully')
          : RecipeOperationResult.failure('Failed to add recipe');
    } catch (e) {
      return RecipeOperationResult.failure(
          'Failed to add recipe: ${e.toString()}');
    }
  }

  /// Update unified recipe
  Future<RecipeOperationResult> updateUnifiedRecipe(
      Recipe unifiedRecipe) async {
    try {
      final success = await updateRecipe(unifiedRecipe);

      return success
          ? RecipeOperationResult.success('Recipe updated successfully')
          : RecipeOperationResult.failure('Failed to update recipe');
    } catch (e) {
      return RecipeOperationResult.failure(
          'Failed to update recipe: ${e.toString()}');
    }
  }

  /// Add multiple unified recipes
  Future<RecipeOperationResult> addMultipleUnifiedRecipes(
      List<Recipe> recipes) async {
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
        return RecipeOperationResult.success(
            '${recipes.length} recipes imported');
      } else if (successCount > 0) {
        return RecipeOperationResult.success(
            '$successCount/${recipes.length} recipes imported. Errors: ${failures.join(', ')}');
      } else {
        return RecipeOperationResult.failure(
            AppLocale.current.errorCouldNotImportRecipes);
      }
    } catch (e) {
      AppLogger.error('Failed to add multiple unified recipes', e);
      return RecipeOperationResult.failure(
          AppLocale.current.errorCouldNotImportRecipes);
    }
  }

  // Delegate methods
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
    List<String>? personalTagIds,
    String? sourceUrl,
  }) async {
    return await _delegate.createRecipe(
      title: title,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      imageUrls: imageUrls,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      personalTagIds: personalTagIds,
      sourceUrl: sourceUrl,
    );
  }

  Future<List<Recipe>> fetchAllUserRecipes(String userId) async {
    return await _delegate.fetchAllUserRecipes(userId);
  }

  Future<void> saveRecipeRaw(Recipe recipe) async {
    return await _delegate.saveRecipeRaw(recipe);
  }

  Future<bool> updateRecipe(Recipe recipe) async {
    return await _delegate.updateRecipe(recipe);
  }

  // Additional methods needed by ViewModels
  Future<bool> deleteRecipe(String id) async {
    return await _delegate.deleteRecipe(id);
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
    List<String>? personalTagIds,
    String? sourceUrl,
  }) async {
    return await _delegate.updateRecipeContent(
      recipeId: recipeId,
      title: title,
      description: description,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      ingredients: ingredients,
      instructions: instructions,
      personalTagIds: personalTagIds,
      sourceUrl: sourceUrl,
    );
  }

  Future<bool> addIngredient(String recipeId, String ingredient) async {
    return await _delegate.addIngredient(recipeId, ingredient);
  }

  Future<bool> updateIngredient(
      String recipeId, int index, String ingredient) async {
    return await _delegate.updateIngredient(recipeId, index, ingredient);
  }

  Future<bool> removeIngredient(String recipeId, int index) async {
    return await _delegate.removeIngredient(recipeId, index);
  }

  Future<bool> addInstruction(String recipeId, String instruction) async {
    return await _delegate.addInstruction(recipeId, instruction);
  }

  Future<bool> updateInstruction(
      String recipeId, int index, String instruction) async {
    return await _delegate.updateInstruction(recipeId, index, instruction);
  }

  Future<bool> removeInstruction(String recipeId, int index) async {
    return await _delegate.removeInstruction(recipeId, index);
  }

  Future<bool> markAsCooked(String recipeId) async {
    return await _delegate.markAsCooked(recipeId);
  }

  // Legacy compatibility methods for ViewModel
  Future<RecipeOperationResult> addLegacyRecipe(Recipe recipe) async {
    return await addUnifiedRecipe(recipe);
  }

  Future<RecipeOperationResult> updateLegacyRecipe(Recipe recipe) async {
    return await updateUnifiedRecipe(recipe);
  }
}
