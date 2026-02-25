/// Unit tests for KnownIngredients - static ingredient registry
///
/// Tests the compound name additions (cheese, allium, spice blends)
/// and isCompoundName / isKnown / getCategory behavior for new entries.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/constants/known_ingredients.dart';

void main() {
  group('KnownIngredients', () {
    group('isKnown', () {
      test('should recognize basic ingredients', () {
        expect(KnownIngredients.isKnown('mjölk'), isTrue);
        expect(KnownIngredients.isKnown('lök'), isTrue);
        expect(KnownIngredients.isKnown('salt'), isTrue);
      });

      test('should be case-insensitive', () {
        expect(KnownIngredients.isKnown('Mjölk'), isTrue);
        expect(KnownIngredients.isKnown('SALT'), isTrue);
      });

      test('should reject unknown ingredients', () {
        expect(KnownIngredients.isKnown('xyzfooditem'), isFalse);
        expect(KnownIngredients.isKnown('foobarbaz'), isFalse);
      });

      test('should recognize compound names as known', () {
        expect(KnownIngredients.isKnown('vitpeppar'), isTrue);
        expect(KnownIngredients.isKnown('rödlök'), isTrue);
        expect(KnownIngredients.isKnown('parmesanost'), isTrue);
        expect(KnownIngredients.isKnown('kokosmjölk'), isTrue);
      });
    });

    group('isCompoundName', () {
      test('should recognize pepper compounds', () {
        expect(KnownIngredients.isCompoundName('vitpeppar'), isTrue);
        expect(KnownIngredients.isCompoundName('svartpeppar'), isTrue);
        expect(KnownIngredients.isCompoundName('cayennepeppar'), isTrue);
        expect(KnownIngredients.isCompoundName('kryddpeppar'), isTrue);
      });

      test('should recognize onion compounds', () {
        expect(KnownIngredients.isCompoundName('rödlök'), isTrue);
        expect(KnownIngredients.isCompoundName('gullök'), isTrue);
        expect(KnownIngredients.isCompoundName('salladslök'), isTrue);
        expect(KnownIngredients.isCompoundName('purjolök'), isTrue);
      });

      test('should recognize cabbage compounds', () {
        expect(KnownIngredients.isCompoundName('vitkål'), isTrue);
        expect(KnownIngredients.isCompoundName('rödkål'), isTrue);
        expect(KnownIngredients.isCompoundName('grönkål'), isTrue);
        expect(KnownIngredients.isCompoundName('blomkål'), isTrue);
      });

      test('should recognize cheese compounds (Phase 1 addition)', () {
        expect(KnownIngredients.isCompoundName('parmesanost'), isTrue);
        expect(KnownIngredients.isCompoundName('fetaost'), isTrue);
        expect(KnownIngredients.isCompoundName('cheddarost'), isTrue);
        expect(KnownIngredients.isCompoundName('mozzarellaost'), isTrue);
      });

      test('should recognize allium compounds (Phase 1 addition)', () {
        expect(KnownIngredients.isCompoundName('schalottenlök'), isTrue);
        expect(KnownIngredients.isCompoundName('ramslök'), isTrue);
      });

      test('should recognize spice blend compounds (Phase 1 addition)', () {
        expect(KnownIngredients.isCompoundName('citronpeppar'), isTrue);
        expect(KnownIngredients.isCompoundName('vitlökspeppar'), isTrue);
        expect(KnownIngredients.isCompoundName('jordnötssmör'), isTrue);
        expect(KnownIngredients.isCompoundName('kokosmjölk'), isTrue);
      });

      test('should recognize multi-word compound names', () {
        expect(KnownIngredients.isCompoundName('vita bönor'), isTrue);
        expect(KnownIngredients.isCompoundName('svarta bönor'), isTrue);
        expect(KnownIngredients.isCompoundName('vit choklad'), isTrue);
        expect(KnownIngredients.isCompoundName('mörk choklad'), isTrue);
        expect(KnownIngredients.isCompoundName('svarta vinbär'), isTrue);
      });

      test('should be case-insensitive', () {
        expect(KnownIngredients.isCompoundName('Vitpeppar'), isTrue);
        expect(KnownIngredients.isCompoundName('PARMESANOST'), isTrue);
      });

      test('should NOT treat simple ingredients as compound names', () {
        expect(KnownIngredients.isCompoundName('mjölk'), isFalse);
        expect(KnownIngredients.isCompoundName('lök'), isFalse);
        expect(KnownIngredients.isCompoundName('peppar'), isFalse);
        expect(KnownIngredients.isCompoundName('ost'), isFalse);
      });
    });

    group('getCategory', () {
      test('should return correct categories for standard ingredients', () {
        expect(KnownIngredients.getCategory('mjölk'), 'dairy');
        expect(KnownIngredients.getCategory('kyckling'), 'meat');
        expect(KnownIngredients.getCategory('lax'), 'seafood');
        expect(KnownIngredients.getCategory('tomat'), 'vegetables');
        expect(KnownIngredients.getCategory('äpple'), 'fruits');
        expect(KnownIngredients.getCategory('pasta'), 'grains');
        expect(KnownIngredients.getCategory('baguette'), 'bread');
        expect(KnownIngredients.getCategory('ketchup'), 'condiments');
        expect(KnownIngredients.getCategory('salt'), 'spices');
        expect(KnownIngredients.getCategory('olivolja'), 'oils');
        expect(KnownIngredients.getCategory('socker'), 'sweeteners');
        expect(KnownIngredients.getCategory('mandel'), 'nuts_seeds');
        expect(KnownIngredients.getCategory('bakpulver'), 'baking');
        expect(KnownIngredients.getCategory('kidneybönor'), 'canned');
        expect(KnownIngredients.getCategory('kaffe'), 'beverages');
        expect(KnownIngredients.getCategory('rödvin'), 'alcohol');
        expect(KnownIngredients.getCategory('ägg'), 'eggs');
      });

      test('should return null for unknown ingredients', () {
        expect(KnownIngredients.getCategory('xyzfooditem'), isNull);
      });
    });

    group('compoundNames set included in all set', () {
      test('should include all compound names in the all set', () {
        for (final compound in KnownIngredients.compoundNames) {
          expect(
            KnownIngredients.all.contains(compound),
            isTrue,
            reason: '"$compound" from compoundNames should be in all set',
          );
        }
      });
    });

    group('getIngredientsInCategory', () {
      test('should return correct set for valid categories', () {
        expect(KnownIngredients.getIngredientsInCategory('dairy'),
            KnownIngredients.dairy);
        expect(KnownIngredients.getIngredientsInCategory('spices'),
            KnownIngredients.spices);
        expect(KnownIngredients.getIngredientsInCategory('eggs'),
            KnownIngredients.eggs);
      });

      test('should return null for invalid category', () {
        expect(KnownIngredients.getIngredientsInCategory('nonsense'), isNull);
      });
    });

    group('getAllCategories', () {
      test('should return all 17 categories', () {
        final categories = KnownIngredients.getAllCategories();
        expect(categories, hasLength(17));
        expect(categories, contains('dairy'));
        expect(categories, contains('eggs'));
        expect(categories, contains('nuts_seeds'));
      });
    });
  });
}
