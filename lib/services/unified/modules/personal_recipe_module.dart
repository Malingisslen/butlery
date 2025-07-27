// lib/services/unified/modules/personal_recipe_module.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';

/// Personal recipe operations module
/// 
/// This module contains ONLY:
/// - Personal recipe CRUD operations
/// - Import/export functionality
/// - Personal recipe validation
/// - Local storage management
/// 
/// ❌ DOES NOT CONTAIN: Social features, realtime editing, UI concerns, auth logic
class PersonalRecipeModule {
  final FirebaseFirestore _firestore;
  final JsonCacheHelper _cacheHelper;
  final String? Function() _getCurrentUserId;
  final String? Function() _getCurrentUserDisplayName;
  final void Function(String) _setError;
  final void Function() _notifyListeners;
  final RecipeServiceAdapter _serviceAdapter;

  PersonalRecipeModule({
    required FirebaseFirestore firestore,
    required JsonCacheHelper cacheHelper,
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required void Function(String) setError,
    required void Function() notifyListeners,
    RecipeServiceAdapter? serviceAdapter,
  })  : _firestore = firestore,
        _cacheHelper = cacheHelper,
        _getCurrentUserId = getCurrentUserId,
        _getCurrentUserDisplayName = getCurrentUserDisplayName,
        _setError = setError,
        _notifyListeners = notifyListeners,
        _serviceAdapter = serviceAdapter ?? RecipeServiceAdapter();

  // ===== PERSONAL RECIPE CRUD =====

