// lib/viewmodels/recipe/personal_recipe_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/types/recipe_types.dart'
    show RecipeOperationResult;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

/// Personal Recipe ViewModel
/// Handles ONLY personal recipe operations and management.
/// This includes creation, editing, deletion, and content management for personal recipes.
class PersonalRecipeViewModel extends ChangeNotifier
    with ErrorHandlingMixin, StreamManagementMixin {
  final UnifiedRecipeService _recipeService =
      ServiceLocator.get<UnifiedRecipeService>();

  String get serviceName => 'PersonalRecipeViewModel';
  List<Recipe> get personalRecipes => _recipeService.personalRecipes;
  bool get hasPersonalRecipes => personalRecipes.isNotEmpty;
  int get personalRecipeCount => personalRecipes.length;

  String? get currentUserId => _recipeService.currentUserId;
  String? get currentUserDisplayName => _recipeService.currentUserDisplayName;
  Future<bool> createPersonalRecipe({
    required String name,
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
    // Use ValidationUtils for consistent validation
    final nameError = ValidationUtils.validateRecipeName(name);
    if (nameError != null) return false;

    return await safeExecute(
          () async {
            final recipeId = await _recipeService.personal.createRecipe(
              title: name.trim(),
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
              AppLogger.success('✅ Created personal recipe: ${name.trim()}');
            }
            return recipeId != null;
          },
          operationName: 'Create Personal Recipe',
          defaultValue: false,
        ) ??
        false;
  }

  Future<bool> updatePersonalRecipe(Recipe recipe) async {
    if (!recipe.isPersonal) return false;

    final result = await _recipeService.personal.updateRecipe(recipe);
    if (result) {
      AppLogger.info('✅ Updated personal recipe: ${recipe.core.title}');
    }
    return result;
  }

  Future<bool> deletePersonalRecipe(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;

    final result = await _recipeService.personal.deleteRecipe(recipeId);
    if (result) {
      AppLogger.warning('🗑️ Deleted personal recipe: ${recipe.core.title}');
    }
    return result;
  }

  Future<bool> updateRecipeContent({
    required String recipeId,
    String? name,
    String? description,
    String? mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
  }) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;

    // Validate name if provided
    if (name != null) {
      final nameError = ValidationUtils.validateRecipeName(name);
      if (nameError != null) return false;
    }

    final result = await _recipeService.personal.updateRecipeContent(
      recipeId: recipeId,
      title: name,
      description: description,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      personalTagIds: personalTagIds,
      sourceUrl: sourceUrl,
    );
    if (result) {
      AppLogger.info('✅ Updated recipe content: ${recipe.core.title}');
    }
    return result;
  }

  Future<bool> addIngredient(String recipeId, String ingredient) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) ||
        ValidationUtils.isNullOrEmpty(ingredient)) {
      return false;
    }

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;

    final result =
        await _recipeService.personal.addIngredient(recipeId, ingredient);
    if (result) {
      AppLogger.info(
          '✅ Added ingredient to personal recipe: ${recipe.core.title}');
    }
    return result;
  }

  Future<bool> updateIngredient(
      String recipeId, int index, String newIngredient) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) ||
        ValidationUtils.isNullOrEmpty(newIngredient)) {
      return false;
    }

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;

    final result = await _recipeService.personal
        .updateIngredient(recipeId, index, newIngredient);
    if (result) {
      AppLogger.info(
          '✅ Updated ingredient in personal recipe: ${recipe.core.title}');
    }
    return result;
  }

  Future<bool> removeIngredient(String recipeId, int index) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;

    final result =
        await _recipeService.personal.removeIngredient(recipeId, index);
    if (result) {
      AppLogger.info(
          '🗑️ Removed ingredient from personal recipe: ${recipe.core.title}');
    }
    return result;
  }

  Future<bool> addInstruction(String recipeId, String instruction) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) ||
        ValidationUtils.isNullOrEmpty(instruction)) {
      return false;
    }

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;

    return await _recipeService.personal.addInstruction(recipeId, instruction);
  }

  Future<bool> updateInstruction(
      String recipeId, int index, String newInstruction) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) ||
        ValidationUtils.isNullOrEmpty(newInstruction)) {
      return false;
    }

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;

    return await _recipeService.personal
        .updateInstruction(recipeId, index, newInstruction);
  }

  Future<bool> removeInstruction(String recipeId, int index) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;

    return await _recipeService.personal.removeInstruction(recipeId, index);
  }

  Future<bool> markAsCooked(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;

    return await _recipeService.personal.markAsCooked(recipeId);
  }

  Future<RecipeOperationResult> addLegacyRecipe(Recipe recipe) async {
    if (!recipe.isPersonal) {
      return RecipeOperationResult.failure('Recipe is not personal');
    }

    return await safeExecute(
          () async {
            final result =
                await _recipeService.personal.addLegacyRecipe(recipe);
            if (result.isSuccess) {
              AppLogger.success(
                  '✅ Added legacy personal recipe: ${recipe.core.title}');
            }
            return result;
          },
          operationName: 'Add Legacy Personal Recipe',
          defaultValue: RecipeOperationResult.failure('Failed to add recipe'),
        ) ??
        RecipeOperationResult.failure('Failed to add recipe');
  }

  Future<RecipeOperationResult> updateLegacyRecipe(Recipe recipe) async {
    if (!recipe.isPersonal) {
      return RecipeOperationResult.failure('Recipe is not personal');
    }

    return await safeExecute(
          () async {
            final result =
                await _recipeService.personal.updateLegacyRecipe(recipe);
            if (result.isSuccess) {
              AppLogger.info(
                  '✅ Updated legacy personal recipe: ${recipe.core.title}');
            }
            return result;
          },
          operationName: 'Update Legacy Personal Recipe',
          defaultValue:
              RecipeOperationResult.failure('Failed to update recipe'),
        ) ??
        RecipeOperationResult.failure('Failed to update recipe');
  }

  Recipe? getPersonalRecipeById(String id) {
    return personalRecipes.where((r) => r.id == id).firstOrNull;
  }

  List<Recipe> getPersonalRecipesByMealType(String mealType) {
    return personalRecipes.where((r) => r.mealType == mealType).toList();
  }

  List<Recipe> getPersonalRecipesByTag(String tag) {
    return personalRecipes
        .where((r) => r.personalTagIds?.contains(tag) ?? false)
        .toList();
  }

  List<Recipe> searchPersonalRecipes(String query) {
    if (query.trim().isEmpty) return personalRecipes;

    final lowercaseQuery = query.toLowerCase();
    return personalRecipes.where((recipe) {
      return recipe.title.toLowerCase().contains(lowercaseQuery) ||
          recipe.description.toLowerCase().contains(lowercaseQuery) ||
          recipe.ingredients.any((ingredient) =>
              ingredient.toLowerCase().contains(lowercaseQuery)) ||
          recipe.instructions.any((instruction) =>
              instruction.toLowerCase().contains(lowercaseQuery)) ||
          (recipe.personalTagIds
                  ?.any((tag) => tag.toLowerCase().contains(lowercaseQuery)) ??
              false);
    }).toList();
  }

  Map<String, int> getPersonalMealTypeCounts() {
    final mealTypeCounts = <String, int>{};
    for (final recipe in personalRecipes) {
      mealTypeCounts[recipe.mealType] =
          (mealTypeCounts[recipe.mealType] ?? 0) + 1;
    }
    return mealTypeCounts;
  }

  Map<String, int> getPersonalTagCounts() {
    final tagCounts = <String, int>{};
    for (final recipe in personalRecipes) {
      if (recipe.personalTagIds != null) {
        for (final tag in recipe.personalTagIds!) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }
    }
    return tagCounts;
  }

  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions
    // Dispose of resources
    disposeStreamResources(); // From StreamManagementMixin
    super.dispose();
  }
}
