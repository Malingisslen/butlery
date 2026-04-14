// lib/services/unified/helpers/personal_recipe_crud.dart

import 'package:flutter/foundation.dart' show kIsWeb;
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
    List<String>? personalTagIds,
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
      personalTagIds: personalTagIds,
      sourceUrl: sourceUrl,
    );

    if (recipeId != null) {
      // BUG-003 FIX: On web, cache is stubbed so we use direct recipe access
      // instead of loading from cache (which would return null).
      Recipe? recipe;
      if (kIsWeb) {
        // Get the recipe directly from the module (stored during create)
        recipe = personalModule.popLastCreatedRecipe();
      } else {
        // On mobile, load from cache as before
        recipe = await cacheModule.loadRecipeFromCache(recipeId);
      }

      if (recipe != null) {
        // Dedup: Firebase sync listener may have already added this recipe
        // to the list (race between optimistic add and listener callback).
        final newId = recipe.id;
        if (!recipes.any((r) => r.id == newId)) {
          recipes.add(recipe);
        }
        notifyListeners();
      }
    }

    return recipeId;
  }

  /// Save recipe directly without re-tagging (for batch retag operations).
  Future<void> saveRecipeRaw(Recipe recipe) async {
    await personalModule.saveRecipeRaw(recipe);

    final index = recipes.indexWhere((r) => r.id == recipe.id);
    if (index != -1) {
      recipes[index] = recipe;
      notifyListeners();
    }
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
