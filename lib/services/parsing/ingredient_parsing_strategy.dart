import 'package:flutter/services.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/services/parsing/crf/crf_feature_extractor.dart';
import 'package:butlery/services/parsing/crf/crf_ingredient_parser.dart';
import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';
import 'package:butlery/services/parsing/crf/remote_weight_loader.dart';
import 'package:butlery/services/parsing/ingredient_registry_service.dart';
import 'package:butlery/services/parsing/ner/neural_ingredient_parser.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';
import 'package:butlery/utils/text/ocr_error_corrector.dart';

/// Unified ingredient parsing strategy: CRF → BERT NER → regex fallback.
///
/// All tiers route through this single entry point for consistent quality.
/// When CRF weights are available, uses the trained CRF model which handles
/// edge cases (ranges, alternatives, optionals) better than regex.
/// Uncertain CRF lines are re-parsed with BERT NER if the model is available.
/// Falls back to legacy IngredientParser when neither model is available.
class IngredientParsingStrategy {
  static const String _weightsPath = 'assets/data/crf_ingredient_weights.json';
  static const String _serviceName = 'IngredientParsingStrategy';

  /// Bundled weight version. Increment when updating the bundled weights file.
  /// Remote weights with a higher version number will replace these.
  static const int bundledWeightVersion = 1;

  /// Confidence threshold below which CRF-parsed lines are considered uncertain
  /// and routed to BERT NER or cloud LLM for re-parsing.
  /// Shared with [NeuralIngredientParser.confidenceThreshold] for cascade consistency.
  static const double _uncertaintyThreshold =
      NeuralIngredientParser.confidenceThreshold;

  CrfIngredientParser? _crfParser;
  bool _initialized = false;
  DateTime? _lastInitFailure;
  static const _initRetryDelay = Duration(minutes: 5);
  bool _remoteCheckStarted = false;
  bool _nerInitStarted = false;
  DateTime? _nerLastAttempt;

  /// Injected parser for testing.
  final CrfIngredientParser? _injectedParser;

  /// Remote weight loader for active learning updates.
  final RemoteWeightLoader? _remoteLoader;

  /// On-device BERT NER parser (optional, downloaded on demand).
  final NeuralIngredientParser? _neuralParser;

  IngredientParsingStrategy({
    CrfIngredientParser? crfParser,
    RemoteWeightLoader? remoteLoader,
    NeuralIngredientParser? neuralParser,
  })  : _injectedParser = crfParser,
        _remoteLoader = remoteLoader,
        _neuralParser = neuralParser;

  /// Whether CRF parsing is available.
  bool get hasCrf => _injectedParser != null || _crfParser != null;

  /// Whether BERT NER is available for uncertain line re-parsing.
  bool get hasNer => _neuralParser?.isAvailable ?? false;

  /// Initialize CRF weights (lazy, idempotent).
  ///
  /// Loads bundled weights first, then triggers a background check
  /// for updated remote weights from Firebase Storage.
  Future<void> _ensureInitialized() async {
    if (_initialized || _injectedParser != null) return;

    // After a failure, wait before retrying
    if (_lastInitFailure != null &&
        DateTime.now().difference(_lastInitFailure!) < _initRetryDelay) {
      return;
    }

    try {
      final jsonString = await rootBundle.loadString(_weightsPath);
      final weights = CrfWeights.fromJson(jsonString);

      final registry = ServiceLocator.tryGet<IngredientRegistryService>();
      final enriched = registry?.allIngredients;

      final extractor = CrfFeatureExtractor(enrichedIngredients: enriched);
      final decoder = CrfViterbiDecoder(weights: weights, extractor: extractor);
      _crfParser = CrfIngredientParser(decoder);
      _initialized = true;
      _lastInitFailure = null;
      AppLogger.info('$_serviceName: CRF weights loaded'
          '${enriched != null ? ' (${enriched.length} enriched ingredients)' : ''}');

      _tryLoadRemoteWeightsInBackground();
      _tryInitNerInBackground();
    } catch (e) {
      AppLogger.warning('$_serviceName: CRF weights unavailable, '
          'using regex fallback: $e');
      _lastInitFailure = DateTime.now();
    }
  }

  /// Background check for updated CRF weights from Firebase Storage.
  ///
  /// Fire-and-forget -- failures never affect parsing.
  void _tryLoadRemoteWeightsInBackground() {
    if (_remoteCheckStarted || _remoteLoader == null) return;
    _remoteCheckStarted = true;

    Future(() async {
      try {
        final remoteParser = await _remoteLoader.tryLoadRemoteWeights(
          bundledVersion: bundledWeightVersion,
        );
        if (remoteParser != null) {
          _crfParser = remoteParser;
          AppLogger.info('$_serviceName: Upgraded to remote CRF weights');
        }
      } catch (e) {
        AppLogger.debug('$_serviceName: Remote weight check failed: $e');
      }
    });
  }

  /// Parse a single ingredient line.
  ///
  /// Tries CRF first for better accuracy on edge cases,
  /// falls back to regex IngredientParser.
  Future<ParsedIngredient> parseLine(
    String line, {
    bool ocrCorrection = false,
  }) async {
    await _ensureInitialized();

    final cleaned = ocrCorrection ? OcrErrorCorrector.correctLine(line) : line;
    final parser = _injectedParser ?? _crfParser;
    if (parser != null) {
      return parser.parseLine(cleaned);
    }

    return _parseWithRegex(cleaned);
  }

