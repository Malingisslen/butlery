import 'package:clock/clock.dart';
import 'package:html_unescape/html_unescape.dart';

import 'package:butlery/models/nutrition_info.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/tiers/parsing_tier.dart';
import 'package:butlery/utils/recipe_scraper.dart';

/// Tier 1: Schema.org JSON-LD and Microdata extraction.
///
/// This tier wraps the existing RecipeScraper to extract structured
/// data from HTML content. It's the fastest and most reliable tier
/// for websites that implement schema.org Recipe markup.
class SchemaOrgTier extends ParsingTier with QualityScoring {
  static final _unescape = HtmlUnescape();
  final IngredientParsingStrategy _ingredientStrategy;

  SchemaOrgTier({IngredientParsingStrategy? ingredientStrategy})
      : _ingredientStrategy = ingredientStrategy ?? IngredientParsingStrategy();

  static const tierIdentifier = 'SchemaOrg';

  @override
  String get tierName => tierIdentifier;

  @override
  int get priority => 1;

  @override
  Duration get defaultTimeout => const Duration(seconds: 5);

  @override
  double get minQualityScore => 0.0;

  @override
  bool shouldSkip(ParsingContext context) {
    // Only works for URL sources with HTML content
    if (context.source != ImportSource.url) return true;
    if (context.sanitizedContent.isEmpty) return true;

    // Skip if content doesn't look like HTML
    if (!context.sanitizedContent.contains('<')) return true;

    return false;
  }

  @override
  Future<TierResult> parse(ParsingContext context) async {
    final stopwatch = Stopwatch()..start();

    // Use existing RecipeScraper with detailed result
    final extraction = extractRecipeFromHtmlDetailed(context.sanitizedContent);

    if (extraction.data == null) {
      if (extraction.hadStructuredData) {
        return TierResult.failure(
          tierName: tierName,
          reason: TierFailureReason.parseError,
          duration: stopwatch.elapsed,
        );
      }
      return TierResult.noData(
        tierName: tierName,
        duration: stopwatch.elapsed,
      );
    }

    final data = extraction.data!;

    // Cache JSON-LD data in context for other tiers
    context.jsonLdData = data;

    // Convert schema.org data to ParsedRecipe
    final recipe = await _convertToRecipe(data, context);

    if (recipe == null) {
      return TierResult.failure(
        tierName: tierName,
        reason: TierFailureReason.parseError,
        duration: stopwatch.elapsed,
      );
    }

    return TierResult.success(
      tierName: tierName,
      recipe: recipe,
      duration: stopwatch.elapsed,
    );
  }

  /// Convert schema.org data to ParsedRecipe.
  Future<ParsedRecipe?> _convertToRecipe(
    Map<String, dynamic> data,
    ParsingContext context,
  ) async {
    // Extract title
    final title = _extractTitle(data);
    if (!title.hasValue) return null;

    // Extract portions
    final portions = _extractPortions(data);

    // Extract ingredients
    final ingredients = await _extractIngredients(data, context);

    // Extract instructions
    final instructions = _extractInstructions(data);

    // Extract time
    final totalTime = _extractTotalTime(data);
    final prepTime = _extractPrepTime(data);
    final cookTime = _extractCookTime(data);

    // Extract new Schema.org fields
    final cuisine = _extractCuisine(data);
    final category = _extractCategory(data);
    final difficulty = _extractDifficulty(data);
    final nutrition = _extractNutrition(data);

    // Extract image
    final imageUrl = _extractImageUrl(data);

    // Extract description
    final description = _extractDescription(data);

    // Create metadata
    final metadata = ParseMetadata(
      source: context.source,
      domain: context.domain,
      sourceUrl: context.sourceUrl,
      parserVersion: context.parserVersion,
      timestamp: clock.now(),
      totalParseTime: context.elapsed,
      tierResults: const [],
    );

    return ParsedRecipe(
      title: title,
      portions: portions,
      ingredients: ingredients,
      instructions: instructions,
      totalTime: totalTime,
      prepTime: prepTime,
      cookTime: cookTime,
      cuisine: cuisine,
      category: category,
      difficulty: difficulty,
      nutrition: nutrition,
      metadata: metadata,
      imageUrl: imageUrl,
      description: description,
    );
  }

  FieldResult<String> _extractTitle(Map<String, dynamic> data) {
    final name = data['name'];
    if (name is String && name.isNotEmpty) {
      return FieldResult.success(_unescape.convert(name.trim()));
    }

    // Fallback to headline
    final headline = data['headline'];
    if (headline is String && headline.isNotEmpty) {
      return FieldResult.success(_unescape.convert(headline.trim()));
    }

    return FieldResult.failed('No title in schema.org data');
  }

