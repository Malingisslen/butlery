import 'package:flutter/services.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/services/parsing/crf/crf_ingredient_parser.dart';
import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';
import 'package:butlery/utils/text/ingredient_parser.dart'
    hide ParsedIngredient;

/// Unified ingredient parsing strategy that tries CRF first, regex fallback.
///
/// All tiers route through this single entry point for consistent quality.
/// When CRF weights are available, uses the trained CRF model which handles
/// edge cases (ranges, alternatives, optionals) better than regex.
/// Falls back to legacy IngredientParser when weights are unavailable.
class IngredientParsingStrategy {
  static const String _weightsPath = 'assets/data/crf_ingredient_weights.json';
  static const String _serviceName = 'IngredientParsingStrategy';

  CrfIngredientParser? _crfParser;
  bool _crfLoadFailed = false;
  bool _initialized = false;

  /// Injected parser for testing.
  final CrfIngredientParser? _injectedParser;

  IngredientParsingStrategy({CrfIngredientParser? crfParser})
      : _injectedParser = crfParser;

  /// Whether CRF parsing is available.
  bool get hasCrf => _injectedParser != null || _crfParser != null;

  /// Initialize CRF weights (lazy, idempotent).
  Future<void> _ensureInitialized() async {
    if (_initialized || _injectedParser != null) return;
    _initialized = true;

    if (_crfLoadFailed) return;

    try {
      final jsonString = await rootBundle.loadString(_weightsPath);
      final weights = CrfWeights.fromJson(jsonString);
      final decoder = CrfViterbiDecoder(weights: weights);
      _crfParser = CrfIngredientParser(decoder);
      AppLogger.info('$_serviceName: CRF weights loaded');
    } catch (e) {
      AppLogger.warning('$_serviceName: CRF weights unavailable, '
          'using regex fallback: $e');
      _crfLoadFailed = true;
    }
  }

  /// Parse a single ingredient line.
  ///
  /// Tries CRF first for better accuracy on edge cases,
  /// falls back to regex IngredientParser.
  Future<ParsedIngredient> parseLine(String line) async {
    await _ensureInitialized();

    final parser = _injectedParser ?? _crfParser;
    if (parser != null) {
      return parser.parseLine(line);
    }

    return _parseWithRegex(line);
  }

  /// Parse a single ingredient line synchronously (regex only).
  ///
  /// Used when CRF isn't available and async isn't desired.
  ParsedIngredient parseLineSync(String line) {
    final parser = _injectedParser ?? _crfParser;
    if (parser != null) {
      return parser.parseLine(line);
    }
    return _parseWithRegex(line);
  }

  /// Parse multiple ingredient lines.
  Future<FieldResult<List<ParsedIngredient>>> parseLines(
    List<String> lines,
  ) async {
    if (lines.isEmpty) {
      return FieldResult.failed('No ingredients found');
    }

    await _ensureInitialized();

    final parser = _injectedParser ?? _crfParser;
    final parsed = <ParsedIngredient>[];

    for (final line in lines) {
      final cleaned = line.trim();
      if (cleaned.isEmpty) continue;

      if (parser != null) {
        parsed.add(parser.parseLine(cleaned));
      } else {
        parsed.add(_parseWithRegex(cleaned));
      }
    }

    if (parsed.isEmpty) {
      return FieldResult.failed('Could not parse ingredients');
    }

    final source = parser != null ? 'CRF model' : 'regex parser';

    // Use per-ingredient confidence when CRF is active (more accurate
    // than just checking isStructured, since CRF sets confidence based
    // on label coverage). Fall back to isStructured ratio for regex.
    final confidenceScore =
        parser != null ? _crfConfidenceScore(parsed) : _structuredRatio(parsed);

    if (confidenceScore >= 0.7) {
      return FieldResult.success(parsed);
    } else if (confidenceScore >= 0.5) {
      return FieldResult.mediumConfidence(parsed, 'Parsed via $source');
    } else if (confidenceScore >= 0.3) {
      return FieldResult.lowConfidence(
        parsed,
        '$source: some ingredients unstructured',
      );
    } else {
      return FieldResult.lowConfidence(
        parsed,
        '$source: most ingredients unstructured',
      );
    }
  }

  /// Confidence score based on CRF per-ingredient confidence levels.
  /// Weights: high=1.0, medium=0.7, low=0.3.
  double _crfConfidenceScore(List<ParsedIngredient> parsed) {
    if (parsed.isEmpty) return 0.0;
    var total = 0.0;
    for (final p in parsed) {
      total += p.confidence.score;
    }
    return total / parsed.length;
  }

  /// Confidence score based on structured ingredient ratio (regex fallback).
  double _structuredRatio(List<ParsedIngredient> parsed) {
    if (parsed.isEmpty) return 0.0;
    final structuredCount = parsed.where((p) => p.isStructured).length;
    return structuredCount / parsed.length;
  }

  /// Regex fallback using legacy IngredientParser.
  ParsedIngredient _parseWithRegex(String line) {
    final result = IngredientParser.parseIngredient(line);

    ParseConfidence confidence;
    if (result.quantity > 0 && result.unit.isNotEmpty) {
      confidence = ParseConfidence.high;
    } else if (result.quantity > 0 || result.unit.isNotEmpty) {
      confidence = ParseConfidence.medium;
    } else {
      confidence = ParseConfidence.low;
    }

    return ParsedIngredient(
      name: result.name,
      originalLine: line,
      quantity: result.quantity > 0 ? result.quantity.toString() : null,
      unit: result.unit.isNotEmpty ? result.unit : null,
      confidence: confidence,
    );
  }
}