  /// Parse a single ingredient line synchronously (regex only).
  ///
  /// Used when CRF isn't available and async isn't desired.
  ParsedIngredient parseLineSync(
    String line, {
    bool ocrCorrection = false,
  }) {
    final cleaned = ocrCorrection ? OcrErrorCorrector.correctLine(line) : line;
    final parser = _injectedParser ?? _crfParser;
    if (parser != null) {
      return parser.parseLine(cleaned);
    }
    return _parseWithRegex(cleaned);
  }

  /// Parse multiple ingredient lines.
  Future<FieldResult<List<ParsedIngredient>>> parseLines(
    List<String> lines, {
    bool ocrCorrection = false,
  }) async {
    if (lines.isEmpty) {
      return FieldResult.failed('No ingredients found');
    }

    await _ensureInitialized();

    final parser = _injectedParser ?? _crfParser;
    final parsed = <ParsedIngredient>[];

    for (final line in lines) {
      var cleaned = line.trim();
      if (cleaned.isEmpty) continue;

      if (ocrCorrection) {
        cleaned = OcrErrorCorrector.correctLine(cleaned);
      }

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

    return FieldResult.fromConfidenceScore(parsed, confidenceScore, source);
  }

  /// Initialize BERT NER model in background (fire-and-forget).
  ///
  /// Downloads the ONNX model from Firebase Storage if not cached,
  /// then loads it into ONNX Runtime. Failures never block parsing.
  void _tryInitNerInBackground() {
    if (_neuralParser == null || _neuralParser.isAvailable) return;
    if (_nerInitStarted) return;
    // Don't retry more often than once per hour
    if (_nerLastAttempt != null &&
        DateTime.now().difference(_nerLastAttempt!) <
            const Duration(hours: 1)) {
      return;
    }
    _nerInitStarted = true;

    Future(() async {
      try {
        final ready = await _neuralParser.ensureInitialized();
        if (ready) {
          AppLogger.info('$_serviceName: BERT NER model ready');
        }
      } catch (e) {
        AppLogger.debug('$_serviceName: NER init failed: $e');
      } finally {
        _nerInitStarted = false;
        _nerLastAttempt = DateTime.now();
      }
    });
  }

  /// Identifies ingredient lines where CRF confidence is below
  /// [_uncertaintyThreshold], suitable for BERT NER or LLM re-parsing.
  ///
  /// This enables the CRF → BERT → LLM cascade: uncertain lines are first
  /// tried with BERT NER (on-device), then remaining uncertain lines go to
  /// the cloud LLM.
  List<int> getUncertainLineIndices(List<ParsedIngredient> parsed) {
    final uncertain = <int>[];
    for (var i = 0; i < parsed.length; i++) {
      if (parsed[i].name.isEmpty) continue; // Skip group headers
      if (parsed[i].confidence.score < _uncertaintyThreshold) {
        uncertain.add(i);
      }
    }
    return uncertain;
  }

  /// Returns uncertain lines that still need LLM help after BERT NER.
  ///
  /// If BERT NER is available, tries it on uncertain CRF lines first.
  /// Lines that BERT handles confidently are merged into [parsed].
  /// Only lines that both CRF and BERT are uncertain about are returned
  /// for LLM re-parsing.
  ///
  /// **Note**: [parsed] is mutated in place — lines where BERT NER succeeds
  /// are replaced with the improved result.
  Future<Map<int, String>> getUncertainLines(
    List<ParsedIngredient> parsed,
    List<String> originalLines,
  ) async {
    final uncertainIndices = getUncertainLineIndices(parsed);
    if (uncertainIndices.isEmpty) return {};

    // Try BERT NER on uncertain lines first
    if (_neuralParser != null && _neuralParser.isAvailable) {
      final filteredIndices = <int>[];
      final uncertainTexts = <String>[];
      for (final i in uncertainIndices) {
        if (i < originalLines.length) {
          filteredIndices.add(i);
          uncertainTexts.add(originalLines[i]);
        }
      }

      if (uncertainTexts.isNotEmpty) {
        final nerResults = await _neuralParser.parseLines(uncertainTexts);

        // Merge BERT results back — only keep lines BERT couldn't handle
        var nerHandled = 0;
        for (var j = 0; j < uncertainTexts.length; j++) {
          if (nerResults.containsKey(j)) {
            parsed[filteredIndices[j]] = nerResults[j]!;
            nerHandled++;
          }
        }

        if (nerHandled > 0) {
          AppLogger.debug(
            '$_serviceName: BERT NER handled $nerHandled/${uncertainTexts.length} uncertain lines',
          );
        }
      }
    }

    // Return lines that are still uncertain (BERT didn't handle)
    final result = <int, String>{};
    for (final i in uncertainIndices) {
      if (i < originalLines.length &&
          parsed[i].confidence.score < _uncertaintyThreshold) {
        result[i] = originalLines[i];
      }
    }
    return result;
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
