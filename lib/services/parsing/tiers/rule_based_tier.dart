import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/services/parsing/line_classifier/neural_line_classifier.dart';
import 'package:butlery/services/parsing/parsers/swedish_line_classifier.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/tiers/parsing_tier.dart';
import 'package:html_unescape/html_unescape.dart';

/// Tier 3: Rule-based Swedish text parsing.
///
/// Uses the SwedishLineClassifier (or NeuralLineClassifier when available)
/// to parse unstructured text from Instagram, TikTok, YouTube descriptions,
/// and other social media sources. Also serves as fallback for URL content
/// that lacks structured data.
class RuleBasedTier extends ParsingTier with QualityScoring {
  final IngredientParsingStrategy _ingredientStrategy;
  final NeuralLineClassifier? _neuralClassifier;

  RuleBasedTier({
    IngredientParsingStrategy? ingredientStrategy,
    NeuralLineClassifier? neuralClassifier,
  })  : _ingredientStrategy = ingredientStrategy ?? IngredientParsingStrategy(),
        _neuralClassifier = neuralClassifier;

  static const tierIdentifier = 'RuleBased';

  @override
  String get tierName => tierIdentifier;

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

    // Classify and parse (cached across tiers)
    final structure = context.parseStructureCached(
      text,
      neuralClassifier: _neuralClassifier,
    );

    if (!structure.isValid) {
      return TierResult.noData(
        tierName: tierName,
        duration: stopwatch.elapsed,
      );
    }

    // Convert to ParsedRecipe
    final recipe = await _convertToRecipe(structure, context);

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

  Future<ParsedRecipe?> _convertToRecipe(
    ParsedRecipeStructure structure,
    ParsingContext context,
  ) async {
    final ingredients = await _ingredientStrategy.parseLines(
      structure.ingredients,
      ocrCorrection: context.isOcrSource,
    );
    if (ingredients.value == null || ingredients.value!.isEmpty) {
      return null;
    }

    final instructions = parseInstructionLines(structure.instructions);
    if (instructions.value == null || instructions.value!.isEmpty) {
      return null;
    }

    return buildRecipeFromStructure(
      structure: structure,
      context: context,
      ingredients: ingredients,
      instructions: instructions,
    );
  }
}
