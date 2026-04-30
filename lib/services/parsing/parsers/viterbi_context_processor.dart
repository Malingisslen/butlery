import 'dart:math' as math;

import 'package:butlery/services/parsing/parsers/swedish_line_classifier.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Re-labels classified lines using Viterbi decoding over a transition
/// probability matrix. The per-line classifier is context-free; this
/// post-processor exploits sequential structure (ingredient runs, instruction
/// runs) to fix ambiguous lines that context makes obvious.
class ViterbiContextProcessor {
  final double highConfidenceThreshold;
  final double highEmissionWeight;
  final double lowEmissionWeight;

  const ViterbiContextProcessor()
      : highConfidenceThreshold = _defaultHighConfidenceThreshold,
        highEmissionWeight = _defaultHighEmissionWeight,
        lowEmissionWeight = _defaultLowEmissionWeight;

  /// Test-only escape hatch for calibration sweeps. See
  /// `test/unit/services/parsing/parsers/viterbi_calibration_test.dart`.
  @visibleForTesting
  const ViterbiContextProcessor.withTuning({
    this.highConfidenceThreshold = _defaultHighConfidenceThreshold,
    this.highEmissionWeight = _defaultHighEmissionWeight,
    this.lowEmissionWeight = _defaultLowEmissionWeight,
  });

  // Transition probabilities P(state_t | state_{t-1}).
  // Tuned for Swedish recipe text where ingredients and instructions
  // appear in long contiguous runs separated by headers.
  static const _transitions = {
    LineType.ingredient: {
      LineType.ingredient: 0.80,
      LineType.instruction: 0.05,
      LineType.sectionHeader: 0.05,
      LineType.empty: 0.05,
      LineType.noise: 0.03,
      LineType.metadata: 0.01,
      LineType.title: 0.01,
    },
    LineType.instruction: {
      LineType.instruction: 0.75,
      LineType.ingredient: 0.03,
      LineType.sectionHeader: 0.05,
      LineType.empty: 0.05,
      LineType.noise: 0.05,
      LineType.metadata: 0.05,
      LineType.title: 0.02,
    },
    LineType.sectionHeader: {
      LineType.ingredient: 0.45,
      LineType.instruction: 0.40,
      LineType.empty: 0.05,
      LineType.noise: 0.05,
      LineType.metadata: 0.03,
      LineType.sectionHeader: 0.01,
      LineType.title: 0.01,
    },
    LineType.title: {
      LineType.ingredient: 0.25,
      LineType.instruction: 0.15,
      LineType.metadata: 0.25,
      LineType.sectionHeader: 0.15,
      LineType.empty: 0.10,
      LineType.noise: 0.05,
      LineType.title: 0.05,
    },
    LineType.metadata: {
      LineType.ingredient: 0.30,
      LineType.instruction: 0.20,
      LineType.sectionHeader: 0.20,
      LineType.empty: 0.10,
      LineType.metadata: 0.10,
      LineType.noise: 0.05,
      LineType.title: 0.05,
    },
    LineType.empty: {
      LineType.ingredient: 0.25,
      LineType.instruction: 0.25,
      LineType.sectionHeader: 0.20,
      LineType.noise: 0.10,
      LineType.empty: 0.10,
      LineType.metadata: 0.05,
      LineType.title: 0.05,
    },
    LineType.noise: {
      LineType.ingredient: 0.25,
      LineType.instruction: 0.25,
      LineType.noise: 0.20,
      LineType.empty: 0.10,
      LineType.sectionHeader: 0.10,
      LineType.metadata: 0.05,
      LineType.title: 0.05,
    },
  };

  /// Section header patterns duplicated here to detect header type without
  /// coupling to the classifier's private fields.
  static final _ingredientHeaderPatterns = [
    RegExp(r'ingrediens(er)?', caseSensitive: false),
    RegExp(r'du behöver', caseSensitive: false),
    RegExp(r'detta behövs', caseSensitive: false),
    RegExp(r'det här behöver du', caseSensitive: false),
  ];

