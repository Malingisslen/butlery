/// Base class for site-specific recipe parsers
/// Provides a common interface for extracting recipes from specific recipe websites
/// (ICA.se, Arla.se, Köket.se, etc.) with site-specific enhancements and fallbacks.
/// **Architecture:**
/// - Primary: Extract JSON-LD/Microdata using RecipeScraper
/// - Enhancement: Add site-specific fields (difficulty, tips, etc.)
/// - Fallback: CSS selector extraction when JSON-LD unavailable
/// - Validation: Quality scoring to ensure >90% completeness

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:butlery/core/extensions/default_value_extensions.dart';
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
    // One parse feeds every step below (BUT-2026).
    final document = html_parser.parse(html);

    // Try standard schema.org extraction first
    var recipe = extractRecipeFromDocument(document).data;

    if (recipe != null) {
      // Enhance with site-specific fields
      recipe = enhanceRecipe(recipe, document);

      // Validate quality
      // MED-7: meetsMinimumQuality requires 80% completeness (see RecipeQualityScorer)
      // Ensures recipes have title, ingredients, and instructions at minimum
      final quality = scoreRecipe(recipe);
      if (quality.meetsMinimumQuality) {
        return recipe;
      }
    }

    // Fallback: Try site-specific CSS selector extraction
    recipe = extractWithCssSelectors(document);

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
  /// Map<String, dynamic> enhanceRecipe(Map<String, dynamic> recipe, Document doc) {
  ///   final difficulty = _extractDifficulty(doc);
  ///   if (difficulty != null) {
  ///     recipe['difficulty'] = difficulty;
  ///   }
  ///   return recipe;
  /// }
  /// ```
  Map<String, dynamic> enhanceRecipe(
    Map<String, dynamic> recipe,
    Document doc,
  ) {
    // Default: no enhancements
    return recipe;
  }

  /// Extract recipe using site-specific CSS selectors (fallback method)
  /// Override this method to implement CSS selector-based extraction
  /// for sites that don't use JSON-LD or have malformed structured data.
  /// **Example:**
  /// ```dart
  /// @override
  /// Map<String, dynamic>? extractWithCssSelectors(Document doc) {
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
  Map<String, dynamic>? extractWithCssSelectors(Document doc) {
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

  /// Helper: Strip "ca"/"cirka" from the portions and from the start of each
  /// ingredient, and clean the ingredient and instruction text.
  Map<String, dynamic> cleanCirkaFormatting(Map<String, dynamic> recipe) {
    final yield_ = recipe['recipeYield'];
    if (yield_ is String) {
      recipe['recipeYield'] = yield_
          .replaceAll('ca ', '')
          .replaceAll('cirka ', '')
          .trim();
    }

    if (recipe['recipeIngredient'] is List) {
      final ingredients = recipe['recipeIngredient'] as List;
      recipe['recipeIngredient'] = ingredients
          .map((ing) {
            String cleaned = cleanSwedishText(ing.toString());
            cleaned = cleaned.replaceAll(
              RegExp(r'^ca\s+', caseSensitive: false),
              '',
            );
            cleaned = cleaned.replaceAll(
              RegExp(r'^cirka\s+', caseSensitive: false),
              '',
            );
            return cleaned.trim();
          })
          .where((ing) => ing.isNotEmpty)
          .toList();
    }

    if (recipe['recipeInstructions'] is List) {
      recipe['recipeInstructions'] = recipeInstructionTexts(
        recipe['recipeInstructions'] as List,
      ).map(cleanSwedishText).where((step) => step.isNotEmpty).toList();
    }

    return recipe;
  }

  /// Helper: Portions from the shared selectors, with the site's own
  /// [sitePortionsSelector] tried after `.recipe-portions`; failing those, the
  /// number after "Portioner:" anywhere on the page.
  String? extractPortions(Document doc, {String? sitePortionsSelector}) {
    final selectors = [
      '.recipe-portions',
      ?sitePortionsSelector,
      '[itemprop="recipeYield"]',
      '.recipe-servings',
      '.portions',
    ];

    for (final selector in selectors) {
      final element = doc.querySelector(selector);
      if (element != null) {
        final portions = element.text.trim();
        if (portions.isNotEmpty) {
          return cleanSwedishText(portions);
        }
      }
    }

    final bodyText = (doc.body?.text).orEmpty();
    final portionMatch = RegExp(
      r'Portioner?:\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(bodyText);
    return portionMatch?.group(1);
  }

  /// Helper: First absolute image URL found by the shared selectors, with
  /// the site's own [siteImageSelector] tried after `.recipe-image img`.
  String? extractImage(Document doc, {String? siteImageSelector}) {
    final selectors = [
      '[itemprop="image"]',
      '.recipe-image img',
      ?siteImageSelector,
      '.recipe-hero img',
      'article img',
    ];

    for (final selector in selectors) {
      final element = doc.querySelector(selector);
      if (element != null) {
        final src = element.attributes['src'] ?? element.attributes['data-src'];
        if (src != null && src.startsWith('http')) {
          return src;
        }
      }
    }

    return null;
  }

  /// Helper: Convert Swedish time text to ISO 8601 duration
  /// Examples:
  /// - "30 minuter" → "PT30M"
  /// - "1 timme 30 min" → "PT1H30M"
  /// - "45 min" → "PT45M"
  String? swedishTimeToIso8601(String timeText) {
    final lowerText = timeText.toLowerCase();

    // Extract hours
    final hoursMatch = RegExp(r'(\d+)\s*timm').firstMatch(lowerText);
    final hours = hoursMatch != null
        ? int.tryParse(hoursMatch.group(1)!)
        : null;

    // Extract minutes
    final minutesMatch = RegExp(r'(\d+)\s*min').firstMatch(lowerText);
    final minutes = minutesMatch != null
        ? int.tryParse(minutesMatch.group(1)!)
        : null;

    if (hours == null && minutes == null) {
      return null;
    }

    final buffer = StringBuffer('PT');
    if (hours != null && hours > 0) {
      buffer.write('${hours}H');
    }
    if (minutes != null && minutes > 0) {
      buffer.write('${minutes}M');
    }

    return buffer.toString();
  }
}
