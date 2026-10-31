// lib/services/unified/helpers/recipe_content_operations.dart

import 'package:butlery/models/recipe/recipe_operations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';

/// Recipe content (ingredients, instructions) operations. Each one edits the
/// recipe the service holds and hands it to [saveRecipe], which must also
/// refresh the service's own recipe list: a second edit is computed from that
/// list.
class RecipeContentOperations {
  final Recipe? Function(String recipeId) _lookupRecipe;
  final Future<bool> Function(Recipe recipe) _saveRecipe;

  RecipeContentOperations({
    required Recipe? Function(String recipeId) lookupRecipe,
    required Future<bool> Function(Recipe recipe) saveRecipe,
  }) : _lookupRecipe = lookupRecipe,
       _saveRecipe = saveRecipe;

  Future<bool> addIngredient(String recipeId, String ingredient) {
    return _edit(
      recipeId,
      (recipe) => RecipeOperations.addIngredient(recipe, ingredient),
    );
  }

  Future<bool> updateIngredient(
    String recipeId,
    int index,
    String newIngredient,
  ) {
    return _edit(
      recipeId,
      (recipe) => RecipeOperations.updateIngredient(
        recipe,
        index,
        newIngredient,
      ),
    );
  }

  Future<bool> removeIngredient(String recipeId, int index) {
    return _edit(
      recipeId,
      (recipe) => RecipeOperations.removeIngredient(recipe, index),
    );
  }

  Future<bool> addInstruction(String recipeId, String instruction) {
    return _edit(
      recipeId,
      (recipe) => RecipeOperations.addInstruction(recipe, instruction),
    );
  }

  Future<bool> updateInstruction(
    String recipeId,
    int index,
    String newInstruction,
  ) {
    return _edit(
      recipeId,
      (recipe) => RecipeOperations.updateInstruction(
        recipe,
        index,
        newInstruction,
      ),
    );
  }

  Future<bool> removeInstruction(String recipeId, int index) {
    return _edit(
      recipeId,
      (recipe) => RecipeOperations.removeInstruction(recipe, index),
    );
  }

  /// False when the recipe is not loaded or the edit changed nothing (bad
  /// index, blank text): RecipeOperations hands back the same instance then,
  /// and reporting that as saved is what made the UI claim a swap that never
  /// happened.
  Future<bool> _edit(String recipeId, Recipe Function(Recipe) apply) async {
    final recipe = _lookupRecipe(recipeId);
    if (recipe == null) {
      AppLogger.warning('Recipe edit skipped, recipe not loaded: $recipeId');
      return false;
    }
    final edited = apply(recipe);
    if (identical(edited, recipe)) return false;
    return _saveRecipe(edited);
  }
}
