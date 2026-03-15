// lib/viewmodels/menu/menu_generator.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/l10n/app_locale.dart';

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

  /// Whether to filter out recipes that don't match user's dietary preferences.
  bool filterByDietary;

  MenuGenerator({
    required MenuService menuService,
    required UnifiedRecipeService recipeService,
    required UserService userService,
    this.filterByAllergens = true,
    this.filterByDietary = true,
  })  : _menuService = menuService,
        _recipeService = recipeService,
        _userService = userService;

  List<Recipe> get availableRecipes {
    if (!_recipeService.isInitialized) {
      return [];
    }
    var recipes = _recipeService.recipes;
    if (filterByAllergens) {
      recipes = _filterByAllergenPreferences(recipes);
    }
    if (filterByDietary) {
      recipes = _filterByDietaryPreferences(recipes);
    }
    return recipes;
  }

  /// Filters out recipes that CONTAIN any of the user's tracked allergens.
  /// When includeUnknownInMenu is false, also excludes UNKNOWN status recipes.
  List<Recipe> _filterByAllergenPreferences(List<Recipe> recipes) {
    final prefs = _userService.allergenPreferences;
    if (!prefs.hasTrackedAllergens) return recipes;

    final tracked = prefs.trackedAllergens;
    final includeUnknown = prefs.includeUnknownInMenu;
    return recipes.where((recipe) {
      final tagResult = recipe.tagResult;
      if (tagResult == null) {
        return includeUnknown; // No tag data = respect preference
      }

      for (final allergen in tracked) {
        final status = tagResult.getAllergenStatus(allergen);
        if (status == TriState.contains) {
          return false;
        }
        if (!includeUnknown && status == TriState.unknown) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Filters out recipes that don't match user's tracked dietary preferences.
  /// A recipe passes if it is FREE for ALL tracked dietary preferences.
  /// Respects includeUnknownInMenu setting for consistency with allergen filtering.
  List<Recipe> _filterByDietaryPreferences(List<Recipe> recipes) {
    final prefs = _userService.allergenPreferences;
    if (!prefs.hasTrackedDietary) return recipes;

    final tracked = prefs.trackedDietary;
    final includeUnknown = prefs.includeUnknownInMenu;
    return recipes.where((recipe) {
      final tagResult = recipe.tagResult;
      if (tagResult == null) {
        return includeUnknown; // No tag data = respect preference
      }

      for (final diet in tracked) {
        final status = tagResult.getDietaryStatus(diet);
        if (status == TriState.contains) {
          return false;
        }
        if (!includeUnknown && status == TriState.unknown) {
          return false;
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
      throw Exception(AppLocale.current.errorNoRecipesAvailable);
    }

    final generatedMenu = await _menuService.generateMenuFromPrompt(
      prompt,
      availableRecipes,
    );

    if (generatedMenu.isEmpty) {
      throw Exception(
        AppLocale.current.errorGeneric,
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

  /// UI Redesign: Swap a single recipe with another matching the same category.
  /// Finds a random recipe from available recipes that:
  /// - Matches the same meal type (category)
  /// - Is not already in the current menu
  /// - Has similar characteristics to the original
  Recipe? swapSingleRecipe(
    Recipe currentRecipe,
    String category,
    Map<String, List<Recipe>> currentMenu,
  ) {
    // Get all recipe IDs currently in the menu to avoid duplicates
    final currentMenuRecipeIds = <String>{};
    for (final recipes in currentMenu.values) {
      for (final recipe in recipes) {
        currentMenuRecipeIds.add(recipe.id);
      }
    }

    // Find eligible recipes that match the category and aren't in the menu
    final eligibleRecipes = availableRecipes.where((recipe) {
      // Skip if already in menu
      if (currentMenuRecipeIds.contains(recipe.id)) return false;

      // Match by meal type or category-appropriate recipes
      final categoryLower = category.toLowerCase();
      final mealTypeLower = recipe.mealType.toLowerCase();

      // Check if meal type matches category
      if (categoryLower.contains('middag') ||
          categoryLower.contains('dinner')) {
        return mealTypeLower.contains('middag') ||
            mealTypeLower.contains('dinner') ||
            mealTypeLower.isEmpty; // Include uncategorized recipes
      }
      if (categoryLower.contains('lunch')) {
        return mealTypeLower.contains('lunch') || mealTypeLower.isEmpty;
      }
      if (categoryLower.contains('frukost') ||
          categoryLower.contains('breakfast')) {
        return mealTypeLower.contains('frukost') ||
            mealTypeLower.contains('breakfast') ||
            mealTypeLower.isEmpty;
      }

      // Default: include if meal type matches or is empty
      return mealTypeLower == categoryLower || mealTypeLower.isEmpty;
    }).toList();

    if (eligibleRecipes.isEmpty) {
      AppLogger.warning(
          'No eligible recipes found for swap in category: $category');
      return null;
    }

    // Shuffle and return a random recipe
    eligibleRecipes.shuffle();
    return eligibleRecipes.first;
  }

  /// Validate menu generation prerequisites
  void validateGenerationPrerequisites(String prompt) {
    if (prompt.trim().isEmpty) {
      throw ArgumentError(AppLocale.current.errorFillRequiredFields);
    }

    if (availableRecipes.isEmpty) {
      throw Exception(AppLocale.current.errorNoRecipesAvailable);
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
      AppLocale.current.menuSuggestionVegetarian,
      AppLocale.current.menuSuggestionQuickDinners,
      AppLocale.current.menuSuggestionMeatFish,
      AppLocale.current.menuSuggestionFamily,
      AppLocale.current.menuSuggestionHealthy,
      AppLocale.current.menuSuggestionBudget,
      AppLocale.current.menuSuggestionItalian,
      AppLocale.current.menuSuggestionAsian,
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
