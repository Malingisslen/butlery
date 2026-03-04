import 'dart:math' as math;
import 'dart:typed_data';

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
  /// [modelPath] is the path to the ONNX model file on disk.
  /// [vocabContent] is the content of vocab.txt as a string.
  Future<bool> initialize({
    required String modelPath,
    required String vocabContent,
  }) async {
    if (_initialized) return !_initFailed;
    if (_initFailed) return false;

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
      AppLogger.info(
        '$_serviceName: Initialized (vocab: ${_tokenizer!.vocabSize} tokens)',
      );
      return true;
    } catch (e) {
      _initFailed = true;
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

      // Create input tensors (Int64List for BERT model compatibility)
      final inputIds = await OrtValue.fromList(
        Int64List.fromList(tokenized.inputIds),
        [1, _maxLength],
      );
      final attentionMask = await OrtValue.fromList(
        Int64List.fromList(tokenized.attentionMask),
        [1, _maxLength],
      );

      // Run inference, ensuring tensors are always disposed
      final List<List<double>> logits;
      try {
        final outputs = await _session!.run({
          _inputIdName!: inputIds,
          _attentionMaskName!: attentionMask,
        });

        try {
          final logitsRaw = await outputs[_outputName]!.asList();
          logits = _flattenLogits(logitsRaw, _labels.length);
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
      final firstSubwordMap = tokenized.firstSubwordIndices;
      final wordLabels = <BioLabel>[];
      var totalConfidence = 0.0;

      for (var wordIdx = 0; wordIdx < words.length; wordIdx++) {
        final subwordPos = firstSubwordMap[wordIdx];
        if (subwordPos == null || subwordPos >= logits.length) {
          wordLabels.add(BioLabel.other);
          continue;
        }

        final wordLogits = logits[subwordPos];
        final softmax = _softmax(wordLogits);
        final bestIdx = _argmax(softmax);

        wordLabels.add(
          bestIdx < _labels.length ? _labels[bestIdx] : BioLabel.other,
        );
        totalConfidence += softmax[bestIdx];
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

  /// Parse the raw output list into per-position logit vectors.
  ///
  /// The ONNX output is a flat list of doubles representing
  /// [batch=1, seq_len, num_labels]. We need to reshape it.
  List<List<double>> _flattenLogits(List<dynamic> raw, int numLabels) {
    // The output might be nested or flat depending on the ONNX Runtime wrapper
    final flat = <double>[];
    _recursiveFlatten(raw, flat);

    final seqLen = flat.length ~/ numLabels;
    final result = <List<double>>[];
    for (var i = 0; i < seqLen; i++) {
      final start = i * numLabels;
      if (start + numLabels <= flat.length) {
        result.add(flat.sublist(start, start + numLabels));
      }
    }
    return result;
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

  List<double> _softmax(List<double> logits) {
    final maxVal = logits.reduce(math.max);
    final exps = logits.map((x) => math.exp(x - maxVal)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  int _argmax(List<double> values) {
    var bestIdx = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[bestIdx]) bestIdx = i;
    }
    return bestIdx;
  }

  /// Release ONNX session resources.
  Future<void> dispose() async {
    await _session?.close();
    _session = null;
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
