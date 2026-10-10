import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/nutrition/nutrition_key.dart';
import 'package:butlery/services/nutrition/nutrition_table.dart';

Map<String, dynamic> _food(int id, String name, {double kcal = 100}) => {
  'id': id,
  'name': name,
  'kcal': kcal,
  'fat': 1.5,
  'satFat': 0.5,
  'carbs': 2,
  'protein': 3,
};

NutritionTable _table({Map<String, dynamic>? matching}) =>
    NutritionTable.fromJsonStrings(
      foodsJson: jsonEncode({
        'version': '2026-07-01',
        'foods': [
          _food(1, 'Mjölk fett 3% berikad'),
          _food(2, 'Mjölkchoklad'),
          _food(3, 'Mjölk'),
          _food(4, 'Kyckling bröstfilé rå u. skinn', kcal: 104),
          _food(5, 'Crème fraiche 34%'),
        ],
      }),
      matchingJson: jsonEncode(
        matching ??
            {
              'ingredients': {
                'kycklingfilé': {
                  'food': 4,
                  'units': {'st': 150},
                },
                'Crème fraiche': {'food': 5, 'gPerDl': 100},
                'mjölk': {'food': 3, 'gPerDl': 103, 'toTaste': false},
                'salt': {'food': 3, 'toTaste': true},
              },
              'aliases': {
                'Kycklingbröst': 'Kycklingfilé',
                'dangling': 'finns inte',
              },
              'negligible': ['Svartpeppar', 'Paprikapulver'],
            },
      ),
    );

void main() {
  group('loading', () {
    test('food rows keep their id, name and per-100 g values', () {
      final food = _table().food(4)!;
      expect(food.name, 'Kyckling bröstfilé rå u. skinn');
      expect(food.per100g.kcal, 104);
      expect(food.per100g.protein, 3);
      expect(_table().food(999), isNull);
    });

    test('a nutrient missing from a food row reads as 0', () {
      final food = _table().food(1)!;
      expect(food.per100g.sugar, 0);
      expect(food.per100g.salt, 0);
    });

    test('version comes from the file, empty when absent', () {
      expect(_table().version, '2026-07-01');
      final noVersion = NutritionTable.fromJsonStrings(
        foodsJson: jsonEncode({'foods': <dynamic>[]}),
        matchingJson: jsonEncode({'ingredients': <String, dynamic>{}}),
      );
      expect(noVersion.version, '');
    });

    test('a matching file with only ingredients loads', () {
      final t = _table(
        matching: {
          'ingredients': {
            'mjölk': {'food': 3},
          },
        },
      );
      expect(t.curated('mjölk')!.foodId, 3);
      expect(t.isNegligible('peppar'), isFalse);
    });
  });

  group('curated ingredients', () {
    test(
      'a curated name is matched through the same key function as a recipe line',
      () {
        final t = _table();
        expect(t.curated(NutritionKey.lookupKey('Kycklingfile'))!.foodId, 4);
        expect(t.curated(NutritionKey.lookupKey('KYCKLINGFILÉ'))!.foodId, 4);
        expect(t.curated(NutritionKey.lookupKey('Creme fraiche'))!.foodId, 5);
      },
    );

    test('weights and the toTaste flag come through', () {
      final t = _table();
      expect(t.curated('kycklingfile')!.gramsPerUnit, {'st': 150});
      expect(t.curated('mjölk')!.gramsPerDl, 103);
      expect(t.curated('mjölk')!.toTaste, isFalse);
      expect(t.curated('salt')!.toTaste, isTrue);
    });

    test('an alias hops once to the curated entry', () {
      final t = _table();
      final viaAlias = t.curated(NutritionKey.lookupKey('Kycklingbröst'));
      expect(viaAlias, isNotNull);
      expect(viaAlias!.foodId, 4);
    });

    test(
      'an alias pointing at nothing curated, and unknown names, give null',
      () {
        final t = _table();
        expect(t.curated('dangling'), isNull);
        expect(t.curated('kryptonit'), isNull);
      },
    );

    test(
      'a name that is curated itself wins over an alias of the same name',
      () {
        final t = _table(
          matching: {
            'ingredients': {
              'a': {'food': 1},
              'b': {'food': 2},
            },
            'aliases': {'a': 'b'},
          },
        );
        expect(t.curated('a')!.foodId, 1);
      },
    );
  });

  group('negligible', () {
    test('listed names are negligible under the folded key', () {
      final t = _table();
      expect(t.isNegligible(NutritionKey.lookupKey('Svartpeppar')), isTrue);
      expect(t.isNegligible(NutritionKey.lookupKey('paprikapulver')), isTrue);
    });

    test('an unlisted name is not', () {
      expect(_table().isNegligible('mjölk'), isFalse);
    });
  });

  group('search', () {
    test('a shorter name ranks before a longer one', () {
      final names = _table().search('mjölk').map((f) => f.name).toList();
      expect(names, ['Mjölk', 'Mjölkchoklad', 'Mjölk fett 3% berikad']);
    });

    test('every word of the query must be in the name, case-insensitively', () {
      final names = _table().search('MJÖLK berikad').map((f) => f.name);
      expect(names, ['Mjölk fett 3% berikad']);
      expect(_table().search('mjölk kyckling'), isEmpty);
    });

    test('a query typed without accents finds the accented name', () {
      expect(_table().search('creme fraiche').map((f) => f.name), [
        'Crème fraiche 34%',
      ]);
      expect(_table().search('filé').map((f) => f.id), [4]);
    });

    test('a blank query finds nothing rather than everything', () {
      expect(_table().search(''), isEmpty);
      expect(_table().search('   '), isEmpty);
    });

    test('the limit keeps the shortest names', () {
      final names = _table().search('mjölk', limit: 2).map((f) => f.name);
      expect(names, ['Mjölk', 'Mjölkchoklad']);
    });
  });
}
