import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/nutrition/nutrition_amount.dart';
import 'package:butlery/services/nutrition/nutrition_table.dart';

const _flour = IngredientMatch(foodId: 1, gramsPerDl: 60);
const _onion = IngredientMatch(
  foodId: 2,
  gramsPerDl: 60,
  gramsPerUnit: {'st': 110},
);
const _garlic = IngredientMatch(
  foodId: 3,
  gramsPerUnit: {'klyfta': 5, 'st': 50},
);
const _tomatoes = IngredientMatch(
  foodId: 4,
  gramsPerDl: 100,
  gramsPerUnit: {'burk': 400, 'paket': 390},
);
const _cabbage = IngredientMatch(foodId: 5, gramsPerUnit: {'huvud': 900});
const _noWeights = IngredientMatch(foodId: 6);

double? _g(num amount, String? unit, IngredientMatch match) =>
    NutritionAmount.grams(amount: amount, unit: unit, match: match);

void main() {
  group('mass units need no density', () {
    test('g, kg and hg convert directly', () {
      expect(_g(200, 'g', _noWeights), 200);
      expect(_g(1.5, 'kg', _noWeights), 1500);
      expect(_g(2, 'hg', _noWeights), 200);
    });

    test('a mass is not scaled by a density it also has', () {
      expect(_g(100, 'g', _flour), 100);
    });
  });

  group('volume units go through grams per dl', () {
    test('dl, msk, tsk, krm and l use the density', () {
      expect(_g(2, 'dl', _flour), closeTo(120, 1e-9));
      expect(_g(1, 'msk', _flour), closeTo(9, 1e-9)); // 15 ml
      expect(_g(1, 'tsk', _flour), closeTo(3, 1e-9)); // 5 ml
      expect(_g(2, 'krm', _flour), closeTo(1.2, 1e-9)); // 2 ml
      expect(_g(1, 'l', _flour), closeTo(600, 1e-9)); // 1000 ml
    });

    test('a volume of something with no density cannot be weighed', () {
      for (final unit in ['dl', 'msk', 'tsk', 'krm', 'l', 'ml']) {
        expect(_g(2, unit, _noWeights), isNull, reason: unit);
        expect(_g(2, unit, _garlic), isNull, reason: unit);
      }
    });

    test('unit spelling is case and space insensitive', () {
      expect(_g(2, ' DL ', _flour), closeTo(120, 1e-9));
    });
  });

  group('pieces', () {
    test('no unit means st', () {
      expect(_g(2, null, _onion), 220);
      expect(_g(2, '', _onion), 220);
      expect(_g(2, '   ', _onion), 220);
    });

    test('no unit on something with no st weight cannot be weighed', () {
      expect(_g(2, null, _flour), isNull);
      expect(_g(2, null, _noWeights), isNull);
    });

    test('plural and long spellings fold to the table spelling', () {
      expect(_g(3, 'klyftor', _garlic), 15);
      expect(_g(1, 'klyfta', _garlic), 5);
      expect(_g(2, 'burkar', _tomatoes), 800);
      expect(_g(1, 'Burk', _tomatoes), 400);
    });

    test('förp and pkt are the table\'s paket', () {
      expect(_g(1, 'förp', _tomatoes), 390);
      expect(_g(2, 'pkt', _tomatoes), 780);
      expect(_g(2, 'styck', _onion), 220);
      expect(_g(2, 'st.', _onion), 220);
    });

    test('a known piece unit the ingredient has no weight for is unknown', () {
      expect(_g(1, 'burk', _garlic), isNull);
      expect(_g(2, 'klyftor', _onion), isNull);
    });

    test('a unit present directly in the table is used as written', () {
      expect(_g(1, 'huvud', _cabbage), 900);
      expect(_g(0.5, 'huvud', _cabbage), 450);
    });

    test('an unknown unit is never guessed', () {
      expect(_g(1, 'nypa', _onion), isNull);
      expect(_g(1, 'huvud', _onion), isNull);
      expect(_g(2, 'banan', _noWeights), isNull);
    });
  });
}
