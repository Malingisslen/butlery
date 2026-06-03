/// Recept.se recipe parser with aggregation-specific enhancements
/// Recept.se is Sweden's leading recipe aggregation platform, featuring recipes from
/// professional chefs, food bloggers, and home cooks. This parser handles the site's
/// specific data structure and enhancements.
/// **Target Success Rate:** >90% (high quality, standardized format)
/// **Recept-Specific Features:**
/// - Recipe source/origin tracking
/// - Detailed categorization (meal type, cuisine, occasion)
/// - Prep/cook time breakdown
/// - Serving suggestions
/// - Print-optimized formatting
/// - Recipe variations/alternatives

import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/services/extraction/site_parsers/recipe_site_parser.dart';

/// Parser for Recept.se recipes
/// **Example URL:** https://www.recept.se/recept/kottbullar/
class ReceptRecipeParser extends RecipeSiteParser {
  @override
  String get domain => 'recept.se';

  @override
  String get siteName => 'Recept';

  @override
  Map<String, dynamic> enhanceRecipe(Map<String, dynamic> recipe, String html) {
    try {
      final doc = html_parser.parse(html);

      // Extract site-specific fields from HTML
      recipe = _extractReceptEnhancements(recipe, doc);

      // Normalize author from JSON-LD nested object to plain string
      final author = recipe['author'];
      if (author is Map && author['name'] != null) {
        recipe['author'] = author['name'];
      }

      // Clean up formatting quirks
      recipe = _cleanReceptFormatting(recipe);
      return recipe;
    } catch (e) {
      // Enhancement failed, return recipe as-is
      return recipe;
    }
  }

  /// Extract Recept-specific enhancements from HTML
  Map<String, dynamic> _extractReceptEnhancements(
      Map<String, dynamic> recipe, Document doc) {
    // Difficulty level
    if (recipe['difficulty'] == null) {
      final diffEl = doc.querySelector('.recipe-difficulty');
      if (diffEl != null) {
        final difficulty = extractDifficulty(diffEl.text);
        if (difficulty != null) recipe['difficulty'] = difficulty;
      }
    }

    // Category (meal type) from HTML or JSON-LD
    if (recipe['category'] == null) {
      final catEl = doc.querySelector('.recipe-category');
      if (catEl != null) {
        final cat = catEl.text.trim();
        if (cat.isNotEmpty) recipe['category'] = cat;
      }
      // Fallback: use JSON-LD recipeCategory
      recipe['category'] ??= recipe['recipeCategory'];
    }

    // Cuisine from HTML or JSON-LD
    if (recipe['cuisine'] == null) {
      final cuisineEl = doc.querySelector('.recipe-cuisine');
      if (cuisineEl != null) {
        final cuisine = cuisineEl.text.trim();
        if (cuisine.isNotEmpty) recipe['cuisine'] = cuisine;
      }
      // Fallback: use JSON-LD recipeCuisine
      recipe['cuisine'] ??= recipe['recipeCuisine'];
    }

    // Cooking tips from HTML
    if (recipe['cookingTips'] == null) {
      final tips = <String>[];
      for (final selector in ['.recipe-tips p', '.recipe-tips']) {
        for (final el in doc.querySelectorAll(selector)) {
          final text = el.text.trim();
          if (text.isNotEmpty) {
            final cleaned =
                text.replaceFirst(RegExp(r'^Tips[^:]*:\s*'), '').trim();
            if (cleaned.isNotEmpty) tips.add(cleaned);
          }
        }
        if (tips.isNotEmpty) break;
      }
      if (tips.isNotEmpty) recipe['cookingTips'] = tips;
    }

    // Serving suggestions from HTML
    if (recipe['servingSuggestions'] == null) {
      final suggestions = <String>[];
      for (final selector in [
        '.serving-suggestions p',
        '.serving-suggestions'
      ]) {
        for (final el in doc.querySelectorAll(selector)) {
          final text = el.text.trim();
          if (text.isNotEmpty) suggestions.add(text);
        }
        if (suggestions.isNotEmpty) break;
      }
      if (suggestions.isNotEmpty) recipe['servingSuggestions'] = suggestions;
    }

    return recipe;
  }

