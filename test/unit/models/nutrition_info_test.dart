/// Unit tests for NutritionInfo model.
///
/// Pure-Dart; targets the 57 unhit lines.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/nutrition_info.dart';

void main() {
  group('constructor + isEmpty', () {
    test('empty constructor yields isEmpty=true', () {
      expect(const NutritionInfo().isEmpty, isTrue);
    });

    test('any populated field flips isEmpty=false', () {
      expect(const NutritionInfo(calories: 100).isEmpty, isFalse);
      expect(const NutritionInfo(fat: '10g').isEmpty, isFalse);
      expect(const NutritionInfo(sodium: '300mg').isEmpty, isFalse);
    });
  });

  group('toJson / toFirestore / fromJson round-trip', () {
    test('omits null fields from JSON', () {
      const info = NutritionInfo(calories: 250, fat: '10g');
      final json = info.toJson();
      expect(json.keys.toSet(), {'calories', 'fat'});
      expect(json['calories'], 250);
    });

    test('toFirestore returns same shape as toJson', () {
      const info = NutritionInfo(calories: 250);
      expect(info.toFirestore(), info.toJson());
    });

    test('fromJson reconstructs all fields', () {
      const original = NutritionInfo(
        calories: 270,
        fat: '12g',
        protein: '8g',
        carbs: '30g',
        fiber: '4g',
        sugar: '2g',
        sodium: '300mg',
      );
      final json = original.toJson();
      final restored = NutritionInfo.fromJson(json);
      expect(restored.calories, 270);
      expect(restored.fat, '12g');
      expect(restored.protein, '8g');
      expect(restored.carbs, '30g');
      expect(restored.fiber, '4g');
      expect(restored.sugar, '2g');
      expect(restored.sodium, '300mg');
    });

    test('fromJson handles missing keys as null', () {
      final restored = NutritionInfo.fromJson(const {});
      expect(restored.isEmpty, isTrue);
    });
  });

  group('fromSchemaOrg parsing', () {
    test('parses calorie int directly', () {
      final info = NutritionInfo.fromSchemaOrg(const {'calories': 250});
      expect(info.calories, 250);
    });

    test('parses calorie numeric prefix from "270 calories"', () {
      final info =
          NutritionInfo.fromSchemaOrg(const {'calories': '270 calories'});
      expect(info.calories, 270);
    });

    test('parses calorie num to int', () {
      final info = NutritionInfo.fromSchemaOrg(const {'calories': 250.7});
      expect(info.calories, 250);
    });

    test('returns null for empty/null calorie strings', () {
      expect(
          NutritionInfo.fromSchemaOrg(const {'calories': ''}).calories, isNull);
      expect(NutritionInfo.fromSchemaOrg(const {}).calories, isNull);
    });

    test('returns null when no digits found in calorie string', () {
      expect(NutritionInfo.fromSchemaOrg(const {'calories': 'abc'}).calories,
          isNull);
    });

    test('caps long string fields at 200 chars', () {
      final long = 'x' * 250;
      final info = NutritionInfo.fromSchemaOrg({'fatContent': long});
      expect(info.fat!.length, 200);
    });

    test('returns null for empty string content fields', () {
      final info = NutritionInfo.fromSchemaOrg(const {'fatContent': ''});
      expect(info.fat, isNull);
    });

    test('preserves short content strings verbatim', () {
      final info =
          NutritionInfo.fromSchemaOrg(const {'fatContent': '12 grams'});
      expect(info.fat, '12 grams');
    });

    test('maps every schema.org nutrient field', () {
      final info = NutritionInfo.fromSchemaOrg(const {
        'calories': '300 calories',
        'fatContent': '15g',
        'proteinContent': '10g',
        'carbohydrateContent': '40g',
        'fiberContent': '5g',
        'sugarContent': '2g',
        'sodiumContent': '300mg',
      });
      expect(info.calories, 300);
      expect(info.fat, '15g');
      expect(info.protein, '10g');
      expect(info.carbs, '40g');
      expect(info.fiber, '5g');
      expect(info.sugar, '2g');
      expect(info.sodium, '300mg');
    });
  });

  group('copyWith with sentinel-null semantics', () {
    test('copyWith preserves unspecified fields', () {
      const original = NutritionInfo(calories: 250, fat: '10g');
      final copied = original.copyWith(protein: '8g');
      expect(copied.calories, 250);
      expect(copied.fat, '10g');
      expect(copied.protein, '8g');
    });

    test('copyWith allows setting field to null explicitly', () {
      const original = NutritionInfo(calories: 250);
      final copied = original.copyWith(calories: null);
      expect(copied.calories, isNull);
    });

    test('copyWith replaces existing value', () {
      const original = NutritionInfo(calories: 250);
      final copied = original.copyWith(calories: 300);
      expect(copied.calories, 300);
    });
  });

  test('toString includes calories', () {
    expect(const NutritionInfo(calories: 250).toString(), contains('250'));
  });
}
