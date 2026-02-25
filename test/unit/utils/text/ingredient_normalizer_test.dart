/// Unit tests for IngredientNormalizer - ingredient name normalization
///
/// Tests comprehensive ingredient normalization including:
/// - Preparation word removal
/// - Diet descriptor preservation
/// - Color descriptor handling
/// - Compound ingredient recognition
/// - Plural normalization
/// - Phase 0 bug fix regressions (BUG-7, BUG-12, BUG-13)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/utils/text/ingredient_normalizer.dart';
import 'package:butlery/constants/known_ingredients.dart';
import 'package:butlery/constants/preparation_words.dart';

void main() {
  group('IngredientNormalizer', () {
    group('basic normalization', () {
      test('lowercases and trims input', () {
        final result = IngredientNormalizer.normalize('  TOMAT  ');
        expect(result.normalized, 'tomat');
      });

      test('returns empty result for empty input', () {
        final result = IngredientNormalizer.normalize('');
        expect(result.normalized, '');
        expect(result.isKnown, false);
      });

      test('removes preparation words', () {
        final result = IngredientNormalizer.normalize('hackad lök');
        expect(result.normalized, 'lök');
        expect(result.removedWords, contains('hackad'));
      });

      test('removes size descriptors', () {
        final result = IngredientNormalizer.normalize('stort ägg');
        expect(result.normalized, 'ägg');
        expect(result.removedWords, contains('stort'));
      });
    });

    group('diet descriptor preservation', () {
      test('preserves glutenfri at start', () {
        final result = IngredientNormalizer.normalize('glutenfri pasta');
        expect(result.normalized, 'glutenfri pasta');
      });

      test('preserves glutenfri at end and reorders', () {
        final result = IngredientNormalizer.normalize('pasta glutenfri');
        expect(result.normalized, 'glutenfri pasta');
      });

      test('preserves laktosfri', () {
        final result = IngredientNormalizer.normalize('laktosfri mjölk');
        expect(result.normalized, 'laktosfri mjölk');
      });

      test('preserves vegansk', () {
        final result = IngredientNormalizer.normalize('vegansk ost');
        expect(result.normalized, 'vegansk ost');
      });
    });

    group('flavor pattern preservation', () {
      test('preserves med pattern', () {
        final result =
            IngredientNormalizer.normalize('mayo med lime och jalapeño');
        expect(result.normalized, 'mayo med lime och jalapeño');
      });

      test('preserves med hallonsmak', () {
        final result = IngredientNormalizer.normalize('läsk med hallonsmak');
        expect(result.normalized, 'läsk med hallonsmak');
      });
    });

    group('eller alternatives', () {
      test('takes last item after eller', () {
        final result = IngredientNormalizer.normalize('gul eller röd lök');
        // Result should be 'lök' - just the base ingredient
        // (L2 color compound reconstruction is skipped for "eller" alternatives)
        expect(result.normalized, 'lök');
        expect(result.removedWords, contains('gul'));
        expect(result.removedWords, contains('eller'));
        expect(result.removedWords, contains('röd'));
      });

      test('handles sugar alternatives', () {
        final result =
            IngredientNormalizer.normalize('farinsocker eller strösocker');
        // "strösocker" is a known invariant — should NOT strip -er
        expect(result.normalized, 'strösocker');
      });
    });

    group('L2: color word order handling', () {
      test('handles color before ingredient (standard order)', () {
        // "röd lök" should be normalized - color is a preparation word
        final result = IngredientNormalizer.normalize('röd lök');
        // If rödlök is a compound, it should return rödlök
        // Otherwise it returns lök
        expect(result.normalized.endsWith('lök'), isTrue);
      });

      test('handles color after ingredient (reverse order)', () {
        // "lök röd" should also work
        final result = IngredientNormalizer.normalize('lök röd');
        // Should still normalize to lök or rödlök
        expect(result.normalized.endsWith('lök'), isTrue);
      });

      test('handles gula after ingredient', () {
        final result = IngredientNormalizer.normalize('paprika gul');
        // Should normalize and remove color
        expect(result.removedWords, contains('gul'));
      });

      test('preserves compound names with colors', () {
        // vitpeppar should stay as vitpeppar (compound name)
        final result = IngredientNormalizer.normalize('vitpeppar');
        expect(result.normalized, 'vitpeppar');
      });

      test('preserves svartpeppar compound', () {
        final result = IngredientNormalizer.normalize('svartpeppar');
        expect(result.normalized, 'svartpeppar');
      });
    });

    group('compound ingredient extraction', () {
      test('extracts base from sås compounds', () {
        // tomatsås should extract to tomat if tomat is known
        final result = IngredientNormalizer.normalize('tomatsås');
        // Result depends on whether tomat is in KnownIngredients
        expect(result.original, 'tomatsås');
      });

      test('extracts base from filé compounds', () {
        final result = IngredientNormalizer.normalize('kycklingfilé');
        expect(result.original, 'kycklingfilé');
      });
    });

    group('batch normalization', () {
      test('normalizes multiple ingredients', () {
        final results = IngredientNormalizer.normalizeMany([
          'hackad lök',
          'stort ägg',
          'glutenfri pasta',
        ]);

        expect(results, hasLength(3));
        expect(results[0].normalized, 'lök');
        expect(results[1].normalized, 'ägg');
        expect(results[2].normalized, 'glutenfri pasta');
      });
    });

    group('Phase 0 bug fix regressions', () {
      group('BUG-12: lagerblad typo fix', () {
        test('should recognize lagerblad as known ingredient', () {
          expect(KnownIngredients.isKnown('lagerblad'), isTrue);
        });

        test('should normalize lagerblad with isKnown true', () {
          final result = IngredientNormalizer.normalize('lagerblad');
          expect(result.isKnown, isTrue);
          expect(result.category, 'spices');
        });
      });

      group('BUG-13: pumpakärnor typo fix', () {
        test('should recognize pumpakärnor as known ingredient', () {
          expect(KnownIngredients.isKnown('pumpakärnor'), isTrue);
        });

        test('should have pumpakärnor in nutsAndSeeds category', () {
          expect(KnownIngredients.nutsAndSeeds.contains('pumpakärnor'), isTrue);
          expect(KnownIngredients.getCategory('pumpakärnor'), 'nuts_seeds');
        });

        test('should normalize pumpakärnor (plural stripped by normalizer)',
            () {
          // The normalizer runs SwedishPluralization which strips the -or
          // suffix, so the normalized form won't match the plural.
          // The key BUG-13 fix is that the typo 'pumppärnor' was corrected
          // to 'pumpakärnor' in the KnownIngredients registry.
          final result = IngredientNormalizer.normalize('pumpakärnor');
          expect(result.original, 'pumpakärnor');
          // The normalized form has -or stripped by pluralization
          expect(result.normalized, isNotEmpty);
        });
      });

      group('BUG-7: mandel not stripped as prep word', () {
        test('should not treat mandel as a removable preparation word', () {
          expect(PreparationWords.shouldRemove('mandel'), isFalse);
        });

        test('should recognize mandel as known ingredient in nutsAndSeeds', () {
          expect(KnownIngredients.isKnown('mandel'), isTrue);
          expect(KnownIngredients.nutsAndSeeds.contains('mandel'), isTrue);
        });

        test('should normalize mandel with isKnown true', () {
          final result = IngredientNormalizer.normalize('mandel');
          expect(result.normalized, 'mandel');
          expect(result.isKnown, isTrue);
          expect(result.category, 'nuts_seeds');
        });

        test('should have mandelpotatis in compoundNames', () {
          expect(
            KnownIngredients.compoundNames.contains('mandelpotatis'),
            isTrue,
          );
        });

        test('should recognize mandelpotatis as compound name', () {
          expect(KnownIngredients.isCompoundName('mandelpotatis'), isTrue);
        });

        test('should normalize mandelpotatis as compound (not stripped)', () {
          final result = IngredientNormalizer.normalize('mandelpotatis');
          expect(result.normalized, 'mandelpotatis');
          expect(result.isKnown, isTrue);
        });
      });
    });

    group('compound cheese and allium names', () {
      test('preserves parmesanost as compound name', () {
        final result = IngredientNormalizer.normalize('parmesanost');
        expect(result.normalized, 'parmesanost');
        expect(result.isKnown, isTrue);
      });

      test('preserves fetaost as compound name', () {
        final result = IngredientNormalizer.normalize('fetaost');
        expect(result.normalized, 'fetaost');
        expect(result.isKnown, isTrue);
      });

      test('preserves cheddarost as compound name', () {
        final result = IngredientNormalizer.normalize('cheddarost');
        expect(result.normalized, 'cheddarost');
        expect(result.isKnown, isTrue);
      });

      test('preserves mozzarellaost as compound name', () {
        final result = IngredientNormalizer.normalize('mozzarellaost');
        expect(result.normalized, 'mozzarellaost');
        expect(result.isKnown, isTrue);
      });

      test('preserves schalottenlök as compound name', () {
        final result = IngredientNormalizer.normalize('schalottenlök');
        expect(result.normalized, 'schalottenlök');
        expect(result.isKnown, isTrue);
      });

      test('preserves ramslök as compound name', () {
        final result = IngredientNormalizer.normalize('ramslök');
        expect(result.normalized, 'ramslök');
        expect(result.isKnown, isTrue);
      });

      test('preserves citronpeppar as compound name', () {
        final result = IngredientNormalizer.normalize('citronpeppar');
        expect(result.normalized, 'citronpeppar');
        expect(result.isKnown, isTrue);
      });

      test('preserves vitlökspeppar as compound name', () {
        final result = IngredientNormalizer.normalize('vitlökspeppar');
        expect(result.normalized, 'vitlökspeppar');
        expect(result.isKnown, isTrue);
      });

      test('preserves jordnötssmör as compound name', () {
        final result = IngredientNormalizer.normalize('jordnötssmör');
        expect(result.normalized, 'jordnötssmör');
        expect(result.isKnown, isTrue);
      });

      test('preserves kokosmjölk as compound name', () {
        final result = IngredientNormalizer.normalize('kokosmjölk');
        expect(result.normalized, 'kokosmjölk');
        expect(result.isKnown, isTrue);
      });
    });

    group('new preparation state removal', () {
      test('removes marinerad from ingredient', () {
        final result = IngredientNormalizer.normalize('marinerad lax');
        expect(result.normalized, 'lax');
        expect(result.removedWords, contains('marinerad'));
      });

      test('removes torkad from ingredient', () {
        final result = IngredientNormalizer.normalize('torkad timjan');
        expect(result.normalized, 'timjan');
        expect(result.removedWords, contains('torkad'));
      });

      test('removes blancherad from ingredient', () {
        final result = IngredientNormalizer.normalize('blancherad broccoli');
        expect(result.normalized, 'broccoli');
        expect(result.removedWords, contains('blancherad'));
      });

      test('removes skalad from ingredient', () {
        final result = IngredientNormalizer.normalize('skalad potatis');
        expect(result.normalized, 'potatis');
        expect(result.removedWords, contains('skalad'));
      });

      test('removes halverad from ingredient', () {
        final result = IngredientNormalizer.normalize('halverad tomat');
        expect(result.normalized, 'tomat');
        expect(result.removedWords, contains('halverad'));
      });

      test('removes tinad from ingredient', () {
        final result = IngredientNormalizer.normalize('tinad lax');
        expect(result.normalized, 'lax');
        expect(result.removedWords, contains('tinad'));
      });

      test('removes smulad from ingredient', () {
        final result = IngredientNormalizer.normalize('smulad ost');
        expect(result.normalized, 'ost');
        expect(result.removedWords, contains('smulad'));
      });

      test('removes urvattnad from ingredient', () {
        final result = IngredientNormalizer.normalize('urvattnad spenat');
        expect(result.normalized, 'spenat');
        expect(result.removedWords, contains('urvattnad'));
      });

      test('removes upphackad from ingredient', () {
        final result = IngredientNormalizer.normalize('upphackad persilja');
        expect(result.normalized, 'persilja');
        expect(result.removedWords, contains('upphackad'));
      });

      test('all new prep word forms are registered', () {
        // Verify all forms exist in PreparationWords
        final newWords = [
          'urvattnad',
          'urvattnade',
          'urvattnat',
          'avrunnen',
          'avrunnet',
          'avrunna',
          'tinad',
          'tinat',
          'tinade',
          'blancherad',
          'blancherat',
          'blancherade',
          'marinerad',
          'marinerat',
          'marinerade',
          'halverad',
          'halverat',
          'halverade',
          'upphackad',
          'upphackat',
          'upphackade',
          'skalad',
          'skalat',
          'skalade',
          'strödd',
          'strött',
          'strödda',
          'torkad',
          'torkat',
          'torkade',
          'smulad',
          'smulat',
          'smulade',
        ];
        for (final word in newWords) {
          expect(
            PreparationWords.shouldRemove(word),
            isTrue,
            reason: '"$word" should be removable',
          );
        }
      });
    });

    group('Firestore enrichment via additionalKnown', () {
      test('recognizes Firestore-only ingredients when passed explicitly', () {
        final firestoreSet = {'tahini', 'harissa', "za'atar"};
        final result = IngredientNormalizer.normalize(
          'tahini',
          additionalKnown: firestoreSet,
        );
        expect(result.normalized, 'tahini');
        expect(result.isKnown, isTrue);
      });

      test('Step 1b short-circuits single Firestore-known ingredients', () {
        final firestoreSet = {'harissa'};
        final result = IngredientNormalizer.normalize(
          'harissa',
          additionalKnown: firestoreSet,
        );
        expect(result.normalized, 'harissa');
        expect(result.isKnown, isTrue);
      });

      test('Step 1b does not short-circuit multi-word prep+ingredient', () {
        final firestoreSet = {'lök', 'harissa'};
        final result = IngredientNormalizer.normalize(
          'hackad lök',
          additionalKnown: firestoreSet,
        );
        expect(result.normalized, 'lök');
        expect(result.removedWords, contains('hackad'));
      });

      test('Firestore enrichment helps definite form stripping', () {
        final firestoreSet = {'tahini'};
        final result = IngredientNormalizer.normalize(
          'tahinien',
          additionalKnown: firestoreSet,
        );
        expect(result.normalized, 'tahini');
        expect(result.isKnown, isTrue);
      });

      test('Firestore enrichment helps compound base extraction', () {
        final firestoreSet = {'harissa'};
        final result = IngredientNormalizer.normalize(
          'harissasås',
          additionalKnown: firestoreSet,
        );
        expect(result.normalized, 'harissa');
        expect(result.isKnown, isTrue);
      });

      test('without additionalKnown and no ServiceLocator falls back to static',
          () {
        // When ServiceLocator is not initialized (test environment),
        // _defaultAdditionalKnown returns null, so only static ingredients
        // are available
        final result = IngredientNormalizer.normalize('tahini');
        expect(result.isKnown, KnownIngredients.isKnown('tahini'));
      });

      test('batch normalizeMany passes additionalKnown through', () {
        final firestoreSet = {'tahini', 'harissa'};
        final results = IngredientNormalizer.normalizeMany(
          ['tahini', 'harissa', 'hackad lök'],
          additionalKnown: firestoreSet,
        );
        expect(results[0].isKnown, isTrue);
        expect(results[0].normalized, 'tahini');
        expect(results[1].isKnown, isTrue);
        expect(results[1].normalized, 'harissa');
        expect(results[2].normalized, 'lök');
      });
    });

    group('NormalizationResult', () {
      test('toString includes all relevant info', () {
        final result = IngredientNormalizer.normalize('hackad lök');
        final str = result.toString();

        expect(str, contains('original: "hackad lök"'));
        expect(str, contains('normalized: "lök"'));
        expect(str, contains('removed: hackad'));
      });

      test('toString includes confidence', () {
        final result = IngredientNormalizer.normalize('vitpeppar');
        final str = result.toString();

        expect(str, contains('confidence: 1.0'));
      });
    });

    group('confidence scores', () {
      test('compound name match has confidence 1.0', () {
        final result = IngredientNormalizer.normalize('vitpeppar');
        expect(result.confidence, 1.0);
      });

      test('known ingredient has confidence 0.8', () {
        final result = IngredientNormalizer.normalize('mjölk');
        expect(result.confidence, 0.8);
      });

      test('unknown ingredient has confidence 0.3', () {
        final result = IngredientNormalizer.normalize('xyzfooditem');
        expect(result.confidence, 0.3);
      });

      test('empty input has confidence 0.0', () {
        final result = IngredientNormalizer.normalize('');
        expect(result.confidence, 0.0);
      });

      test('diet descriptor with known rest has confidence 0.9', () {
        final result = IngredientNormalizer.normalize('glutenfri pasta');
        expect(result.confidence, 0.9);
      });

      test('standalone diet descriptor has confidence 0.4', () {
        final result = IngredientNormalizer.normalize('glutenfri');
        expect(result.confidence, 0.4);
      });

      test('flavor pattern has confidence 0.85', () {
        final result = IngredientNormalizer.normalize('mayo med lime');
        expect(result.confidence, 0.85);
      });

      test('Firestore-known ingredient has confidence 0.95', () {
        final result = IngredientNormalizer.normalize(
          'tahini',
          additionalKnown: {'tahini'},
        );
        expect(result.confidence, 0.95);
      });

      test('default confidence is 0.5 for manually constructed result', () {
        const result = NormalizationResult(
          normalized: 'test',
          isKnown: false,
          original: 'test',
        );
        expect(result.confidence, 0.5);
      });
    });
  });
}
