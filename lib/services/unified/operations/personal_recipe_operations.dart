/// 🔍 AI INFO BLOCK:
/// Component: Personal Recipe Operations - Feature interface for personal recipe management
/// File: lib/services/unified/operations/personal_recipe_operations.dart
/// Quick Guide: Handles all personal recipe CRUD operations and offline functionality
/// Dependencies IN: UnifiedRecipeService, UnifiedRecipe model, AppLogger
/// Dependencies OUT: Used by ViewModels for personal recipe operations
/// Data flow: ViewModels -> PersonalRecipeOperations -> UnifiedRecipeService -> Firebase/Cache
/// State management: Delegates to parent UnifiedRecipeService
/// Purpose: Separate personal recipe concerns from unified service
/// Common issues: Permission validation, offline/online sync
/// Test coverage: Unit tests for CRUD operations
/// Performance: Optimistic updates with debounced sync
/// Analytics: Recipe creation/update/delete events
/// Code smells: None - follows single responsibility principle
/// Connected to: UnifiedRecipeService, Recipe ViewModels, Import ViewModels
/// Used in phases: Phase 5 - Service Consolidation

import '../../../models/unified/unified_recipe.dart';
import '../../../models/recipe.dart';
import '../../../core/utils/logger.dart';
import '../types/recipe_types.dart';

/// Personal recipe operations feature interface
/// 
/// Handles all operations related to personal (non-collaborative) recipes:
/// - CRUD operations for personal recipes
/// - Import/export functionality
/// - Offline sync management
/// - Legacy compatibility for existing Recipe model
class PersonalRecipeOperations {
  final dynamic _parent; // UnifiedRecipeService

  PersonalRecipeOperations(this._parent);

  // ===== PERSONAL RECIPE CRUD =====

