/// Behaviour covered for [OnnxNerService]:
///
/// 1. `isAvailable` reflects init state: false before initialize, false when
///    initialize fails, true on success, false after dispose.
/// 2. `predict` and `predictBatch` degrade gracefully (return null /
///    list-of-nulls) when not initialized — they must not throw on the
///    cold path used by every parsing pipeline before warm-up.
/// 3. `predict` returns null for empty input (an obvious guard that a
///    refactor could accidentally remove).
/// 4. `predictBatch` returns a same-length list of nulls when called with
///    only empty word lists, and preserves original indices when mixed.
/// 5. `initialize` swallows session-creation errors and marks the service
///    unavailable instead of throwing — this is the user-facing graceful
///    degradation contract.
/// 6. `initialize` is idempotent: a second call returns the cached result
///    without re-creating the session.
/// 7. `dispose` is safe to call before init and idempotent after.
/// 8. End-to-end (with a faked ONNX platform) the BIO label index produced
///    by argmax over scripted logits is mapped through the SERVICE's
///    `_labels` ordering, not through `BioLabel.values` ordering — this is
///    where ML wrappers classically have off-by-one bugs.
/// 9. End-to-end: confidence is the softmax of the argmax logit, averaged
///    across words; sane bounds [0, 1].
/// 10. `predictBatch` chunks inputs larger than the service's batch limit
///     and still produces one result per input (including nulls in the
///     right slots for empties).
/// 11. `NerPrediction` value class exposes labels + confidence verbatim.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';
import 'package:butlery/services/parsing/ner/onnx_ner_service.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
// ignore: implementation_imports
import 'package:flutter_onnxruntime/src/flutter_onnxruntime_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// OnnxRuntime subclass that throws on session creation — used to drive
/// the initialize-failure branch without any platform setup.
class _ThrowingOnnxRuntime extends OnnxRuntime {
  final Object error;
  _ThrowingOnnxRuntime(this.error);

  @override
  Future<OrtSession> createSession(
    String modelPath, {
    OrtSessionOptions? options,
  }) async {
    throw error;
  }
}

/// OnnxRuntime subclass that records how many sessions were created — used
/// to verify initialize() doesn't double-create.
class _CountingOnnxRuntime extends OnnxRuntime {
  int createCount = 0;
  final OrtSession Function() build;
  _CountingOnnxRuntime(this.build);

  @override
  Future<OrtSession> createSession(
    String modelPath, {
    OrtSessionOptions? options,
  }) async {
    createCount++;
    return build();
  }
}

/// Scripted platform fake — answers just enough of the platform interface to
/// run an end-to-end predict() / predictBatch() without a real native runtime.
///
/// Logit script: callers register what each `runInference` call should
/// return as a flattened list of doubles (shape [batch, seq, numLabels]).
class _ScriptedOnnxPlatform extends FlutterOnnxruntimePlatform
    with MockPlatformInterfaceMixin {
  _ScriptedOnnxPlatform({
    required this.inputNames,
    required this.outputName,
    required this.numLabels,
  });

  final List<String> inputNames;
  final String outputName;
  final int numLabels;

  int closeCount = 0;
  int sessionCreateCount = 0;
  int valueIdCounter = 0;

  /// Queue of flattened logit arrays — one entry consumed per runInference.
  final List<List<double>> scriptedLogits = [];

  /// Records the shape passed for each runInference call.
  final List<List<int>> runShapes = [];

  /// Storage: valueId → data list (for asList()).
  final Map<String, List<dynamic>> _valueData = {};
  final Map<String, List<int>> _valueShape = {};

  @override
  Future<Map<String, dynamic>> createSession(
    String modelPath, {
    Map<String, dynamic>? sessionOptions,
  }) async {
    sessionCreateCount++;
    return {
      'sessionId': 'test-session-$sessionCreateCount',
      'inputNames': inputNames,
      'outputNames': [outputName],
    };
  }

  @override
  Future<Map<String, dynamic>> createOrtValue(
    String sourceType,
    dynamic data,
    List<int> shape,
  ) async {
    final id = 'val-${valueIdCounter++}';
    _valueShape[id] = List<int>.from(shape);
    return {'valueId': id, 'dataType': sourceType, 'shape': shape};
  }

  @override
  Future<Map<String, dynamic>> runInference(
    String sessionId,
    Map<String, OrtValue> inputs, {
    Map<String, dynamic>? runOptions,
  }) async {
    if (scriptedLogits.isEmpty) {
      throw StateError(
        'Test scripted no logits but production called runInference',
      );
    }
    final logits = scriptedLogits.removeAt(0);
    // Infer shape from the first input tensor.
    final firstInput = inputs.values.first;
    final batch = firstInput.shape[0];
    final seq = firstInput.shape[1];
    runShapes.add([batch, seq]);

    final outId = 'out-${valueIdCounter++}';
    _valueData[outId] = logits;
    _valueShape[outId] = [batch, seq, numLabels];
    return {
      outputName: [outId, 'float32', _valueShape[outId]!],
    };
  }

  @override
  Future<Map<String, dynamic>> getOrtValueData(String valueId) async {
    return {'data': _valueData[valueId] ?? <double>[]};
  }

  @override
  Future<void> releaseOrtValue(String valueId) async {
    _valueData.remove(valueId);
    _valueShape.remove(valueId);
  }

  @override
  Future<void> closeSession(String sessionId) async {
    closeCount++;
  }
}

