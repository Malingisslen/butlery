// lib/services/unified/helpers/recipe_content_operations.dart

import 'package:butlery/services/unified/modules/personal_recipe_module.dart';
import 'package:butlery/services/unified/modules/realtime_recipe_module.dart';

/// Helper class for managing recipe content (ingredients, instructions) operations.
/// Routes operations to either personal module or realtime module based on editing session status.
class RecipeContentOperations {
  final PersonalRecipeModule personalModule;
  final RealtimeRecipeModule realtimeModule;
  final bool Function(String) isInRealtimeSession;

  RecipeContentOperations({
    required this.personalModule,
    required this.realtimeModule,
    required this.isInRealtimeSession,
  });

  // ===== INGREDIENT OPERATIONS =====

  Future<bool> addIngredient(String recipeId, String ingredient) async {
    if (isInRealtimeSession(recipeId)) {
      return await realtimeModule.addIngredientRealtime(recipeId, ingredient, null);
    } else {
      return await personalModule.addIngredient(recipeId, ingredient);
    }
  }

  Future<bool> updateIngredient(String recipeId, int index, String newIngredient) async {
    if (isInRealtimeSession(recipeId)) {
      return await realtimeModule.updateIngredientRealtime(recipeId, index, newIngredient);
    } else {
      return await personalModule.updateIngredient(recipeId, index, newIngredient);
    }
  }

  Future<bool> removeIngredient(String recipeId, int index) async {
    if (isInRealtimeSession(recipeId)) {
      return await realtimeModule.removeIngredientRealtime(recipeId, index);
    } else {
      return await personalModule.removeIngredient(recipeId, index);
    }
  }

  // ===== INSTRUCTION OPERATIONS =====

  Future<bool> addInstruction(String recipeId, String instruction) async {
    if (isInRealtimeSession(recipeId)) {
      return await realtimeModule.addInstructionRealtime(recipeId, instruction, null);
    } else {
      return await personalModule.addInstruction(recipeId, instruction);
    }
  }

  Future<bool> updateInstruction(String recipeId, int index, String newInstruction) async {
    if (isInRealtimeSession(recipeId)) {
      return await realtimeModule.updateInstructionRealtime(recipeId, index, newInstruction);
    } else {
      return await personalModule.updateInstruction(recipeId, index, newInstruction);
    }
  }

  Future<bool> removeInstruction(String recipeId, int index) async {
    if (isInRealtimeSession(recipeId)) {
      return await realtimeModule.removeInstructionRealtime(recipeId, index);
    } else {
      return await personalModule.removeInstruction(recipeId, index);
    }
  }
}
