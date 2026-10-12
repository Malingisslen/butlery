import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/views/cooking_mode/ingredient_quantity_split.dart';

void main() {
  IngredientQuantitySplit split(String s) => splitIngredientQuantity(s);

  test('cuts amount and unit from the name', () {
    expect(split('400 g färska champinjoner').quantity, '400 g');
    expect(split('400 g färska champinjoner').name, 'färska champinjoner');
    expect(split('3 dl grädde').quantity, '3 dl');
    expect(split('1,5 dl mjölk').quantity, '1,5 dl');
  });

  test('a count without a unit keeps the count as the amount', () {
    final s = split('2 vitlökskl.');
    expect(s.quantity, '2');
    expect(s.name, 'vitlökskl.');
    expect(split('2 st vitlöksklyftor').quantity, '2 st');
  });

  test('ranges and fractions count as an amount', () {
    expect(split('2-3 msk olja').quantity, '2-3 msk');
    expect(split('½ citron').quantity, '½');
  });

  test('a line without an amount stays whole', () {
    final s = split('Färsk timjan');
    expect(s.quantity, '');
    expect(s.name, 'Färsk timjan');
  });

  test('a word starting like a unit is not eaten as one', () {
    final s = split('2 stora lökar');
    expect(s.quantity, '2');
    expect(s.name, 'stora lökar');
  });
}
