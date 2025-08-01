import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';

/// Specialized personal recipe operations interface providing comprehensive CRUD functionality for individual recipe management.
///
/// This operations interface implements sophisticated personal recipe management following Single Responsibility Principle,
/// handling all aspects of individual recipe operations including creation, modification, deletion, and content management.
/// It provides comprehensive personal recipe functionality while maintaining clean separation from social features
/// and collaborative editing concerns for maintainable and testable recipe operations.
///
/// **Single Responsibility Focus:**
/// This interface exclusively handles personal recipe operations:
/// - **Recipe CRUD Operations**: Complete create, read, update, delete operations for personal recipes
/// - **Content Management**: Detailed ingredient and instruction management with granular editing capabilities
/// - **Batch Operations**: Efficient multi-recipe operations for import and bulk management scenarios
/// - **Legacy Compatibility**: Backward compatibility methods ensuring smooth migration from legacy implementations
///
/// **What This Interface Does NOT Handle:**
/// - Social recipe sharing and collaboration (handled by SocialRecipeOperations)
/// - Real-time collaborative editing (handled by RealtimeRecipeOperations)
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Authentication and permission management (handled by parent services)
///
/// **Personal Recipe Features:**
/// - **Complete CRUD**: Full recipe lifecycle management with validation and error handling
/// - **Content Editing**: Granular ingredient and instruction management with index-based operations
/// - **Batch Processing**: Efficient multi-recipe operations for import scenarios and bulk management
/// - **Result Handling**: Comprehensive operation result handling with success/failure tracking
/// - **Legacy Support**: Backward compatibility ensuring smooth transition from legacy implementations
///
/// **Usage Examples:**
/// ```dart
/// final personalOps = PersonalRecipeOperations(parentService);
/// 
/// // Create individual recipe
/// final result = await personalOps.addUnifiedRecipe(recipe);
/// 
/// // Batch recipe import
/// final batchResult = await personalOps.addMultipleUnifiedRecipes(recipes);
/// 
/// // Content management
/// await personalOps.addIngredient(recipeId, '2 dl mjölk');
/// await personalOps.updateInstruction(recipeId, 0, 'Värm ugnen till 200°C');
/// 
/// // Recipe lifecycle
/// await personalOps.updateRecipeContent(recipeId, title: 'Nya köttbullar');
/// await personalOps.markAsCooked(recipeId);
/// ```
class PersonalRecipeOperations {
  final dynamic _parent;

  PersonalRecipeOperations(this._parent);

  /// Add unified recipe
  Future<RecipeOperationResult> addUnifiedRecipe(Recipe unifiedRecipe) async {
    try {
      final recipeId = await createRecipe(
        title: unifiedRecipe.title,
        description: unifiedRecipe.description,
        ingredients: unifiedRecipe.ingredients,
        instructions: unifiedRecipe.instructions,
        imageUrls: unifiedRecipe.imageUrls,
        mealType: unifiedRecipe.mealType,
        portions: unifiedRecipe.portions,
        timeMinutes: unifiedRecipe.timeMinutes,
        rating: unifiedRecipe.rating,
        tags: unifiedRecipe.tags,
        sourceUrl: unifiedRecipe.sourceUrl,
      );
      
      return recipeId != null 
          ? RecipeOperationResult.success('Recipe added successfully')
          : RecipeOperationResult.failure('Failed to add recipe');
    } catch (e) {
      return RecipeOperationResult.failure('Failed to add recipe: ${e.toString()}');
    }
  }

  /// Update unified recipe
  Future<RecipeOperationResult> updateUnifiedRecipe(Recipe unifiedRecipe) async {
    try {
      final success = await updateRecipe(unifiedRecipe);
      
      return success 
          ? RecipeOperationResult.success('Recipe updated successfully')
          : RecipeOperationResult.failure('Failed to update recipe');
    } catch (e) {
      return RecipeOperationResult.failure('Failed to update recipe: ${e.toString()}');
    }
  }

  /// Add multiple unified recipes
  Future<RecipeOperationResult> addMultipleUnifiedRecipes(List<Recipe> recipes) async {
    try {
      int successCount = 0;
      final failures = <String>[];

      for (final recipe in recipes) {
        final result = await addUnifiedRecipe(recipe);
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
      AppLogger.error('Failed to add multiple unified recipes', e);
      return RecipeOperationResult.failure('Batch import fel: $e');
    }
  }

  // Delegate methods to parent service
  Future<String?> createRecipe({
    required String title,
    required String description,
    required List<String> ingredients,
    required List<String> instructions,
    required List<String> imageUrls,
    required String mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    String? sourceUrl,
  }) async {
    return await _parent.createRecipe(
      title: title,
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

  Future<bool> updateRecipe(Recipe recipe) async {
    return await _parent.updateRecipe(recipe);
  }

  // Additional methods needed by ViewModels
  Future<bool> deleteRecipe(String id) async {
    return await _parent.deleteRecipe(id);
  }

  Future<bool> updateRecipeContent({
    required String recipeId,
    String? title,
    String? description,
    String? mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? tags,
    String? sourceUrl,
  }) async {
    return await _parent.updateRecipeContent(
      recipeId: recipeId,
      title: title,
      description: description,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      ingredients: ingredients,
      instructions: instructions,
      tags: tags,
      sourceUrl: sourceUrl,
    );
  }

  Future<bool> addIngredient(String recipeId, String ingredient) async {
    return await _parent.addIngredient(recipeId, ingredient);
  }

  Future<bool> updateIngredient(String recipeId, int index, String ingredient) async {
    return await _parent.updateIngredient(recipeId, index, ingredient);
  }

  Future<bool> removeIngredient(String recipeId, int index) async {
    return await _parent.removeIngredient(recipeId, index);
  }

  Future<bool> addInstruction(String recipeId, String instruction) async {
    return await _parent.addInstruction(recipeId, instruction);
  }

  Future<bool> updateInstruction(String recipeId, int index, String instruction) async {
    return await _parent.updateInstruction(recipeId, index, instruction);
  }

  Future<bool> removeInstruction(String recipeId, int index) async {
    return await _parent.removeInstruction(recipeId, index);
  }

  Future<bool> markAsCooked(String recipeId) async {
    return await _parent.markAsCooked(recipeId);
  }

  // Legacy compatibility methods for ViewModel
  Future<RecipeOperationResult> addLegacyRecipe(Recipe recipe) async {
    return await addUnifiedRecipe(recipe);
  }

  Future<RecipeOperationResult> updateLegacyRecipe(Recipe recipe) async {
    return await updateUnifiedRecipe(recipe);
  }
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}