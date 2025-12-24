import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/site_config.dart';
import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/tiers/parsing_tier.dart';
import 'package:butlery/utils/text/ingredient_parser.dart' hide ParsedIngredient;
import 'package:butlery/core/utils/logger.dart';

/// Tier 2: Site-specific CSS selector extraction.
///
/// Uses Firestore-stored CSS selectors per domain to extract recipe data.
/// This allows updating site configurations without app releases.
class SiteConfigTier extends ParsingTier with QualityScoring {
  /// Function to load site config from repository.
  final Future<SiteConfig?> Function(String domain)? configLoader;

  /// Optional pre-loaded config for testing.
  final SiteConfig? preloadedConfig;

  SiteConfigTier({
    this.configLoader,
    this.preloadedConfig,
  });

  @override
  String get tierName => 'SiteConfig';

  @override
  int get priority => 2;

  @override
  Duration get defaultTimeout => const Duration(seconds: 10);

  @override
  double get minQualityScore => 0.3;

  @override
  bool shouldSkip(ParsingContext context) {
    // Only works for URL sources with HTML content
    if (context.source != ImportSource.url) return true;
    if (context.sanitizedContent.isEmpty) return true;
    if (context.domain == null) return true;

    return false;
  }

  @override
  Future<TierResult> parse(ParsingContext context) async {
    final stopwatch = Stopwatch()..start();

    // Load site config
    final config = await _loadConfig(context.domain!);

    if (config == null || !config.hasSelectors) {
      return TierResult.skipped(
        tierName: tierName,
        duration: stopwatch.elapsed,
      );
    }

    if (!config.isSupported) {
      AppLogger.debug('$tierName: Site ${context.domain} is not supported');
      return TierResult.skipped(
        tierName: tierName,
        duration: stopwatch.elapsed,
      );
    }

    // Parse HTML
    final document = _getDocument(context);
    if (document == null) {
      return TierResult.noData(
        tierName: tierName,
        duration: stopwatch.elapsed,
      );
    }

    // Extract using selectors
    final recipe = _extractWithSelectors(document, config, context);

    if (recipe == null) {
      return TierResult.noData(
        tierName: tierName,
        duration: stopwatch.elapsed,
      );
    }

    return TierResult.success(
      tierName: tierName,
      recipe: recipe,
      duration: stopwatch.elapsed,
    );
  }

  Future<SiteConfig?> _loadConfig(String domain) async {
    if (preloadedConfig != null) {
      return preloadedConfig;
    }

    if (configLoader != null) {
      return configLoader!(domain);
    }

    return null;
  }

  Document? _getDocument(ParsingContext context) {
    // Use cached document if available
    if (context.parsedDocument is Document) {
      return context.parsedDocument as Document;
    }

    try {
      final doc = html_parser.parse(context.sanitizedContent);
      context.parsedDocument = doc;
      return doc;
    } catch (e) {
      AppLogger.warning('$tierName: Failed to parse HTML: $e');
      return null;
    }
  }

  ParsedRecipe? _extractWithSelectors(
    Document document,
    SiteConfig config,
    ParsingContext context,
  ) {
    // Extract title
    final title = _extractBySelector(document, config.titleSelector);

    // Extract ingredients
    final ingredientElements =
        _extractAllBySelector(document, config.ingredientsSelector);
    final ingredients = _parseIngredients(ingredientElements);

    // Extract instructions
    final instructionElements =
        _extractAllBySelector(document, config.instructionsSelector);
    final instructions = _parseInstructions(instructionElements);

    // Extract portions
    final portionsText = _extractBySelector(document, config.portionsSelector);
    final portions = _parsePortions(portionsText);

    // Extract time
    final timeText = _extractBySelector(document, config.timeSelector);
    final totalTime = _parseTime(timeText);

    // Extract image
    final imageUrl = _extractImageBySelector(document, config.imageSelector);

    // Extract description
    final description =
        _extractBySelector(document, config.descriptionSelector);

    // Check minimum requirements
    if (ingredients.value == null || ingredients.value!.isEmpty) {
      return null;
    }

    // Create metadata
    final metadata = ParseMetadata(
      source: context.source,
      domain: context.domain,
      sourceUrl: context.sourceUrl,
      parserVersion: context.parserVersion,
      timestamp: DateTime.now(),
      totalParseTime: context.elapsed,
      tierResults: const [],
    );

    return ParsedRecipe(
      title: title != null && title.isNotEmpty
          ? FieldResult.success(title)
          : FieldResult.failed('No title found'),
      portions: portions,
      ingredients: ingredients,
      instructions: instructions,
      totalTime: totalTime,
      metadata: metadata,
      imageUrl: imageUrl,
      description: description,
    );
  }

