// lib/services/unified/helpers/recipe_utility_operations.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/modules/recipe_cache_module.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Helper class for recipe utility operations (refresh, save from social, etc.).
class RecipeUtilityOperations {
  final RecipeCacheModule cacheModule;
  final FirebaseAuthRepository authRepository;
  final List<Recipe> recipes;
  final RecipeServiceAdapter Function() getServiceAdapter;
  final Recipe? Function(String) getRecipeById;
  final void Function(String) setError;
  final void Function(bool) setLoading;
  final void Function() notifyListeners;

  RecipeUtilityOperations({
    required this.cacheModule,
    required this.authRepository,
    required this.recipes,
    required this.getServiceAdapter,
    required this.getRecipeById,
    required this.setError,
    required this.setLoading,
    required this.notifyListeners,
  });

  /// Save a recipe from the social module (handles both create and update).
  Future<bool> saveRecipeForSocialModule(Recipe recipe) async {
    try {
      final serviceAdapter = getServiceAdapter();

      // Check if this recipe already exists
      final existingRecipe = getRecipeById(recipe.id);

      if (existingRecipe != null) {
        // Update existing recipe
        final success = await serviceAdapter.updateRecipe(recipe);
        if (success) {
          // Update local cache
          final index = recipes.indexWhere((r) => r.id == recipe.id);
          if (index != -1) {
            recipes[index] = recipe;
            notifyListeners();
          }
        }
        return success;
      } else {
        // Create new recipe
        final createdId = await serviceAdapter.createRecipe(recipe);
        if (createdId != null) {
          // Add to local cache
          recipes.add(recipe);
          notifyListeners();
          return true;
        }
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Failed to save recipe from social module: $e');
      return false;
    }
  }

  /// Refresh all recipes from cache and restart Firebase sync.
  Future<void> refresh() async {
    try {
      setLoading(true);
      notifyListeners();

      // Clear local data
      recipes.clear();

      // Reload from cache
      final cachedRecipes = await cacheModule.initializeCache();
      recipes.addAll(cachedRecipes);

      // Restart Firebase sync
      await cacheModule.stopFirebaseSync();
      if (authRepository.currentUser != null) {
        await cacheModule.startFirebaseSync();
      }

      setLoading(false);
      notifyListeners();
    } catch (e) {
      setError(AppLocale.current.errorCouldNotUpdateRecipes);
      setLoading(false);
      notifyListeners();
    }
  }

  /// Update recipe content with partial updates.
  Future<bool> updateRecipeContent({
    required String recipeId,
    required String? currentUserId,
    required String? currentUserDisplayName,
    required Future<bool> Function(Recipe) updateRecipe,
    String? title,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? imageUrls,
    String? mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
  }) async {
    final recipe = getRecipeById(recipeId);
    if (recipe == null) {
      setError(AppLocale.current.errorRecipeNotFound);
      return false;
    }

    final updatedRecipe = recipe.copyWith(
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
      lastEditedByUserId: currentUserId,
      lastEditedByDisplayName: currentUserDisplayName,
    );

    return await updateRecipe(updatedRecipe);
  }
}
