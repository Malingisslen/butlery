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

    test('range token detected as digit and range', () {
      final features = extractor.extractAt(['1-2', 'msk', 'socker'], 0);
      expect(features['word.isDigit'], 1.0);
      expect(features['word.isRange'], 1.0);
    });

    test('comma token has hasComma feature', () {
      final features = extractor.extractAt(['salt,'], 0);
      expect(features['word.hasComma'], 1.0);
    });

    test('conjunction has isConjunction feature', () {
      final features = extractor.extractAt(['smör', 'eller', 'olja'], 1);
      expect(features['word.isConjunction'], 1.0);
    });

    test('optional marker has isOptional feature', () {
      final features = extractor.extractAt(['ev.', '1', 'krm', 'salt'], 0);
      expect(features['word.isOptional'], 1.0);
    });

    test('ca is optional marker', () {
      final features = extractor.extractAt(['ca', '2', 'dl'], 0);
      expect(features['word.isOptional'], 1.0);
    });

    test('group header has isGroupHeader feature', () {
      final features = extractor.extractAt(['Fyllning:'], 0);
      expect(features['word.isGroupHeader'], 1.0);
    });

    test('paren has isParen feature', () {
      final features = extractor.extractAt(['(', 'kall', ')'], 0);
      expect(features['word.isParen'], 1.0);
    });

    test('includes prev2 features for window-2 context', () {
      final features = extractor.extractAt(['2', 'dl', 'hackad', 'lök'], 2);
      expect(features['prev2.word.isDigit'], 1.0);
      expect(features['prev2.word.isUnit'], 0.0);
    });

    test('includes next2 features for window-2 context', () {
      final features = extractor.extractAt(['2', 'dl', 'hackad', 'lök'], 1);
      expect(features['next2.word.isFood'], 1.0);
    });

    test('no prev2 for second token', () {
      final features = extractor.extractAt(['2', 'dl', 'mjölk'], 1);
      expect(features.containsKey('prev2.word.isDigit'), false);
    });

    test('no next2 for second-to-last token', () {
      final features = extractor.extractAt(['2', 'dl', 'mjölk'], 1);
      expect(features.containsKey('next2.word.isFood'), false);
    });

    test('prev2 reduced features do not include word.lower', () {
      final features = extractor.extractAt(['ca', '2', 'dl', 'mjölk'], 2);
      expect(features.containsKey('prev2.word.isDigit'), true);
      expect(features.containsKey('prev2.word.lower=ca'), false);
    });

    test('compound word has isCompound feature', () {
      // rabarbersylt is NOT in Firebase, but rabarber IS known → splittable
      final features = extractor.extractAt(['1', 'burk', 'rabarbersylt'], 2);
      expect(features['word.isCompound'], 1.0);
      expect(features['word.compoundSuffix=sylt'], 1.0);
    });

    test('non-compound word has isCompound=0', () {
      final features = extractor.extractAt(['2', 'dl', 'mjölk'], 2);
      expect(features['word.isCompound'], 0.0);
      expect(
        features.keys.where((k) => k.startsWith('word.compoundSuffix=')),
        isEmpty,
      );
    });

    test('known compound name does not trigger isCompound', () {
      // vitpeppar is in KnownIngredients.compoundNames — should NOT split
      final features = extractor.extractAt(['1', 'krm', 'vitpeppar'], 2);
      expect(features['word.isCompound'], 0.0);
    });

    test('bigram features include prev-cur and cur-next word pairs', () {
      final features = extractor.extractAt(['2', 'dl', 'mjölk'], 1);
      expect(features['bigram.prev=2|cur=dl'], 1.0);
      expect(features['bigram.cur=dl|next=mjölk'], 1.0);
    });

    test('bigram features absent at boundaries', () {
      final tokens = ['2', 'dl', 'mjölk'];
      final first = extractor.extractAt(tokens, 0);
      expect(first.containsKey('bigram.prev='), false);
      expect(first['bigram.cur=2|next=dl'], 1.0);

      final last = extractor.extractAt(tokens, 2);
      expect(last['bigram.prev=dl|cur=mjölk'], 1.0);
      expect(last.keys.where((k) => k.startsWith('bigram.cur=mjölk|next=')),
          isEmpty);
    });

    test('type-level bigram features use coarse token types', () {
      // "2 dl mjölk" -> NUM UNIT FOOD
      final features = extractor.extractAt(['2', 'dl', 'mjölk'], 1);
      expect(features['typeBigram.prev=NUM|cur=UNIT'], 1.0);
      expect(features['typeBigram.cur=UNIT|next=FOOD'], 1.0);
    });

    test('type-level bigram for prep token', () {
      // "hackad lök" -> PREP FOOD
      final features = extractor.extractAt(['hackad', 'lök'], 0);
      expect(features['typeBigram.cur=PREP|next=FOOD'], 1.0);
    });

    test('enrichedIngredients supplements static food detection', () {
      // "zaatar" is not in static KnownIngredients
      final plain = CrfFeatureExtractor();
      final plainFeatures = plain.extractAt(['1', 'msk', 'zaatar'], 2);
      expect(plainFeatures['word.isFood'], 0.0);

      // With enriched set, zaatar is recognized
      final enriched = CrfFeatureExtractor(
        enrichedIngredients: {'zaatar', 'harissa'},
      );
      final enrichedFeatures = enriched.extractAt(['1', 'msk', 'zaatar'], 2);
      expect(enrichedFeatures['word.isFood'], 1.0);
    });

    test('enrichedIngredients affects type bigrams', () {
      // With enriched set, "zaatar" becomes FOOD type
      final enriched = CrfFeatureExtractor(
        enrichedIngredients: {'zaatar'},
      );
      final features = enriched.extractAt(['1', 'msk', 'zaatar'], 1);
      expect(features['typeBigram.cur=UNIT|next=FOOD'], 1.0);
    });

    test('definite form detected with isDefinite feature', () {
      // "tomaterna" is definite plural of "tomat" and NOT in static set
      final features = extractor.extractAt(['tomaterna'], 0);
      expect(features['word.isDefinite'], 1.0);
      expect(features['word.baseForm=tomat'], 1.0);
    });

    test('non-definite word has isDefinite=0', () {
      final features = extractor.extractAt(['salt'], 0);
      expect(features['word.isDefinite'], 0.0);
      expect(
        features.keys.where((k) => k.startsWith('word.baseForm=')),
        isEmpty,
      );
    });
  });
}
