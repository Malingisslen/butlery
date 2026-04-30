# Viterbi confidence calibration baseline

Recorded 2026-04-30 (BUT-611). Companion to
`viterbi_calibration_test.dart`. The numbers below are what the test
prints on a clean run against the 10-recipe golden corpus
(`viterbi_context_processor_fixtures.dart`) and the 4-recipe held-out
corpus (`viterbi_calibration_fixtures.dart`). If they drift more than
~1pp on re-run, investigate before updating this file.

The assertions in the test are intentionally loose so the test acts as
a guard rail (catches material drift, monotonicity violations,
overfitting), not a brittle snapshot.

## Calibration table - Golden corpus (110 scorable lines)

```
band              n    correct   accuracy
[0.00, 0.60)      1          1   100.0%
[0.60, 0.70)     23         23   100.0%
[0.70, 0.75)     18         18   100.0%
[0.75, 0.80)      1          1   100.0%
[0.80, 0.90)     15         13    86.7%   <-- non-monotone band
[0.90, 1.00]     52         52   100.0%
```

## Calibration table - Held-out corpus (59 scorable lines)

```
band              n    correct   accuracy
[0.00, 0.60)      4          3    75.0%
[0.60, 0.70)     10          8    80.0%
[0.70, 0.75)      7          7   100.0%
[0.75, 0.80)      0          0      n/a
[0.80, 0.90)     12         12   100.0%
[0.90, 1.00]     26         26   100.0%
```

## Aggregate accuracy

- Golden:   98.18% (108/110 correct at default threshold)
- Held-out: 94.92% (56/59 correct at default threshold)
- Spread:   3.26pp - well inside the 5pp overfitting flag.

## Threshold sweep - end-to-end post-Viterbi accuracy

```
threshold   Golden acc   Held-out acc
0.60        90.91%       93.22%      <-- anchoring effectively off
0.70        98.18%       94.92%
0.75        98.18%       94.92%      <-- production default
0.80        98.18%       94.92%
0.90        98.18%       94.92%      <-- anchoring fully off
```

P/R/F1 supplementary diagnostics (treating "above-threshold" as the
positive class) are printed by the test but should not drive the
decision: this F1 framing is structurally biased toward low thresholds
because virtually every line is correctly classified, so widening the
"positive" set mechanically inflates recall regardless of whether
anchoring helped.

## Decision

**0.75 stands.** End-to-end accuracy is flat across thresholds
0.70-0.90 on both corpora. Only 0.60 changes outcomes (drops accuracy by
~7pp on golden, ~2pp on held-out): at 0.60 too many lines are anchored
and transitions can no longer pull genuinely-ambiguous lines to context.

The plateau on the upper side reflects that the per-line classifier
emits very few confidences in the [0.75, 0.90) range (1 line on golden,
0 on held-out), so nudging the threshold inside that gap does not change
which lines get anchored. We could move the threshold anywhere in
[0.70, 0.90] without changing behaviour - but moving without a measured
accuracy gain is churn, and 0.75 leaves more headroom above the per-line
classifier's most common output band ([0.60, 0.70)), so future
classifier changes that bump confidences up slightly will not
accidentally cross the threshold.

## Calibration finding (small-corpus artifact)

The golden [0.80, 0.90) band shows 86.7% accuracy where neighbouring
bands are 100%. Inspecting the 2 misclassifications: bare food-word
lines (e.g. "salt", "peppar") that the per-line classifier rates around
0.85 but Viterbi's section-header boost should pull to ingredient.
n=15 makes the Wilson 95% CI on this band wide enough that the dip is
within noise, and the held-out set's [0.80, 0.90) band is 12/12 = 100%,
which corroborates the noise interpretation.

No action. A future tuning pass on the section-header boost
(`_computeSectionBoosts` in `viterbi_context_processor.dart`) should
target this band.

## Honest residual

- **Confidence range is sparse.** The per-line classifier emits a
  small number of discrete confidence values (driven by its
  pattern-match scoring). The [0.75, 0.80) band has only 1 line on
  golden and 0 on held-out. Calibration measurements above the threshold
  are dominated by the [0.90, 1.00] band, so the test cannot
  distinguish between threshold values inside the sparse region.
- **Corpus is small.** 110+59 = 169 scorable lines is enough to detect
  multi-pp threshold differences but not finer-grained tuning. The
  noise floor for the decision rule is set at 2pp; a >2pp change must
  show up on BOTH corpora to count.
- **F1 framing is intentionally not the decision metric.** F1 with
  "above-threshold" as the positive class would have flagged 0.60 as the
  winner, but the gain is mechanical (recall inflates because almost
  every line is correct). End-to-end accuracy is the metric the
  threshold actually controls, and by that metric 0.60 is materially
  worse than 0.75 on golden.
