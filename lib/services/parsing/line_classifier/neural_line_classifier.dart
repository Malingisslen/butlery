import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/parsing/line_classifier/line_classifier_model_manager.dart';
import 'package:butlery/services/parsing/line_classifier/onnx_line_classifier_service.dart';
import 'package:butlery/services/parsing/parsers/swedish_line_classifier.dart';
import 'package:butlery/services/parsing/parsers/viterbi_context_processor.dart';

/// Neural line classifier that replaces rule-based [SwedishLineClassifier]
/// when the ONNX model is available.
///
/// Falls back to [SwedishLineClassifier] when:
/// - Model hasn't been downloaded yet (first launch, web platform)
/// - Model download failed (no internet, Firebase error)
/// - ONNX session creation failed (corrupted model file)
class NeuralLineClassifier {
  static const _serviceName = 'NeuralLineClassifier';

  final OnnxLineClassifierService _classifierService;
  final LineClassifierModelManager _modelManager;
  final _viterbi = const ViterbiContextProcessor();

  bool _initAttempted = false;

  NeuralLineClassifier({
    required OnnxLineClassifierService classifierService,
    required LineClassifierModelManager modelManager,
  })  : _classifierService = classifierService,
        _modelManager = modelManager;

  /// Whether the neural model is ready for inference.
  bool get isAvailable => _classifierService.isAvailable;

  /// Initialize the model (download if needed, load into ONNX Runtime).
  ///
  /// Safe to call multiple times — only attempts once unless [dispose] resets.
  Future<bool> ensureInitialized() async {
    if (_classifierService.isAvailable) return true;
    if (_initAttempted) return false;
    _initAttempted = true;

    try {
      final modelFiles = await _modelManager.ensureModelAvailable();
      if (modelFiles == null) {
        AppLogger.debug('$_serviceName: Model not available, using rule-based');
        return false;
      }

      final success = await _classifierService.initialize(
        modelPath: modelFiles.modelPath,
        vocabContent: modelFiles.vocabContent,
      );

      if (success) {
        AppLogger.info('$_serviceName: Neural classifier ready');
      }
      return success;
    } catch (e) {
      AppLogger.debug('$_serviceName: Initialization failed: $e');
      return false;
    }
  }

  /// Parse text into a recipe structure using neural classification.
  ///
  /// **Deprecated:** Always falls back to rule-based because ONNX inference
  /// is async. Use [parseStructureAsync] instead.
  @Deprecated('Always falls back to rule-based. Use parseStructureAsync().')
  ParsedRecipeStructure parseStructure(String text) {
    return SwedishLineClassifier.instance.parseStructure(text);
  }

  /// Async version that actually uses the neural model.
  ///
  /// Preferred entry point — callers that can await should use this.
  Future<ParsedRecipeStructure> parseStructureAsync(String text) async {
    if (!_classifierService.isAvailable) {
      return SwedishLineClassifier.instance.parseStructure(text);
    }

    final lines = text.split(RegExp(r'\r?\n'));

    // Batch classify all lines through ONNX
    final classified = await _classifierService.classifyBatch(lines);

    // Apply Viterbi context correction
    final contextual = _viterbi.classifyWithContext(classified);

    // Group into sections and extract structure
    final sections = SwedishLineClassifier.groupIntoSections(contextual);
    return SwedishLineClassifier.extractStructureFromSections(sections);
  }
}
