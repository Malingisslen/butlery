// lib/services/recipe_service.dart

import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../data/dummy_data.dart';

/// Centraliserad service för hantering av recept
/// Kapslar in all logik för CRUD-operationer och sökfunktioner
class RecipeService extends ChangeNotifier {
  // Singleton pattern för global åtkomst
  static final RecipeService _instance = RecipeService._internal();
  factory RecipeService() => _instance;
  RecipeService._internal();

  // Privat lista som håller alla recept
  List<Recipe> _recipes = [];

  // Getter för att komma åt recepten (read-only)
  List<Recipe> get recipes => List.unmodifiable(_recipes);

  // Laddar initial data (anropa från main.dart)
  void initialize() {
    _recipes = List.from(dummyRecipesNotifier.value);
    notifyListeners();
  }

  // ===== CRUD OPERATIONER =====

  /// Lägger till ett nytt recept
  void addRecipe(Recipe recipe) {
    _recipes.add(recipe);
    _updateNotifier();
    notifyListeners();
  }

  /// Uppdaterar ett befintligt recept
  void updateRecipe(Recipe updatedRecipe) {
    final index = _recipes.indexWhere((r) => r.id == updatedRecipe.id);
    if (index != -1) {
      _recipes[index] = updatedRecipe;
      _updateNotifier();
      notifyListeners();
    }
  }

  /// Tar bort ett recept
  void deleteRecipe(String recipeId) {
    _recipes.removeWhere((r) => r.id == recipeId);
    _updateNotifier();
    notifyListeners();
  }

  /// Lägger till flera recept (t.ex. från arkiv)
  void addMultipleRecipes(List<Recipe> newRecipes) {
    _recipes.addAll(newRecipes);
    _updateNotifier();
    notifyListeners();
  }

  // ===== SÖKFUNKTIONER =====

  /// Söker recept baserat på query-sträng
  List<Recipe> searchRecipes(String query) {
    if (query.trim().isEmpty) return recipes;

    final lowerQuery = query.toLowerCase().trim();

    return _recipes.where((recipe) {
      return _matchesSearchQuery(recipe, lowerQuery);
    }).toList();
  }

  /// Filtrerar recept baserat på måltidstyp
  List<Recipe> getRecipesByMealType(String mealType) {
    return _recipes.where((recipe) => recipe.mealType == mealType).toList();
  }

  /// Filtrerar recept baserat på taggar (AND-logik)
  List<Recipe> getRecipesByTags(List<String> tags) {
    if (tags.isEmpty) return recipes;

    return _recipes.where((recipe) {
      return tags.every((tag) => recipe.tags?.contains(tag) ?? false);
    }).toList();
  }

  /// Filtrerar recept baserat på tid
  List<Recipe> getRecipesByMaxTime(int maxMinutes) {
    return _recipes.where((recipe) {
      return recipe.timeMinutes != null && recipe.timeMinutes! <= maxMinutes;
    }).toList();
  }

  /// Avancerad filtrering med flera kriterier
  List<Recipe> filterRecipes({
    String? searchQuery,
    String? mealType,
    List<String>? tags,
    int? maxTime,
    double? minRating,
  }) {
    var filtered = List<Recipe>.from(_recipes);

    // Sökquery
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      filtered =
          filtered.where((recipe) {
            return _matchesSearchQuery(recipe, searchQuery.toLowerCase());
          }).toList();
    }

    // Måltidstyp
    if (mealType != null) {
      filtered =
          filtered.where((recipe) => recipe.mealType == mealType).toList();
    }

    // Taggar (AND-logik)
    if (tags != null && tags.isNotEmpty) {
      filtered =
          filtered.where((recipe) {
            return tags.every((tag) => recipe.tags?.contains(tag) ?? false);
          }).toList();
    }

    // Max tid
    if (maxTime != null) {
      filtered =
          filtered.where((recipe) {
            return recipe.timeMinutes != null && recipe.timeMinutes! <= maxTime;
          }).toList();
    }

