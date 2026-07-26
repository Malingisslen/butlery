// BUT-888 — wire the categorize_ingredient golden corpus.
//
// The categorizer is a pure-Dart rule engine (no model, no Firebase, no
// platform channels) so this runs as a vanilla flutter test. Each case
// goes through `IngredientCategorizer.categorize` and is scored against
// the expected category in cases.json.
//
// PASS/FAIL output is also written to ./goldens-categorize_ingredient.json
// so the nightly workflow (golden-llm.yml) can upload it as an artifact.
//
// Baseline shape: the test asserts the *set of passing case ids* against
// a snapshot. Reviewers flagged that a pass-count assertion can mask
// regressions when one case regresses and another improves on the same
// commit — set equality catches that case. When BUT-1004 closes any
// known gap, flip the case in `_expectedPassing` in the same commit.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/shopping/ingredient_categorizer.dart';

import '_golden_runner.dart';

/// Case ids the categorizer currently produces the expected output for.
/// Bump in lockstep with BUT-1004 (categorizer enhancement).
const _expectedPassing = <String>{
  'ci-001',
  'ci-002',
  'ci-003',
  'ci-004',
  'ci-005',
  'ci-006',
  'ci-007',
  'ci-008',
  'ci-009',
  'ci-010',
  // BUT-1666: substring shadowing fixed — nuts, roasted items, ground paprika
  // and coconut milk now resolve to their real aisle.
  'ci-011',
  'ci-012',
  'ci-013',
  'ci-014',
  'ci-015',
  'ci-016',
  'ci-017',
  // BUT-1666 acceptance criteria, spelled out as the literals the ticket names
  // (open-compound paprika, rostbiff, the nut family, the -ost compounds) plus
  // the adjacent compounds and recall controls each touched rule needs.
  'ci-018',
  'ci-019',
  'ci-020',
  'ci-021',
  'ci-022',
  'ci-023',
  'ci-024',
  'ci-025',
  'ci-026',
  'ci-027',
  'ci-028',
  'ci-029',
  'ci-030',
  'ci-031',
  'ci-032',
  'ci-033',
  'ci-034',
  'ci-035',
  'ci-036',
  // ci-037 ("gräddfil" → dairy). Found absent from the corpus while writing
  // these cases and confirmed as a pre-existing miss — Swedish sour cream is
  // `grädd` + `fil`, so neither `contains('grädde')` nor any bare-word `fil`
  // rule ever reached it. Fixed in the same change that added the case.
  'ci-037',
};

void main() {
  test('categorize_ingredient corpus matches passing-id snapshot', () async {
    final results = await runCorpus(
      resolveCorpusPath('categorize_ingredient'),
      runner: (input) async {
        return IngredientCategorizer.categorize(input as String);
      },
      corpusLabel: 'categorize_ingredient',
    );

    _writeArtifactSummary('categorize_ingredient', results);

    final actualPassing = results
        .where((r) => r.passed)
        .map((r) => r.id)
        .toSet();

    expect(
      actualPassing,
      _expectedPassing,
      reason:
          'Pass-set drift detected.\n'
          'Regressed (were passing, now fail): '
          '${_expectedPassing.difference(actualPassing)}\n'
          'Newly passing (update _expectedPassing): '
          '${actualPassing.difference(_expectedPassing)}',
    );
  });
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
    // Best-effort — local runs without write access just skip the artifact.
  }
}
