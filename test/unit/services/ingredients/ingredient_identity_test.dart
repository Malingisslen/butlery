import 'package:butlery/services/ingredients/ingredient_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IngredientIdentity.same', () {
    const same = [
      ('hackad lök', 'lök'),
      ('tomater', 'tomat'),
      ('Lök', 'lok'),
      ('gul lök (ca 1 st)', 'gul lök'),
      ('finhackad persilja', 'persilja'),
      ('stora potatisar', 'potatis'),
    ];
    for (final (a, b) in same) {
      test('"$a" is "$b"', () => expect(IngredientIdentity.same(a, b), isTrue));
    }

    const different = [
      ('mjölk', 'mjöl'),
      ('ägg', 'äggula'),
      ('socker', 'sock'),
      ('rökt lax', 'lax'),
      ('soltorkade tomater', 'tomater'),
      ('torkade tomater', 'tomater'),
      ('krossade tomater', 'tomat'),
    ];
    for (final (a, b) in different) {
      test(
        '"$a" is not "$b"',
        () => expect(IngredientIdentity.same(a, b), isFalse),
      );
    }
  });

  group('IngredientIdentity.nameKey', () {
    test('folds diacritics last', () {
      expect(IngredientIdentity.nameKey('Lök'), 'lok');
    });

    test('keeps words that singularising would otherwise cut', () {
      expect(IngredientIdentity.nameKey('peppar'), 'peppar');
      expect(IngredientIdentity.nameKey('socker'), 'socker');
      expect(IngredientIdentity.nameKey('bakpulver'), 'bakpulver');
    });

    test('an empty name has an empty key', () {
      expect(IngredientIdentity.nameKey('  '), '');
    });
  });
}
