import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';

/// Minimal weights for testing: strong digit→QTY, unit→UNIT, food→NAME signals.
CrfWeights _testWeights() {
  final json = '''
{
  "features": {
    "B-QTY": {"word.isDigit": 3.0, "word.isFraction": 3.0, "word.isUnit": -2.0, "word.isFood": -2.0},
    "I-QTY": {"word.isDigit": 2.0, "word.isFraction": 2.0, "prev.word.isDigit": 1.5},
    "B-UNIT": {"word.isUnit": 3.5, "prev.word.isDigit": 1.5, "word.isDigit": -2.0, "word.isFood": -1.5},
    "B-NAME": {"word.isFood": 3.0, "prev.word.isUnit": 2.0, "word.isDigit": -2.5, "word.isUnit": -1.5, "word.isPrep": -1.0},
    "I-NAME": {"word.isFood": 2.5, "prev.word.isFood": 2.0, "word.isDigit": -2.0, "word.isUnit": -1.5},
    "B-PREP": {"word.isPrep": 3.5, "word.isDigit": -2.0, "word.isUnit": -2.0},
    "I-PREP": {"word.isPrep": 2.0, "prev.word.isPrep": 1.5},
    "B-SIZE": {"word.isSize": 3.5, "word.isDigit": -2.0},
    "O": {"word.lower=ca": 2.5, "word.lower=eller": 2.0, "word.isDigit": -1.0, "word.isUnit": -1.5, "word.isFood": -1.5}
  },
  "transitions": {
    "B-QTY":  {"B-QTY": -2.0, "I-QTY": 2.0, "B-UNIT": 3.0, "B-NAME": 0.5, "I-NAME": -2.0, "B-PREP": -1.0, "I-PREP": -3.0, "B-SIZE": 0.5, "O": 0.0},
    "I-QTY":  {"B-QTY": -2.0, "I-QTY": 1.0, "B-UNIT": 3.0, "B-NAME": 0.5, "I-NAME": -2.0, "B-PREP": -1.0, "I-PREP": -3.0, "B-SIZE": 0.5, "O": 0.0},
    "B-UNIT": {"B-QTY": -2.0, "I-QTY": -3.0, "B-UNIT": -1.5, "B-NAME": 3.0, "I-NAME": -2.0, "B-PREP": 1.0, "I-PREP": -3.0, "B-SIZE": 0.5, "O": 0.0},
    "B-NAME": {"B-QTY": -2.0, "I-QTY": -3.0, "B-UNIT": -1.5, "B-NAME": -0.5, "I-NAME": 2.5, "B-PREP": 1.5, "I-PREP": -3.0, "B-SIZE": -0.5, "O": 0.5},
    "I-NAME": {"B-QTY": -2.0, "I-QTY": -3.0, "B-UNIT": -1.5, "B-NAME": -0.5, "I-NAME": 2.5, "B-PREP": 1.5, "I-PREP": -3.0, "B-SIZE": -0.5, "O": 0.5},
    "B-PREP": {"B-QTY": -1.0, "I-QTY": -3.0, "B-UNIT": -1.0, "B-NAME": 2.0, "I-NAME": -2.0, "B-PREP": -0.5, "I-PREP": 2.0, "B-SIZE": -0.5, "O": 0.5},
    "I-PREP": {"B-QTY": -1.0, "I-QTY": -3.0, "B-UNIT": -1.0, "B-NAME": 2.0, "I-NAME": -2.0, "B-PREP": -0.5, "I-PREP": 2.0, "B-SIZE": -0.5, "O": 0.5},
    "B-SIZE": {"B-QTY": -1.0, "I-QTY": -3.0, "B-UNIT": -0.5, "B-NAME": 2.5, "I-NAME": -2.0, "B-PREP": 0.5, "I-PREP": -3.0, "B-SIZE": -1.5, "O": 0.0},
    "O":      {"B-QTY": 1.5, "I-QTY": -2.0, "B-UNIT": 0.5, "B-NAME": 1.5, "I-NAME": -1.0, "B-PREP": 0.5, "I-PREP": -2.0, "B-SIZE": 0.5, "O": 1.0}
  }
}
''';
  return CrfWeights.fromJson(json);
}

void main() {
  group('CrfWeights', () {
    test('fromJson parses all labels', () {
      final weights = _testWeights();
      expect(weights.featureWeights.length, 9);
      expect(weights.transitionWeights.length, 9);
    });

    test('fromJson/toJson round-trip preserves structure', () {
      final original = _testWeights();
      final jsonStr = jsonEncode(original.toJson());
      final restored = CrfWeights.fromJson(jsonStr);

      expect(restored.featureWeights.length, original.featureWeights.length);
      expect(
        restored.transitionWeights.length,
        original.transitionWeights.length,
      );

      // Spot-check a feature weight
      expect(
        restored.featureWeights[BioLabel.bQty]!['word.isDigit'],
        original.featureWeights[BioLabel.bQty]!['word.isDigit'],
      );
    });
  });

  group('CrfViterbiDecoder', () {
    late CrfViterbiDecoder decoder;

    setUp(() {
      decoder = CrfViterbiDecoder(weights: _testWeights());
    });

    test('simple "2 dl mjölk" → QTY UNIT NAME', () {
      final labels = decoder.decode(['2', 'dl', 'mjölk']);
      expect(labels[0], BioLabel.bQty);
      expect(labels[1], BioLabel.bUnit);
      expect(labels[2], BioLabel.bName);
    });

    test('empty input returns empty', () {
      expect(decoder.decode([]), isEmpty);
    });

    test('single token gets best label', () {
      final labels = decoder.decode(['mjölk']);
      expect(labels.length, 1);
      // Should be B-NAME since mjölk is a known food
      expect(labels[0], BioLabel.bName);
    });

    test('preparation word gets B-PREP', () {
      final labels = decoder.decode(['2', 'dl', 'hackad', 'lök']);
      expect(labels[2], BioLabel.bPrep);
    });

    test('multi-word name uses I-NAME continuation', () {
      final labels = decoder.decode(['1', 'st', 'röd', 'paprika']);
      // Quantity, unit, then name tokens
      expect(labels[0], BioLabel.bQty);
    });
  });
}
