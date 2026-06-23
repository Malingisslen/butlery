import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/parsing/ner/wordpiece_tokenizer.dart';
import 'package:butlery/services/parsing/parsers/swedish_line_classifier.dart';

/// Runs line classification inference using ONNX Runtime.
///
/// Loads a quantized ONNX model (distilled KB-BERT + 7-class head),
/// tokenizes lines, runs inference, and returns [ClassifiedLine] results.
///
/// The model outputs softmax probabilities over 7 classes matching [LineType].
/// These feed directly into [ViterbiContextProcessor] as emission probabilities.
class OnnxLineClassifierService {
  static const _serviceName = 'OnnxLineClassifierService';
  static const _maxLength = 64;
  static const _batchTimeout = Duration(seconds: 10);
  static const _maxBatchSize = 64;

  /// Label ordering — must match training script's LABELS list.
  static const _labels = [
    LineType.ingredient,
    LineType.instruction,
    LineType.title,
    LineType.metadata,
    LineType.sectionHeader,
    LineType.empty,
    LineType.noise,
  ];

  /// Minimum softmax probability for secondary type assignment.
  static const _secondaryTypeThreshold = 0.15;

  final OnnxRuntime _runtime;
  OrtSession? _session;
  WordPieceTokenizer? _tokenizer;
  bool _initialized = false;
  bool _initFailed = false;
  bool _isDisposed = false;
  Completer<void>? _runCompleter;
  String? _inputIdName;
  String? _attentionMaskName;
  String? _outputName;

  OnnxLineClassifierService({OnnxRuntime? runtime})
    : _runtime = runtime ?? OnnxRuntime();

  bool get isAvailable => _initialized && !_initFailed && !_isDisposed;

  /// Initialize with model and vocabulary data.
  Future<bool> initialize({
    required String modelPath,
    required String vocabContent,
  }) async {
    if (_isDisposed) return false;
    if (_initialized) return !_initFailed;

    try {
      _tokenizer = WordPieceTokenizer.fromVocabString(
        vocabContent,
        maxInputLength: _maxLength,
        isCased: true,
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
      _initialized = true;
      AppLogger.warning('$_serviceName: Initialization failed: $e');
      return false;
    }
  }

  /// Classify a batch of lines in a single ONNX forward pass.
  ///
  /// Returns one [ClassifiedLine] per input line. Empty lines are handled
  /// without ONNX inference. Batches larger than [_maxBatchSize] are chunked.
  Future<List<ClassifiedLine>> classifyBatch(List<String> lines) async {
    if (!isAvailable || _session == null || _tokenizer == null) {
      return lines.map(_fallbackClassify).toList();
    }
    if (lines.isEmpty) return [];

    // Separate empty lines from lines needing inference
    final results = List<ClassifiedLine?>.filled(lines.length, null);
    final inferenceIndices = <int>[];
    final inferenceTexts = <String>[];

    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) {
        results[i] = ClassifiedLine(
          text: lines[i],
          type: LineType.empty,
          confidence: 1.0,
        );
      } else {
        inferenceIndices.add(i);
        inferenceTexts.add(lines[i]);
      }
    }

    // Run inference in chunks
    for (
      var chunkStart = 0;
      chunkStart < inferenceTexts.length;
      chunkStart += _maxBatchSize
    ) {
      final chunkEnd = (chunkStart + _maxBatchSize).clamp(
        0,
        inferenceTexts.length,
      );
      final chunkTexts = inferenceTexts.sublist(chunkStart, chunkEnd);
      final chunkIndices = inferenceIndices.sublist(chunkStart, chunkEnd);

      final chunkResults = await _classifyChunk(chunkTexts);
      if (chunkResults != null) {
        for (var i = 0; i < chunkResults.length; i++) {
          results[chunkIndices[i]] = chunkResults[i];
        }
      } else {
        // Fallback for failed chunk
        for (var i = 0; i < chunkTexts.length; i++) {
          results[chunkIndices[i]] = _fallbackClassify(chunkTexts[i]);
        }
      }
    }