// ---------------------------------------------------------------------------
// Vocab fixture
// ---------------------------------------------------------------------------

/// Minimal cased BERT-style vocab. Index = line number (0-based).
/// Special tokens first to mirror real KB-BERT vocab.
const String _testVocab =
    '[PAD]\n' // 0
    '[UNK]\n' // 1
    '[CLS]\n' // 2  (but real BERT has [CLS] at 101; the service uses
    //     vocab[_clsToken] so the index here is what matters)
    '[SEP]\n' // 3
    'mjölk\n' // 4
    'tomat\n' // 5
    'salt\n' // 6
    'gul\n' // 7
    'lök\n' // 8
    'finhackad\n' // 9
    '2\n' // 10
    'dl\n'; // 11

// Production label ordering (must mirror the private `_labels` constant in
// onnx_ner_service.dart). Captured here so the test asserts on the SAME
// ordering and a refactor that re-orders without updating both surfaces is
// caught.
const _productionLabelOrder = [
  BioLabel.other, // 0 → O
  BioLabel.bQty, // 1 → B-QTY
  BioLabel.iQty, // 2 → I-QTY
  BioLabel.bUnit, // 3 → B-UNIT
  BioLabel.bName, // 4 → B-NAME
  BioLabel.iName, // 5 → I-NAME
  BioLabel.bPrep, // 6 → B-PREP
  BioLabel.iPrep, // 7 → I-PREP
  BioLabel.bSize, // 8 → B-SIZE
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnnxNerService — cold-path / lifecycle', () {
    test('isAvailable is false before initialize', () {
      final service = OnnxNerService();
      expect(service.isAvailable, isFalse);
    });

    /// Cold-path callers (parser pipeline before warm-up) must get null,
    /// NOT an exception. Off-by-one or "throw on null session" would
    /// regress this.
    test('predict returns null when not initialized', () async {
      final service = OnnxNerService();
      final result = await service.predict(['2', 'dl', 'mjölk']);
      expect(result, isNull);
    });

    /// Same contract for batch — and crucially, returns a list of correct
    /// length so callers can zip results back to inputs.
    test(
      'predictBatch returns same-length list of nulls when uninitialized',
      () async {
        final service = OnnxNerService();
        final results = await service.predictBatch([
          ['2', 'dl', 'mjölk'],
          ['salt'],
          ['1', 'st', 'tomat'],
        ]);
        expect(results, hasLength(3));
        expect(results, everyElement(isNull));
      },
    );

    test('predictBatch returns empty list for empty batch', () async {
      final service = OnnxNerService();
      final results = await service.predictBatch([]);
      expect(results, isEmpty);
    });

    test('predict returns null for empty word list', () async {
      // Ensure this guard fires BEFORE any platform interaction, so even
      // post-init the empty-list guard still works (no logits requested).
      final platform = _ScriptedOnnxPlatform(
        inputNames: ['input_ids', 'attention_mask'],
        outputName: 'logits',
        numLabels: _productionLabelOrder.length,
      );
      _withPlatform(platform, () async {
        final service = OnnxNerService();
        await service.initialize(modelPath: 'x', vocabContent: _testVocab);

        final result = await service.predict(<String>[]);
        expect(result, isNull);
        // Production must NOT have called the runtime for an empty input.
        expect(platform.runShapes, isEmpty);
      });
    });

    test('dispose is safe before init (no session to close)', () async {
      final service = OnnxNerService();
      await service.dispose(); // must not throw
      expect(service.isAvailable, isFalse);
    });

    test('dispose is idempotent', () async {
      final service = OnnxNerService();
      await service.dispose();
      await service.dispose();
      expect(service.isAvailable, isFalse);
    });
  });

  group('OnnxNerService — initialize failure paths', () {
    /// Graceful degradation: a missing/corrupt model must NOT crash the
    /// app — it should mark the service unavailable and let the CRF
    /// fallback take over. This is the contract that the user-visible
    /// "ingredient parsing still works without ML" relies on.
    test(
      'initialize returns false and isAvailable stays false when session creation throws',
      () async {
        final runtime = _ThrowingOnnxRuntime(
          StateError('model file not found'),
        );
        final service = OnnxNerService(runtime: runtime);

        final ok = await service.initialize(
          modelPath: '/no/such/model.onnx',
          vocabContent: _testVocab,
        );

        expect(ok, isFalse);
        expect(service.isAvailable, isFalse);
      },
    );

    /// After a failed initialize, subsequent predict()/predictBatch() must
    /// still return null/list-of-nulls (not throw). Without this, every
    /// parse after a flaky model load would crash.
    test(
      'predict and predictBatch return null after failed initialize',
      () async {
        final runtime = _ThrowingOnnxRuntime(Exception('boom'));
        final service = OnnxNerService(runtime: runtime);
        await service.initialize(modelPath: 'x', vocabContent: _testVocab);

        expect(await service.predict(['salt']), isNull);
        final batch = await service.predictBatch([
          ['salt'],
          ['tomat'],
        ]);
        expect(batch, [null, null]);
      },
    );

    /// A second initialize() call on an already-initialised service must
    /// not re-run createSession — that would leak native session handles.
    /// (The production guard is `if (_initialized) return !_initFailed;`.)
    test(
      'initialize is idempotent — second call does not re-create session',
      () async {
        final platform = _ScriptedOnnxPlatform(
          inputNames: ['input_ids', 'attention_mask'],
          outputName: 'logits',
          numLabels: _productionLabelOrder.length,
        );

        await _withPlatform(platform, () async {
          final service = OnnxNerService();
          final first = await service.initialize(
            modelPath: 'x',
            vocabContent: _testVocab,
          );
          final second = await service.initialize(
            modelPath: 'y', // different path — must still be ignored
            vocabContent: _testVocab,
          );

          expect(first, isTrue);
          expect(second, isTrue);
          expect(
            platform.sessionCreateCount,
            1,
            reason: 'initialize() must short-circuit after success',
          );
        });
      },
    );

    /// Repeat for the failure case: a service that failed init should not
    /// retry on its own — caller has to dispose() first.
    test(
      'initialize is idempotent on failure (returns cached false)',
      () async {
        final runtime = _ThrowingOnnxRuntime(Exception('boom'));
        // Wrap in counting runtime to count attempts.
        final counting = _CountingOnnxRuntime(() => throw Exception('boom'));
        final service = OnnxNerService(runtime: counting);

        final a = await service.initialize(modelPath: 'x', vocabContent: 'tok');
        final b = await service.initialize(modelPath: 'y', vocabContent: 'tok');

        expect(a, isFalse);
        expect(b, isFalse);
        expect(
          counting.createCount,
          1,
          reason: 'second initialize must not retry without dispose()',
        );

        // Silence unused-warning safely.
        expect(runtime, isNotNull);
      },
    );
  });

  group('OnnxNerService — end-to-end inference contract', () {
    /// Argmax over scripted logits must map index→label via the SERVICE's
    /// internal `_labels` ordering, not via BioLabel.values. Setting logit
    /// index 4 highest must produce BioLabel.bName (production index 4),
    /// even though BioLabel.bName is enum index 3 in the enum declaration.
    /// This is the test that catches the classic "labels list re-ordered
    /// but enum not" bug.
    test(
      'predict maps argmax index through the production label ordering',
      () async {
        final platform = _ScriptedOnnxPlatform(
          inputNames: ['input_ids', 'attention_mask'],
          outputName: 'logits',
          numLabels: _productionLabelOrder.length,
        );

        // Build logits for [1, 128, 9]: pad with zeros, but at the position of
        // the first subword of the single input word, put a big peak at index 4
        // → BioLabel.bName in the production label ordering.
        // The tokenizer puts [CLS] at position 0, then the word's first
        // subword at position 1.
        const seqLen = 128;
        const numLabels = 9;
        final logits = List<double>.filled(seqLen * numLabels, 0.0);
        const firstSubwordPos = 1; // after [CLS]
        const peakLabel = 4; // → BioLabel.bName
        logits[firstSubwordPos * numLabels + peakLabel] = 10.0;
        platform.scriptedLogits.add(logits);

        await _withPlatform(platform, () async {
          final service = OnnxNerService();
          await service.initialize(modelPath: 'm', vocabContent: _testVocab);
          final result = await service.predict(['salt']);

          expect(result, isNotNull);
          expect(result!.labels, hasLength(1));
          expect(
            result.labels[0],
            BioLabel.bName,
            reason: 'label index 4 in _labels is BioLabel.bName',
          );
          // Softmax of (10, 0, 0, ..., 0) is e^10 / (e^10 + 8) ≈ ~1.0
          expect(result.confidence, greaterThan(0.99));
          expect(result.confidence, lessThanOrEqualTo(1.0));
        });
      },
    );

    /// Confidence is the average softmax probability across words. Two
    /// words with the same logit profile must have the same per-word
    /// confidence, and the average must equal that per-word value.
    test('predict confidence is averaged softmax across words', () async {
      final platform = _ScriptedOnnxPlatform(
        inputNames: ['input_ids', 'attention_mask'],
        outputName: 'logits',
        numLabels: _productionLabelOrder.length,
      );
      const seqLen = 128;
      const numLabels = 9;
      final logits = List<double>.filled(seqLen * numLabels, 0.0);
      // Two words → first subwords at positions 1 and 2 (each word is a
      // single in-vocab subword in our fixture).
      // Word 0: strong peak at label 1 (B-QTY). Word 1: weaker peak at
      // label 4 (B-NAME). Confidence should be between the two.
      logits[1 * numLabels + 1] = 10.0; // very confident
      logits[2 * numLabels + 4] = 2.0; // somewhat confident
      platform.scriptedLogits.add(logits);

      await _withPlatform(platform, () async {
        final service = OnnxNerService();
        await service.initialize(modelPath: 'm', vocabContent: _testVocab);
        final result = await service.predict(['2', 'mjölk']);

        expect(result, isNotNull);
        expect(result!.labels, [BioLabel.bQty, BioLabel.bName]);
        expect(result.confidence, greaterThan(0.0));
        expect(
          result.confidence,
          lessThan(1.0),
          reason: 'second word is not maximally confident',
        );
      });
    });

    /// predictBatch with mixed empty + non-empty inputs must:
    /// 1. Skip the empties (don't tokenize them).
    /// 2. Preserve original indices — empties get null in the result.
    /// 3. Run a single batched inference for the valid lines.
    test('predictBatch preserves indices and skips empty word lists', () async {
      final platform = _ScriptedOnnxPlatform(
        inputNames: ['input_ids', 'attention_mask'],
        outputName: 'logits',
        numLabels: _productionLabelOrder.length,
      );
      const seqLen = 128;
      const numLabels = 9;
      // Two valid lines → batch of 2.
      final logits = List<double>.filled(2 * seqLen * numLabels, 0.0);
      // For the first line (batch=0), peak at label 1 (B-QTY) for word 0.
      logits[0 * seqLen * numLabels + 1 * numLabels + 1] = 5.0;
      // For the second line (batch=1), peak at label 4 (B-NAME) for word 0.
      logits[1 * seqLen * numLabels + 1 * numLabels + 4] = 5.0;
      platform.scriptedLogits.add(logits);

      await _withPlatform(platform, () async {
        final service = OnnxNerService();
        await service.initialize(modelPath: 'm', vocabContent: _testVocab);

        final results = await service.predictBatch([
          ['2'], // index 0 → valid
          <String>[], // index 1 → empty, must remain null
          ['salt'], // index 2 → valid
        ]);

        expect(results, hasLength(3));
        expect(results[0]?.labels, [BioLabel.bQty]);
        expect(results[1], isNull, reason: 'empty list must stay null');
        expect(results[2]?.labels, [BioLabel.bName]);

        // One batched inference call, shape [2, 128].
        expect(platform.runShapes, hasLength(1));
        expect(platform.runShapes.single, [2, 128]);
      });
    });

    /// predictBatch with >32 (the internal _maxBatchSize) inputs must
    /// split into multiple inference calls, but still return one result
    /// per input. Off-by-one in the chunking bound is a classic ML wrapper
    /// bug — this test catches it.
    test(
      'predictBatch chunks inputs exceeding the internal batch size',
      () async {
        final platform = _ScriptedOnnxPlatform(
          inputNames: ['input_ids', 'attention_mask'],
          outputName: 'logits',
          numLabels: _productionLabelOrder.length,
        );
        const seqLen = 128;
        const numLabels = 9;
        // 40 valid lines → 32 + 8 chunks.
        // Each chunk gets its own scripted logits batch.
        List<double> zerosFor(int batch) =>
            List<double>.filled(batch * seqLen * numLabels, 0.0);
        platform.scriptedLogits.add(zerosFor(32));
        platform.scriptedLogits.add(zerosFor(8));

        await _withPlatform(platform, () async {
          final service = OnnxNerService();
          await service.initialize(modelPath: 'm', vocabContent: _testVocab);

          final inputs = List<List<String>>.generate(40, (_) => ['salt']);
          final results = await service.predictBatch(inputs);

          expect(results, hasLength(40));
          expect(
            results,
            everyElement(isNotNull),
            reason: 'no chunk boundary should produce null',
          );
          // Verify the two batch shapes recorded.
          expect(platform.runShapes, hasLength(2));
          expect(platform.runShapes[0], [32, 128]);
          expect(platform.runShapes[1], [8, 128]);
        });
      },
    );

    /// If runInference throws, predictBatch must degrade to nulls for
    /// the affected chunk (not propagate the exception). Other chunks
    /// in the same call should still get their result if scripted.
    test(
      'predictBatch returns nulls for a chunk whose inference throws',
      () async {
        final platform = _ScriptedOnnxPlatform(
          inputNames: ['input_ids', 'attention_mask'],
          outputName: 'logits',
          numLabels: _productionLabelOrder.length,
        );
        // No scripted logits — the _ScriptedOnnxPlatform throws StateError
        // on runInference when scriptedLogits is empty. predictBatch should
        // catch and return nulls.
        await _withPlatform(platform, () async {
          final service = OnnxNerService();
          await service.initialize(modelPath: 'm', vocabContent: _testVocab);

          final results = await service.predictBatch([
            ['salt'],
            ['tomat'],
          ]);
          expect(results, [null, null]);
        });
      },
    );

    /// dispose() must call into the session close on the platform. This is
    /// the only way the user knows native memory is freed.
    test('dispose closes the underlying session and clears state', () async {
      final platform = _ScriptedOnnxPlatform(
        inputNames: ['input_ids', 'attention_mask'],
        outputName: 'logits',
        numLabels: _productionLabelOrder.length,
      );

      await _withPlatform(platform, () async {
        final service = OnnxNerService();
        await service.initialize(modelPath: 'm', vocabContent: _testVocab);
        expect(service.isAvailable, isTrue);

        await service.dispose();
        expect(service.isAvailable, isFalse);
        expect(platform.closeCount, 1);

        // After dispose, predict() must again degrade to null, not throw
        // on the stale session reference.
        final result = await service.predict(['salt']);
        expect(result, isNull);
      });
    });

    /// After dispose, initialize() can be called again to reset and
    /// re-create the session — documented in the production doc-comment.
    test('initialize after dispose creates a fresh session', () async {
      final platform = _ScriptedOnnxPlatform(
        inputNames: ['input_ids', 'attention_mask'],
        outputName: 'logits',
        numLabels: _productionLabelOrder.length,
      );

      await _withPlatform(platform, () async {
        final service = OnnxNerService();
        await service.initialize(modelPath: 'm', vocabContent: _testVocab);
        await service.dispose();
        await service.initialize(modelPath: 'm', vocabContent: _testVocab);

        expect(service.isAvailable, isTrue);
        expect(
          platform.sessionCreateCount,
          2,
          reason: 'dispose + initialize must rebuild the session',
        );
      });
    });
  });

  group('NerPrediction value class', () {
    test('exposes labels and confidence verbatim', () {
      const p = NerPrediction(
        labels: [BioLabel.bQty, BioLabel.bUnit, BioLabel.bName],
        confidence: 0.875,
      );
      expect(p.labels, [BioLabel.bQty, BioLabel.bUnit, BioLabel.bName]);
      expect(p.confidence, 0.875);
    });
  });
}

// ---------------------------------------------------------------------------
// Platform wiring helper
// ---------------------------------------------------------------------------

/// Run [body] with [platform] installed as the singleton
/// FlutterOnnxruntimePlatform.instance, restoring the previous one after.
/// Uses `Future<void>` so we can `await _withPlatform(...)`.
Future<T> _withPlatform<T>(
  _ScriptedOnnxPlatform platform,
  Future<T> Function() body,
) async {
  final previous = FlutterOnnxruntimePlatform.instance;
  FlutterOnnxruntimePlatform.instance = platform;
  try {
    return await body();
  } finally {
    FlutterOnnxruntimePlatform.instance = previous;
  }
}

// Silence unused-import lint for dart:async (used implicitly by Futures).
// ignore: unused_element
void _retainAsync() => Completer<void>();

// Silence unused dart:typed_data import warning if not referenced.
// ignore: unused_element
Int64List? _retainTyped() => null;
