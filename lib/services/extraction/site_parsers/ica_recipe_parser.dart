/// ICA.se recipe parser with Swedish-specific enhancements
/// ICA (Swedish grocery chain) provides recipes with schema.org JSON-LD markup.
/// This parser extracts standard recipe data and adds ICA-specific enhancements.
/// **Target Success Rate:** >95% (high quality)
/// **ICA-Specific Features:**
/// - Difficulty level extraction
/// - Cooking tips
/// - Equipment recommendations
/// - Swedish ingredient formatting

import 'package:html/dom.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/services/extraction/site_parsers/recipe_site_parser.dart';
import 'package:butlery/utils/recipe_scraper.dart';

/// Parser for ICA.se recipes
/// **Example URL:** https://www.ica.se/recept/kottbullar-724853/
class IcaRecipeParser extends RecipeSiteParser {
  @override
  String get domain => 'ica.se';

  @override
  String get siteName => 'ICA';

  @override
  Map<String, dynamic> enhanceRecipe(
    Map<String, dynamic> recipe,
    Document doc,
  ) {
    try {
      // Extract ICA-specific fields
      final difficulty = _extractIcaDifficulty(doc);
      if (difficulty != null) {
        recipe['difficulty'] = difficulty;
      }

      final tips = _extractCookingTips(doc);
      if (tips.isNotEmpty) {
        recipe['cookingTips'] = tips;
      }

      final equipment = _extractEquipment(doc);
      if (equipment.isNotEmpty) {
        recipe['equipment'] = equipment;
      }

      // Clean up ICA-specific formatting quirks
      recipe = _cleanIcaFormatting(recipe);

      return recipe;
    } catch (e) {
      // Enhancement failed, return recipe as-is
      return recipe;
    }
  }

  @override
  Map<String, dynamic>? extractWithCssSelectors(Document doc) {
    try {
      // ICA.se uses various CSS classes/selectors for recipe content
      final title = _extractTitle(doc);
      final description = _extractDescription(doc);
      final ingredients = _extractIngredients(doc);
      final instructions = _extractInstructions(doc);
      final portions = extractPortions(doc);
      final time = _extractTime(doc);
      final image = extractImage(doc);

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

      return recipe;
    } catch (e) {
      return null;
    }
  }

  /// Extract ICA difficulty level
  /// Common ICA difficulty indicators:
  /// - "Enkel" (Simple)
  /// - "Medel" (Medium)
  /// - "Avancerad" (Advanced)
  String? _extractIcaDifficulty(Document doc) {
    // Try common ICA difficulty selectors
    final selectors = [
      '.recipe-difficulty',
      '[data-difficulty]',
      '.recipe-meta-difficulty',
      '.difficulty-level',
    ];

    for (final selector in selectors) {
      final element = doc.querySelector(selector);
      if (element != null) {
        final text = element.text.trim();
        return extractDifficulty(text);
      }
    }

    // Try finding in text content
    final bodyText = (doc.body?.text).orEmpty();
    return extractDifficulty(bodyText);
  }

  /// Extract cooking tips
  List<String> _extractCookingTips(Document doc) {
    final tips = <String>[];

    // Try common ICA tip selectors
    final selectors = [
      '.recipe-tips',
      '.cooking-tips',
      '.chef-tips',
      '.recipe-notes',
    ];

    for (final selector in selectors) {
      final elements = doc.querySelectorAll(selector);
      for (final element in elements) {
        final tip = element.text.trim();
        if (tip.isNotEmpty && tip.length > 10) {
          tips.add(cleanSwedishText(tip));
        }
      }
    }

    // Look for "Tips:" sections in text
    final bodyText = (doc.body?.text).orEmpty();
    final tipMatch = RegExp(
      r'Tips?:\s*(.+?)(?:\n|$)',
      caseSensitive: false,
    ).firstMatch(bodyText);
    if (tipMatch != null) {
      final tip = tipMatch.group(1)?.trim();
      if (tip != null && tip.isNotEmpty) {
        tips.add(cleanSwedishText(tip));
      }
    }

    return tips;
  }

  /// Extract equipment recommendations
  List<String> _extractEquipment(Document doc) {
    final equipment = <String>[];

    final selectors = [
      '.recipe-equipment',
      '.equipment-list li',
      '.required-equipment li',
    ];

    for (final selector in selectors) {
      final elements = doc.querySelectorAll(selector);
      for (final element in elements) {
        final item = element.text.trim();
        if (item.isNotEmpty) {
          equipment.add(cleanSwedishText(item));
        }
      }
    }

    return equipment;
  }

  /// Clean ICA-specific formatting quirks
  Map<String, dynamic> _cleanIcaFormatting(Map<String, dynamic> recipe) {
    // ICA sometimes includes "ca" (cirka/approximately) in portions
    final yield_ = recipe['recipeYield'];
    if (yield_ is String) {
      recipe['recipeYield'] = yield_
          .replaceAll('ca ', '')
          .replaceAll('cirka ', '')
          .trim();
    }

    // Clean ingredient formatting
    if (recipe['recipeIngredient'] is List) {
      final ingredients = recipe['recipeIngredient'] as List;
      recipe['recipeIngredient'] = ingredients
          .map((ing) => cleanSwedishText(ing.toString()))
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

  // CSS SELECTOR EXTRACTION (Fallback Methods)

  String? _extractTitle(Document doc) {
    final selectors = [
      'h1.recipe-title',
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

  List<String> _extractInstructions(Document doc) {
    final instructions = <String>[];

    final selectors = [
      '.recipe-steps li',
      '.instructions ol li',
      '.recipe-instructions li',
      '[itemprop="recipeInstructions"] li',
    ];

    for (final selector in selectors) {
      final elements = doc.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        for (final element in elements) {
          final text = element.text.trim();
          if (text.isNotEmpty) instructions.add(cleanSwedishText(text));
        }

        // If we found instructions with this selector, stop
        if (instructions.isNotEmpty) break;
      }
    }

    return instructions;
  }

  String? _extractTime(Document doc) {
    final selectors = [
      '[itemprop="totalTime"]',
      '.recipe-time',
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
          return swedishTimeToIso8601(timeText);
        }
      }
    }

    return null;
  }
}
