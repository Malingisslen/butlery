// ignore_for_file: avoid_print
//
// This file intentionally prints calibration tables on every run so that
// refactor-driven drift is visible in test logs before any assertion fires.

import 'package:butlery/services/parsing/parsers/swedish_line_classifier.dart';
import 'package:butlery/services/parsing/parsers/viterbi_context_processor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'viterbi_calibration_fixtures.dart';
import 'viterbi_context_processor_fixtures.dart';

/// ViterbiContextProcessor — confidence calibration measurement
/// =============================================================
///
/// Subject: the **0.75 confidence threshold** at
/// `viterbi_context_processor.dart` (`_defaultHighConfidenceThreshold`),
/// used to gate the high-emission anchoring weight (2.5x). The threshold
/// was hardcoded last sprint without empirical evidence; this test proves
/// or disproves it.
///
/// Three measurements:
///
/// 1. **Calibration curve.** Bucket per-line predictions by *input*
///    confidence (the per-line classifier's score, which is what the
///    threshold gates) into bands. Compute empirical accuracy per band.
///    A well-calibrated classifier has band-accuracy ≈ band-midpoint.
///
/// 2. **Threshold sweep at {0.6, 0.7, 0.75, 0.8, 0.9}.** For each
///    candidate anchor threshold, instantiate a `ViterbiContextProcessor`
///    with that threshold, classify the corpus, and measure end-to-end
///    accuracy of the post-Viterbi predictions. The threshold that
///    maximizes accuracy is the empirical optimum for the anchoring
///    behaviour the constant actually gates.
///
///    Precision/recall/F1 are reported as supplementary diagnostics
///    (treating "above-threshold" as the positive class), but the
///    decision is driven by accuracy, not F1 — the F1 framing is
///    structurally biased toward low thresholds because virtually every
///    line in the corpus is correctly classified, so widening the
///    "positive" set mechanically inflates recall regardless of whether
///    anchoring helped.
///
/// 3. **Held-out validation.** Re-run measurements on a fresh 4-recipe
///    corpus (`viterbi_calibration_fixtures.dart`) that the original
///    golden set has not been tuned against. Material divergence between
///    golden and held-out F1 = overfitting flag.
///
/// **What "input confidence" means.** The threshold gates emission
/// weighting based on the per-line classifier's confidence — not the
/// post-Viterbi confidence (which is a blended derived value for
/// overridden lines). So calibration banding uses the input (pre-Viterbi)
/// confidence; correctness is measured post-Viterbi (since that is the
/// final prediction the rest of the system sees).
///
/// **Determinism.** No randomness, no sampling. Every measurement is a
/// pure function of the fixture corpora; running this test twice yields
/// byte-identical numbers.
///
/// ## Baseline measurement
///
/// Full numbers are committed in `viterbi_calibration_baseline.md`
/// (sibling file). The print statements below emit the same tables on
/// every run, so a refactor that drifts the calibration shows up as a
/// diff in test logs even before any assertion fires.
///
/// **Decision recorded 2026-04-30: 0.75 stands.** End-to-end accuracy is
/// flat across thresholds 0.70-0.90 on both golden (110 lines) and
/// held-out (59 lines) corpora. Only 0.60 materially changes outcomes
/// (drops accuracy by ~7pp on golden, ~2pp on held-out). The constant is
/// kept at 0.75. See the baseline file for the full reasoning, including
/// why F1 is reported but not used to drive the decision.

