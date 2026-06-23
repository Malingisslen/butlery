import 'dart:async';
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
  static const _singleTimeout = Duration(seconds: 5);
  static const _batchTimeout = Duration(seconds: 10);
  static const _maxBatchSize = 32;

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

      final flatLogits = await _runInference(
        tokenized.inputIds,
        tokenized.attentionMask,
        [1, _maxLength],
        _singleTimeout,
      );

      return _extractPrediction(
        flatLogits: flatLogits,
        logitOffset: 0,
        seqLen: flatLogits.length ~/ _labels.length,
        words: words,
        firstSubwordMap: tokenized.firstSubwordIndices,
      );
    } catch (e) {
      AppLogger.warning('$_serviceName: Prediction failed: $e');
      return null;
    }
  }

  /// Predict BIO labels for multiple word lists in a single ONNX call.
  ///
  /// More efficient than calling [predict] in a loop — builds a single
  /// batched tensor of shape [N, maxLen] and runs one inference pass.
  /// Batches larger than [_maxBatchSize] are split into chunks.
  /// Returns one [NerPrediction?] per input (null for empty/failed lines).
  Future<List<NerPrediction?>> predictBatch(
    List<List<String>> wordsList,
  ) async {
    if (!isAvailable || _session == null || _tokenizer == null) {
      return List.filled(wordsList.length, null);
    }
    if (wordsList.isEmpty) return [];

    // Filter out empty word lists, tracking original indices
    final validIndices = <int>[];
    final validWords = <List<String>>[];
    for (var i = 0; i < wordsList.length; i++) {
      if (wordsList[i].isNotEmpty) {
        validIndices.add(i);
        validWords.add(wordsList[i]);
      }
    }
    if (validWords.isEmpty) return List.filled(wordsList.length, null);

    // Split into chunks to avoid OOM on large inputs
    final results = List<NerPrediction?>.filled(wordsList.length, null);
    for (
      var chunkStart = 0;
      chunkStart < validWords.length;
      chunkStart += _maxBatchSize
    ) {
      final chunkEnd = (chunkStart + _maxBatchSize).clamp(0, validWords.length);
      final chunkWords = validWords.sublist(chunkStart, chunkEnd);
      final chunkIndices = validIndices.sublist(chunkStart, chunkEnd);

      final chunkResults = await _predictChunk(chunkWords);
      if (chunkResults == null) continue;

      for (var i = 0; i < chunkResults.length; i++) {
        results[chunkIndices[i]] = chunkResults[i];
      }
    }
    return results;
  }

  Future<List<NerPrediction?>?> _predictChunk(
    List<List<String>> validWords,
  ) async {
    try {
      final tokenResults = validWords
          .map((w) => _tokenizer!.tokenizeWords(w))
          .toList();

      final batchSize = validWords.length;
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
        _batchTimeout,
      );

      const seqLen = _maxLength;
      final lineLogitsSize = seqLen * _labels.length;

      final chunkResults = <NerPrediction?>[];
      for (var b = 0; b < batchSize; b++) {
        chunkResults.add(
          _extractPrediction(
            flatLogits: flatLogits,
            logitOffset: b * lineLogitsSize,
            seqLen: seqLen,
            words: validWords[b],
            firstSubwordMap: tokenResults[b].firstSubwordIndices,
          ),
        );
      }
      return chunkResults;
    } catch (e) {
      AppLogger.warning('$_serviceName: Batch prediction failed: $e');
      return null;
    }
  }

  /// Create tensors, run ONNX inference, dispose tensors, return flat logits.
  Future<List<double>> _runInference(
    List<int> inputIdData,
    List<int> attentionData,
    List<int> shape,
    Duration timeout,
  ) async {
    final inputIds = await OrtValue.fromList(inputIdData, shape);
    final attentionMask = await OrtValue.fromList(attentionData, shape);
    try {
      final outputs = await _session!
          .run({
            _inputIdName!: inputIds,
            _attentionMaskName!: attentionMask,
          })
          .timeout(timeout);
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

  /// Extract word-level labels + confidence from logits for one line.
  NerPrediction _extractPrediction({
    required List<double> flatLogits,
    required int logitOffset,
    required int seqLen,
    required List<String> words,
    required Map<int, int?> firstSubwordMap,
  }) {
    final numLabels = _labels.length;
    final wordLabels = <BioLabel>[];
    var totalConfidence = 0.0;

    for (var wordIdx = 0; wordIdx < words.length; wordIdx++) {
      final subwordPos = firstSubwordMap[wordIdx];
      if (subwordPos == null || subwordPos >= seqLen) {
        wordLabels.add(BioLabel.other);
        continue;
      }

      final logitStart = logitOffset + subwordPos * numLabels;
      final (bestIdx, confidence) = _argmaxSoftmax(
        flatLogits,
        logitStart,
        numLabels,
      );

      wordLabels.add(
        bestIdx < _labels.length ? _labels[bestIdx] : BioLabel.other,
      );
      totalConfidence += confidence;
    }

    return NerPrediction(
      labels: wordLabels,
      confidence: words.isNotEmpty ? totalConfidence / words.length : 0.0,
    );
  }

  /// Flatten the raw ONNX output into a single list of doubles.
  ///
  /// The output is [batch, seq_len, num_labels], possibly nested
  /// depending on the ONNX Runtime wrapper. We flatten it once and
  /// extract per-position logits on demand.
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

  /// Fused argmax + softmax over a slice of [logits] starting at [offset]
  /// for [length] elements. Zero list allocations.
  (int index, double confidence) _argmaxSoftmax(
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
    for (var i = 0; i < length; i++) {
      final e = math.exp(logits[offset + i] - maxVal);
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
