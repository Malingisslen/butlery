import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/utils/text/swedish_compound_splitter.dart';

void main() {
  group('SwedishCompoundSplitter', () {
    group('trySplit', () {
      test('splits ingredient+food suffix compounds', () {
        final result = SwedishCompoundSplitter.trySplit('lingonsylt');
        expect(result, isNotNull);
        expect(result!.$1, 'lingon');
        expect(result.$2, 'sylt');
      });

      test('does not split known compound names with joining s', () {
        // jordnötssmör is in KnownIngredients.compoundNames
        expect(SwedishCompoundSplitter.trySplit('jordnötssmör'), isNull);
      });

      test('splits unknown compound with joining s', () {
        // vitlöksolja: vitlök + s + olja (vitlök is known, olja is known)
        // but olivolja is in KnownIngredients.all so it won't split
        // try: pepparkvarn — peppar + kvarn
        final result = SwedishCompoundSplitter.trySplit('pepparkvarn');
        expect(result, isNotNull);
        expect(result!.$1, 'peppar');
        expect(result.$2, 'kvarn');
      });

      test('splits vitlökspress', () {
        final result = SwedishCompoundSplitter.trySplit('vitlökspress');
        expect(result, isNotNull);
        expect(result!.$1, 'vitlök');
        expect(result.$2, 'press');
      });

      test('splits kokosmjölk - but it is in compoundNames so returns null',
          () {
        // kokosmjölk is a known compound name, should not be split
        final result = SwedishCompoundSplitter.trySplit('kokosmjölk');
        expect(result, isNull);
      });

      test('splits citronjuice', () {
        final result = SwedishCompoundSplitter.trySplit('citronjuice');
        expect(result, isNotNull);
        expect(result!.$1, 'citron');
        expect(result.$2, 'juice');
      });

      test('splits tomatpuré - but known ingredient returns null', () {
        // tomatpuré is already in KnownIngredients, don't split
        final result = SwedishCompoundSplitter.trySplit('tomatpuré');
        expect(result, isNull);
      });

      test('does not split äppelmos (äppel not in registry)', () {
        // "äpple" is known but "äppel" is not — splitter correctly refuses
        expect(SwedishCompoundSplitter.trySplit('äppelmos'), isNull);
      });

      test('splits laxfilé via food suffix', () {
        final result = SwedishCompoundSplitter.trySplit('laxfilé');
        expect(result, isNotNull);
        expect(result!.$1, 'lax');
        expect(result.$2, 'filé');
      });

      test('does not split short words', () {
        expect(SwedishCompoundSplitter.trySplit('ost'), isNull);
        expect(SwedishCompoundSplitter.trySplit('mjöl'), isNull);
      });

      test('does not split known compound names', () {
        expect(SwedishCompoundSplitter.trySplit('vitpeppar'), isNull);
        expect(SwedishCompoundSplitter.trySplit('rödlök'), isNull);
        expect(SwedishCompoundSplitter.trySplit('blomkål'), isNull);
      });

      test('does not split already-known simple ingredients', () {
        expect(SwedishCompoundSplitter.trySplit('olivolja'), isNull);
        expect(SwedishCompoundSplitter.trySplit('rapsolja'), isNull);
      });

      test('does not split non-food words', () {
        expect(SwedishCompoundSplitter.trySplit('bildskärm'), isNull);
        expect(SwedishCompoundSplitter.trySplit('datormus'), isNull);
      });

      test('handles empty string', () {
        expect(SwedishCompoundSplitter.trySplit(''), isNull);
      });
    });

    group('isCompound', () {
      test('returns true for compound food words', () {
        expect(SwedishCompoundSplitter.isCompound('lingonsylt'), isTrue);
      });

      test('returns false for simple words', () {
        expect(SwedishCompoundSplitter.isCompound('salt'), isFalse);
      });
    });

    group('compoundSuffix', () {
      test('returns suffix for compound words', () {
        expect(SwedishCompoundSplitter.compoundSuffix('lingonsylt'), 'sylt');
      });

      test('returns null for non-compound words', () {
        expect(SwedishCompoundSplitter.compoundSuffix('salt'), isNull);
      });
    });
  });
}