  FieldResult<int> _extractPortions(Map<String, dynamic> data) {
    // recipeYield can be string or number
    final yield_ = data['recipeYield'];

    if (yield_ is int) {
      return FieldResult.success(yield_);
    }

    if (yield_ is String) {
      // Try to extract number from string like "4 portioner" or "Serves 4"
      final match = RegExp(r'(\d+)').firstMatch(yield_);
      if (match != null) {
        final num = int.tryParse(match.group(1) ?? '');
        if (num != null && num > 0 && num <= ParsingTier.kMaxPortions) {
          return FieldResult.success(num);
        }
      }
    }

    if (yield_ is List && yield_.isNotEmpty) {
      // Sometimes it's an array, take first numeric value
      for (final item in yield_) {
        if (item is int) return FieldResult.success(item);
        if (item is String) {
          final match = RegExp(r'(\d+)').firstMatch(item);
          if (match != null) {
            final num = int.tryParse(match.group(1) ?? '');
            if (num != null && num > 0 && num <= ParsingTier.kMaxPortions) {
              return FieldResult.success(num);
            }
          }
        }
      }
    }

    return FieldResult.lowConfidence(
      ParsingTier.kDefaultPortions,
      'Defaulting to ${ParsingTier.kDefaultPortions} portions',
    );
  }

  Future<FieldResult<List<ParsedIngredient>>> _extractIngredients(
    Map<String, dynamic> data,
    ParsingContext context,
  ) async {
    final rawIngredients = data['recipeIngredient'];

    if (rawIngredients is! List || rawIngredients.isEmpty) {
      return FieldResult.failed('No ingredients in schema.org data');
    }

    final lines = rawIngredients
        .whereType<String>()
        .map((s) => _stripPriceAnnotation(s.trim()))
        .where((s) => s.isNotEmpty)
        .toList();

    return _ingredientStrategy.parseLines(
      lines,
      ocrCorrection: context.isOcrSource,
    );
  }