  @override
  Map<String, dynamic>? extractWithCssSelectors(String html) {
    try {
      final doc = html_parser.parse(html);

      // Recept.se uses various CSS classes/selectors for recipe content
      final title = _extractTitle(doc);
      final description = _extractDescription(doc);
      final ingredients = _extractIngredients(doc);
      final instructions = _extractInstructions(doc);
      final portions = _extractPortions(doc);
      final time = _extractTime(doc);
      final image = _extractImage(doc);

      // Must have at least title and ingredients
      if (title == null || ingredients.isEmpty) {
        return null;
      }

      final recipe = <String, dynamic>{
        'name': title,
        'recipeIngredient': ingredients,
        'recipeInstructions': instructions,
      };

      if (description != null) recipe['description'] = description;
      if (portions != null) recipe['recipeYield'] = portions;
      if (time != null) recipe['totalTime'] = time;
      if (image != null) recipe['image'] = image;

      // Extract difficulty from CSS fallback
      final diffEl = doc.querySelector('.recipe-difficulty');
      if (diffEl != null) {
        final difficulty = extractDifficulty(diffEl.text);
        if (difficulty != null) recipe['difficulty'] = difficulty;
      }

      // Extract category from CSS fallback
      final catEl = doc.querySelector('.recipe-category');
      if (catEl != null) {
        final cat = catEl.text.trim();
        if (cat.isNotEmpty) recipe['category'] = cat;
      }

      return recipe;
    } catch (e) {
      return null;
    }
  }

  /// Clean Recept-specific formatting quirks
  Map<String, dynamic> _cleanReceptFormatting(Map<String, dynamic> recipe) {
    // Recept sometimes includes "ca" (cirka/approximately) in portions
    final yield_ = recipe['recipeYield'];
    if (yield_ is String) {
      recipe['recipeYield'] =
          yield_.replaceAll('ca ', '').replaceAll('cirka ', '').trim();
    }

    // Clean ingredient formatting
    if (recipe['recipeIngredient'] is List) {
      final ingredients = recipe['recipeIngredient'] as List;
      recipe['recipeIngredient'] = ingredients
          .map((ing) {
            String cleaned = cleanSwedishText(ing.toString());
            // Remove "ca " and "cirka " prefixes from ingredients
            cleaned =
                cleaned.replaceAll(RegExp(r'^ca\s+', caseSensitive: false), '');
            cleaned = cleaned.replaceAll(
                RegExp(r'^cirka\s+', caseSensitive: false), '');
            return cleaned.trim();
          })
          .where((ing) => ing.isNotEmpty)
          .toList();
    }

    // Clean instruction formatting
    if (recipe['recipeInstructions'] is List) {
      final instructions = recipe['recipeInstructions'] as List;
      recipe['recipeInstructions'] = instructions
          .map((inst) {
            if (inst is String) {
              return cleanSwedishText(inst);
            } else if (inst is Map && inst['text'] != null) {
              return {
                ...inst,
                'text': cleanSwedishText(inst['text'].toString()),
              };
            }
            return inst;
          })
          .where((inst) => inst is String
              ? inst.isNotEmpty
              : inst is Map && inst['text'] != null)
          .toList();
    }

    return recipe;
  }

  // CSS SELECTOR EXTRACTION (Fallback Methods)

  String? _extractTitle(Document doc) {
    final selectors = [
      'h1.recipe-title',
      '.recept-title',
      '.recipe-header h1',
      '[itemprop="name"]',
      'h1',
    ];

    for (final selector in selectors) {
      final element = doc.querySelector(selector);
      if (element != null) {
        final title = element.text.trim();
        if (title.isNotEmpty && title.length > 3) {
          return cleanSwedishText(title);
        }
      }
    }

    return null;
  }

