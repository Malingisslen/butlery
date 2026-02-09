// lib/viewmodels/menu/menu_generator.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/utils/logger.dart';

/// Focused module for menu generation
/// This module handles ONLY menu generation:
/// - AI-powered menu generation from prompts
/// - Menu section regeneration
/// - Recipe availability validation
/// - Generation error handling
/// - Allergen-safe recipe filtering
/// ❌ DOES NOT CONTAIN: State management, persistence, social features
class MenuGenerator {
  final MenuService _menuService;
  final UnifiedRecipeService _recipeService;
  final UserService _userService;

  /// Whether to filter out recipes containing user's tracked allergens.
  bool filterByAllergens;

  MenuGenerator({
    required MenuService menuService,
    required UnifiedRecipeService recipeService,
    required UserService userService,
    this.filterByAllergens = true,
  })  : _menuService = menuService,
        _recipeService = recipeService,
        _userService = userService;

  List<Recipe> get availableRecipes {
    if (!_recipeService.isInitialized) {
      return [];
    }
    final recipes = _recipeService.recipes;
    if (!filterByAllergens) return recipes;
    return _filterByAllergenPreferences(recipes);
  }

  /// Filters out recipes that CONTAIN any of the user's tracked allergens.
  /// Recipes with UNKNOWN status are kept (may be safe, user can verify).
  List<Recipe> _filterByAllergenPreferences(List<Recipe> recipes) {
    final prefs = _userService.allergenPreferences;
    if (!prefs.hasTrackedAllergens) return recipes;

    final tracked = prefs.trackedAllergens;
    return recipes.where((recipe) {
      final tagResult = recipe.tagResult;
      if (tagResult == null) return true; // No tag data = keep

      for (final allergen in tracked) {
        if (tagResult.getAllergenStatus(allergen) == TriState.contains) {
          return false; // Exclude recipes that CONTAIN tracked allergens
        }
      }
      return true;
    }).toList();
  }

  bool get hasAvailableRecipes => availableRecipes.isNotEmpty;

  Future<void> ensureRecipeServiceInitialized() async {
    if (!_recipeService.isInitialized) {
      AppLogger.info('🔄 Initialiserar recept-service för meny-generering...');
      await _recipeService.initialize();
    }
  }

  /// Generate complete menu from prompt
  Future<Map<String, List<Recipe>>> generateMenuFromPrompt(
      String prompt) async {
    await ensureRecipeServiceInitialized();

    await Future.delayed(const Duration(milliseconds: 300));

    if (availableRecipes.isEmpty) {
      throw Exception('Inga recept tillgängliga. Lägg till recept först.');
    }

    final generatedMenu = await _menuService.generateMenuFromPrompt(
      prompt,
      availableRecipes,
    );

    if (generatedMenu.isEmpty) {
      throw Exception(
        'Kunde inte generera meny från din begäran. Prova att vara mer specifik.',
      );
    }

    return generatedMenu;
  }

  /// Regenerate specific menu section
  Future<List<Recipe>?> regenerateMenuSection(
    String section,
    Map<String, List<Recipe>> currentMenu,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final currentCount = currentMenu[section]?.length ?? 1;

    final newRecipes = await _menuService.generateMenuFromPrompt(
      '$currentCount $section',
      availableRecipes,
    );

    if (newRecipes.containsKey(section)) {
      return newRecipes[section];
    }

    return null;
  }

  /// Validate menu generation prerequisites
  void validateGenerationPrerequisites(String prompt) {
    if (prompt.trim().isEmpty) {
      throw ArgumentError('Ange vad du vill ha för meny');
    }

    if (availableRecipes.isEmpty) {
      throw Exception('Inga recept tillgängliga. Lägg till recept först.');
    }
  }

  /// Analyze generated menu quality
  Map<String, dynamic> analyzeMenuQuality(Map<String, List<Recipe>> menu) {
    final analysis = <String, dynamic>{
      'totalRecipes':
          menu.values.fold(0, (sum, recipes) => sum + recipes.length),
      'sections': menu.keys.length,
      'averageRecipesPerSection': 0.0,
      'hasVariety': false,
      'mealTypes': <String>{},
    };

    if (menu.isNotEmpty) {
      analysis['averageRecipesPerSection'] =
          analysis['totalRecipes'] / analysis['sections'];

      // Analyze meal type variety
      final mealTypes = <String>{};
      for (final recipes in menu.values) {
        for (final recipe in recipes) {
          mealTypes.add(recipe.mealType);
        }
      }

      analysis['mealTypes'] = mealTypes;
      analysis['hasVariety'] = mealTypes.length > 1;
    }

    return analysis;
  }

  /// Get menu generation suggestions
  List<String> getGenerationSuggestions() {
    return [
      'Vegetarisk veckomeny för 2 personer',
      'Snabba middagar för hela veckan',
      'Kött och fisk varierad meny',
      'Familjevänlig veckomeny',
      'Hälsosam och näringsrik meny',
      'Budgetvänlig veckomeny',
      'Italiensk temameny',
      'Asiatisk inspirerad veckomeny',
    ];
  }

  /// Check if prompt is likely to generate good results
  bool isPromptOptimal(String prompt) {
    final lowerPrompt = prompt.toLowerCase();

    // Good indicators
    final goodKeywords = [
      'veckomeny',
      'meny',
      'middag',
      'lunch',
      'frukost',
      'vegetarisk',
      'kött',
      'fisk',
      'familj',
      'person',
      'snabb',
      'hälsosam',
      'budget',
      'tema'
    ];

    final hasGoodKeywords =
        goodKeywords.any((keyword) => lowerPrompt.contains(keyword));

    // Length check
    final hasGoodLength = prompt.length >= 10 && prompt.length <= 200;

    return hasGoodKeywords && hasGoodLength;
  }
}