  static final _instructionHeaderPatterns = [
    RegExp(r'gör\s+så\s+här|så\s+gör\s+du', caseSensitive: false),
    RegExp(r'instruktion(er)?', caseSensitive: false),
    RegExp(r'tillagnin(g|gssätt)', caseSensitive: false),
    RegExp(r'framställning', caseSensitive: false),
    RegExp(r'steg:', caseSensitive: false),
    RegExp(r'metod:', caseSensitive: false),
  ];

  // Confidence-adaptive emission weight: high-confidence lines (>= threshold)
  // get amplified emissions so transitions cannot override them, while
  // low-confidence / ambiguous lines use standard weighting so context
  // can pull them toward their neighbors.
  //
  // Threshold = 0.75 is the empirically-validated calibration point; see
  // `test/unit/services/parsing/parsers/viterbi_calibration_test.dart` for
  // the F1-by-threshold sweep on the 10-recipe golden corpus + 4-recipe
  // held-out corpus. Held-out F1 is maximized at this threshold within the
  // 2pp noise floor.
  static const _defaultHighConfidenceThreshold = 0.75;
  static const _defaultHighEmissionWeight = 2.5;
  static const _defaultLowEmissionWeight = 1.0;

  /// Re-labels [lines] using the Viterbi algorithm, combining per-line
  /// emission probabilities with sequential transition probabilities.
  ///
  /// High-confidence lines (>= 0.75) are effectively anchored: the emission
  /// signal dominates the transition prior. Low-confidence / ambiguous lines
  /// get pulled toward the surrounding context.
  List<ClassifiedLine> classifyWithContext(List<ClassifiedLine> lines) {
    if (lines.length <= 1) return lines;

    final n = lines.length;
    const states = LineType.values;
    final numStates = states.length;

    // Build section-header boost map: for each line index, the emission
    // multiplier applied on top of the base emission probability.
    final boosts = _computeSectionBoosts(lines);

    // Forward pass: viterbi[t][s] = max log-probability of any path
    // ending in state s at time t.
    final viterbi = List.generate(n, (_) => List.filled(numStates, _negInf));
    final backpointer = List.generate(n, (_) => List.filled(numStates, 0));

    // Initialization (t = 0): uniform prior, emission only
    for (var s = 0; s < numStates; s++) {
      final weight = _emissionWeightFor(lines[0]);
      final emission = _emissionLogProb(lines[0], states[s], boosts[0]);
      viterbi[0][s] = emission * weight;
    }

    // Recursion
    for (var t = 1; t < n; t++) {
      for (var s = 0; s < numStates; s++) {
        var bestLogProb = _negInf;
        var bestPrev = 0;

        for (var p = 0; p < numStates; p++) {
          final trans = _transitionLogProb(states[p], states[s]);
          final candidate = viterbi[t - 1][p] + trans;
          if (candidate > bestLogProb) {
            bestLogProb = candidate;
            bestPrev = p;
          }
        }

        final weight = _emissionWeightFor(lines[t]);
        final emission = _emissionLogProb(lines[t], states[s], boosts[t]);
        viterbi[t][s] = bestLogProb + emission * weight;
        backpointer[t][s] = bestPrev;
      }
    }

    // Find best final state
    var bestFinalState = 0;
    var bestFinalProb = _negInf;
    for (var s = 0; s < numStates; s++) {
      if (viterbi[n - 1][s] > bestFinalProb) {
        bestFinalProb = viterbi[n - 1][s];
        bestFinalState = s;
      }
    }

    // Backtrack
    final optimalPath = List.filled(n, 0);
    optimalPath[n - 1] = bestFinalState;
    for (var t = n - 2; t >= 0; t--) {
      optimalPath[t] = backpointer[t + 1][optimalPath[t + 1]];
    }

    // Build result with updated types and confidences
    final result = <ClassifiedLine>[];
    for (var t = 0; t < n; t++) {
      final newType = states[optimalPath[t]];
      final original = lines[t];

      if (newType == original.type) {
        result.add(original);
      } else {
        // Viterbi overrode the per-line classifier: compute a blended
        // confidence reflecting both the emission and the context.
        final emissionForNew = _rawEmissionProb(original, newType, boosts[t]);
        final contextConfidence = emissionForNew.clamp(0.3, 0.95);
        result.add(ClassifiedLine(
          text: original.text,
          type: newType,
          confidence: contextConfidence,
          secondaryType: original.type,
        ));
      }
    }

    return result;
  }

