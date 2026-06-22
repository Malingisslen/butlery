// lib/viewmodels/menu/menu_quality_analyzer.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Pure quality/analysis helpers for generated menus and prompts.
///
/// Extracted from [MenuGenerator] (BUT-1349) to keep the generation
/// orchestrator focused. These are stateless functions over a menu/prompt —
/// they hold no service dependencies, so they live as static methods.
class MenuQualityAnalyzer {
  const MenuQualityAnalyzer._();

  /// Throws if the prompt is empty. The caller is responsible for the
  /// availability check, which depends on generator state.
  static void validatePromptNotEmpty(String prompt) {
    if (prompt.trim().isEmpty) {
      throw ArgumentError(AppLocale.current.errorFillRequiredFields);
    }
  }

  /// Analyze generated menu quality.
  static Map<String, dynamic> analyzeMenuQuality(
    Map<String, List<Recipe>> menu,
  ) {
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

  /// Get menu generation suggestions.
  static List<String> getGenerationSuggestions() {
    return [
      AppLocale.current.menuSuggestionVegetarian,
      AppLocale.current.menuSuggestionQuickDinners,
      AppLocale.current.menuSuggestionMeatFish,
      AppLocale.current.menuSuggestionFamily,
      AppLocale.current.menuSuggestionHealthy,
      AppLocale.current.menuSuggestionBudget,
      AppLocale.current.menuSuggestionItalian,
      AppLocale.current.menuSuggestionAsian,
      AppLocale.current.menuSuggestionFavorites,
      AppLocale.current.menuSuggestionRecent,
    ];
  }

  /// Check if prompt is likely to generate good results.
  static bool isPromptOptimal(String prompt) {
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
      'tema',
      'favoriter',
      'senaste',
    ];

    final hasGoodKeywords =
        goodKeywords.any((keyword) => lowerPrompt.contains(keyword));

    // Length check
    final hasGoodLength = prompt.length >= 10 && prompt.length <= 200;

    return hasGoodKeywords && hasGoodLength;
  }
}
