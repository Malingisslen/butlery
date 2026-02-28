import 'dart:convert';

import 'package:butlery/services/parsing/crf/crf_feature_extractor.dart';

/// BIO label schema for ingredient token classification.
enum BioLabel {
  bQty, // B-QTY: Beginning of quantity
  iQty, // I-QTY: Inside quantity (ranges, mixed numbers)
  bUnit, // B-UNIT: Unit token
  bName, // B-NAME: Beginning of ingredient name
  iName, // I-NAME: Inside ingredient name (multi-word)
  bPrep, // B-PREP: Beginning of preparation
  iPrep, // I-PREP: Inside preparation (multi-word)
  bSize, // B-SIZE: Size descriptor
  other, // O: Other (punctuation, "ca", "eller")
}

/// Learned CRF weights: feature weights + transition matrix.
class CrfWeights {
  /// Feature weights: label → (feature_name → weight).
  final Map<BioLabel, Map<String, double>> featureWeights;

  /// Transition weights: previous_label → current_label → weight.
  final Map<BioLabel, Map<BioLabel, double>> transitionWeights;

  const CrfWeights({
    required this.featureWeights,
    required this.transitionWeights,
  });

  factory CrfWeights.fromJson(String jsonString) {
    final data = json.decode(jsonString) as Map<String, dynamic>;

    final featureMap = <BioLabel, Map<String, double>>{};
    final features = data['features'] as Map<String, dynamic>;
    for (final entry in features.entries) {
      final label = _labelFromString(entry.key);
      final weights = (entry.value as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));
      featureMap[label] = weights;
    }

    final transMap = <BioLabel, Map<BioLabel, double>>{};
    final transitions = data['transitions'] as Map<String, dynamic>;
    for (final entry in transitions.entries) {
      final from = _labelFromString(entry.key);
      final toWeights = (entry.value as Map<String, dynamic>)
          .map((k, v) => MapEntry(_labelFromString(k), (v as num).toDouble()));
      transMap[from] = toWeights;
    }

    return CrfWeights(
      featureWeights: featureMap,
      transitionWeights: transMap,
    );
  }

  Map<String, dynamic> toJson() {
    final features = <String, dynamic>{};
    for (final entry in featureWeights.entries) {
      features[_labelToString(entry.key)] = entry.value;
    }

    final transitions = <String, dynamic>{};
    for (final entry in transitionWeights.entries) {
      final toMap = <String, dynamic>{};
      for (final inner in entry.value.entries) {
        toMap[_labelToString(inner.key)] = inner.value;
      }
      transitions[_labelToString(entry.key)] = toMap;
    }

    return {'features': features, 'transitions': transitions};
  }

  static BioLabel _labelFromString(String s) {
    switch (s) {
      case 'B-QTY':
        return BioLabel.bQty;
      case 'I-QTY':
        return BioLabel.iQty;
      case 'B-UNIT':
        return BioLabel.bUnit;
      case 'B-NAME':
        return BioLabel.bName;
      case 'I-NAME':
        return BioLabel.iName;
      case 'B-PREP':
        return BioLabel.bPrep;
      case 'I-PREP':
        return BioLabel.iPrep;
      case 'B-SIZE':
        return BioLabel.bSize;
      case 'O':
        return BioLabel.other;
      default:
        return BioLabel.other;
    }
  }

  static String _labelToString(BioLabel label) {
    switch (label) {
      case BioLabel.bQty:
        return 'B-QTY';
      case BioLabel.iQty:
        return 'I-QTY';
      case BioLabel.bUnit:
        return 'B-UNIT';
      case BioLabel.bName:
        return 'B-NAME';
      case BioLabel.iName:
        return 'I-NAME';
      case BioLabel.bPrep:
        return 'B-PREP';
      case BioLabel.iPrep:
        return 'I-PREP';
      case BioLabel.bSize:
        return 'B-SIZE';
      case BioLabel.other:
        return 'O';
    }
  }
}

/// Linear-chain CRF Viterbi decoder for BIO label sequences.
///
/// Uses learned feature weights and transition weights to find the
/// optimal label sequence for a tokenized ingredient line.
class CrfViterbiDecoder {
  static const _negInf = -1e10;

  final CrfWeights weights;
  final CrfFeatureExtractor _extractor;

  CrfViterbiDecoder({
    required this.weights,
    CrfFeatureExtractor? extractor,
  }) : _extractor = extractor ?? CrfFeatureExtractor();

  /// Decodes the optimal BIO label sequence for the given tokens.
  List<BioLabel> decode(List<String> tokens) {
    if (tokens.isEmpty) return [];

    final n = tokens.length;
    const labels = BioLabel.values;
    final numLabels = labels.length;

    // Extract features for all positions
    final allFeatures = _extractor.extractAll(tokens);

    // Viterbi tables
    final viterbi = List.generate(n, (_) => List.filled(numLabels, _negInf));
    final backpointer = List.generate(n, (_) => List.filled(numLabels, 0));

    // Initialize t=0
    for (var s = 0; s < numLabels; s++) {
      viterbi[0][s] = _emissionScore(labels[s], allFeatures[0]);
    }

    // Forward pass
    for (var t = 1; t < n; t++) {
      for (var s = 0; s < numLabels; s++) {
        final emission = _emissionScore(labels[s], allFeatures[t]);
        var bestScore = _negInf;
        var bestPrev = 0;

        for (var p = 0; p < numLabels; p++) {
          final score = viterbi[t - 1][p] +
              _transitionScore(labels[p], labels[s]) +
              emission;
          if (score > bestScore) {
            bestScore = score;
            bestPrev = p;
          }
        }

        viterbi[t][s] = bestScore;
        backpointer[t][s] = bestPrev;
      }
    }

    // Backtrack
    final path = List.filled(n, 0);
    var bestFinal = 0;
    var bestFinalScore = _negInf;
    for (var s = 0; s < numLabels; s++) {
      if (viterbi[n - 1][s] > bestFinalScore) {
        bestFinalScore = viterbi[n - 1][s];
        bestFinal = s;
      }
    }
    path[n - 1] = bestFinal;

    for (var t = n - 2; t >= 0; t--) {
      path[t] = backpointer[t + 1][path[t + 1]];
    }

    return path.map((i) => labels[i]).toList();
  }

  double _emissionScore(BioLabel label, Map<String, double> features) {
    final labelWeights = weights.featureWeights[label];
    if (labelWeights == null) return 0.0;

    var score = 0.0;
    for (final entry in features.entries) {
      final w = labelWeights[entry.key];
      if (w != null) {
        score += w * entry.value;
      }
    }
    return score;
  }

  double _transitionScore(BioLabel from, BioLabel to) {
    return weights.transitionWeights[from]?[to] ?? 0.0;
  }
}