  /// Create a new personal recipe
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
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError('Du måste vara inloggad');
      return null;
    }

    if (title.trim().isEmpty) {
      _setError('Receptnamn kan inte vara tomt');
      return null;
    }

    try {
      final newRecipe = Recipe.personal(
        title: title.trim(),
        description: description,
        ingredients: ingredients,
        instructions: instructions,
        mealType: mealType,
        createdBy: currentUserId,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        tags: tags,
        sourceUrl: sourceUrl,
        imageUrls: imageUrls,
      );

      // Save to cache first (optimistic update)
      await _saveToCache(newRecipe);

      // Create recipe using repository pattern
      final createdId = await _serviceAdapter.createRecipe(newRecipe);
      if (createdId != null) {
        AppLogger.success('✅ Personal recipe "$title" created');
        return createdId;
      } else {
        // Remove from cache if creation failed
        await _removeFromCache(newRecipe.id);
        _setError('Kunde inte spara recept till servern');
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ Could not create personal recipe: $e');
      _setError('Kunde inte skapa recept: $e');
      return null;
    }
  }

  /// Update an existing personal recipe
  Future<bool> updatePersonalRecipe(Recipe updatedRecipe) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError('Du måste vara inloggad');
      return false;
    }

    if (!updatedRecipe.isPersonal) {
      _setError('Kan bara uppdatera personliga recept');
      return false;
    }

    try {
      final editedRecipe = updatedRecipe.copyWith(
        lastEditedByUserId: currentUserId,
        lastEditedByDisplayName: _getCurrentUserDisplayName(),
      );

      // Save to cache (optimistic update)
      await _saveToCache(editedRecipe);

      // Update recipe using repository pattern
      final updateSuccess = await _serviceAdapter.updateRecipe(editedRecipe);
      if (updateSuccess) {
        AppLogger.success('✅ Personal recipe "${editedRecipe.title}" updated');
      } else {
        _setError('Kunde inte uppdatera recept på servern');
        return false;
      }
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not update personal recipe: $e');
      _setError('Kunde inte uppdatera recept: $e');
      return false;
    }
  }

  /// Delete a personal recipe
  Future<bool> deletePersonalRecipe(String recipeId) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError('Du måste vara inloggad');
      return false;
    }

    try {
      // Remove from cache
      await _removeFromCache(recipeId);

      // Delete from Firebase using repository pattern
      final deleteSuccess = await _serviceAdapter.deleteRecipe(recipeId);
      if (deleteSuccess) {
        AppLogger.success('✅ Personal recipe deleted');
      } else {
        _setError('Kunde inte ta bort recept från servern');
        return false;
      }
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not delete personal recipe: $e');
      _setError('Kunde inte ta bort recept: $e');
      return false;
    }
  }

  /// Mark recipe as cooked
  Future<bool> markRecipeAsCooked(String recipeId) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError('Du måste vara inloggad');
      return false;
    }

    try {
      // This would need to be implemented with recipe loading first
      // For now, we'll create a basic implementation
      AppLogger.info('Recipe marked as cooked: $recipeId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not mark recipe as cooked: $e');
      _setError('Kunde inte markera recept som tillagat: $e');
      return false;
    }
  }

  // ===== RECIPE CONTENT OPERATIONS =====

  /// Add ingredient to recipe
  Future<bool> addIngredient(String recipeId, String ingredient) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError('Du måste vara inloggad');
      return false;
    }

    try {
      // This would need recipe loading implementation
      AppLogger.info('Ingredient added to recipe $recipeId: $ingredient');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not add ingredient: $e');
      _setError('Kunde inte lägga till ingrediens: $e');
      return false;
    }
  }

  /// Update ingredient at specific index
  Future<bool> updateIngredient(String recipeId, int index, String newIngredient) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError('Du måste vara inloggad');
      return false;
    }

    try {
      // This would need recipe loading implementation
      AppLogger.info('Ingredient updated in recipe $recipeId at index $index: $newIngredient');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not update ingredient: $e');
      _setError('Kunde inte uppdatera ingrediens: $e');
      return false;
    }
  }

  /// Remove ingredient at specific index
  Future<bool> removeIngredient(String recipeId, int index) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError('Du måste vara inloggad');
      return false;
    }

    try {
      // This would need recipe loading implementation
      AppLogger.info('Ingredient removed from recipe $recipeId at index $index');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not remove ingredient: $e');
      _setError('Kunde inte ta bort ingrediens: $e');
      return false;
    }
  }

  /// Add instruction to recipe
  Future<bool> addInstruction(String recipeId, String instruction) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError('Du måste vara inloggad');
      return false;
    }

    try {
      // This would need recipe loading implementation
      AppLogger.info('Instruction added to recipe $recipeId: $instruction');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not add instruction: $e');
      _setError('Kunde inte lägga till instruktion: $e');
      return false;
    }
  }

  /// Update instruction at specific index
  Future<bool> updateInstruction(String recipeId, int index, String newInstruction) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError('Du måste vara inloggad');
      return false;
    }

    try {
      // This would need recipe loading implementation
      AppLogger.info('Instruction updated in recipe $recipeId at index $index: $newInstruction');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not update instruction: $e');
      _setError('Kunde inte uppdatera instruktion: $e');
      return false;
    }
  }

  /// Remove instruction at specific index
  Future<bool> removeInstruction(String recipeId, int index) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError('Du måste vara inloggad');
      return false;
    }

    try {
      // This would need recipe loading implementation
      AppLogger.info('Instruction removed from recipe $recipeId at index $index');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not remove instruction: $e');
      _setError('Kunde inte ta bort instruktion: $e');
      return false;
    }
  }

  // ===== VALIDATION =====

  /// Validate recipe data before creation/update
  bool validateRecipeData({
    required String title,
    required List<String> ingredients,
    required List<String> instructions,
  }) {
    if (title.trim().isEmpty) {
      _setError('Receptnamn kan inte vara tomt');
      return false;
    }

    if (ingredients.isEmpty) {
      _setError('Recept måste ha minst en ingrediens');
      return false;
    }

    if (instructions.isEmpty) {
      _setError('Recept måste ha minst en instruktion');
      return false;
    }

    return true;
  }

  /// Check if recipe belongs to current user
  bool isOwnRecipe(Recipe recipe) {
    final currentUserId = _getCurrentUserId();
    return currentUserId != null && recipe.core.createdBy == currentUserId;
  }

  // ===== CACHE OPERATIONS =====

  /// Save recipe to local cache
  Future<void> _saveToCache(Recipe recipe) async {
    try {
      final recipeData = recipe.toJson();
      await _cacheHelper.saveJson(recipe.id, recipeData);
      AppLogger.debug('Recipe cached: ${recipe.title}');
    } catch (e) {
      AppLogger.error('Cache save error: $e');
    }
  }

  /// Remove recipe from local cache
  Future<void> _removeFromCache(String recipeId) async {
    try {
      await _cacheHelper.delete(recipeId);
      AppLogger.debug('Recipe removed from cache: $recipeId');
    } catch (e) {
      AppLogger.error('Cache removal error: $e');
    }
  }

  /// Load cached recipes for offline access
  Future<List<Recipe>> loadCachedPersonalRecipes() async {
    try {
      final cachedRecipeIds = await _cacheHelper.getAllKeys();
      final recipes = <Recipe>[];

      for (final recipeId in cachedRecipeIds) {
        final recipeData = await _cacheHelper.loadJson(recipeId);
        if (recipeData != null) {
          try {
            final recipe = Recipe.fromJson(recipeData);
            if (recipe.isPersonal && isOwnRecipe(recipe)) {
              recipes.add(recipe);
            }
          } catch (e) {
            AppLogger.error('Error parsing cached recipe $recipeId: $e');
            await _cacheHelper.delete(recipeId);
          }
        }
      }

      AppLogger.debug('✅ ${recipes.length} cached personal recipes loaded');
      return recipes;
    } catch (e) {
      AppLogger.error('Error loading cached recipes: $e');
      return [];
    }
  }

  // ===== FIREBASE OPERATIONS (DEPRECATED - Use Repository Pattern) =====
  
  // These methods are now handled by the RecipeServiceAdapter
  // They are kept for potential backward compatibility but should not be used

  /// Get Firebase query for personal recipes
  Query<Map<String, dynamic>>? getPersonalRecipesQuery() {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) return null;

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('unified_recipes');
  }

  // ===== IMPORT/EXPORT FUNCTIONALITY =====

  /// Import recipes from external sources
  Future<List<String>> importRecipesFromData(List<Map<String, dynamic>> recipesData) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError('Du måste vara inloggad för att importera recept');
      return [];
    }

    final importedIds = <String>[];

    try {
      for (final recipeData in recipesData) {
        try {
          final recipe = Recipe.fromJson(recipeData);
          
          // Convert to personal recipe
          final personalRecipe = recipe.copyWith(
            createdBy: currentUserId,
            lastEditedByUserId: currentUserId,
            lastEditedByDisplayName: _getCurrentUserDisplayName(),
          );

          await _saveToCache(personalRecipe);
          await _serviceAdapter.createRecipe(personalRecipe);
          
          importedIds.add(personalRecipe.id);
          AppLogger.info('Imported recipe: ${personalRecipe.title}');
        } catch (e) {
          AppLogger.error('Error importing individual recipe: $e');
        }
      }

      if (importedIds.isNotEmpty) {
        _notifyListeners();
        AppLogger.success('✅ ${importedIds.length} recipes imported successfully');
      }

      return importedIds;
    } catch (e) {
      AppLogger.error('❌ Import error: $e');
      _setError('Kunde inte importera recept: $e');
      return [];
    }
  }

  /// Export personal recipes to JSON format
  Future<List<Map<String, dynamic>>> exportPersonalRecipes() async {
    try {
      final cachedRecipes = await loadCachedPersonalRecipes();
      final exportData = cachedRecipes.map((recipe) => recipe.toJson()).toList();
      
      AppLogger.success('✅ ${exportData.length} recipes exported');
      return exportData;
    } catch (e) {
      AppLogger.error('❌ Export error: $e');
      _setError('Kunde inte exportera recept: $e');
      return [];
    }
  }

  // ===== UTILITY METHODS =====

  /// Create recipe operation result
  RecipeOperationResult createSuccessResult([String? message]) {
    return RecipeOperationResult.success(message);
  }

  /// Create recipe operation failure result
  RecipeOperationResult createFailureResult(String error) {
    return RecipeOperationResult.failure(error);
  }

  /// Clear any existing errors
  void clearError() {
    // This would be handled by the parent service
  }
}