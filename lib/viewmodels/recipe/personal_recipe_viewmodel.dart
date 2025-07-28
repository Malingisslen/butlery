// lib/viewmodels/recipe/personal_recipe_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/utils/logging_utils.dart';
import 'package:butlery/services/unified/types/recipe_types.dart' show RecipeOperationResult;
import 'package:butlery/models/recipe_unified.dart';

/// Personal Recipe ViewModel
/// 
/// Handles ONLY personal recipe operations and management.
/// This includes creation, editing, deletion, and content management for personal recipes.
class PersonalRecipeViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final UnifiedRecipeService _recipeService = sl<UnifiedRecipeService>();

  String get serviceName => 'PersonalRecipeViewModel';

  // ===== GETTERS =====

  List<Recipe> get personalRecipes => _recipeService.personalRecipes;
  bool get hasPersonalRecipes => personalRecipes.isNotEmpty;
  int get personalRecipeCount => personalRecipes.length;

  String? get currentUserId => _recipeService.currentUserId;
  String? get currentUserDisplayName => _recipeService.currentUserDisplayName;

  // ===== PERSONAL RECIPE CREATION =====

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
    List<String>? tags,
    String? sourceUrl,
  }) async {
    // Use ValidationUtils for consistent validation
    final nameError = ValidationUtils.validateRecipeName(name);
    if (nameError != null) return false;

    return await safeExecute(
      () => LoggingUtils.loggedCreate(
        'Personal Recipe',
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
            tags: tags,
            sourceUrl: sourceUrl,
          );

          return recipeId != null;
        },
        metadata: {'meal_type': mealType, 'ingredient_count': ingredients.length},
      ),
      operationName: 'Create Personal Recipe',
      defaultValue: false,
    ) ?? false;
  }

  // ===== PERSONAL RECIPE MANAGEMENT =====

  Future<bool> updatePersonalRecipe(Recipe recipe) async {
    if (!recipe.isPersonal) return false;

    return await LoggingUtils.loggedUpdate(
      'Personal Recipe',
      () => _recipeService.personal.updateRecipe(recipe),
      itemId: recipe.id,
      metadata: {'title': recipe.core.title},
    );
  }

  Future<bool> deletePersonalRecipe(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;
    
    return await LoggingUtils.loggedDelete(
      'Personal Recipe',
      () => _recipeService.personal.deleteRecipe(recipeId),
      itemId: recipeId,
      metadata: {'title': recipe.core.title},
    );
  }

  // ===== CONTENT EDITING =====

  Future<bool> updateRecipeContent({
    required String recipeId,
    String? name,
    String? description,
    String? mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
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
    
    return await LoggingUtils.loggedUpdate(
      'Personal Recipe Content',
      () => _recipeService.personal.updateRecipeContent(
        recipeId: recipeId,
        title: name,
        description: description,
        mealType: mealType,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        tags: tags,
        sourceUrl: sourceUrl,
      ),
      itemId: recipeId,
      metadata: {'recipe_title': recipe.core.title},
    );
  }

  // ===== INGREDIENT MANAGEMENT =====

  Future<bool> addIngredient(String recipeId, String ingredient) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) || ValidationUtils.isNullOrEmpty(ingredient)) {
      return false;
    }

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;

    return await LoggingUtils.loggedUpdate(
      'Personal Recipe Ingredient',
      () => _recipeService.personal.addIngredient(recipeId, ingredient),
      itemId: recipeId,
      metadata: {'ingredient': ingredient},
    );
  }

  Future<bool> updateIngredient(String recipeId, int index, String newIngredient) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) || ValidationUtils.isNullOrEmpty(newIngredient)) {
      return false;
    }

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;
    
    return await LoggingUtils.loggedUpdate(
      'Personal Recipe Ingredient',
      () => _recipeService.personal.updateIngredient(recipeId, index, newIngredient),
      itemId: recipeId,
      metadata: {'index': index, 'ingredient': newIngredient},
    );
  }

  Future<bool> removeIngredient(String recipeId, int index) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;
    
    return await LoggingUtils.loggedDelete(
      'Personal Recipe Ingredient',
      () => _recipeService.personal.removeIngredient(recipeId, index),
      itemId: recipeId,
      metadata: {'index': index},
    );
  }

  // ===== INSTRUCTION MANAGEMENT =====

  Future<bool> addInstruction(String recipeId, String instruction) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) || ValidationUtils.isNullOrEmpty(instruction)) {
      return false;
    }

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;
    
    return await _recipeService.personal.addInstruction(recipeId, instruction);
  }

  Future<bool> updateInstruction(String recipeId, int index, String newInstruction) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) || ValidationUtils.isNullOrEmpty(newInstruction)) {
      return false;
    }

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;
    
    return await _recipeService.personal.updateInstruction(recipeId, index, newInstruction);
  }

  Future<bool> removeInstruction(String recipeId, int index) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;
    
    return await _recipeService.personal.removeInstruction(recipeId, index);
  }

  // ===== COOKING TRACKING =====

  Future<bool> markAsCooked(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    final recipe = getPersonalRecipeById(recipeId);
    if (recipe == null || !recipe.isPersonal) return false;
    
    return await _recipeService.personal.markAsCooked(recipeId);
  }

  // ===== LEGACY COMPATIBILITY =====

  Future<RecipeOperationResult> addLegacyRecipe(Recipe recipe) async {
    if (!recipe.isPersonal) {
      return RecipeOperationResult.failure('Recipe is not personal');
    }

    return await safeExecute(
      () => LoggingUtils.loggedOperation(
        'Add Legacy Personal Recipe',
        () => _recipeService.personal.addLegacyRecipe(recipe),
        metadata: {'recipe_title': recipe.core.title},
      ),
      operationName: 'Add Legacy Personal Recipe',
      defaultValue: RecipeOperationResult.failure('Failed to add recipe'),
    ) ?? RecipeOperationResult.failure('Failed to add recipe');
  }

  Future<RecipeOperationResult> updateLegacyRecipe(Recipe recipe) async {
    if (!recipe.isPersonal) {
      return RecipeOperationResult.failure('Recipe is not personal');
    }

    return await safeExecute(
      () => LoggingUtils.loggedOperation(
        'Update Legacy Personal Recipe',
        () => _recipeService.personal.updateLegacyRecipe(recipe),
        metadata: {'recipe_id': recipe.id, 'recipe_title': recipe.core.title},
      ),
      operationName: 'Update Legacy Personal Recipe',
      defaultValue: RecipeOperationResult.failure('Failed to update recipe'),
    ) ?? RecipeOperationResult.failure('Failed to update recipe');
  }

  // ===== QUERY UTILITIES =====

  Recipe? getPersonalRecipeById(String id) {
    return personalRecipes.where((r) => r.id == id).firstOrNull;
  }

  List<Recipe> getPersonalRecipesByMealType(String mealType) {
    return personalRecipes.where((r) => r.mealType == mealType).toList();
  }

  List<Recipe> getPersonalRecipesByTag(String tag) {
    return personalRecipes.where((r) => r.tags?.contains(tag) ?? false).toList();
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
          (recipe.tags
                  ?.any((tag) => tag.toLowerCase().contains(lowercaseQuery)) ??
              false);
    }).toList();
  }

  // ===== ANALYTICS =====

  Map<String, int> getPersonalMealTypeCounts() {
    final mealTypeCounts = <String, int>{};
    for (final recipe in personalRecipes) {
      mealTypeCounts[recipe.mealType] = (mealTypeCounts[recipe.mealType] ?? 0) + 1;
    }
    return mealTypeCounts;
  }

  Map<String, int> getPersonalTagCounts() {
    final tagCounts = <String, int>{};
    for (final recipe in personalRecipes) {
      if (recipe.tags != null) {
        for (final tag in recipe.tags!) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }
    }
    return tagCounts;
  }
}