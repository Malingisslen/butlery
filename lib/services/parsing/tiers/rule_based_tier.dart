import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/services/parsing/parsers/swedish_line_classifier.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/tiers/parsing_tier.dart';
import 'package:butlery/utils/text/ingredient_parser.dart'
    hide ParsedIngredient;
import 'package:html_unescape/html_unescape.dart';

/// Tier 3: Rule-based Swedish text parsing.
///
/// Uses the SwedishLineClassifier to parse unstructured text from
/// Instagram, TikTok, YouTube descriptions, and other social media sources.
/// Also serves as fallback for URL content that lacks structured data.
class RuleBasedTier extends ParsingTier with QualityScoring {
  @override
  String get tierName => 'RuleBased';

  @override
  int get priority => 3;

  @override
  Duration get defaultTimeout => const Duration(seconds: 15);

  @override
  double get minQualityScore => 0.3;

  @override
  bool shouldSkip(ParsingContext context) {
    // Works for any text-based source
    if (context.sanitizedContent.isEmpty) return true;

    return false;
  }

  @override
  Future<TierResult> parse(ParsingContext context) async {
    final stopwatch = Stopwatch()..start();

    // Get text content to classify
    final text = _extractTextContent(context);

    if (text.isEmpty) {
      return TierResult.noData(
        tierName: tierName,
        duration: stopwatch.elapsed,
      );
    }

    // Classify and parse
    final classifier = SwedishLineClassifier.instance;
    final structure = classifier.parseStructure(text);

    if (!structure.isValid) {
      return TierResult.noData(
        tierName: tierName,
        duration: stopwatch.elapsed,
      );
    }

    // Convert to ParsedRecipe
    final recipe = _convertToRecipe(structure, context);

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

  /// Extract text content from context.
  ///
  /// For HTML content, strips tags to get plain text.
  /// For text sources, returns content directly.
  String _extractTextContent(ParsingContext context) {
    final content = context.sanitizedContent;

    // If it looks like HTML, strip tags
    if (content.contains('<')) {
      return _stripHtmlTags(content);
    }

    return content;
  }

  /// Strip HTML tags and normalize whitespace.
  String _stripHtmlTags(String html) {
    // Remove script and style content first
    var text = html.replaceAll(
      RegExp(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>',
          caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>',
          caseSensitive: false),
      '',
    );

    // Replace block elements with newlines
    text = text.replaceAll(
      RegExp(r'<(?:br|p|div|li|tr|h[1-6])[^>]*>', caseSensitive: false),
      '\n',
    );

    // Remove remaining tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Decode HTML entities
    text = _decodeHtmlEntities(text);

    // Normalize whitespace
    text = text
        .replaceAll(RegExp(r'\t+'), ' ')
        .replaceAll(RegExp(r' +'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }

  static final _htmlUnescape = HtmlUnescape();

  /// Decode HTML entities (full spec coverage via html_unescape package).
  String _decodeHtmlEntities(String text) {
    return _htmlUnescape.convert(text);
  }

  ParsedRecipe? _convertToRecipe(
    ParsedRecipeStructure structure,
    ParsingContext context,
  ) {
    // Parse ingredients
    final ingredients = _parseIngredients(structure.ingredients);

    if (ingredients.value == null || ingredients.value!.isEmpty) {
      return null;
    }

    // Parse instructions
    final instructions = _parseInstructions(structure.instructions);

    if (instructions.value == null || instructions.value!.isEmpty) {
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
      title: structure.title != null && structure.title!.isNotEmpty
          ? FieldResult.mediumConfidence(
              structure.title!, 'Extracted from text')
          : FieldResult.failed('No title found'),
      portions: structure.portions != null
          ? FieldResult.mediumConfidence(
              structure.portions!, 'Extracted from text')
          : FieldResult.lowConfidence(4, 'Defaulting to 4 portions'),
      ingredients: ingredients,
      instructions: instructions,
      totalTime: structure.totalTime != null
          ? FieldResult.mediumConfidence(
              structure.totalTime!, 'Extracted from text')
          : FieldResult.failed('No time found'),
      metadata: metadata,
    );
  }

  FieldResult<List<ParsedIngredient>> _parseIngredients(List<String> lines) {
    if (lines.isEmpty) {
      return FieldResult.failed('No ingredients found');
    }

    final parsed = <ParsedIngredient>[];

    for (final line in lines) {
      final cleaned = line.trim();
      if (cleaned.isEmpty) continue;

      // Use existing IngredientParser
      final result = IngredientParser.parseIngredient(cleaned);

      // Determine confidence based on structure
      ParseConfidence confidence;
      if (result.quantity > 0 && result.unit.isNotEmpty) {
        confidence = ParseConfidence.high;
      } else if (result.quantity > 0 || result.unit.isNotEmpty) {
        confidence = ParseConfidence.medium;
      } else {
        confidence = ParseConfidence.low;
      }

      parsed.add(ParsedIngredient(
        name: result.name,
        originalLine: cleaned,
        quantity: result.quantity > 0 ? result.quantity.toString() : null,
        unit: result.unit.isNotEmpty ? result.unit : null,
        confidence: confidence,
      ));
    }

    if (parsed.isEmpty) {
      return FieldResult.failed('Could not parse ingredients');
    }

    // Score based on how many are structured
    final structuredCount = parsed.where((p) => p.isStructured).length;
    final ratio = parsed.isEmpty ? 0.0 : structuredCount / parsed.length;

    if (ratio >= 0.5) {
      return FieldResult.mediumConfidence(
        parsed,
        'Extracted via Swedish line classification',
      );
    } else {
      return FieldResult.lowConfidence(
        parsed,
        'Most ingredients unstructured',
      );
    }
  }

  FieldResult<List<String>> _parseInstructions(List<String> lines) {
    if (lines.isEmpty) {
      return FieldResult.failed('No instructions found');
    }

    // Clean and filter
    final cleaned = lines
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        // Remove step numbers
        .map((l) => l.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), ''))
        .toList();

    if (cleaned.isEmpty) {
      return FieldResult.failed('Could not parse instructions');
    }

    // Instructions from line classification are lower confidence
    return FieldResult.lowConfidence(
      cleaned,
      'Extracted via Swedish line classification',
    );
  }
}
