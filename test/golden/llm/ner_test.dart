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
// When the env vars are unset (the default for CI nightly today), the
// test SKIPS with a clear message. Bundling the model + vocab is the
// follow-up — see BUT-1005.

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
      expect(initOk, isTrue,
          reason: 'NER service failed to initialize from $mp');

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
        ? 'NER_MODEL_PATH + NER_VOCAB_PATH env vars not set. See BUT-1005 for '
            'bundling the test model. The categorize_ingredient runner '
            'produces baseline numbers in the meantime.'
        : null,
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