    return results.map((r) => r!).toList();
  }

  Future<List<ClassifiedLine>?> _classifyChunk(List<String> texts) async {
    if (_isDisposed || _session == null || _tokenizer == null) return null;
    _runCompleter = Completer<void>();
    try {
      final tokenResults = texts
          .map((t) => _tokenizer!.tokenizeWords(t.split(RegExp(r'\s+'))))
          .toList();

      final batchSize = texts.length;
      final allInputIds = Int64List(batchSize * _maxLength);
      final allAttention = Int64List(batchSize * _maxLength);

      for (var i = 0; i < batchSize; i++) {
        final offset = i * _maxLength;
        allInputIds.setRange(
          offset,
          offset + _maxLength,
          tokenResults[i].inputIds,
        );
        allAttention.setRange(
          offset,
          offset + _maxLength,
          tokenResults[i].attentionMask,
        );
      }

      final flatLogits = await _runInference(
        allInputIds,
        allAttention,
        [batchSize, _maxLength],
      );

      // For sequence classification, model outputs [batch, num_labels]
      // (CLS pooling is done inside the model)
      final numLabels = _labels.length;
      final results = <ClassifiedLine>[];

      for (var b = 0; b < batchSize; b++) {
        final logitStart = b * numLabels;
        final (bestIdx, confidence, secondIdx, secondConf) = _topTwoSoftmax(
          flatLogits,
          logitStart,
          numLabels,
        );

        final primaryType = bestIdx < _labels.length
            ? _labels[bestIdx]
            : LineType.noise;
        final secondaryType =
            secondConf >= _secondaryTypeThreshold && secondIdx < _labels.length
            ? _labels[secondIdx]
            : null;

        results.add(
          ClassifiedLine(
            text: texts[b],
            type: primaryType,
            confidence: confidence,
            secondaryType: secondaryType,
          ),
        );
      }

      return results;
    } catch (e) {
      AppLogger.warning('$_serviceName: Batch classification failed: $e');
      return null;
    } finally {
      _runCompleter?.complete();
      _runCompleter = null;
    }
  }

  Future<List<double>> _runInference(
    List<int> inputIdData,
    List<int> attentionData,
    List<int> shape,
  ) async {
    final inputIds = await OrtValue.fromList(inputIdData, shape);
    final attentionMask = await OrtValue.fromList(attentionData, shape);
    try {
      final outputs = await _session!
          .run({
            _inputIdName!: inputIds,
            _attentionMaskName!: attentionMask,
          })
          .timeout(_batchTimeout);
      try {
        final logitsRaw = await outputs[_outputName]!.asList();
        return _flattenToDoubles(logitsRaw);
      } finally {
        for (final tensor in outputs.values) {
          tensor.dispose();
        }
      }
    } finally {
      inputIds.dispose();
      attentionMask.dispose();
    }
  }

  /// Top-2 softmax: returns (bestIdx, bestProb, secondIdx, secondProb).
  (int, double, int, double) _topTwoSoftmax(
    List<double> logits,
    int offset,
    int length,
  ) {
    var maxVal = logits[offset];
    for (var i = 1; i < length; i++) {
      final v = logits[offset + i];
      if (v > maxVal) maxVal = v;
    }

    var sumExp = 0.0;
    var bestIdx = 0;
    var bestExp = 0.0;
    var secondIdx = 0;
    var secondExp = 0.0;

    for (var i = 0; i < length; i++) {
      final e = math.exp(logits[offset + i] - maxVal);
      sumExp += e;
      if (e > bestExp) {
        secondExp = bestExp;
        secondIdx = bestIdx;
        bestExp = e;
        bestIdx = i;
      } else if (e > secondExp) {
        secondExp = e;
        secondIdx = i;
      }
    }

    return (bestIdx, bestExp / sumExp, secondIdx, secondExp / sumExp);
  }

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

  /// Minimal fallback when ONNX fails — marks as noise so Viterbi can fix.
  ClassifiedLine _fallbackClassify(String line) {
    if (line.trim().isEmpty) {
      return ClassifiedLine(text: line, type: LineType.empty, confidence: 1.0);
    }
    return ClassifiedLine(text: line, type: LineType.noise, confidence: 0.3);
  }

  Future<void> dispose() async {
    _isDisposed = true;
    // Wait for any in-flight inference to complete before closing session
    await _runCompleter?.future;
    await _session?.close();
    _session = null;
    _tokenizer = null;
    _initialized = false;
    _initFailed = false;
    _inputIdName = null;
    _attentionMaskName = null;
    _outputName = null;
  }

  /// Reset disposed state so the service can be re-initialized.
  void resetForReuse() {
    if (!_isDisposed) return;
    _isDisposed = false;
  }
}
