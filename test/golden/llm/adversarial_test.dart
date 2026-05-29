// BUT-804 HIGH-AI4 — adversarial golden corpus.
//
// Authors prompt-injection / jailbreak / structural-attack inputs and asserts
// the categorizer's output stays inside the ShoppingCategory schema. The
// subject under test is the same deterministic rule engine the runtime
// shopping list uses (IngredientCategorizer.categorize), wired through the
// shared BUT-784 golden runner so the adversarial corpus produces the same
// triageable JSON summary as categorize_ingredient / ner.
//
// Why the categorizer is the right target: it is the one LLM-adjacent flow
// that is fully deterministic and bundled (no model, no Firebase, no platform
// channel), so it can run as a vanilla `flutter test` on every CI shard
// without API cost or model fetch. The safe-schema contract it must honor —
// "no matter the input, the output is a valid bucket, never the attacker's
// payload, never an exception" — is exactly the invariant the adversarial
// corpus exists to guard. The model-driven flows (OCR retry, recipe
// extraction, menu generation) need live API calls + a cost guard and are
// tracked as the AI1/AI5/AI6/AI8 ops follow-up, not this in-session slice.
//
// Two layers of assertion:
//   1. Schema-safety (the security contract): EVERY case output must be a
//      member of ShoppingCategory.all, must not throw, and must never equal
//      the raw adversarial payload. This is the assertion that would fail if
//      a future "smart" categorizer started echoing input or emitting
//      free-form labels.
//   2. Passing-id snapshot (regression canary): the set of cases whose
//      expected bucket matches actual, mirroring categorize_ingredient_test's
//      `_expectedPassing` pattern so drift is caught as set inequality.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/tagging/ingredient_categorizer.dart';

import '_golden_runner.dart';

/// Case ids whose `expected` bucket the categorizer currently reproduces.
/// All ten adversarial cases are authored against the current rule engine, so
/// the corpus starts fully green: the point is to FAIL LOUDLY the day a
/// categorizer change lets an adversarial input redirect or escape the schema.
const _expectedPassing = <String>{
  'adv-inj-001',
  'adv-inj-002',
  'adv-inj-003',
  'adv-inj-004',
  'adv-jb-001',
  'adv-jb-002',
  'adv-jb-003',
  'adv-struct-001',
  'adv-struct-002',
  'adv-struct-003',
  'adv-struct-004',
};

void main() {
  late List<GoldenCase> cases;

  setUpAll(() {
    cases = loadCases(resolveCorpusPath('adversarial'));
  });

  test('adversarial output never escapes the ShoppingCategory schema', () {
    final validBuckets = ShoppingCategory.all.toSet();

    for (final c in cases) {
      final input = c.input as String;

      // Contract 1: must not throw on any adversarial input.
      late final String actual;
      expect(
        () => actual = IngredientCategorizer.categorize(input),
        returnsNormally,
        reason: 'categorize() threw on adversarial case ${c.id}',
      );

      // Contract 2: output is a valid bucket constant, not a free-form string.
      expect(
        validBuckets,
        contains(actual),
        reason: 'case ${c.id} produced out-of-schema bucket "$actual" '
            'for input <${_describe(input)}>',
      );

      // Contract 3: the classifier must never echo the attacker payload back
      // as the category. A deterministic engine can't, but this guards the
      // day someone swaps in an LLM-backed categorizer.
      expect(
        actual == input,
        isFalse,
        reason: 'case ${c.id} echoed its raw input as the category',
      );
    }
  });

  test('adversarial corpus matches passing-id snapshot', () async {
    final results = await runCorpus(
      resolveCorpusPath('adversarial'),
      runner: (input) async =>
          IngredientCategorizer.categorize(input as String),
      corpusLabel: 'adversarial',
    );

    _writeArtifactSummary('adversarial', results);

    final actualPassing =
        results.where((r) => r.passed).map((r) => r.id).toSet();

    expect(
      actualPassing,
      _expectedPassing,
      reason: 'Pass-set drift detected.\n'
          'Regressed (were passing, now fail): '
          '${_expectedPassing.difference(actualPassing)}\n'
          'Newly passing (update _expectedPassing): '
          '${actualPassing.difference(_expectedPassing)}',
    );
  });
}

/// Render an adversarial input for failure messages without dumping raw
/// control bytes into the test log. Sub-0x20 code units render as \\uXXXX.
String _describe(String input) {
  if (input.isEmpty) return '<empty>';
  final buffer = StringBuffer();
  for (final unit in input.codeUnits) {
    if (unit < 0x20) {
      buffer.write('\\u${unit.toRadixString(16).padLeft(4, '0')}');
    } else {
      buffer.writeCharCode(unit);
    }
  }
  final escaped = buffer.toString();
  return escaped.length > 60 ? '${escaped.substring(0, 60)}…' : escaped;
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
    // Best-effort artifact write — local runs without write access skip it.
  }
}
