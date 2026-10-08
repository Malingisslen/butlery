// lib/services/unified/operations/realtime_recipe/collaboration_management_module.dart

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/operations/modules/recipe_sharing_manager.dart'
    show CreateCollaborativeRecipeFn, CreatePersonalRecipeFn;

/// Converts a personal recipe into a social (shared) recipe and back, the
/// "Samarbete" toggle on the recipe detail screen. Nothing here writes
/// `realtime_recipes`.
class CollaborationManagementModule {
  final List<Recipe> Function() _getRecipes;
  final CreateCollaborativeRecipeFn _createCollaborativeRecipe;
  final CreatePersonalRecipeFn _createPersonalRecipe;
  final Future<bool> Function(String) _deleteRecipe;

  CollaborationManagementModule({
    required List<Recipe> Function() getRecipes,
    required CreateCollaborativeRecipeFn createCollaborativeRecipe,
    required CreatePersonalRecipeFn createPersonalRecipe,
    required Future<bool> Function(String) deleteRecipe,
  }) : _getRecipes = getRecipes,
       _createCollaborativeRecipe = createCollaborativeRecipe,
       _createPersonalRecipe = createPersonalRecipe,
       _deleteRecipe = deleteRecipe;

  /// Enable collaborative editing for a personal recipe
  Future<bool> enableCollaborativeEditing(
    String recipeId,
    List<String> memberIds,
  ) async {
    try {
      final recipe = _getRecipes().where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) {
        AppLogger.error(
          'Cannot enable collaborative editing: Recipe not found',
        );
        return false;
      }

      if (recipe.isCollaborative) {
        AppLogger.warning('Recipe is already collaborative');
        return true;
      }

      if (!ServiceLocator.get<PermissionService>().isRecipeOwner(recipeId)) {
        AppLogger.error('Only recipe owner can enable collaborative editing');
        return false;
      }

      if (memberIds.isEmpty) {
        AppLogger.error(
          'At least one member must be specified to enable collaboration',
        );
        return false;
      }

      // Convert to collaborative recipe
      final collaborativeRecipeId = await _createCollaborativeRecipe(
        title: recipe.title,
        memberIds: memberIds,
        description: recipe.description,
        ingredients: recipe.ingredients,
        instructions: recipe.instructions,
        imageUrls: recipe.imageUrls,
        mealType: recipe.mealType,
        portions: recipe.portions,
        timeMinutes: recipe.timeMinutes,
        rating: recipe.rating,
        personalTagIds: recipe.personalTagIds,
        sourceUrl: recipe.sourceUrl,
      );

      if (collaborativeRecipeId != null) {
        // Delete original personal recipe
        await _deleteRecipe(recipeId);

        AppLogger.success(
          'Enabled collaborative editing for recipe: ${recipe.title}',
        );
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Failed to enable collaborative editing', e);
      return false;
    }
  }

  /// Disable collaborative editing and convert back to personal recipe
  Future<bool> disableCollaborativeEditing(String recipeId) async {
    try {
      final recipe = _getRecipes().where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) {
        AppLogger.error(
          'Cannot disable collaborative editing: Recipe not found',
        );
        return false;
      }

      if (!recipe.isCollaborative) {
        AppLogger.warning('Recipe is not collaborative');
        return true;
      }

      if (!ServiceLocator.get<PermissionService>().isRecipeOwner(recipeId)) {
        AppLogger.error('Only recipe owner can disable collaborative editing');
        return false;
      }

      // Convert back to personal recipe
      final personalRecipeId = await _createPersonalRecipe(
        title: recipe.title,
        description: recipe.description,
        ingredients: recipe.ingredients,
        instructions: recipe.instructions,
        imageUrls: recipe.imageUrls,
        mealType: recipe.mealType,
        portions: recipe.portions,
        timeMinutes: recipe.timeMinutes,
        rating: recipe.rating,
        personalTagIds: recipe.personalTagIds,
        sourceUrl: recipe.sourceUrl,
      );

      if (personalRecipeId != null) {
        // Delete collaborative recipe
        await _deleteRecipe(recipeId);
        AppLogger.success(
          'Disabled collaborative editing for recipe: ${recipe.title}',
        );
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Failed to disable collaborative editing', e);
      return false;
    }
  }
}
