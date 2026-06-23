// BUT-888 — wire the ner golden corpus.
//
// Unlike the categorize_ingredient runner, the NER service requires:
//   * The ONNX runtime (platform channel — not available under `dart test`)
//   * The BERT NER model file (~30-40 MB, fetched from Firebase Storage
//     at runtime — NOT bundled in the repo)
//   * The KB-BERT vocab.txt
//   * Pre-tokenization via CrfIngredientParser.tokenize()
//   * BIO-span extraction to convert per-word labels back to entity spans
//
// To keep the nightly green without the model bundled, this runner gates
// on the `NER_MODEL_PATH` env var:
//
//   NER_MODEL_PATH=/path/to/model.onnx \
//   NER_VOCAB_PATH=/path/to/vocab.txt \
//   flutter test test/golden/llm/ner_test.dart
//
// BUT-1005 resolution: the skip is PERMANENT under `flutter test`.
// flutter_onnxruntime is a platform-channel plugin — the headless test VM
// has no plugin registrants, so `OnnxRuntime.createSession` throws
// MissingPluginException regardless of whether the model file is present.
// Bundling a stub model or downloading the production one in CI cannot
// fix that. Real NER golden signal needs an integration_test lane on a
// device-capable runner (tracked separately — see the BUT-1005 close-out).
// The env-var gate stays so such a lane can opt in without test changes,
// and the companion test below emits a machine-readable skip artifact so
// the nightly upload always contains `goldens-ner.json`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';
import 'package:butlery/services/parsing/ner/onnx_ner_service.dart';

import '_golden_runner.dart';

void main() {
  final modelPath = Platform.environment['NER_MODEL_PATH'];
  final vocabPath = Platform.environment['NER_VOCAB_PATH'];

  test(
    'ner corpus produces baseline pass count',
    () async {
      final mp = modelPath;
      final vp = vocabPath;
      if (mp == null || vp == null) {
        fail('unreachable — skip guard should have fired');
      }
      final service = OnnxNerService();
      final initOk = await service.initialize(
        modelPath: mp,
        vocabContent: File(vp).readAsStringSync(),
      );
      expect(
        initOk,
        isTrue,
        reason: 'NER service failed to initialize from $mp',
      );

      final results = await runCorpus(
        resolveCorpusPath('ner'),
        runner: (input) async {
          final words = (input as String).split(RegExp(r'\s+'));
          final prediction = await service.predict(words);
          if (prediction == null) return <Map<String, String>>[];
          return _bioToSpans(words, prediction.labels);
        },
        corpusLabel: 'ner',
      );

      _writeArtifactSummary('ner', results);

      // Once BUT-1005 bundles the test model and this stops skipping,
      // replace this smoke assertion with a passing-id snapshot like
      // categorize_ingredient_test.dart's `_expectedPassing`.
      expect(results.length, greaterThan(0));
    },
    skip: (modelPath == null || vocabPath == null)
        ? 'NER_MODEL_PATH + NER_VOCAB_PATH env vars not set — and ONNX '
              'inference cannot run under flutter test anyway (platform-channel '
              'plugin, BUT-1005). The categorize_ingredient runner produces '
              'baseline numbers in the meantime.'
        : null,
  );

  test(
    'ner skip artifact is emitted when the corpus cannot run (BUT-1005)',
    () {
      // The nightly uploads goldens-*.json; a silently-skipped corpus would
      // simply be missing from the artifact set, indistinguishable from a
      // broken runner. Emit an explicit skip record instead so "could not
      // run" is machine-readable. When the env vars ARE set, the real test
      // above owns the artifact and this test must not clobber it.
      if (modelPath != null && vocabPath != null) return;

      final summary = {
        'corpus': 'ner',
        'total': 0,
        'passed': 0,
        'failed': 0,
        'skipped': true,
        'reason':
            'ONNX runtime is a platform-channel plugin — unavailable '
            'under flutter test. Needs an integration_test lane on a '
            'device-capable runner (BUT-1005).',
        'failures': const <Object>[],
      };
      File('goldens-ner.json').writeAsStringSync(jsonEncode(summary));
      expect(File('goldens-ner.json').existsSync(), isTrue);
    },
  );
}

/// Convert per-word BIO labels into entity-span maps matching the
/// `[{text, label}]` shape `ner/cases.json` expects.
///
/// Only B-NAME / I-NAME runs are emitted as "INGREDIENT" spans —
/// other BIO labels (B-QTY, B-UNIT, B-PREP, B-SIZE) are out of scope
/// for the ingredient-only golden corpus.
List<Map<String, String>> _bioToSpans(
  List<String> words,
  List<BioLabel> labels,
) {
  final spans = <Map<String, String>>[];
  final buffer = <String>[];

  void flush() {
    if (buffer.isEmpty) return;
    spans.add({'text': buffer.join(' '), 'label': 'INGREDIENT'});
    buffer.clear();
  }

  for (var i = 0; i < words.length && i < labels.length; i++) {
    final label = labels[i];
    if (label == BioLabel.bName) {
      flush();
      buffer.add(words[i]);
    } else if (label == BioLabel.iName) {
      buffer.add(words[i]);
    } else {
      flush();
    }
  }
  flush();
  return spans;
}

void _writeArtifactSummary(String corpus, List<GoldenResult> results) {
  final passed = results.where((r) => r.passed).length;
  final summary = {
    'corpus': corpus,
    'total': results.length,
    'passed': passed,
    'failed': results.length - passed,
    'failures': results
        .where((r) => !r.passed)
        .map((r) => {'id': r.id, 'reason': r.failureReason})
        .toList(),
  };
  try {
    File('goldens-$corpus.json').writeAsStringSync(jsonEncode(summary));
  } on FileSystemException {
    // Best-effort artifact write.
  }
}
