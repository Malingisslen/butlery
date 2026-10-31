import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/utils/text/ingredient_quantity.dart';
import 'package:butlery/utils/text/structured_ingredient_deriver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IngredientQuantity.read', () {
    final cases = <String, (double?, double?, bool)>{
      'salt': (null, null, false),
      'salt efter smak': (null, null, false),
      'peppar': (null, null, false),
      'hackad lök': (null, null, false),
      'olja till stekning': (null, null, false),
      '2 dl mjölk': (2, 2, false),
      '1 ägg': (1, 1, false),
      'ett ägg': (1, 1, false),
      'en nypa salt': (1, 1, false),
      '2-3 dl mjölk': (2, 3, false),
      '2–3 msk olivolja': (2, 3, false),
      '1-2 vitlöksklyftor': (1, 2, false),
      'ca 2 dl grädde': (2, 2, true),
      'cirka 500 g nötfärs': (500, 500, true),
      '½ citron': (0.5, 0.5, false),
      '1 ½ dl vatten': (1.5, 1.5, false),
      '1/2 tsk salt': (0.5, 0.5, false),
      '1,5 dl socker': (1.5, 1.5, false),
      'creme fraiche, 2 dl': (2, 2, false),
    };
    for (final MapEntry(key: line, value: (min, max, approx))
        in cases.entries) {
      test('"$line"', () {
        final q = IngredientQuantity.read(line);
        expect(q.min, min, reason: 'min');
        expect(q.max, max, reason: 'max');
        expect(q.approximate, approx, reason: 'approximate');
      });
    }

    test('a range is bought at its highest value', () {
      expect(IngredientQuantity.read('2-3 tomater').forShopping, 3);
      expect(IngredientQuantity.read('salt').forShopping, isNull);
    });
  });

  group('IngredientQuantity.shoppingLine', () {
    test('a line without an amount has none, whatever path stored it', () {
      for (final entry in [
        RecipeIngredient.rawOnly('salt'),
        StructuredIngredientDeriver.derive('salt'),
        const RecipeIngredient(amount: 1, name: 'salt', raw: 'salt'),
      ]) {
        final line = IngredientQuantity.shoppingLine(entry);
        expect(line.amount, isNull, reason: entry.toString());
        expect(line.unit, '');
      }
    });

    test('a range stored at its low end or midpoint is bought at the top', () {
      for (final stored in [2, 2.5, null]) {
        final line = IngredientQuantity.shoppingLine(
          RecipeIngredient(
            amount: stored,
            unit: 'dl',
            name: 'mjölk',
            raw: '2-3 dl mjölk',
          ),
        );
        expect(line.amount, 3, reason: 'stored $stored');
        expect(line.unit, 'dl');
      }
    });

    test('an edited amount outside the range is kept', () {
      final line = IngredientQuantity.shoppingLine(
        const RecipeIngredient(
          amount: 5,
          unit: 'dl',
          name: 'mjölk',
          raw: '2-3 dl mjölk',
        ),
      );
      expect(line.amount, 5);
    });

    test('an older recipe without structure is parsed, not listed whole', () {
      final line = IngredientQuantity.shoppingLine(
        RecipeIngredient.rawOnly('2 dl mjölk'),
      );
      expect(line.name, 'mjölk');
      expect(line.unit, 'dl');
      expect(line.amount, 2);
    });

    test('a measured line keeps its stored amount and unit', () {
      final line = IngredientQuantity.shoppingLine(
        StructuredIngredientDeriver.derive('400 g krossade tomater'),
      );
      expect(line.amount, 400);
      expect(line.unit, 'g');
      expect(line.name, 'krossade tomater');
    });

    test('a unit written out in full comes back as its short form', () {
      // The list sums rows by unit, so "matsked" and "msk" must meet.
      for (final MapEntry(key: raw, value: unit) in {
        '1 matsked olja': 'msk',
        '2 styck ägg': 'st',
      }.entries) {
        expect(
          IngredientQuantity.shoppingLine(RecipeIngredient.rawOnly(raw)).unit,
          unit,
          reason: raw,
        );
      }
    });
  });
}