  // Compute per-line emission boosts from section headers.
  // After an ingredient header: boost ingredient emission for next 15 lines.
  // After an instruction header: boost instruction emission for next 20 lines.
  Map<int, Map<LineType, double>> _computeSectionBoosts(
    List<ClassifiedLine> lines,
  ) {
    final boosts = <int, Map<LineType, double>>{};
    LineType? activeBoostType;
    int boostRemaining = 0;

    for (var i = 0; i < lines.length; i++) {
      if (lines[i].type == LineType.sectionHeader) {
        final headerText = lines[i].text.toLowerCase();
        if (_ingredientHeaderPatterns.any((p) => p.hasMatch(headerText))) {
          activeBoostType = LineType.ingredient;
          boostRemaining = 15;
        } else if (_instructionHeaderPatterns
            .any((p) => p.hasMatch(headerText))) {
          activeBoostType = LineType.instruction;
          boostRemaining = 20;
        }
        continue;
      }

      if (activeBoostType != null && boostRemaining > 0) {
        boosts[i] = {activeBoostType: 2.0};
        boostRemaining--;
      }
    }

    return boosts;
  }

  // Log-space emission probability for a candidate state given the
  // per-line classifier output and any section-header boost.
  double _emissionLogProb(
    ClassifiedLine line,
    LineType candidateState,
    Map<LineType, double>? boost,
  ) {
    final prob = _rawEmissionProb(line, candidateState, boost);
    if (prob <= 0) return _negInf;
    return math.log(prob);
  }

  // Raw (linear) emission probability before log transform.
  double _rawEmissionProb(
    ClassifiedLine line,
    LineType candidateState,
    Map<LineType, double>? boost,
  ) {
    final numStates = LineType.values.length;
    double prob;

    if (candidateState == line.type) {
      prob = line.confidence;
    } else if (candidateState == line.secondaryType) {
      prob = line.confidence * 0.5;
    } else {
      // Spread remaining probability uniformly across other states.
      // The primary type holds `confidence` and the secondary (if any) holds
      // `confidence * 0.5`, so the leftover is divided among the rest.
      final primaryMass = line.confidence;
      final secondaryMass =
          line.secondaryType != null ? line.confidence * 0.5 : 0.0;
      final remainingMass = (1.0 - primaryMass - secondaryMass).clamp(0.0, 1.0);
      final otherCount = numStates - 1 - (line.secondaryType != null ? 1 : 0);
      prob = otherCount > 0 ? remainingMass / otherCount : 0.01;
    }

    // Apply section-header boost
    if (boost != null && boost.containsKey(candidateState)) {
      prob *= boost[candidateState]!;
    }

    return prob.clamp(0.001, 1.0);
  }

  // High-confidence lines resist context override; low-confidence lines
  // are easily pulled by surrounding context.
  double _emissionWeightFor(ClassifiedLine line) {
    return line.confidence >= highConfidenceThreshold
        ? highEmissionWeight
        : lowEmissionWeight;
  }

  double _transitionLogProb(LineType from, LineType to) {
    final row = _transitions[from];
    if (row == null) return _negInf;
    final prob = row[to] ?? 0.001;
    return math.log(prob);
  }

  static const _negInf = -1e9;
}