  String? _extractBySelector(Document document, String? selector) {
    if (selector == null || selector.isEmpty) return null;

    try {
      final element = document.querySelector(selector);
      return element?.text.trim();
    } catch (e) {
      AppLogger.warning('$tierName: Invalid selector "$selector": $e');
      return null;
    }
  }

  List<String> _extractAllBySelector(Document document, String? selector) {
    if (selector == null || selector.isEmpty) return [];

    try {
      final elements = document.querySelectorAll(selector);
      return elements.map((e) => e.text.trim()).where((t) => t.isNotEmpty).toList();
    } catch (e) {
      AppLogger.warning('$tierName: Invalid selector "$selector": $e');
      return [];
    }
  }

  String? _extractImageBySelector(Document document, String? selector) {
    if (selector == null || selector.isEmpty) return null;

    try {
      final element = document.querySelector(selector);
      if (element == null) return null;

      // Try src attribute first, then data-src
      var url = element.attributes['src'];
      url ??= element.attributes['data-src'];
      url ??= element.attributes['data-lazy-src'];

      if (url != null && url.startsWith('http')) {
        return url;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  FieldResult<List<ParsedIngredient>> _parseIngredients(List<String> texts) {
    if (texts.isEmpty) {
      return FieldResult.failed('No ingredients found');
    }

    final parsed = <ParsedIngredient>[];

    for (final text in texts) {
      // Clean up text
      final cleaned = text
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (cleaned.isEmpty) continue;

      // Use existing IngredientParser
      final result = IngredientParser.parseIngredient(cleaned);

      parsed.add(ParsedIngredient(
        name: result.name,
        originalLine: cleaned,
        quantity: result.quantity > 0 ? result.quantity.toString() : null,
        unit: result.unit.isNotEmpty ? result.unit : null,
        confidence: result.quantity > 0 || result.unit.isNotEmpty
            ? ParseConfidence.medium
            : ParseConfidence.low,
      ));
    }

    if (parsed.isEmpty) {
      return FieldResult.failed('Could not parse ingredients');
    }

    return FieldResult.mediumConfidence(
      parsed,
      'Extracted via CSS selectors',
    );
  }

  FieldResult<List<String>> _parseInstructions(List<String> texts) {
    if (texts.isEmpty) {
      return FieldResult.failed('No instructions found');
    }

    final cleaned = texts
        .map((t) => t.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((t) => t.isNotEmpty)
        // Remove step numbers
        .map((t) => t.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), ''))
        .toList();

    if (cleaned.isEmpty) {
      return FieldResult.failed('Could not parse instructions');
    }

    return FieldResult.mediumConfidence(
      cleaned,
      'Extracted via CSS selectors',
    );
  }

  FieldResult<int> _parsePortions(String? text) {
    if (text == null || text.isEmpty) {
      return FieldResult.lowConfidence(4, 'Defaulting to 4 portions');
    }

    final match = RegExp(r'(\d+)').firstMatch(text);
    if (match != null) {
      final num = int.tryParse(match.group(1) ?? '');
      if (num != null && num > 0 && num <= 100) {
        return FieldResult.mediumConfidence(num, 'Extracted from page');
      }
    }

    return FieldResult.lowConfidence(4, 'Could not parse portions');
  }

  FieldResult<Duration> _parseTime(String? text) {
    if (text == null || text.isEmpty) {
      return FieldResult.failed('No time found');
    }

    // Try to extract minutes
    final minMatch = RegExp(r'(\d+)\s*(?:min|m\b)', caseSensitive: false).firstMatch(text);
    final hourMatch = RegExp(r'(\d+)\s*(?:tim|h\b|hour)', caseSensitive: false).firstMatch(text);

    var totalMinutes = 0;

    if (hourMatch != null) {
      totalMinutes += (int.tryParse(hourMatch.group(1) ?? '') ?? 0) * 60;
    }

    if (minMatch != null) {
      totalMinutes += int.tryParse(minMatch.group(1) ?? '') ?? 0;
    }

    // If no unit found, assume the number is minutes
    if (totalMinutes == 0) {
      final numMatch = RegExp(r'(\d+)').firstMatch(text);
      if (numMatch != null) {
        totalMinutes = int.tryParse(numMatch.group(1) ?? '') ?? 0;
      }
    }

    if (totalMinutes > 0) {
      return FieldResult.mediumConfidence(
        Duration(minutes: totalMinutes),
        'Extracted from page',
      );
    }

    return FieldResult.failed('Could not parse time');
  }
}
