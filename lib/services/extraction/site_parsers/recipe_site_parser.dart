/// Base class for site-specific recipe parsers
/// Provides a common interface for extracting recipes from specific recipe websites
/// (ICA.se, Arla.se, Köket.se, etc.) with site-specific enhancements and fallbacks.
/// **Architecture:**
/// - Primary: Extract JSON-LD/Microdata using RecipeScraper
/// - Enhancement: Add site-specific fields (difficulty, tips, etc.)
/// - Fallback: CSS selector extraction when JSON-LD unavailable
/// - Validation: Quality scoring to ensure >90% completeness

import 'package:butlery/services/extraction/site_parsers/recipe_quality_scorer.dart';
import 'package:butlery/utils/recipe_scraper.dart';

/// Base class for all site-specific recipe parsers
abstract class RecipeSiteParser {
  /// Domain this parser handles (e.g., "ica.se", "arla.se")
  String get domain;

  /// Display name for the recipe site (e.g., "ICA", "Arla")
  String get siteName;

  /// Extract recipe from HTML using site-specific logic
  /// **Extraction workflow:**
  /// 1. Try standard JSON-LD/Microdata extraction (via RecipeScraper)
  /// 2. If successful, enhance with site-specific fields
  /// 3. If failed, try site-specific CSS selector extraction
  /// 4. Validate quality and return result
  /// Returns `null` if extraction fails or quality is too low.
  Map<String, dynamic>? parseRecipe(String html) {
    // Try standard schema.org extraction first
    var recipe = extractRecipeFromHtml(html);

    if (recipe != null) {
      // Enhance with site-specific fields
      recipe = enhanceRecipe(recipe, html);

      // Validate quality
      final quality = scoreRecipe(recipe);
      if (quality.meetsMinimumQuality) {
        return recipe;
      }
    }

    // Fallback: Try site-specific CSS selector extraction
    recipe = extractWithCssSelectors(html);

    if (recipe != null) {
      final quality = scoreRecipe(recipe);
      if (quality.meetsMinimumQuality) {
        return recipe;
      }
    }

    return null;
  }

  /// Score recipe quality based on field completeness
  /// Uses RecipeQualityScorer to calculate completeness percentage.
  /// Subclasses can override to add site-specific quality criteria.
  RecipeQualityScore scoreRecipe(Map<String, dynamic> recipe) {
    return RecipeQualityScorer.score(recipe);
  }

  /// Enhance recipe with site-specific fields
  /// Override this method to extract site-specific data like:
  /// - Difficulty level
  /// - Cooking tips
  /// - Equipment needed
  /// - Nutritional information
  /// - Tags/categories
  /// **Example (ICA.se):**
  /// ```dart
  /// @override
  /// Map<String, dynamic> enhanceRecipe(Map<String, dynamic> recipe, String html) {
  ///   // Extract difficulty from HTML
  ///   final difficulty = _extractDifficulty(html);
  ///   if (difficulty != null) {
  ///     recipe['difficulty'] = difficulty;
  ///   }
  ///   return recipe;
  /// }
  /// ```
  Map<String, dynamic> enhanceRecipe(Map<String, dynamic> recipe, String html) {
    // Default: no enhancements
    return recipe;
  }

  /// Extract recipe using site-specific CSS selectors (fallback method)
  /// Override this method to implement CSS selector-based extraction
  /// for sites that don't use JSON-LD or have malformed structured data.
  /// **Example:**
  /// ```dart
  /// @override
  /// Map<String, dynamic>? extractWithCssSelectors(String html) {
  ///   final doc = parse(html);
  ///   final title = doc.querySelector('h1.recipe-title')?.text;
  ///   final ingredients = doc.querySelectorAll('.ingredient-list li')
  ///     .map((e) => e.text.trim()).toList();
  ///   if (title != null && ingredients.isNotEmpty) {
  ///     return {
  ///       'name': title,
  ///       'recipeIngredient': ingredients,
  ///       // ... other fields
  ///     };
  ///   }
  ///   return null;
  /// }
  /// ```
  Map<String, dynamic>? extractWithCssSelectors(String html) {
    // Default: no CSS fallback
    return null;
  }

  /// Helper: Extract difficulty level from text
  /// Common Swedish difficulty levels:
  /// - "Enkel" / "Lätt" (Easy/Simple)
  /// - "Medel" (Medium)
  /// - "Svår" / "Avancerad" (Hard/Advanced)
  String? extractDifficulty(String text) {
    final lowerText = text.toLowerCase();

    // Hard/Advanced
    if (lowerText.contains('svår')) return 'Svår';
    if (lowerText.contains('avancerad')) return 'Avancerad';

    // Medium
    if (lowerText.contains('medel')) return 'Medel';

    // Easy/Simple
    if (lowerText.contains('enkel')) return 'Enkel';
    if (lowerText.contains('lätt')) return 'Lätt';

    return null;
  }

  /// Helper: Clean up Swedish text
  /// Handles common Swedish formatting:
  /// - Removes extra whitespace
  /// - Preserves Swedish characters (Å, Ä, Ö)
  /// - Normalizes quotes and dashes
  String cleanSwedishText(String text) {
    return text
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[\u201C\u201D]'), '"') // Smart quotes
        .replaceAll(RegExp(r'[\u2013\u2014]'), '-'); // Em/en dashes
  }
}
