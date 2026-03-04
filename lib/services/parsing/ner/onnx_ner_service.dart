import 'dart:math' as math;

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';
import 'package:butlery/services/parsing/ner/wordpiece_tokenizer.dart';

/// Runs BERT NER inference using ONNX Runtime.
///
/// Loads a quantized ONNX model and WordPiece vocabulary, tokenizes
/// ingredient lines, runs inference, and returns BIO labels per word.
///
/// The model expects inputs shaped [batch, seq_len] for input_ids and
/// attention_mask, and outputs logits shaped [batch, seq_len, num_labels].
class OnnxNerService {
  static const _serviceName = 'OnnxNerService';
  static const _maxLength = 128;

  /// BIO label ordering — must match training script's LABELS list.
  static const _labels = [
    BioLabel.other, // O
    BioLabel.bQty, // B-QTY
    BioLabel.iQty, // I-QTY
    BioLabel.bUnit, // B-UNIT
    BioLabel.bName, // B-NAME
    BioLabel.iName, // I-NAME
    BioLabel.bPrep, // B-PREP
    BioLabel.iPrep, // I-PREP
    BioLabel.bSize, // B-SIZE
  ];

  final OnnxRuntime _runtime;
  OrtSession? _session;
  WordPieceTokenizer? _tokenizer;
  bool _initialized = false;
  bool _initFailed = false;
  String? _inputIdName;
  String? _attentionMaskName;
  String? _outputName;

  OnnxNerService({OnnxRuntime? runtime}) : _runtime = runtime ?? OnnxRuntime();

  bool get isAvailable => _initialized && !_initFailed;

  /// Initialize with model and vocabulary data.
  ///
  /// Can be retried after transient failures — call [dispose] first
  /// to reset state, or simply call initialize again with new paths.
  Future<bool> initialize({
    required String modelPath,
    required String vocabContent,
  }) async {
    if (_initialized) return !_initFailed;

    try {
      _tokenizer = WordPieceTokenizer.fromVocabString(
        vocabContent,
        maxInputLength: _maxLength,
        isCased: true, // KB-BERT is cased
      );

      _session = await _runtime.createSession(modelPath);
      _inputIdName = _session!.inputNames[0];
      _attentionMaskName = _session!.inputNames[1];
      _outputName = _session!.outputNames[0];

      _initialized = true;
      _initFailed = false;
      AppLogger.info(
        '$_serviceName: Initialized (vocab: ${_tokenizer!.vocabSize} tokens)',
      );
      return true;
    } catch (e) {
      _initFailed = true;
      _initialized = true; // Mark as attempted so isAvailable returns false
      AppLogger.warning('$_serviceName: Initialization failed: $e');
      return false;
    }
  }

  /// Predict BIO labels for a list of pre-tokenized words.
  ///
  /// [words] should be pre-tokenized using CrfIngredientParser.tokenize().
  /// Returns a list of [BioLabel] with one label per word, plus a confidence
  /// score (average max softmax probability across words).
  Future<NerPrediction?> predict(List<String> words) async {
    if (!isAvailable || _session == null || _tokenizer == null) return null;
    if (words.isEmpty) return null;

    try {
      final tokenized = _tokenizer!.tokenizeWords(words);

      // Create input tensors — tokenizer returns Int64List directly
      final inputIds = await OrtValue.fromList(
        tokenized.inputIds,
        [1, _maxLength],
      );
      final attentionMask = await OrtValue.fromList(
        tokenized.attentionMask,
        [1, _maxLength],
      );

      // Run inference, ensuring tensors are always disposed
      final List<double> flatLogits;
      try {
        final outputs = await _session!.run({
          _inputIdName!: inputIds,
          _attentionMaskName!: attentionMask,
        });

        try {
          final logitsRaw = await outputs[_outputName]!.asList();
          flatLogits = _flattenToDoubles(logitsRaw);
        } finally {
          for (final tensor in outputs.values) {
            tensor.dispose();
          }
        }
      } finally {
        inputIds.dispose();
        attentionMask.dispose();
      }

      // Map subword predictions back to word-level
      final numLabels = _labels.length;
      final seqLen = flatLogits.length ~/ numLabels;
      final firstSubwordMap = tokenized.firstSubwordIndices;
      final wordLabels = <BioLabel>[];
      var totalConfidence = 0.0;

      for (var wordIdx = 0; wordIdx < words.length; wordIdx++) {
        final subwordPos = firstSubwordMap[wordIdx];
        if (subwordPos == null || subwordPos >= seqLen) {
          wordLabels.add(BioLabel.other);
          continue;
        }

        final wordLogits = _getLogitsAt(flatLogits, subwordPos, numLabels);
        final (bestIdx, confidence) = _argmaxSoftmax(wordLogits);

        wordLabels.add(
          bestIdx < _labels.length ? _labels[bestIdx] : BioLabel.other,
        );
        totalConfidence += confidence;
      }

      final avgConfidence =
          words.isNotEmpty ? totalConfidence / words.length : 0.0;

      return NerPrediction(
        labels: wordLabels,
        confidence: avgConfidence,
      );
    } catch (e) {
      AppLogger.warning('$_serviceName: Prediction failed: $e');
      return null;
    }
  }

  /// Flatten the raw ONNX output into a single list of doubles.
  ///
  /// The output is [batch=1, seq_len, num_labels], possibly nested
  /// depending on the ONNX Runtime wrapper. We flatten it once and
  /// extract per-position logits on demand via [_getLogitsAt].
  List<double> _flattenToDoubles(List<dynamic> raw) {
    final flat = <double>[];
    _recursiveFlatten(raw, flat);
    return flat;
  }

  void _recursiveFlatten(dynamic value, List<double> out) {
    if (value is List) {
      for (final item in value) {
        _recursiveFlatten(item, out);
      }
    } else if (value is num) {
      out.add(value.toDouble());
    }
  }

  /// Extract logits for a single position from the flat array.
  List<double> _getLogitsAt(List<double> flat, int pos, int numLabels) {
    final start = pos * numLabels;
    return flat.sublist(start, start + numLabels);
  }

  /// Fused argmax + softmax: finds the best label index and its probability
  /// in a single pass with zero list allocations.
  (int index, double confidence) _argmaxSoftmax(List<double> logits) {
    final maxVal = logits.reduce(math.max);
    var sumExp = 0.0;
    var bestIdx = 0;
    var bestExp = 0.0;
    for (var i = 0; i < logits.length; i++) {
      final e = math.exp(logits[i] - maxVal);
      sumExp += e;
      if (e > bestExp) {
        bestExp = e;
        bestIdx = i;
      }
    }
    return (bestIdx, bestExp / sumExp);
  }

  /// Release ONNX session resources.
  Future<void> dispose() async {
    await _session?.close();
    _session = null;
    _tokenizer = null;
    _initialized = false;
    _initFailed = false;
    _inputIdName = null;
    _attentionMaskName = null;
    _outputName = null;
  }
}

/// Result of BERT NER prediction for a single ingredient line.
class NerPrediction {
  /// BIO labels, one per input word.
  final List<BioLabel> labels;

  /// Average confidence (max softmax probability) across words.
  /// Range: 0.0–1.0. Higher means more certain.
  final double confidence;

  const NerPrediction({
    required this.labels,
    required this.confidence,
  });
}
