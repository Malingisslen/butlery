import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/services/parsing/crf/crf_ingredient_parser.dart';
import 'package:butlery/services/parsing/ner/ner_model_manager.dart';
import 'package:butlery/services/parsing/ner/onnx_ner_service.dart';

/// Parses ingredient lines using the on-device BERT NER model.
///
/// This parser sits between CRF and Gemini in the parsing cascade.
/// It handles lines where CRF confidence is low but that don't need
/// a full cloud LLM call — just better contextual understanding.
///
/// Uses the same tokenizer and BIO→ParsedIngredient assembly logic
/// as CrfIngredientParser to ensure consistent output format.
class NeuralIngredientParser {
  static const _serviceName = 'NeuralIngredientParser';

  /// Minimum confidence from BERT to accept the prediction.
  /// Below this, the line should fall through to Gemini.
  static const double confidenceThreshold = 0.7;

  final OnnxNerService _nerService;
  final NerModelManager _modelManager;

  NeuralIngredientParser({
    required OnnxNerService nerService,
    required NerModelManager modelManager,
  })  : _nerService = nerService,
        _modelManager = modelManager;

  /// Whether the BERT NER model is available for inference.
  bool get isAvailable => _nerService.isAvailable;

  /// Initialize the NER model (download if needed, load into ONNX Runtime).
  ///
  /// Returns true if the model is ready for inference.
  /// This is fire-and-forget safe — failures never throw.
  Future<bool> ensureInitialized() async {
    if (_nerService.isAvailable) return true;

    try {
      // Reset state if a previous attempt failed, allowing retry
      await _nerService.dispose();

      // Ensure model files are available locally
      final modelFiles = await _modelManager.ensureModelAvailable();
      if (modelFiles == null) {
        AppLogger.debug('$_serviceName: Model not available');
        return false;
      }

      // Initialize ONNX Runtime with model and vocab
      return await _nerService.initialize(
        modelPath: modelFiles.modelPath,
        vocabContent: modelFiles.vocabContent,
      );
    } catch (e) {
      AppLogger.debug('$_serviceName: Initialization failed: $e');
      return false;
    }
  }

  /// Parse a single ingredient line using BERT NER.
  ///
  /// Returns null if:
  /// - The model is not available
  /// - Prediction confidence is below threshold
  /// - Prediction fails for any reason
  ///
  /// When null is returned, the caller should fall through to Gemini.
  Future<ParsedIngredient?> parseLine(String line) async {
    if (!_nerService.isAvailable) return null;

    final tokens = CrfIngredientParser.tokenize(line.trim());
    if (tokens.isEmpty) return null;

    final prediction = await _nerService.predict(tokens);
    if (prediction == null) return null;

    // Check confidence — below threshold means fall through to Gemini
    if (prediction.confidence < confidenceThreshold) {
      AppLogger.debug(
        '$_serviceName: Low confidence ${prediction.confidence.toStringAsFixed(2)} '
        'on "$line" — deferring to LLM',
      );
      return null;
    }

    return CrfIngredientParser.assembleFromLabels(
        tokens, prediction.labels, line);
  }

  /// Parse multiple ingredient lines in a single batch inference call.
  ///
  /// Returns a map of line index → ParsedIngredient for lines where BERT
  /// confidence was above threshold. Missing indices should fall through to Gemini.
  Future<Map<int, ParsedIngredient>> parseLines(
    List<String> lines,
  ) async {
    if (!_nerService.isAvailable) return {};

    final allTokens =
        lines.map((l) => CrfIngredientParser.tokenize(l.trim())).toList();

    final predictions = await _nerService.predictBatch(allTokens);

    final results = <int, ParsedIngredient>{};
    for (var i = 0; i < lines.length; i++) {
      final prediction = predictions[i];
      if (prediction == null) continue;

      if (prediction.confidence < confidenceThreshold) {
        AppLogger.debug(
          '$_serviceName: Low confidence ${prediction.confidence.toStringAsFixed(2)} '
          'on "${lines[i]}" — deferring to LLM',
        );
        continue;
      }

      results[i] = CrfIngredientParser.assembleFromLabels(
        allTokens[i],
        prediction.labels,
        lines[i],
      );
    }

    return results;
  }
}
