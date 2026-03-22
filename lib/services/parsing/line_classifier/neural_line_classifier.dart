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

  DateTime? _lastInitFailure;
  static const _initRetryDelay = Duration(minutes: 5);
  bool _isDisposed = false;

  NeuralLineClassifier({
    required OnnxLineClassifierService classifierService,
    required LineClassifierModelManager modelManager,
  })  : _classifierService = classifierService,
        _modelManager = modelManager;

  /// Whether the neural model is ready for inference.
  bool get isAvailable => !_isDisposed && _classifierService.isAvailable;

  /// Initialize the model (download if needed, load into ONNX Runtime).
  ///
  /// Retries after 5 minutes if initialization fails (e.g., network issues).
  Future<bool> ensureInitialized() async {
    if (_isDisposed) return false;
    if (_classifierService.isAvailable) return true;

    if (_lastInitFailure != null &&
        DateTime.now().difference(_lastInitFailure!) < _initRetryDelay) {
      return false;
    }

    try {
      final modelFiles = await _modelManager.ensureModelAvailable();
      if (modelFiles == null) {
        AppLogger.debug('$_serviceName: Model not available, using rule-based');
        _lastInitFailure = DateTime.now();
        return false;
      }

      final success = await _classifierService.initialize(
        modelPath: modelFiles.modelPath,
        vocabContent: modelFiles.vocabContent,
      );

      if (success) {
        _lastInitFailure = null;
        AppLogger.info('$_serviceName: Neural classifier ready');
      } else {
        _lastInitFailure = DateTime.now();
      }
      return success;
    } catch (e) {
      AppLogger.debug('$_serviceName: Initialization failed: $e');
      _lastInitFailure = DateTime.now();
      return false;
    }
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
