import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe/meal_types.dart';
import 'package:butlery/widgets/menu/menu_view_helpers.dart';

void main() {
  test('menu sections follow the meal-type vocabulary, snack before fika', () {
    final menu = {
      'fika': <dynamic>[],
      'mellanmål': <dynamic>[],
      'middag': <dynamic>[],
      'frukost': <dynamic>[],
    };
    final keys = MenuViewHelpers.getSortedMenuEntries(
      menu.map((k, v) => MapEntry(k, <Never>[])),
    ).map((e) => MenuViewHelpers.capitalizeCategory(e.key)).toList();

    expect(keys, [
      MealTypes.frukost,
      MealTypes.middag,
      MealTypes.mellanmal,
      MealTypes.fika,
    ]);
  });
}
