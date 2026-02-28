import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/parsing/crf/crf_feature_extractor.dart';

void main() {
  late CrfFeatureExtractor extractor;

  setUp(() {
    extractor = CrfFeatureExtractor();
  });

  group('CrfFeatureExtractor', () {
    test('digit token has isDigit feature', () {
      final features = extractor.extractAt(['2', 'dl', 'mjölk'], 0);
      expect(features['word.isDigit'], 1.0);
      expect(features['word.isFraction'], 0.0);
      expect(features['word.isUnit'], 0.0);
    });

    test('fraction token has isFraction feature', () {
      final features = extractor.extractAt(['½', 'dl', 'mjölk'], 0);
      expect(features['word.isFraction'], 1.0);
    });

    test('unit token has isUnit feature', () {
      final features = extractor.extractAt(['2', 'dl', 'mjölk'], 1);
      expect(features['word.isUnit'], 1.0);
      expect(features['word.isDigit'], 0.0);
    });

    test('food token has isFood feature', () {
      final features = extractor.extractAt(['2', 'dl', 'mjölk'], 2);
      expect(features['word.isFood'], 1.0);
    });

    test('preparation token has isPrep feature', () {
      final features = extractor.extractAt(['hackad', 'lök'], 0);
      expect(features['word.isPrep'], 1.0);
    });

    test('size token has isSize feature', () {
      final features = extractor.extractAt(['stor', 'lök'], 0);
      expect(features['word.isSize'], 1.0);
    });

    test('first token has BOS marker', () {
      final features = extractor.extractAt(['2', 'dl', 'mjölk'], 0);
      expect(features['BOS'], 1.0);
      expect(features.containsKey('EOS'), false);
    });

    test('last token has EOS marker', () {
      final features = extractor.extractAt(['2', 'dl', 'mjölk'], 2);
      expect(features['EOS'], 1.0);
      expect(features.containsKey('BOS'), false);
    });

    test('middle token has neither BOS nor EOS', () {
      final features = extractor.extractAt(['2', 'dl', 'mjölk'], 1);
      expect(features.containsKey('BOS'), false);
      expect(features.containsKey('EOS'), false);
    });

    test('includes previous token features', () {
      final features = extractor.extractAt(['2', 'dl', 'mjölk'], 1);
      expect(features['prev.word.isDigit'], 1.0);
      expect(features['prev.word.lower=2'], 1.0);
    });

    test('includes next token features', () {
      final features = extractor.extractAt(['2', 'dl', 'mjölk'], 1);
      expect(features['next.word.isFood'], 1.0);
      expect(features['next.word.lower=mjölk'], 1.0);
    });

    test('suffix features extracted', () {
      final features = extractor.extractAt(['hackad'], 0);
      expect(features['word.suffix2=ad'], 1.0);
      expect(features['word.suffix3=kad'], 1.0);
    });

    test('extractAll returns features for all tokens', () {
      final all = extractor.extractAll(['2', 'dl', 'mjölk']);
      expect(all.length, 3);
      expect(all[0]['word.isDigit'], 1.0);
      expect(all[1]['word.isUnit'], 1.0);
      expect(all[2]['word.isFood'], 1.0);
    });

    test('range token detected as digit', () {
      final features = extractor.extractAt(['1-2', 'msk', 'socker'], 0);
      expect(features['word.isDigit'], 1.0);
    });

    test('comma token has hasComma feature', () {
      final features = extractor.extractAt(['salt,'], 0);
      expect(features['word.hasComma'], 1.0);
    });
  });
}
