import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/services/parsing/line_classifier/neural_line_classifier.dart';
import 'package:butlery/services/parsing/parsers/swedish_line_classifier.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/sanitizers/html_sanitizer.dart';
import 'package:butlery/services/parsing/tiers/parsing_tier.dart';

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
  }) : _ingredientStrategy = ingredientStrategy ?? IngredientParsingStrategy(),
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
    final structure = await context.parseStructureCachedAsync(
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
      return HtmlSanitizer.stripToPlainText(content);
    }

    return content;
  }

  Future<ParsedRecipe?> _convertToRecipe(
    ParsedRecipeStructure structure,
    ParsingContext context,
  ) async {
    var ingredients = await _ingredientStrategy.parseLines(
      structure.ingredients,
      ocrCorrection: context.isOcrSource,
    );
    if (ingredients.value == null || ingredients.value!.isEmpty) {
      return null;
    }

    ingredients = _applySections(ingredients, structure);

    // Defense-in-depth: reject nav garbage from URL sources.
    // Real ingredients nearly always have quantities; nav text never does.
    if (context.source == ImportSource.url &&
        structure.ingredients.length > 3) {
      final linesWithQuantity = structure.ingredients
          .where((l) => l.contains(RegExp(r'\d')))
          .length;
      if (linesWithQuantity / structure.ingredients.length < 0.4) {
        return null;
      }
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

  /// Stamps the detected component group onto each parsed ingredient.
  ///
  /// Gated by the [isSectionCaptureEnabled] kill switch. Fails OPEN on any
  /// length mismatch between the parsed ingredients and the detected section
  /// list (e.g. a parser that merged/dropped lines): sections are skipped
  /// entirely rather than misaligned — a wrong section is worse than none.
  /// Only non-null groups are stamped; ungrouped lines keep their null
  /// section (so ParsedIngredient.copyWith's inability to clear is moot).
  FieldResult<List<ParsedIngredient>> _applySections(
    FieldResult<List<ParsedIngredient>> ingredients,
    ParsedRecipeStructure structure,
  ) {
    if (!isSectionCaptureEnabled) return ingredients;
    final sections = structure.ingredientSections;
    final parsed = ingredients.value;
    if (parsed == null ||
        sections.isEmpty ||
        sections.length != parsed.length) {
      return ingredients;
    }
    if (sections.every((s) => s == null)) return ingredients;

    final stamped = [
      for (var i = 0; i < parsed.length; i++)
        sections[i] == null
            ? parsed[i]
            : parsed[i].copyWith(section: sections[i]),
    ];
    return FieldResult(
      value: stamped,
      confidence: ingredients.confidence,
      failureReason: ingredients.failureReason,
    );
  }
}