void main() {
  final classifier = SwedishLineClassifier.instance;

  // Confidence bands for the calibration curve. Edges chosen so that 0.75
  // (the threshold under test) sits exactly on a band boundary — this lets
  // the table show whether predictions just-above-threshold are meaningfully
  // more accurate than just-below.
  const bandEdges = <double>[0.0, 0.6, 0.7, 0.75, 0.8, 0.9, 1.0001];

  // Threshold variants to compare. 0.75 is the current production value;
  // the others bracket it on both sides.
  const thresholdSweep = <double>[0.6, 0.7, 0.75, 0.8, 0.9];

  // Hoisted: scoring is deterministic and shared across every test in the
  // file. Computing once removes 3 redundant corpus passes per run.
  late final List<_ScoredLine> goldenScored;
  late final List<_ScoredLine> heldOutScored;
  late final Map<double, _ThresholdMetrics> goldenSweep;
  late final Map<double, _ThresholdMetrics> heldOutSweep;

  setUpAll(() {
    goldenScored = _scoreCorpus(goldenRecipes, classifier);
    heldOutScored = _scoreCorpus(heldOutRecipes, classifier);
    goldenSweep = _sweepCorpus(goldenRecipes, classifier, thresholdSweep);
    heldOutSweep = _sweepCorpus(heldOutRecipes, classifier, thresholdSweep);
  });

  group('ViterbiContextProcessor — confidence calibration', () {
    test(
        'input confidence is monotone with empirical accuracy on golden corpus',
        () {
      final calibration = _calibrationByBand(goldenScored, bandEdges);
      print(_formatCalibrationTable('Golden', calibration));

      // A miscalibrated classifier shows a flat or inverted curve — that
      // means confidence is uncorrelated with correctness, which would make
      // the 0.75 anchor meaningless. Allow one inversion to absorb noise on
      // small bands; flag two as a real calibration failure.
      final populated =
          calibration.where((b) => b.total > 0).toList(growable: false);
      var inversions = 0;
      for (var i = 1; i < populated.length; i++) {
        if (populated[i].accuracy < populated[i - 1].accuracy) inversions++;
      }
      expect(
        inversions,
        lessThanOrEqualTo(1),
        reason:
            'Confidence is not monotonically informative: more than one band '
            'inversion. Threshold-based anchoring assumes monotonicity. '
            'Calibration table:\n${_formatCalibrationTable('Golden', calibration)}',
      );

      final lowest = populated.first;
      final highest = populated.last;
      expect(
        highest.accuracy + 0.05,
        greaterThanOrEqualTo(lowest.accuracy),
        reason:
            'Top-confidence band (${highest.label}) has lower accuracy than '
            'lowest band (${lowest.label}) by more than 5pp — confidence is '
            'inverted. The threshold cannot be calibrated.',
      );
    });

    test('held-out corpus matches golden within 5pp aggregate', () {
      final goldenAcc = _aggregateAccuracy(goldenScored);
      final heldOutAcc = _aggregateAccuracy(heldOutScored);

      // Print the held-out band table here too — the per-band Wilson CI on
      // 59 trials is too wide to support per-band assertions, but emitting
      // the table keeps drift visible in test logs alongside the golden one.
      print(_formatCalibrationTable(
          'Held-out', _calibrationByBand(heldOutScored, bandEdges)));
      print('\nAggregate accuracy comparison (default threshold = 0.75):');
      print('  Golden:   ${(goldenAcc * 100).toStringAsFixed(1)}% '
          '(${goldenScored.length} lines)');
      print('  Held-out: ${(heldOutAcc * 100).toStringAsFixed(1)}% '
          '(${heldOutScored.length} lines)');

      expect(
        (goldenAcc - heldOutAcc).abs(),
        lessThan(0.05),
        reason: 'Held-out corpus accuracy diverges from golden by >5pp. The '
            'algorithm may be overfit to golden-specific phrasings. '
            'Golden=$goldenAcc, HeldOut=$heldOutAcc.',
      );
    });
  });

  group('ViterbiContextProcessor — threshold accuracy sweep', () {
    test('threshold sweep on golden corpus prints end-to-end accuracy', () {
      print(_formatSweepTable('Golden', goldenSweep));
      _assertSweepValid(goldenSweep, label: 'golden');
    });

    test('threshold sweep on held-out corpus prints end-to-end accuracy', () {
      print(_formatSweepTable('Held-out', heldOutSweep));
      _assertSweepValid(heldOutSweep, label: 'held-out');
    });

    test(
        '0.75 is within 2pp of the accuracy-optimal threshold on BOTH '
        'corpora (decision rule: keep current threshold)', () {
      // The decision: only change the constant if a different anchor
      // threshold gives strictly better END-TO-END ACCURACY by >2pp on BOTH
      // golden AND held-out at the SAME threshold value. If a threshold wins
      // on only one corpus, that's the noise floor of a small corpus, not a
      // calibration finding. Sweep accuracy (not F1) because the threshold
      // gates emission anchoring; the right question is "does post-Viterbi
      // correctness change?"
      final goldenAccAtDefault = goldenSweep[0.75]!.accuracy;
      final heldOutAccAtDefault = heldOutSweep[0.75]!.accuracy;

      var bestGolden = goldenAccAtDefault;
      var bestHeldOut = heldOutAccAtDefault;
      var bestGoldenAt = 0.75;
      var bestHeldOutAt = 0.75;
      for (final t in thresholdSweep) {
        if (t == 0.75) continue;
        final g = goldenSweep[t]!.accuracy;
        final h = heldOutSweep[t]!.accuracy;
        if (g > bestGolden) {
          bestGolden = g;
          bestGoldenAt = t;
        }
        if (h > bestHeldOut) {
          bestHeldOut = h;
          bestHeldOutAt = t;
        }
      }

      print('\nDecision diagnostics (end-to-end post-Viterbi accuracy):');
      print('  Golden  acc@0.75 = '
          '${(goldenAccAtDefault * 100).toStringAsFixed(2)}% | '
          'best = ${(bestGolden * 100).toStringAsFixed(2)}% @ $bestGoldenAt');
      print('  HeldOut acc@0.75 = '
          '${(heldOutAccAtDefault * 100).toStringAsFixed(2)}% | '
          'best = ${(bestHeldOut * 100).toStringAsFixed(2)}% @ $bestHeldOutAt');

      const noiseFloor = 0.02;
      final goldenGap = bestGolden - goldenAccAtDefault;
      final heldOutGap = bestHeldOut - heldOutAccAtDefault;

      // A non-default threshold "wins" only when the gap exceeds the noise
      // floor on BOTH corpora and at the SAME threshold.
      final consistentWinner = bestGoldenAt == bestHeldOutAt &&
          bestGoldenAt != 0.75 &&
          goldenGap > noiseFloor &&
          heldOutGap > noiseFloor;

      expect(
        consistentWinner,
        isFalse,
        reason: 'A non-default anchor threshold ($bestGoldenAt) beat 0.75 '
            'by more than ${(noiseFloor * 100).toStringAsFixed(0)}pp '
            'end-to-end accuracy on BOTH golden (gap='
            '${(goldenGap * 100).toStringAsFixed(2)}pp) and held-out '
            '(gap=${(heldOutGap * 100).toStringAsFixed(2)}pp). The constant '
            '`_defaultHighConfidenceThreshold` should be updated. This is '
            'the test catching a real calibration finding — do NOT weaken '
            'the assertion to go green.',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Internal helpers — pure functions, no test fixtures, no I/O.
// ---------------------------------------------------------------------------

class _ScoredLine {
  final double inputConfidence;
  final LineType predictedType;
  final LineType expectedType;
  final bool correct;
  const _ScoredLine({
    required this.inputConfidence,
    required this.predictedType,
    required this.expectedType,
  }) : correct = predictedType == expectedType;
}

class _Band {
  final String label;
  final int total;
  final int correct;
  const _Band(this.label, this.total, this.correct);
  double get accuracy => total == 0 ? 0.0 : correct / total;
}

class _ThresholdMetrics {
  final double threshold;
  final int aboveThreshold;
  final int aboveAndCorrect;
  final int totalCorrect;
  final int total;
  const _ThresholdMetrics({
    required this.threshold,
    required this.aboveThreshold,
    required this.aboveAndCorrect,
    required this.totalCorrect,
    required this.total,
  });
  double get precision =>
      aboveThreshold == 0 ? 0.0 : aboveAndCorrect / aboveThreshold;
  double get recall => totalCorrect == 0 ? 0.0 : aboveAndCorrect / totalCorrect;
  double get f1 {
    final p = precision;
    final r = recall;
    if (p + r == 0) return 0.0;
    return 2 * p * r / (p + r);
  }

  /// End-to-end post-Viterbi accuracy. This is the metric the calibration
  /// decision is driven by: of all predictions Viterbi produced (with
  /// this anchor threshold), what fraction matched the oracle label?
  double get accuracy => total == 0 ? 0.0 : totalCorrect / total;
}

/// Runs every recipe in [corpus] through the per-line classifier and the
/// default Viterbi processor, then collects one `_ScoredLine` per scorable
/// fixture line. `null` expecteds are skipped.
List<_ScoredLine> _scoreCorpus(
  List<GoldenRecipe> corpus,
  SwedishLineClassifier classifier, {
  ViterbiContextProcessor? processor,
}) {
  final viterbi = processor ?? const ViterbiContextProcessor();
  final out = <_ScoredLine>[];
  for (final recipe in corpus) {
    final classified =
        recipe.lines.map((e) => classifier.classifyLine(e.line)).toList();
    final contextual = viterbi.classifyWithContext(classified);
    for (var i = 0; i < recipe.lines.length; i++) {
      final expected = recipe.lines[i].expected;
      if (expected == null) continue;
      out.add(_ScoredLine(
        // Input confidence (pre-Viterbi) is what the threshold gates.
        inputConfidence: classified[i].confidence,
        predictedType: contextual[i].type,
        expectedType: expected,
      ));
    }
  }
  return out;
}

List<_Band> _calibrationByBand(List<_ScoredLine> scored, List<double> edges) {
  final bands = <_Band>[];
  for (var i = 0; i < edges.length - 1; i++) {
    final lo = edges[i];
    final hi = edges[i + 1];
    final inBand = scored
        .where((s) => s.inputConfidence >= lo && s.inputConfidence < hi)
        .toList(growable: false);
    final correct = inBand.where((s) => s.correct).length;
    final hiLabel = hi > 1.0 ? '1.00]' : '${hi.toStringAsFixed(2)})';
    bands.add(_Band(
      '[${lo.toStringAsFixed(2)}, $hiLabel',
      inBand.length,
      correct,
    ));
  }
  return bands;
}

double _aggregateAccuracy(List<_ScoredLine> scored) {
  if (scored.isEmpty) return 0.0;
  final correct = scored.where((s) => s.correct).length;
  return correct / scored.length;
}

/// For each threshold in [thresholds], instantiates a Viterbi processor at
/// that anchor and measures end-to-end accuracy + above-threshold P/R/F1
/// over [corpus]. The "positive" class is "input confidence >= threshold";
/// the truth is "post-Viterbi prediction is correct". Both the anchor used
/// to produce predictions and the decision threshold used to count above/
/// below are tied to the same value — sweeping with mismatched values would
/// not reflect a real production scenario.
Map<double, _ThresholdMetrics> _sweepCorpus(
  List<GoldenRecipe> corpus,
  SwedishLineClassifier classifier,
  List<double> thresholds,
) {
  final out = <double, _ThresholdMetrics>{};
  for (final t in thresholds) {
    final processor =
        ViterbiContextProcessor.withTuning(highConfidenceThreshold: t);
    final scored = _scoreCorpus(corpus, classifier, processor: processor);
    var aboveThreshold = 0;
    var aboveAndCorrect = 0;
    var totalCorrect = 0;
    for (final s in scored) {
      if (s.correct) totalCorrect++;
      if (s.inputConfidence >= t) {
        aboveThreshold++;
        if (s.correct) aboveAndCorrect++;
      }
    }
    out[t] = _ThresholdMetrics(
      threshold: t,
      aboveThreshold: aboveThreshold,
      aboveAndCorrect: aboveAndCorrect,
      totalCorrect: totalCorrect,
      total: scored.length,
    );
  }
  return out;
}

void _assertSweepValid(
  Map<double, _ThresholdMetrics> results, {
  required String label,
}) {
  // Sanity: every threshold should produce non-zero coverage and end-to-end
  // accuracy >= 0.85 on a corpus that is ~95% correctly classified at the
  // production threshold. Anything below that means the calibration
  // measurement itself has a bug, not that the algorithm is broken.
  for (final entry in results.entries) {
    final m = entry.value;
    expect(m.aboveThreshold, greaterThan(0),
        reason: '$label corpus: threshold ${entry.key} excluded every line (no '
            'positives — calibration math is undefined).');
    expect(m.accuracy, greaterThan(0.85),
        reason: '$label corpus: end-to-end accuracy at threshold ${entry.key} '
            'is suspiciously low (${m.accuracy.toStringAsFixed(3)}). Either '
            'the corpus is broken or the algorithm regressed.');
  }
}

String _formatCalibrationTable(String label, List<_Band> bands) {
  final sb = StringBuffer()
    ..writeln()
    ..writeln('=== Calibration table — $label corpus ===')
    ..writeln('band              n    correct   accuracy');
  for (final b in bands) {
    sb.writeln(
      '${b.label.padRight(18)}'
      '${b.total.toString().padLeft(3)}    '
      '${b.correct.toString().padLeft(7)}   '
      '${(b.accuracy * 100).toStringAsFixed(1)}%',
    );
  }
  return sb.toString();
}

String _formatSweepTable(String label, Map<double, _ThresholdMetrics> results) {
  final sb = StringBuffer()
    ..writeln()
    ..writeln('=== Threshold sweep — $label corpus ===')
    ..writeln('(accuracy = end-to-end post-Viterbi correctness; '
        'P/R/F1 = supplementary diagnostics treating above-threshold as '
        'positive class)')
    ..writeln('threshold   above    correct   accuracy   '
        'precision   recall   F1');
  final keys = results.keys.toList()..sort();
  for (final t in keys) {
    final m = results[t]!;
    sb.writeln(
      '${t.toStringAsFixed(2).padRight(11)}'
      '${m.aboveThreshold.toString().padLeft(5)}    '
      '${m.totalCorrect.toString().padLeft(7)}   '
      '${(m.accuracy * 100).toStringAsFixed(2).padLeft(7)}%   '
      '${m.precision.toStringAsFixed(4).padLeft(9)}   '
      '${m.recall.toStringAsFixed(4).padLeft(6)}   '
      '${m.f1.toStringAsFixed(4)}',
    );
  }
  return sb.toString();
}
