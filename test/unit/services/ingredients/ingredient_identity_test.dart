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
      ('Arla mellanmjölk', 'mellanmjölk'),
      ('krossade tomater Mutti', 'krossade tomater'),
      ('ICA Basic gul lök', 'lök'),
      ('Zeta kapris', 'kapris'),
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
      ('Felix ketchup', 'Felix'),
    ];
    for (final (a, b) in different) {
      test(
        '"$a" is not "$b"',
        () => expect(IngredientIdentity.same(a, b), isFalse),
      );
    }
  });

  group('IngredientIdentity.sameItem', () {
    test('the same id is one item although the names differ', () {
      // "rödlök" and "lök" have different name keys; only the id joins them.
      expect(IngredientIdentity.same('rödlök', 'lök'), isFalse);
      expect(
        IngredientIdentity.sameItem('rödlök', 'onion', 'lök', 'onion'),
        isTrue,
      );
    });

    test('without ids the names decide, as before rows carried an id', () {
      expect(IngredientIdentity.sameItem('gul lök', null, 'lök', null), isTrue);
      expect(IngredientIdentity.sameItem('rödlök', null, 'lök', null), isFalse);
      expect(
        IngredientIdentity.sameItem('rödlök', 'onion', 'lök', null),
        isFalse,
      );
      expect(
        IngredientIdentity.sameItem('rödlök', null, 'lök', 'onion'),
        isFalse,
      );
    });

    test('different ids do not keep two rows of one name apart', () {
      expect(
        IngredientIdentity.sameItem(
          'bringa',
          'beef-brisket',
          'bringa',
          'lamb-brisket',
        ),
        isTrue,
      );
    });
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
