import 'package:clock/clock.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/nutrition_info.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Extracts Recipe objects from schema.org JSON-LD data.
class SchemaOrgRecipeExtractor {
  static const _uuid = Uuid();
  static final _unescape = HtmlUnescape();

  SchemaOrgRecipeExtractor._();

  /// Creates a Recipe from schema.org structured data.
  static Recipe createRecipe(Map<String, dynamic> data, String sourceUrl) {
    return Recipe(
      core: RecipeCore(
        id: _uuid.v4(),
        title: extractTitle(data),
        description: extractDescription(data),
        ingredients: extractIngredients(data),
        instructions: extractInstructions(data),
        portions: extractYield(data),
        timeMinutes: extractTime(data),
        mealType: extractCategory(data) ?? 'Middag',
        imageUrls: extractImages(data),
        sourceUrl: sourceUrl,
        createdAt: clock.now(),
        updatedAt: clock.now(),
        createdBy: '',
        prepTimeMinutes: parseDuration(data['prepTime']),
        cookTimeMinutes: parseDuration(data['cookTime']),
        cuisine: extractCuisine(data),
        nutritionInfo: extractNutrition(data),
      ),
      type: RecipeType.personal,
    );
  }

  static String extractTitle(Map<String, dynamic> data) {
    final name = data['name'];
    if (name != null && name.toString().trim().isNotEmpty) {
      return _unescape.convert(name.toString().trim());
    }
    return 'Imported Recipe';
  }

  static String extractDescription(Map<String, dynamic> data) {
    final desc = data['description'];
    final raw = (desc?.toString().trim()).orEmpty();
    return raw.isNotEmpty ? _unescape.convert(raw) : '';
  }

  static List<String> extractIngredients(Map<String, dynamic> data) {
    final ingredients = data['recipeIngredient'];

    if (ingredients == null) return [];

    if (ingredients is List) {
      return ingredients
          .map((e) => _cleanIngredient(e.toString()))
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (ingredients is String && ingredients.trim().isNotEmpty) {
      return [_cleanIngredient(ingredients)];
    }

    return [];
  }

  static List<String> extractInstructions(Map<String, dynamic> data) {
    final instructions = data['recipeInstructions'];

    if (instructions == null) return [];

    if (instructions is List) {
      final steps = <String>[];
      for (final instruction in instructions) {
        _collectInstructionSteps(instruction, steps);
      }
      return steps.where((s) => s.isNotEmpty).toList();
    }

    if (instructions is String && instructions.trim().isNotEmpty) {
      final steps = instructions
          .split(RegExp(r'\.\s+(?=[A-Z])'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (steps.length > 1) {
        return steps.map((s) => s.endsWith('.') ? s : '$s.').toList();
      }

      return [instructions.trim()];
    }

    return [];
  }

  /// Flattens one `recipeInstructions` element into [steps].
  ///
  /// schema.org allows three shapes here: a bare string, a `HowToStep`
  /// ({ text }), and a `HowToSection` whose actual steps live nested under
  /// `itemListElement`. The previous code only read `text` on the top-level
  /// map, so HowToSection recipes (common on sites that group steps into
  /// "Förberedelse"/"Tillagning") yielded ZERO instructions. We recurse into
  /// `itemListElement` so sectioned steps are collected too.
  static void _collectInstructionSteps(
    dynamic instruction,
    List<String> steps,
  ) {
    if (instruction is String) {
      steps.add(instruction.trim());
      return;
    }

    if (instruction is Map) {
      final section = instruction['itemListElement'];
      if (section is List) {
        for (final child in section) {
          _collectInstructionSteps(child, steps);
        }
        return;
      }

      final text = instruction['text'];
      if (text != null && text.toString().trim().isNotEmpty) {
        steps.add(text.toString().trim());
      }
    }
  }

  /// Strips price annotations like "($0.18)", "$7.95*" from ingredient text.
  static String _cleanIngredient(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'\s*\$[\d.,]+\*{0,2}'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*\(\s*\)'), '');
    cleaned = cleaned.replaceAll(RegExp(r',\s*\)'), ')');
    return cleaned.trim();
  }

  static int? extractYield(Map<String, dynamic> data) {
    final yield_ = data['recipeYield'];

    if (yield_ == null) return null;

    final yieldStr = yield_.toString();
    final match = RegExp(r'\d+').firstMatch(yieldStr);

    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  static int? extractTime(Map<String, dynamic> data) {
    final duration = data['totalTime'];

    if (duration == null) {
      final prepTime = parseDuration(data['prepTime']);
      final cookTime = parseDuration(data['cookTime']);

      if (prepTime != null || cookTime != null) {
        return (prepTime ?? 0) + (cookTime ?? 0);
      }

      return null;
    }

    return parseDuration(duration);
  }

  static int? parseDuration(dynamic duration) {
    if (duration == null) return null;

    final durationStr = duration.toString().trim();

    if (!durationStr.startsWith('PT')) return null;

    int totalMinutes = 0;

    final hoursMatch = RegExp(r'(\d+)H').firstMatch(durationStr);
    if (hoursMatch != null) {
      totalMinutes += (int.tryParse(hoursMatch.group(1)!) ?? 0) * 60;
    }

    final minutesMatch = RegExp(r'(\d+)M').firstMatch(durationStr);
    if (minutesMatch != null) {
      totalMinutes += int.tryParse(minutesMatch.group(1)!) ?? 0;
    }

    return totalMinutes > 0 ? totalMinutes : null;
  }

  static String? extractCuisine(Map<String, dynamic> data) {
    final cuisine = data['recipeCuisine'];
    if (cuisine is String && cuisine.trim().isNotEmpty) {
      return _unescape.convert(cuisine.trim());
    }
    if (cuisine is List && cuisine.isNotEmpty) {
      final first = cuisine.first;
      if (first is String && first.trim().isNotEmpty) {
        return _unescape.convert(first.trim());
      }
    }
    return null;
  }

  static String? extractCategory(Map<String, dynamic> data) {
    final category = data['recipeCategory'];
    if (category is String && category.trim().isNotEmpty) {
      return _unescape.convert(category.trim());
    }
    if (category is List && category.isNotEmpty) {
      final first = category.first;
      if (first is String && first.trim().isNotEmpty) {
        return _unescape.convert(first.trim());
      }
    }
    return null;
  }

  static NutritionInfo? extractNutrition(Map<String, dynamic> data) {
    final nutrition = data['nutrition'];
    if (nutrition is Map) {
      final info = NutritionInfo.fromSchemaOrg(
        Map<String, dynamic>.from(nutrition),
      );
      return info.isEmpty ? null : info;
    }
    return null;
  }

  static List<String> extractImages(Map<String, dynamic> data) {
    final image = data['image'];

    if (image == null) return [];

    if (image is String && image.trim().isNotEmpty) {
      return [image.trim()];
    }

    if (image is List) {
      return image
          .map((e) {
            if (e is String) return e.trim();
            if (e is Map && e['url'] != null) return e['url'].toString().trim();
            return null;
          })
          .whereType<String>()
          .where((url) => url.isNotEmpty)
          .toList();
    }

    if (image is Map && image['url'] != null) {
      final url = image['url'].toString().trim();
      if (url.isNotEmpty) {
        return [url];
      }
    }

    return [];
  }
}
