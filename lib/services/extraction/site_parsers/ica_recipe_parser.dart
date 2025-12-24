/// ICA.se recipe parser with Swedish-specific enhancements
/// ICA (Swedish grocery chain) provides recipes with schema.org JSON-LD markup.
/// This parser extracts standard recipe data and adds ICA-specific enhancements.
/// **Target Success Rate:** >95% (high quality)
/// **ICA-Specific Features:**
/// - Difficulty level extraction
/// - Cooking tips
/// - Equipment recommendations
/// - Swedish ingredient formatting

import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:butlery/services/extraction/site_parsers/recipe_site_parser.dart';

/// Parser for ICA.se recipes
/// **Example URL:** https://www.ica.se/recept/kottbullar-724853/
class IcaRecipeParser extends RecipeSiteParser {
  @override
  String get domain => 'ica.se';

  @override
  String get siteName => 'ICA';

  @override
  Map<String, dynamic> enhanceRecipe(Map<String, dynamic> recipe, String html) {
    try {
      final doc = html_parser.parse(html);

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
  Map<String, dynamic>? extractWithCssSelectors(String html) {
    try {
      final doc = html_parser.parse(html);

      // ICA.se uses various CSS classes/selectors for recipe content
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
    final bodyText = doc.body?.text ?? '';
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
    final bodyText = doc.body?.text ?? '';
    final tipMatch = RegExp(r'Tips?:\s*(.+?)(?:\n|$)', caseSensitive: false)
        .firstMatch(bodyText);
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
      recipe['recipeYield'] =
          yield_.replaceAll('ca ', '').replaceAll('cirka ', '').trim();
    }

    // Clean ingredient formatting
    if (recipe['recipeIngredient'] is List) {
      final ingredients = recipe['recipeIngredient'] as List;
      recipe['recipeIngredient'] = ingredients
          .map((ing) => cleanSwedishText(ing.toString()))
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

  // ============================================================================
  // CSS SELECTOR EXTRACTION (Fallback Methods)
  // ============================================================================

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

  List<Map<String, String>> _extractInstructions(Document doc) {
    final instructions = <Map<String, String>>[];

    final selectors = [
      '.recipe-steps li',
      '.instructions ol li',
      '.recipe-instructions li',
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
    final bodyText = doc.body?.text ?? '';
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