  /// Create a new personal recipe
  Future<String?> createRecipe({
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
    return await _parent.createPersonalRecipe(
      name: name,
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
  }

  /// Update an existing personal recipe
  Future<bool> updateRecipe(UnifiedRecipe recipe) async {
    if (recipe.isCollaborative) {
      AppLogger.warning('Attempting to update collaborative recipe through personal operations');
      return false;
    }
    return await _parent.updateRecipe(recipe);
  }

  /// Delete a personal recipe
  Future<bool> deleteRecipe(String recipeId) async {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;
    
    if (recipe.isCollaborative) {
      AppLogger.warning('Attempting to delete collaborative recipe through personal operations');
      return false;
    }
    
    return await _parent.deleteRecipe(recipeId);
  }

  /// Get a personal recipe by ID
  UnifiedRecipe? getRecipeById(String id) {
    return _parent.recipes
        .where((r) => r.id == id && r.isPersonal)
        .firstOrNull;
  }

  /// Get all personal recipes
  List<UnifiedRecipe> getAllRecipes() {
    return _parent.personalRecipes;
  }

  /// Mark recipe as cooked
  Future<bool> markAsCooked(String recipeId) async {
    final recipe = getRecipeById(recipeId);
    if (recipe == null) return false;
    
    return await _parent.markRecipeAsCooked(recipeId);
  }

  // ===== RECIPE CONTENT OPERATIONS =====

  /// Update basic recipe information
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
    final recipe = getRecipeById(recipeId);
    if (recipe == null) return false;

    return await _parent.updateRecipeContent(
      recipeId: recipeId,
      name: name,
      description: description,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      tags: tags,
      sourceUrl: sourceUrl,
    );
  }

  /// Add ingredient to recipe
  Future<bool> addIngredient(String recipeId, String ingredient) async {
    final recipe = getRecipeById(recipeId);
    if (recipe == null) return false;
    
    return await _parent.addIngredient(recipeId, ingredient);
  }

  /// Update ingredient in recipe
  Future<bool> updateIngredient(String recipeId, int index, String newIngredient) async {
    final recipe = getRecipeById(recipeId);
    if (recipe == null) return false;
    
    return await _parent.updateIngredient(recipeId, index, newIngredient);
  }

  /// Remove ingredient from recipe
  Future<bool> removeIngredient(String recipeId, int index) async {
    final recipe = getRecipeById(recipeId);
    if (recipe == null) return false;
    
    return await _parent.removeIngredient(recipeId, index);
  }

  /// Add instruction to recipe
  Future<bool> addInstruction(String recipeId, String instruction) async {
    final recipe = getRecipeById(recipeId);
    if (recipe == null) return false;
    
    return await _parent.addInstruction(recipeId, instruction);
  }

  /// Update instruction in recipe
  Future<bool> updateInstruction(String recipeId, int index, String newInstruction) async {
    final recipe = getRecipeById(recipeId);
    if (recipe == null) return false;
    
    return await _parent.updateInstruction(recipeId, index, newInstruction);
  }

  /// Remove instruction from recipe
  Future<bool> removeInstruction(String recipeId, int index) async {
    final recipe = getRecipeById(recipeId);
    if (recipe == null) return false;
    
    return await _parent.removeInstruction(recipeId, index);
  }

  // ===== IMPORT/EXPORT OPERATIONS =====

  /// Import recipe from archive (Butlery recipe collection)
  Future<String?> importFromArchive({
    required String archiveRecipeId,
    required Map<String, dynamic> archiveData,
  }) async {
    try {
      return await createRecipe(
        name: archiveData['title'] ?? 'Importerat recept',
        description: archiveData['description'] ?? '',
        ingredients: List<String>.from(archiveData['ingredients'] ?? []),
        instructions: List<String>.from(archiveData['instructions'] ?? []),
        imageUrls: List<String>.from(archiveData['imageUrls'] ?? []),
        mealType: archiveData['mealType'] ?? 'Lunch',
        portions: archiveData['portions'],
        timeMinutes: archiveData['timeMinutes'],
        rating: archiveData['rating']?.toDouble(),
        tags: List<String>.from(archiveData['tags'] ?? []),
        sourceUrl: 'Importerat från Butlery-arkivet',
      );
    } catch (e) {
      AppLogger.error('Failed to import recipe from archive', e);
      return null;
    }
  }

  /// Import recipe from text content
  Future<String?> importFromText({
    required String textContent,
    String? recipeName,
  }) async {
    try {
      // Basic text parsing - can be enhanced with AI/ML
      final lines = textContent.split('\n').where((line) => line.trim().isNotEmpty).toList();
      
      String name = recipeName ?? 'Importerat recept';
      List<String> ingredients = [];
      List<String> instructions = [];
      
      bool inIngredients = false;
      bool inInstructions = false;
      
      for (final line in lines) {
        final trimmed = line.trim();
        
        if (trimmed.toLowerCase().contains('ingrediens') || trimmed.toLowerCase().contains('råvaror')) {
          inIngredients = true;
          inInstructions = false;
          continue;
        } else if (trimmed.toLowerCase().contains('instruktion') || trimmed.toLowerCase().contains('tillredning')) {
          inIngredients = false;
          inInstructions = true;
          continue;
        }
        
        if (inIngredients) {
          ingredients.add(trimmed);
        } else if (inInstructions) {
          instructions.add(trimmed);
        } else if (name == 'Importerat recept' && trimmed.isNotEmpty) {
          name = trimmed; // First non-empty line as name
        }
      }
      
      return await createRecipe(
        name: name,
        ingredients: ingredients,
        instructions: instructions,
        sourceUrl: 'Importerat från text',
      );
    } catch (e) {
      AppLogger.error('Failed to import recipe from text', e);
      return null;
    }
  }

  /// Import recipe from URL
  Future<String?> importFromUrl({
    required String url,
    Map<String, dynamic>? extractedData,
  }) async {
    try {
      if (extractedData == null) {
        // Basic URL import without extraction
        return await createRecipe(
          name: 'Recept från $url',
          sourceUrl: url,
        );
      }
      
      return await createRecipe(
        name: extractedData['title'] ?? 'Recept från $url',
        description: extractedData['description'] ?? '',
        ingredients: List<String>.from(extractedData['ingredients'] ?? []),
        instructions: List<String>.from(extractedData['instructions'] ?? []),
        imageUrls: List<String>.from(extractedData['imageUrls'] ?? []),
        portions: extractedData['portions'],
        timeMinutes: extractedData['timeMinutes'],
        sourceUrl: url,
      );
    } catch (e) {
      AppLogger.error('Failed to import recipe from URL', e);
      return null;
    }
  }

  /// Import recipe from photo/OCR
  Future<String?> importFromPhoto({
    required String imagePath,
    Map<String, dynamic>? ocrData,
  }) async {
    try {
      if (ocrData == null) {
        // Basic photo import without OCR
        return await createRecipe(
          name: 'Recept från foto',
          imageUrls: [imagePath],
          sourceUrl: 'Importerat från foto',
        );
      }
      
      return await createRecipe(
        name: ocrData['title'] ?? 'Recept från foto',
        description: ocrData['description'] ?? '',
        ingredients: List<String>.from(ocrData['ingredients'] ?? []),
        instructions: List<String>.from(ocrData['instructions'] ?? []),
        imageUrls: [imagePath],
        sourceUrl: 'Importerat från foto (OCR)',
      );
    } catch (e) {
      AppLogger.error('Failed to import recipe from photo', e);
      return null;
    }
  }

  /// Export recipes to various formats
  Future<Map<String, dynamic>> exportRecipes({
    List<String>? recipeIds,
    String format = 'json',
  }) async {
    try {
      final recipesToExport = recipeIds != null
          ? _parent.recipes.where((r) => r.isPersonal && recipeIds.contains(r.id)).toList()
          : getAllRecipes();

      return {
        'format': format,
        'exportDate': DateTime.now().toIso8601String(),
        'recipeCount': recipesToExport.length,
        'recipes': recipesToExport.map((r) => r.toJson()).toList(),
      };
    } catch (e) {
      AppLogger.error('Failed to export recipes', e);
      return {'error': e.toString()};
    }
  }

  /// Add multiple recipes (for batch import operations)
  Future<RecipeOperationResult> addMultipleRecipes(List<Recipe> recipes) async {
    try {
      int successCount = 0;
      List<String> failures = [];

      for (final recipe in recipes) {
        final result = await addLegacyRecipe(recipe);
        if (result.isSuccess) {
          successCount++;
        } else {
          failures.add('${recipe.title}: ${result.message}');
        }
      }

      if (successCount == recipes.length) {
        return RecipeOperationResult.success('Alla ${recipes.length} recept importerade');
      } else if (successCount > 0) {
        return RecipeOperationResult.success(
          '$successCount av ${recipes.length} recept importerade. Fel: ${failures.join(', ')}'
        );
      } else {
        return RecipeOperationResult.failure(
          'Kunde inte importera några recept. Fel: ${failures.join(', ')}'
        );
      }
    } catch (e) {
      AppLogger.error('Failed to add multiple recipes', e);
      return RecipeOperationResult.failure('Batch import fel: $e');
    }
  }

  // ===== LEGACY COMPATIBILITY =====

  /// Legacy compatibility for existing Recipe model
  Future<RecipeOperationResult> addLegacyRecipe(Recipe legacyRecipe) async {
    return await _parent.addRecipe(legacyRecipe);
  }

  /// Legacy compatibility for existing Recipe model
  Future<RecipeOperationResult> updateLegacyRecipe(Recipe legacyRecipe) async {
    return await _parent.updateLegacyRecipe(legacyRecipe);
  }

  /// Legacy compatibility for existing Recipe model
  Future<RecipeOperationResult> deleteLegacyRecipe(String id) async {
    return await _parent.deleteRecipeById(id);
  }

  /// Legacy compatibility - get recipe as legacy model
  Recipe? getLegacyRecipeById(String id) {
    return _parent.getRecipeById(id);
  }

  /// Legacy compatibility - get all recipes as legacy models
  List<Recipe> getAllLegacyRecipes() {
    return _parent.legacyRecipes.where((r) => !r.isCollaborative).toList();
  }
}

// RecipeOperationResult is now imported from ../types/recipe_types.dart