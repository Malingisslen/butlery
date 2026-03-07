import 'package:flutter/services.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/services/parsing/crf/crf_ingredient_parser.dart';
import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';
import 'package:butlery/services/parsing/line_classifier/neural_line_classifier.dart';
import 'package:butlery/services/parsing/sanitizers/html_sanitizer.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/tiers/parsing_tier.dart';

/// Standalone CRF-based ingredient parsing tier (not in the main pipeline).
///
/// Used for testing and standalone CRF evaluation. In production, CRF parsing
/// runs inside RuleBasedTier via IngredientParsingStrategy.
///
/// Falls back gracefully when weights are unavailable — shouldSkip returns
/// true and the next tier (LLM) handles it.
class CrfTier extends ParsingTier with QualityScoring {
  static const String _weightsPath = 'assets/data/crf_ingredient_weights.json';
  static const String _serviceName = 'CrfTier';

  CrfIngredientParser? _parser;
  bool _weightsLoadFailed = false;

  /// Optional injected parser for testing.
  final CrfIngredientParser? _injectedParser;
  final NeuralLineClassifier? _neuralClassifier;

  CrfTier({
    CrfIngredientParser? parser,
    NeuralLineClassifier? neuralClassifier,
  })  : _injectedParser = parser,
        _neuralClassifier = neuralClassifier;

  static const tierIdentifier = 'CRF';

  @override
  String get tierName => tierIdentifier;

  @override
  int get priority => 4;

  @override
  Duration get defaultTimeout => const Duration(seconds: 10);

  @override
  double get minQualityScore => 0.35;

  @override
  bool shouldSkip(ParsingContext context) {
    if (context.sanitizedContent.isEmpty) return true;
    // Skip if weights previously failed to load
    if (_weightsLoadFailed && _injectedParser == null) return true;
    return false;
  }

  @override
  Future<TierResult> parse(ParsingContext context) async {
    final stopwatch = Stopwatch()..start();

    // Ensure parser is loaded
    final parser = await _getParser();
    if (parser == null) {
      return TierResult.noData(
        tierName: tierName,
        duration: stopwatch.elapsed,
      );
    }

    // Use SwedishLineClassifier for line classification (same as RuleBasedTier)
    final text = _extractPlainText(context);
    if (text.isEmpty) {
      return TierResult.noData(
        tierName: tierName,
        duration: stopwatch.elapsed,
      );
    }

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

    // CRF parses ingredients; instructions come from classifier
    final ingredients = _parseIngredients(parser, structure.ingredients);
    if (ingredients.value == null || ingredients.value!.isEmpty) {
      return TierResult.noData(
        tierName: tierName,
        duration: stopwatch.elapsed,
      );
    }

    final instructions = parseInstructionLines(structure.instructions);
    if (instructions.value == null || instructions.value!.isEmpty) {
      return TierResult.noData(
        tierName: tierName,
        duration: stopwatch.elapsed,
      );
    }

    final recipe = buildRecipeFromStructure(
      structure: structure,
      context: context,
      ingredients: ingredients,
      instructions: instructions,
    );

    return TierResult.success(
      tierName: tierName,
      recipe: recipe,
      duration: stopwatch.elapsed,
    );
  }

  Future<CrfIngredientParser?> _getParser() async {
    if (_injectedParser != null) return _injectedParser;
    if (_parser != null) return _parser;

    try {
      final jsonString = await rootBundle.loadString(_weightsPath);
      final weights = CrfWeights.fromJson(jsonString);
      final decoder = CrfViterbiDecoder(weights: weights);
      _parser = CrfIngredientParser(decoder);
      return _parser;
    } catch (e) {
      AppLogger.warning('Failed to load CRF weights: $e', _serviceName);
      _weightsLoadFailed = true;
      return null;
    }
  }

  String _extractPlainText(ParsingContext context) {
    final content = context.sanitizedContent;
    if (content.contains('<')) {
      return HtmlSanitizer.stripToPlainText(content);
    }
    return content;
  }

  /// Parses ingredient lines using the CRF model.
  FieldResult<List<ParsedIngredient>> _parseIngredients(
    CrfIngredientParser parser,
    List<String> lines,
  ) {
    if (lines.isEmpty) {
      return FieldResult.failed('No ingredients found');
    }

    final parsed = parser.parseLines(lines);

    if (parsed.isEmpty) {
      return FieldResult.failed('Could not parse ingredients');
    }

    final structuredCount = parsed.where((p) => p.isStructured).length;
    final ratio = structuredCount / parsed.length;

    return FieldResult.fromConfidenceScore(parsed, ratio, 'CRF model');
  }
}
