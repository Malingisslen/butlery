// lib/services/unified/helpers/personal_recipe_crud.dart

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/unified/modules/personal_recipe_module.dart';
import 'package:butlery/services/unified/modules/recipe_cache_module.dart';
import 'package:butlery/utils/retry_policy.dart';

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
  ///
  /// Idempotent: writes to a known recipe-ID document, so retrying transient
  /// network failures is safe (would just rewrite the same data).
  Future<void> saveRecipeRaw(Recipe recipe) async {
    await withRetry(
      () => personalModule.saveRecipeRaw(recipe),
      maxAttempts: 3,
    );

    final index = recipes.indexWhere((r) => r.id == recipe.id);
    if (index != -1) {
      recipes[index] = recipe;
      notifyListeners();
    }
  }

  /// Update a recipe and update local list.
  ///
  /// Idempotent: targets an existing recipe by ID, retrying is safe.
  Future<bool> updateRecipe(Recipe updatedRecipe) async {
    final success = await withRetry(
      () => personalModule.updatePersonalRecipe(updatedRecipe),
      maxAttempts: 3,
    );

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

      // BUT-893: scrub the recipe from any weekly menu plan that referenced
      // it so users don't see blank slots / 404 taps. Fire-and-forget — a
      // menu-cleanup failure is logged but must not surface as a failed
      // delete to the user (the recipe IS gone from Firestore at this point).
      unawaited(_cascadeRemoveFromWeeklyMenus(recipeId));
    }

    return success;
  }

  Future<void> _cascadeRemoveFromWeeklyMenus(String recipeId) async {
    try {
      final menuService = ServiceLocator.tryGet<WeeklyMenuPlanService>();
      if (menuService == null) return;
      await menuService.removeRecipeFromAllPlans(recipeId);
    } catch (e, st) {
      AppLogger.warning(
        'BUT-893 cascade failed for recipe $recipeId: $e\n$st',
      );
    }
  }

  /// Mark recipe as cooked.
  Future<bool> markAsCooked(String recipeId) async {
    return await personalModule.markRecipeAsCooked(recipeId);
  }
}
