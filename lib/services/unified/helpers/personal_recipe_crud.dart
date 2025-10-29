// lib/services/unified/helpers/personal_recipe_crud.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/modules/personal_recipe_module.dart';
import 'package:butlery/services/unified/modules/recipe_cache_module.dart';

/// Helper class for personal recipe CRUD operations.
/// Delegates to PersonalRecipeModule and manages local recipe list updates.
class PersonalRecipeCrud {
  final PersonalRecipeModule personalModule;
  final RecipeCacheModule cacheModule;
  final List<Recipe> recipes;
  final void Function() notifyListeners;

  PersonalRecipeCrud({
    required this.personalModule,
    required this.cacheModule,
    required this.recipes,
    required this.notifyListeners,
  });

  /// Create a personal recipe and add to local list.
  Future<String?> createPersonalRecipe({
    required String title,
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
  }) async {
    final recipeId = await personalModule.createPersonalRecipe(
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

    if (recipeId != null) {
      // Add to local list
      final recipe = await cacheModule.loadRecipeFromCache(recipeId);
      if (recipe != null) {
        recipes.add(recipe);
        notifyListeners();
      }
    }

    return recipeId;
  }

  /// Update a recipe and update local list.
  Future<bool> updateRecipe(Recipe updatedRecipe) async {
    final success = await personalModule.updatePersonalRecipe(updatedRecipe);

    if (success) {
      // Update local list
      final index = recipes.indexWhere((r) => r.id == updatedRecipe.id);
      if (index != -1) {
        recipes[index] = updatedRecipe;
        notifyListeners();
      }
    }

    return success;
  }

  /// Delete a recipe and remove from local list.
  Future<bool> deleteRecipe(String recipeId) async {
    final success = await personalModule.deletePersonalRecipe(recipeId);

    if (success) {
      // Remove from local list
      recipes.removeWhere((r) => r.id == recipeId);
      notifyListeners();
    }

    return success;
  }

  /// Mark recipe as cooked.
  Future<bool> markAsCooked(String recipeId) async {
    return await personalModule.markRecipeAsCooked(recipeId);
  }
}
