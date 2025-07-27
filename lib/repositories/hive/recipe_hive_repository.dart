/// 🔍 AI INFO BLOCK:
/// Component: Recipe Hive repository
/// File: repositories/hive/recipe_hive_repository.dart
/// Quick Guide: Persists Recipe objects using Hive
/// Dependencies IN: hive_flutter, models/recipe.dart
/// Dependencies OUT: services needing offline recipes
/// Data flow: init -> CRUD via BaseHiveRepository
/// State management: relies on Hive for persistence
/// Purpose: Separate data layer for recipes
/// Common issues: adapter registration must match typeId
/// Test coverage: none yet
/// Performance: limited by Hive I/O
/// Analytics: none
/// Code smells: incomplete offline features
/// Connected to: base_hive_repository.dart
/// Used in phases: offline storage prototype

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/hive/base_hive_repository.dart';

/// Repository för att lagra Recipe-objekt i Hive.
/// 
/// Använder JSON-serialisering för Recipe-objekt eftersom unified Recipe model
/// inte har Hive TypeAdapter än. Detta ger flexibilitet för framtida ändringar.
class RecipeHiveRepository extends BaseHiveRepository<Map<String, dynamic>> {
  RecipeHiveRepository() : super('recipes');

  @override
  Future<void> init({String? userId}) async {
    // Using JSON serialization for Recipe objects
    // This approach is more flexible and doesn't require TypeAdapter registration
    await super.init(userId: userId);
  }

  /// Initialiserar med aktuell användares ID för säker user-specifik cache
  Future<void> initWithUser(String userId) async {
    await init(userId: userId);
  }

  // ===== RECIPE-SPECIFIC METHODS =====

  /// Sparar ett Recipe-objekt som JSON
  Future<void> saveRecipe(Recipe recipe) async {
    await put(recipe.id, recipe.toJson());
  }

  /// Hämtar ett Recipe-objekt från JSON
  Recipe? getRecipe(String recipeId) {
    final jsonData = get(recipeId);
    if (jsonData == null) return null;
    
    try {
      return Recipe.fromJson(jsonData);
    } catch (e) {
      // Remove corrupted entry
      delete(recipeId);
      return null;
    }
  }

  /// Hämtar alla Recipe-objekt
  List<Recipe> getAllRecipes() {
    final recipes = <Recipe>[];
    
    for (final jsonData in getAll()) {
      try {
        final recipe = Recipe.fromJson(jsonData);
        recipes.add(recipe);
      } catch (e) {
        // Skip corrupted entries
        continue;
      }
    }
    
    return recipes;
  }

  /// Uppdaterar ett Recipe-objekt
  Future<void> updateRecipe(Recipe recipe) async {
    await saveRecipe(recipe); // Same as save since we use recipe.id as key
  }

  /// Tar bort ett recept
  Future<void> deleteRecipe(String recipeId) async {
    await delete(recipeId);
  }

  /// Söker recept baserat på titel
  List<Recipe> searchRecipes(String query) {
    final allRecipes = getAllRecipes();
    final lowerQuery = query.toLowerCase();
    
    return allRecipes.where((recipe) {
      return recipe.title.toLowerCase().contains(lowerQuery) ||
             recipe.description.toLowerCase().contains(lowerQuery) ||
             recipe.ingredients.any((ingredient) => 
                ingredient.toLowerCase().contains(lowerQuery)) ||
             (recipe.tags?.isNotEmpty == true && recipe.tags!.any((tag) => 
                tag.toLowerCase().contains(lowerQuery)));
    }).toList();
  }

  /// Filtrerar recept baserat på måltidstyp
  List<Recipe> getRecipesByMealType(String mealType) {
    return getAllRecipes().where((recipe) => 
        recipe.mealType.toLowerCase() == mealType.toLowerCase()).toList();
  }

  /// Hämtar favoritrecept (rating >= 4.0)
  List<Recipe> getFavoriteRecipes() {
    return getAllRecipes().where((recipe) => 
        recipe.rating != null && recipe.rating! >= 4.0).toList();
  }

  /// Hämtar senast uppdaterade recept
  List<Recipe> getRecentRecipes({int limit = 10}) {
    final recipes = getAllRecipes();
    recipes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return recipes.take(limit).toList();
  }

  /// Hämtar cache-statistik
  Map<String, dynamic> getCacheStats() {
    final allRecipes = getAllRecipes();
    final totalRecipes = allRecipes.length;
    final totalSize = box.length;
    
    final mealTypeCounts = <String, int>{};
    final tagCounts = <String, int>{};
    
    for (final recipe in allRecipes) {
      // Count meal types
      mealTypeCounts[recipe.mealType] = (mealTypeCounts[recipe.mealType] ?? 0) + 1;
      
      // Count tags
      if (recipe.tags?.isNotEmpty == true) {
        for (final tag in recipe.tags!) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }
    }
    
    return {
      'totalRecipes': totalRecipes,
      'totalCacheEntries': totalSize,
      'mealTypeCounts': mealTypeCounts,
      'topTags': tagCounts.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value))
          ..take(5)
          .map((entry) => {'tag': entry.key, 'count': entry.value})
          .toList(),
      'averageRating': allRecipes.where((r) => r.rating != null)
          .fold<double>(0.0, (sum, r) => sum + r.rating!) / 
          allRecipes.where((r) => r.rating != null).length,
    };
  }

  /// Rengör korrupta cache-poster
  Future<int> cleanupCorruptedEntries() async {
    int removedCount = 0;
    final keys = box.keys.toList();
    
    for (final key in keys) {
      final jsonData = box.get(key);
      if (jsonData != null) {
        try {
          Recipe.fromJson(jsonData);
        } catch (e) {
          await delete(key);
          removedCount++;
        }
      }
    }
    
    return removedCount;
  }
}

