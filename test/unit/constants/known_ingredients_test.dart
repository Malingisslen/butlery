/// Unit tests for KnownIngredients - static ingredient registry
///
/// Tests isKnown / isCompoundName / getCategory behavior.
/// Data is auto-generated from Firebase Firestore via the codegen pipeline.
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

      test('should recognize compound ingredient names as known', () {
        expect(KnownIngredients.isKnown('vitpeppar'), isTrue);
        expect(KnownIngredients.isKnown('rödlök'), isTrue);
        expect(KnownIngredients.isKnown('kokosmjölk'), isTrue);
      });
    });

    group('isCompoundName', () {
      test('should NOT treat simple ingredients as compound names', () {
        expect(KnownIngredients.isCompoundName('mjölk'), isFalse);
        expect(KnownIngredients.isCompoundName('lök'), isFalse);
        expect(KnownIngredients.isCompoundName('peppar'), isFalse);
        expect(KnownIngredients.isCompoundName('ost'), isFalse);
      });

      test('compound names set is a Set<String>', () {
        // Verifies the generated type annotation is correct
        expect(KnownIngredients.compoundNames, isA<Set<String>>());
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
        expect(KnownIngredients.getCategory('salt'), 'spices');
        expect(KnownIngredients.getCategory('olivolja'), 'oils');
        expect(KnownIngredients.getCategory('socker'), 'sweeteners');
        expect(KnownIngredients.getCategory('bakpulver'), 'baking');
        expect(KnownIngredients.getCategory('kaffe'), 'beverages');
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
        expect(
          KnownIngredients.getIngredientsInCategory('dairy'),
          KnownIngredients.dairy,
        );
        expect(
          KnownIngredients.getIngredientsInCategory('spices'),
          KnownIngredients.spices,
        );
        expect(
          KnownIngredients.getIngredientsInCategory('eggs'),
          KnownIngredients.eggs,
        );
      });

      test('should return null for invalid category', () {
        expect(KnownIngredients.getIngredientsInCategory('nonsense'), isNull);
      });
    });

    group('getAllCategories', () {
      test('should return all 16 categories', () {
        final categories = KnownIngredients.getAllCategories();
        expect(categories, hasLength(16));
        expect(categories, contains('dairy'));
        expect(categories, contains('eggs'));
        expect(categories, contains('nuts_seeds'));
      });
    });

    group('all set', () {
      test('should contain ingredients from all categories', () {
        expect(KnownIngredients.all.contains('mjölk'), isTrue);
        expect(KnownIngredients.all.contains('kyckling'), isTrue);
        expect(KnownIngredients.all.contains('lax'), isTrue);
        expect(KnownIngredients.all.contains('tomat'), isTrue);
      });

      test('should have substantial coverage from Firebase', () {
        // Firebase export provides 2000+ base ingredients + aliases
        expect(KnownIngredients.all.length, greaterThan(2000));
      });
    });
  });
}
