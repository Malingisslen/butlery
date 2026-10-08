// lib/services/unified/helpers/recipe_content_operations.dart

import 'package:butlery/services/unified/modules/personal_recipe_module.dart';

/// Recipe content (ingredients, instructions) operations, delegated to the
/// personal module.
class RecipeContentOperations {
  final PersonalRecipeModule personalModule;

  RecipeContentOperations({required this.personalModule});

  Future<bool> addIngredient(String recipeId, String ingredient) {
    return personalModule.addIngredient(recipeId, ingredient);
  }

  Future<bool> updateIngredient(
    String recipeId,
    int index,
    String newIngredient,
  ) {
    return personalModule.updateIngredient(recipeId, index, newIngredient);
  }

  Future<bool> removeIngredient(String recipeId, int index) {
    return personalModule.removeIngredient(recipeId, index);
  }

  Future<bool> addInstruction(String recipeId, String instruction) {
    return personalModule.addInstruction(recipeId, instruction);
  }

  Future<bool> updateInstruction(
    String recipeId,
    int index,
    String newInstruction,
  ) {
    return personalModule.updateInstruction(recipeId, index, newInstruction);
  }

  Future<bool> removeInstruction(String recipeId, int index) {
    return personalModule.removeInstruction(recipeId, index);
  }
}