    // Min betyg
    if (minRating != null) {
      filtered =
          filtered.where((recipe) {
            return recipe.rating != null && recipe.rating! >= minRating;
          }).toList();
    }

    return filtered;
  }

  // ===== STATISTIK OCH HJÄLPFUNKTIONER =====

  /// Hämtar alla unika taggar från alla recept
  List<String> getAllTags() {
    final allTags = <String>{};
    for (final recipe in _recipes) {
      if (recipe.tags != null) {
        allTags.addAll(recipe.tags!);
      }
    }
    return allTags.toList()..sort();
  }

  /// Hämtar alla måltidstyper
  List<String> getAllMealTypes() {
    return _recipes.map((r) => r.mealType).toSet().toList()..sort();
  }

  /// Räknar recept per måltidstyp
  Map<String, int> getRecipeCountByMealType() {
    final counts = <String, int>{};
    for (final recipe in _recipes) {
      counts[recipe.mealType] = (counts[recipe.mealType] ?? 0) + 1;
    }
    return counts;
  }

  /// Hämtar slumpmässiga recept för förslag
  List<Recipe> getRandomRecipes(int count) {
    final shuffled = List<Recipe>.from(_recipes)..shuffle();
    return shuffled.take(count).toList();
  }

  /// Hämtar högst betygsatta recept
  List<Recipe> getTopRatedRecipes(int count) {
    final sorted = List<Recipe>.from(_recipes);
    sorted.sort((a, b) {
      final ratingA = a.rating ?? 0;
      final ratingB = b.rating ?? 0;
      return ratingB.compareTo(ratingA);
    });
    return sorted.take(count).toList();
  }

  // ===== PRIVATA HJÄLPFUNKTIONER =====

  /// Kontrollerar om ett recept matchar en sökfråga
  bool _matchesSearchQuery(Recipe recipe, String query) {
    // Titel
    if (recipe.title.toLowerCase().contains(query)) return true;

    // Beskrivning
    if (recipe.description.toLowerCase().contains(query)) return true;

    // Ingredienser
    if (recipe.ingredients.any(
      (ingredient) => ingredient.toLowerCase().contains(query),
    ))
      return true;

    // Instruktioner
    if (recipe.instructions.any(
      (instruction) => instruction.toLowerCase().contains(query),
    ))
      return true;

    // Taggar
    if (recipe.tags?.any((tag) => tag.toLowerCase().contains(query)) ?? false)
      return true;

    // Numeriska fält (portioner, tid, betyg)
    final queryAsNumber = double.tryParse(query);
    if (queryAsNumber != null) {
      if (recipe.portions?.toString().contains(query) ?? false) return true;
      if (recipe.timeMinutes?.toString().contains(query) ?? false) return true;
      if (recipe.rating?.toString().contains(query) ?? false) return true;
    }

    return false;
  }

  /// Uppdaterar den gamla ValueNotifier för bakåtkompatibilitet
  void _updateNotifier() {
    dummyRecipesNotifier.value = List.from(_recipes);
  }

  // ===== IMPORT/EXPORT =====

  /// Exporterar alla recept som JSON (för framtida implementering)
  Map<String, dynamic> exportRecipes() {
    return {
      'recipes':
          _recipes
              .map(
                (recipe) => {
                  'id': recipe.id,
                  'title': recipe.title,
                  'description': recipe.description,
                  'portions': recipe.portions,
                  'timeMinutes': recipe.timeMinutes,
                  'ingredients': recipe.ingredients,
                  'instructions': recipe.instructions,
                  'tags': recipe.tags,
                  'rating': recipe.rating,
                  'imageUrl': recipe.imageUrl,
                  'mealType': recipe.mealType,
                },
              )
              .toList(),
      'exportDate': DateTime.now().toIso8601String(),
    };
  }
}
