import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/utils/text/compound_splitter.dart';

void main() {
  setUp(() {
    CompoundSplitter.clearCache();
  });

  group('CompoundSplitter', () {
    // Simulated Firestore vocabulary (static KnownIngredients are always
    // available; this set represents the additional Firestore enrichment)
    final firestoreKnown = <String>{
      'nötkött',
      'fläskfärs',
      'lax',
      'hallon',
      'lingon',
      'äpple',
      'morot',
      'potatis',
    };

    group('genitive-s compounds', () {
      test('nötköttsgryta splits at genitive-s', () {
        final result =
            CompoundSplitter.extractBase('nötköttsgryta', firestoreKnown);
        expect(result, 'nötkött',
            reason: 'nötkött + s + gryta — genitive-s linking');
      });

      test('fläskfärssås splits at genitive-s', () {
        final result =
            CompoundSplitter.extractBase('fläskfärssås', firestoreKnown);
        expect(result, 'fläskfärs',
            reason: 'fläskfärs + s + sås — genitive-s linking');
      });

      test('laxsås splits directly (no genitive-s needed)', () {
        final result = CompoundSplitter.extractBase('laxsås', firestoreKnown);
        expect(result, 'lax',
            reason: 'lax + sås — direct compound, no genitive');
      });
    });

    group('direct compounds', () {
      test('tomatsås is known ingredient — returned as-is', () {
        // tomatsås is in KnownIngredients.condiments, so no split
        final result = CompoundSplitter.extractBase('tomatsås', null);
        expect(result, 'tomatsås',
            reason: 'Known ingredient, guard short-circuits');
      });

      test('fläskstek extracts fläsk', () {
        // fläsk is in KnownIngredients.meat, stek is a known suffix
        final result = CompoundSplitter.extractBase('fläskstek', null);
        expect(result, 'fläsk');
      });

      test('kycklingfilé extracts kyckling', () {
        // kyckling is in KnownIngredients.meat
        final result = CompoundSplitter.extractBase('kycklingfilé', null);
        expect(result, 'kyckling');
      });

      test('kycklingbröst extracts kyckling', () {
        final result = CompoundSplitter.extractBase('kycklingbröst', null);
        expect(result, 'kyckling');
      });
    });

    group('novel suffixes not in static list', () {
      test('hallonmarmelad extracts hallon', () {
        final result =
            CompoundSplitter.extractBase('hallonmarmelad', firestoreKnown);
        expect(result, 'hallon',
            reason:
                '"marmelad" is not in static suffix list but hallon is known');
      });

      test('laxpudding extracts lax', () {
        final result =
            CompoundSplitter.extractBase('laxpudding', firestoreKnown);
        expect(result, 'lax',
            reason: '"pudding" is not in static suffix list but lax is known');
      });

      test('morotskaka extracts morot via genitive-s', () {
        final result =
            CompoundSplitter.extractBase('morotskaka', firestoreKnown);
        expect(result, 'morot',
            reason: 'morot + s + kaka — genitive-s with novel suffix');
      });

      test('äppelpaj does not split — äppel is not äpple', () {
        // Swedish compound morphology: "äpple" becomes "äppel" in compounds
        // (vowel reduction), so "äppel" won't match "äpple" in the vocabulary.
        // This is a known limitation — vowel-reduced forms need dictionary support.
        final result = CompoundSplitter.extractBase('äppelpaj', firestoreKnown);
        expect(result, 'äppelpaj',
            reason: 'äppel != äpple, no known base found');
      });
    });

    group('protected compound names', () {
      test('vitpeppar is not split', () {
        final result = CompoundSplitter.extractBase('vitpeppar', null);
        expect(result, 'vitpeppar',
            reason: 'In KnownIngredients.compoundNames — must not split');
      });

      test('svartpeppar is not split', () {
        final result = CompoundSplitter.extractBase('svartpeppar', null);
        expect(result, 'svartpeppar');
      });

      test('rödlök is not split', () {
        final result = CompoundSplitter.extractBase('rödlök', null);
        expect(result, 'rödlök');
      });

      test('sötpotatis is not split', () {
        final result = CompoundSplitter.extractBase('sötpotatis', null);
        expect(result, 'sötpotatis');
      });

      test('kokosmjölk is not split', () {
        final result = CompoundSplitter.extractBase('kokosmjölk', null);
        expect(result, 'kokosmjölk');
      });
    });

    group('known ingredients returned as-is', () {
      test('tomat is known — no split attempted', () {
        final result = CompoundSplitter.extractBase('tomat', null);
        // tomat is only 5 chars, below minimum, so returned as-is
        expect(result, 'tomat');
      });

      test('kyckling is known — no split attempted', () {
        final result = CompoundSplitter.extractBase('kyckling', null);
        expect(result, 'kyckling',
            reason: 'Already a known ingredient, skip splitting');
      });

      test('köttfärs is known — no split attempted', () {
        final result = CompoundSplitter.extractBase('köttfärs', null);
        expect(result, 'köttfärs', reason: 'Already in KnownIngredients.meat');
      });
    });

    group('short words skipped', () {
      test('ost is too short to split', () {
        final result = CompoundSplitter.extractBase('ost', null);
        expect(result, 'ost');
      });

      test('lök is too short to split', () {
        final result = CompoundSplitter.extractBase('lök', null);
        expect(result, 'lök');
      });

      test('mjölk is too short to split', () {
        final result = CompoundSplitter.extractBase('mjölk', null);
        expect(result, 'mjölk', reason: '5 chars, below 6-char minimum');
      });
    });

    group('no valid split', () {
      test('unknown word with no known components returns as-is', () {
        final result = CompoundSplitter.extractBase('xyzabcdef', null);
        expect(result, 'xyzabcdef');
      });

      test('word with known suffix but unknown base returns as-is', () {
        final result = CompoundSplitter.extractBase('zyzfilé', null);
        expect(result, 'zyzfilé', reason: '"zyz" is not a known ingredient');
      });
    });

    group('cache behavior', () {
      test('repeated calls return same result', () {
        final first = CompoundSplitter.extractBase('kycklingfilé', null);
        final second = CompoundSplitter.extractBase('kycklingfilé', null);
        expect(first, second);
        expect(first, 'kyckling');
      });

      test('cache is cleared by clearCache', () {
        CompoundSplitter.extractBase('kycklingfilé', null);
        CompoundSplitter.clearCache();
        // After clear, should still produce correct result
        final result = CompoundSplitter.extractBase('kycklingfilé', null);
        expect(result, 'kyckling');
      });
    });

    group('scoring prefers longer bases', () {
      test('prefers longer known base over shorter', () {
        // Both "lax" (3 chars) and (hypothetically) a longer prefix might match.
        // The splitter should prefer the longest known base.
        final known = <String>{'lax', 'potatis'};
        final result = CompoundSplitter.extractBase('potatissallad', known);
        expect(result, 'potatis',
            reason: 'potatis (7 chars) preferred over any shorter match');
      });
    });
  });
}