  String? _extractDescription(Document doc) {
    final selectors = [
      '.recipe-description',
      '.recept-description',
      '[itemprop="description"]',
      '.recipe-intro',
      '.recipe-preamble',
    ];

    for (final selector in selectors) {
      final element = doc.querySelector(selector);
      if (element != null) {
        final desc = element.text.trim();
        if (desc.isNotEmpty && desc.length > 10) {
          return cleanSwedishText(desc);
        }
      }
    }

    return null;
  }

  List<String> _extractIngredients(Document doc) {
    final ingredients = <String>[];

    final selectors = [
      '.ingredient-list li',
      '.ingredients-list li',
      '.recept-ingredients li',
      '[itemprop="recipeIngredient"]',
      '.recipe-ingredients li',
    ];

    for (final selector in selectors) {
      final elements = doc.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        for (final element in elements) {
          final ingredient = element.text.trim();
          if (ingredient.isNotEmpty) {
            ingredients.add(cleanSwedishText(ingredient));
          }
        }

        // If we found ingredients with this selector, stop
        if (ingredients.isNotEmpty) break;
      }
    }

    return ingredients;
  }

  List<Map<String, String>> _extractInstructions(Document doc) {
    final instructions = <Map<String, String>>[];

    final selectors = [
      '.recipe-steps li',
      '.instructions ol li',
      '.recipe-instructions li',
      '.recept-instructions li',
      '[itemprop="recipeInstructions"] li',
    ];

    for (final selector in selectors) {
      final elements = doc.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        int stepNumber = 1;
        for (final element in elements) {
          final text = element.text.trim();
          if (text.isNotEmpty) {
            instructions.add({
              '@type': 'HowToStep',
              'text': cleanSwedishText(text),
              'position': stepNumber.toString(),
            });
            stepNumber++;
          }
        }

        // If we found instructions with this selector, stop
        if (instructions.isNotEmpty) break;
      }
    }

    return instructions;
  }

  String? _extractPortions(Document doc) {
    final selectors = [
      '.recipe-portions',
      '.recept-portions',
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

    // Try finding "Portioner: X" in text
    final bodyText = (doc.body?.text).orEmpty();
    final portionMatch = RegExp(r'Portioner?:\s*(\d+)', caseSensitive: false)
        .firstMatch(bodyText);
    if (portionMatch != null) {
      return portionMatch.group(1);
    }

    return null;
  }

  String? _extractTime(Document doc) {
    final selectors = [
      '[itemprop="totalTime"]',
      '.recipe-time',
      '.recept-time',
      '.cooking-time',
      '.total-time',
    ];

    for (final selector in selectors) {
      final element = doc.querySelector(selector);
      if (element != null) {
        final timeAttr =
            element.attributes['content'] ?? element.attributes['datetime'];
        if (timeAttr != null && timeAttr.startsWith('PT')) {
          return timeAttr; // ISO 8601 format
        }

        final timeText = element.text.trim();
        if (timeText.isNotEmpty) {
          // Try to convert to ISO 8601
          return _convertToIso8601(timeText);
        }
      }
    }

    return null;
  }

  String? _extractImage(Document doc) {
    final selectors = [
      '[itemprop="image"]',
      '.recipe-image img',
      '.recept-image img',
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

  /// Convert Swedish time text to ISO 8601 duration
  /// Examples:
  /// - "30 minuter" → "PT30M"
  /// - "1 timme 30 min" → "PT1H30M"
  /// - "45 min" → "PT45M"
  String? _convertToIso8601(String timeText) {
    final lowerText = timeText.toLowerCase();

    // Extract hours
    final hoursMatch = RegExp(r'(\d+)\s*timm').firstMatch(lowerText);
    final hours =
        hoursMatch != null ? int.tryParse(hoursMatch.group(1)!) : null;

    // Extract minutes
    final minutesMatch = RegExp(r'(\d+)\s*min').firstMatch(lowerText);
    final minutes =
        minutesMatch != null ? int.tryParse(minutesMatch.group(1)!) : null;

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