  FieldResult<List<String>> _extractInstructions(Map<String, dynamic> data) {
    final rawInstructions = data['recipeInstructions'];

    if (rawInstructions == null) {
      return FieldResult.failed('No instructions in schema.org data');
    }

    final instructions = <String>[];

    if (rawInstructions is String) {
      // Single string, split by newlines or periods
      final lines = rawInstructions
          .split(RegExp(r'\n+|(?<=[.!?])\s+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      instructions.addAll(lines);
    } else if (rawInstructions is List) {
      for (final item in rawInstructions) {
        if (item is String && item.trim().isNotEmpty) {
          instructions.add(item.trim());
        } else if (item is Map) {
          // HowToStep or HowToSection
          final text = item['text'] ?? item['name'] ?? '';
          if (text is String && text.trim().isNotEmpty) {
            instructions.add(text.trim());
          }

          // Handle HowToSection with itemListElement
          final itemList = item['itemListElement'];
          if (itemList is List) {
            for (final subItem in itemList) {
              if (subItem is Map) {
                final subText = subItem['text'] ?? subItem['name'] ?? '';
                if (subText is String && subText.trim().isNotEmpty) {
                  instructions.add(subText.trim());
                }
              }
            }
          }
        }
      }
    }

    if (instructions.isEmpty) {
      return FieldResult.failed('Could not parse instructions');
    }

    // Clean up numbered prefixes if present
    final cleaned = instructions.map((s) {
      return s.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '');
    }).toList();

    return FieldResult.success(cleaned);
  }

  FieldResult<Duration> _extractTotalTime(Map<String, dynamic> data) {
    // Check totalTime, then cookTime + prepTime
    final totalTime = data['totalTime'];
    if (totalTime is String) {
      final duration = _parseIsoDuration(totalTime);
      if (duration != null && duration.inMinutes > 0) {
        return FieldResult.success(duration);
      }
    }

    // Try combining prepTime and cookTime
    final prepTime = data['prepTime'];
    final cookTime = data['cookTime'];

    Duration combined = Duration.zero;

    if (prepTime is String) {
      final prep = _parseIsoDuration(prepTime);
      if (prep != null) combined += prep;
    }

    if (cookTime is String) {
      final cook = _parseIsoDuration(cookTime);
      if (cook != null) combined += cook;
    }

    if (combined.inMinutes > 0) {
      return FieldResult.mediumConfidence(
        combined,
        'Calculated from prep + cook time',
      );
    }

    return FieldResult.failed('No time in schema.org data');
  }

  /// Parse ISO 8601 duration format (PT30M, PT1H30M, etc.)
  Duration? _parseIsoDuration(String iso) {
    // Handle common formats: PT30M, PT1H30M, PT1H, P0DT1H30M
    final regex = RegExp(
      r'P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?',
      caseSensitive: false,
    );

    final match = regex.firstMatch(iso);
    if (match == null) return null;

    final days = int.tryParse(match.group(1) ?? '') ?? 0;
    final hours = int.tryParse(match.group(2) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(3) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(4) ?? '') ?? 0;

    if (days == 0 && hours == 0 && minutes == 0 && seconds == 0) {
      return null;
    }

    return Duration(
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    );
  }

  FieldResult<Duration> _extractPrepTime(Map<String, dynamic> data) {
    final prepTime = data['prepTime'];
    if (prepTime is String) {
      final duration = _parseIsoDuration(prepTime);
      if (duration != null && duration.inMinutes > 0) {
        return FieldResult.success(duration);
      }
    }
    return FieldResult.failed('No prep time in schema.org data');
  }

  FieldResult<Duration> _extractCookTime(Map<String, dynamic> data) {
    final cookTime = data['cookTime'];
    if (cookTime is String) {
      final duration = _parseIsoDuration(cookTime);
      if (duration != null && duration.inMinutes > 0) {
        return FieldResult.success(duration);
      }
    }
    return FieldResult.failed('No cook time in schema.org data');
  }

  FieldResult<String> _extractCuisine(Map<String, dynamic> data) {
    final cuisine = data['recipeCuisine'];
    if (cuisine is String && cuisine.trim().isNotEmpty) {
      return FieldResult.success(_sanitizeString(cuisine.trim(), 100));
    }
    if (cuisine is List && cuisine.isNotEmpty) {
      final first = cuisine.first;
      if (first is String && first.trim().isNotEmpty) {
        return FieldResult.success(_sanitizeString(first.trim(), 100));
      }
    }
    return FieldResult.failed('No cuisine in schema.org data');
  }

  FieldResult<String> _extractCategory(Map<String, dynamic> data) {
    final category = data['recipeCategory'];
    if (category is String && category.trim().isNotEmpty) {
      return FieldResult.success(_sanitizeString(category.trim(), 100));
    }
    if (category is List && category.isNotEmpty) {
      final first = category.first;
      if (first is String && first.trim().isNotEmpty) {
        return FieldResult.success(_sanitizeString(first.trim(), 100));
      }
    }
    return FieldResult.failed('No category in schema.org data');
  }

  FieldResult<String> _extractDifficulty(Map<String, dynamic> data) {
    // Schema.org doesn't have a standard difficulty field, but some sites use it
    final difficulty = data['difficulty'] ?? data['proficiencyLevel'];
    if (difficulty is String && difficulty.trim().isNotEmpty) {
      return FieldResult.success(_sanitizeString(difficulty.trim(), 100));
    }
    return FieldResult.failed('No difficulty in schema.org data');
  }

  FieldResult<NutritionInfo> _extractNutrition(Map<String, dynamic> data) {
    final nutrition = data['nutrition'];
    if (nutrition is Map<String, dynamic>) {
      final info = NutritionInfo.fromSchemaOrg(nutrition);
      if (!info.isEmpty) {
        return FieldResult.success(info);
      }
    }
    if (nutrition is Map) {
      final info =
          NutritionInfo.fromSchemaOrg(Map<String, dynamic>.from(nutrition));
      if (!info.isEmpty) {
        return FieldResult.success(info);
      }
    }
    return FieldResult.failed('No nutrition in schema.org data');
  }

  /// Sanitize external string: unescape HTML entities, strip tags, cap length.
  String _sanitizeString(String input, int maxLength) {
    var s = _unescape.convert(input);
    // Strip HTML tags
    s = s.replaceAll(RegExp(r'<[^>]*>'), '');
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  String? _extractImageUrl(Map<String, dynamic> data) {
    final image = data['image'];

    if (image is String && image.startsWith('http')) {
      return image;
    }

    if (image is List && image.isNotEmpty) {
      final first = image.first;
      if (first is String && first.startsWith('http')) {
        return first;
      }
      if (first is Map && first['url'] is String) {
        return first['url'] as String;
      }
    }

    if (image is Map && image['url'] is String) {
      return image['url'] as String;
    }

    return null;
  }

  String? _extractDescription(Map<String, dynamic> data) {
    final description = data['description'];
    if (description is String && description.trim().isNotEmpty) {
      return description.trim();
    }
    return null;
  }

  /// Strips price annotations like "($0.18)", "$7.95*" from ingredient text.
  static String _stripPriceAnnotation(String s) {
    // Remove any dollar-amount pattern (with optional trailing asterisks)
    var cleaned = s.replaceAll(RegExp(r'\s*\$[\d.,]+\*{0,2}'), '');
    // Remove standalone empty parens left behind: "()"
    cleaned = cleaned.replaceAll(RegExp(r'\s*\(\s*\)'), '');
    // Clean up dangling comma before closing paren: "(foo, )" → "(foo)"
    cleaned = cleaned.replaceAll(RegExp(r',\s*\)'), ')');
    return cleaned.trim();
  }
}
