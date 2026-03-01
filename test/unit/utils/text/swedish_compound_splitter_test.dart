import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/utils/text/swedish_compound_splitter.dart';

void main() {
  group('SwedishCompoundSplitter', () {
    group('trySplit', () {
      test('splits unknown compound with food suffix', () {
        // rabarbersylt is NOT in KnownIngredients, rabarber IS known
        final result = SwedishCompoundSplitter.trySplit('rabarbersylt');
        expect(result, isNotNull);
        expect(result!.$1, 'rabarber');
        expect(result.$2, 'sylt');
      });

      test('does not split known compound names with joining s', () {
        expect(SwedishCompoundSplitter.trySplit('jordnötssmör'), isNull);
      });

      test('splits unknown compound with joining s', () {
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

      test('does not split kokosmjölk (known ingredient)', () {
        final result = SwedishCompoundSplitter.trySplit('kokosmjölk');
        expect(result, isNull);
      });

      test('does not split citronjuice (known ingredient in Firebase)', () {
        // citronjuice is in the Firebase-generated set
        final result = SwedishCompoundSplitter.trySplit('citronjuice');
        expect(result, isNull);
      });

      test('does not split tomatpuré (known ingredient)', () {
        final result = SwedishCompoundSplitter.trySplit('tomatpuré');
        expect(result, isNull);
      });

      test('does not split äppelmos (äppel not in registry)', () {
        expect(SwedishCompoundSplitter.trySplit('äppelmos'), isNull);
      });

      test('splits sillfilé via food suffix', () {
        // sillfilé is NOT in Firebase, but sill IS known
        final result = SwedishCompoundSplitter.trySplit('sillfilé');
        expect(result, isNotNull);
        expect(result!.$1, 'sill');
        expect(result.$2, 'filé');
      });

      test('does not split short words', () {
        expect(SwedishCompoundSplitter.trySplit('ost'), isNull);
        expect(SwedishCompoundSplitter.trySplit('mjöl'), isNull);
      });

      test('does not split known ingredients', () {
        expect(SwedishCompoundSplitter.trySplit('vitpeppar'), isNull);
        expect(SwedishCompoundSplitter.trySplit('rödlök'), isNull);
        expect(SwedishCompoundSplitter.trySplit('blomkål'), isNull);
        expect(SwedishCompoundSplitter.trySplit('lingonsylt'), isNull);
        expect(SwedishCompoundSplitter.trySplit('laxfilé'), isNull);
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
      test('returns true for unknown compound food words', () {
        expect(SwedishCompoundSplitter.isCompound('rabarbersylt'), isTrue);
      });

      test('returns false for known ingredients', () {
        expect(SwedishCompoundSplitter.isCompound('lingonsylt'), isFalse);
      });

      test('returns false for simple words', () {
        expect(SwedishCompoundSplitter.isCompound('salt'), isFalse);
      });
    });

    group('compoundSuffix', () {
      test('returns suffix for unknown compound words', () {
        expect(SwedishCompoundSplitter.compoundSuffix('rabarbersylt'), 'sylt');
      });

      test('returns null for known ingredients', () {
        expect(SwedishCompoundSplitter.compoundSuffix('lingonsylt'), isNull);
      });

      test('returns null for non-compound words', () {
        expect(SwedishCompoundSplitter.compoundSuffix('salt'), isNull);
      });
    });
  });
}
