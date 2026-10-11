import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/nutrition/nutrient_values.dart';

// Eight distinct, non-round values per set so a swapped key or a swapped
// field in `+` / `scale` lands a different number in the wrong place.
const Map<String, dynamic> _json = {
  'kcal': 101.5,
  'fat': 2.25,
  'satFat': 3.75,
  'carbs': 4.125,
  'sugar': 5.0625,
  'fiber': 6.3125,
  'protein': 7.4375,
  'salt': 8.53125,
};

const NutrientValues _other = NutrientValues(
  kcal: 11,
  fat: 13,
  satFat: 17,
  carbs: 19,
  sugar: 23,
  fiber: 29,
  protein: 31,
  salt: 37,
);

void _expectFields(
  NutrientValues v, {
  required double kcal,
  required double fat,
  required double satFat,
  required double carbs,
  required double sugar,
  required double fiber,
  required double protein,
  required double salt,
}) {
  expect(v.kcal, closeTo(kcal, 1e-9), reason: 'kcal');
  expect(v.fat, closeTo(fat, 1e-9), reason: 'fat');
  expect(v.satFat, closeTo(satFat, 1e-9), reason: 'satFat');
  expect(v.carbs, closeTo(carbs, 1e-9), reason: 'carbs');
  expect(v.sugar, closeTo(sugar, 1e-9), reason: 'sugar');
  expect(v.fiber, closeTo(fiber, 1e-9), reason: 'fiber');
  expect(v.protein, closeTo(protein, 1e-9), reason: 'protein');
  expect(v.salt, closeTo(salt, 1e-9), reason: 'salt');
}

void main() {
  final base = NutrientValues.fromJson(_json);

  test('fromJson reads each table key into its own field', () {
    _expectFields(
      base,
      kcal: 101.5,
      fat: 2.25,
      satFat: 3.75,
      carbs: 4.125,
      sugar: 5.0625,
      fiber: 6.3125,
      protein: 7.4375,
      salt: 8.53125,
    );
  });

  test('integer JSON numbers are read as doubles', () {
    final v = NutrientValues.fromJson({'kcal': 120, 'salt': 2});
    expect(v.kcal, 120.0);
    expect(v.salt, 2.0);
  });

  test('a nutrient the table row lacks reads as 0, the others stay', () {
    final v = NutrientValues.fromJson({'kcal': 101.5, 'protein': 7.4375});
    _expectFields(
      v,
      kcal: 101.5,
      fat: 0,
      satFat: 0,
      carbs: 0,
      sugar: 0,
      fiber: 0,
      protein: 7.4375,
      salt: 0,
    );
  });

  test('a null value reads as 0', () {
    expect(NutrientValues.fromJson({'fat': null, 'kcal': 5}).fat, 0);
  });

  test('+ adds field by field', () {
    _expectFields(
      base + _other,
      kcal: 112.5,
      fat: 15.25,
      satFat: 20.75,
      carbs: 23.125,
      sugar: 28.0625,
      fiber: 35.3125,
      protein: 38.4375,
      salt: 45.53125,
    );
  });

  test('zero is the identity for +', () {
    _expectFields(
      base + NutrientValues.zero,
      kcal: 101.5,
      fat: 2.25,
      satFat: 3.75,
      carbs: 4.125,
      sugar: 5.0625,
      fiber: 6.3125,
      protein: 7.4375,
      salt: 8.53125,
    );
  });

  test('scale multiplies every field by the factor', () {
    _expectFields(
      base.scale(0.5),
      kcal: 50.75,
      fat: 1.125,
      satFat: 1.875,
      carbs: 2.0625,
      sugar: 2.53125,
      fiber: 3.15625,
      protein: 3.71875,
      salt: 4.265625,
    );
  });

  test('scale by 0 gives all zeros', () {
    _expectFields(
      base.scale(0),
      kcal: 0,
      fat: 0,
      satFat: 0,
      carbs: 0,
      sugar: 0,
      fiber: 0,
      protein: 0,
      salt: 0,
    );
  });
}
