/// Unit tests for ParsedRecipe model.
///
/// Pure-Dart; targets the 111 unhit lines in lib/models/parsing/parsed_recipe.dart.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/nutrition_info.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';

ParseMetadata _meta() => ParseMetadata.cacheHit(
  source: ImportSource.url,
  parserVersion: '1.0.0',
);

ParsedRecipe _completeRecipe() {
  return ParsedRecipe(
    title: FieldResult.success('Pasta'),
    portions: FieldResult.success(4),
    ingredients: FieldResult.success([
      ParsedIngredient.structured(
        name: 'tomato',
        originalLine: '2 tomatoes',
        quantity: '2',
      ),
      ParsedIngredient.simple('basil'),
    ]),
    instructions: FieldResult.success(const ['Cook pasta', 'Add sauce']),
    totalTime: FieldResult.success(const Duration(minutes: 30)),
    prepTime: FieldResult.success(const Duration(minutes: 10)),
    cookTime: FieldResult.success(const Duration(minutes: 20)),
    cuisine: FieldResult.success('Italian'),
    category: FieldResult.success('Middag'),
    difficulty: FieldResult.success('Easy'),
    nutrition: FieldResult.success(const NutritionInfo(calories: 500)),
    metadata: _meta(),
    imageUrl: 'https://example.com/img.jpg',
    description: 'Tasty pasta',
  );
}

void main() {
  group('ParsedRecipe.empty', () {
    test('every field is failed', () {
      final empty = ParsedRecipe.empty(metadata: _meta());
      expect(empty.title.hasValue, isFalse);
      expect(empty.portions.hasValue, isFalse);
      expect(empty.ingredients.hasValue, isFalse);
      expect(empty.instructions.hasValue, isFalse);
      expect(empty.totalTime.hasValue, isFalse);
      expect(empty.isComplete, isFalse);
    });
  });

  group('quality + completeness', () {
    test('overallQuality is high for all-success recipe', () {
      final r = _completeRecipe();
      expect(r.overallQuality, greaterThanOrEqualTo(0.99));
    });

    test('overallQuality is 0 for empty recipe', () {
      final r = ParsedRecipe.empty(metadata: _meta());
      expect(r.overallQuality, 0.0);
    });

    test('isComplete true when title + ingredients + instructions present', () {
      expect(_completeRecipe().isComplete, isTrue);
    });

    test('isComplete false when any essential field missing', () {
      final r = _completeRecipe().copyWith(
        ingredients: FieldResult.failed('missing'),
      );
      expect(r.isComplete, isFalse);
    });
  });

  group('needsReview', () {
    test('false when all essentials are high-confidence', () {
      expect(_completeRecipe().needsReview, isFalse);
    });

    test('true when any essential field has low confidence', () {
      final r = _completeRecipe().copyWith(
        title: FieldResult.low('Bad title', reason: 'unsure'),
      );
      expect(r.needsReview, isTrue);
    });
  });

  group('fieldsNeedingImprovement', () {
    test('empty for high-quality recipe', () {
      expect(_completeRecipe().fieldsNeedingImprovement, isEmpty);
    });

    test('lists fields with confidence < 0.5', () {
      final r = _completeRecipe().copyWith(
        title: FieldResult.low('Bad title'),
        portions: FieldResult.failed('?'),
      );
      expect(r.fieldsNeedingImprovement, containsAll(['title', 'portions']));
    });
  });

  group('ingredient stats', () {
    test('structuredIngredientCount counts only structured', () {
      expect(_completeRecipe().structuredIngredientCount, 1);
    });

    test('structuredIngredientCount 0 when ingredients absent', () {
      final r = ParsedRecipe.empty(metadata: _meta());
      expect(r.structuredIngredientCount, 0);
    });

    test('ingredientStructureRatio computes correctly', () {
      expect(_completeRecipe().ingredientStructureRatio, 0.5);
    });

    test('ingredientStructureRatio 0 for empty list', () {
      final r = _completeRecipe().copyWith(
        ingredients: FieldResult.success(const <ParsedIngredient>[]),
      );
      expect(r.ingredientStructureRatio, 0.0);
    });

    test('ingredientStructureRatio 0 when ingredients absent', () {
      expect(
        ParsedRecipe.empty(metadata: _meta()).ingredientStructureRatio,
        0.0,
      );
    });
  });

  group('copyWith', () {
    test('preserves unspecified fields', () {
      final original = _completeRecipe();
      final copied = original.copyWith(
        title: FieldResult.success('New Title'),
      );
      expect(copied.title.value, 'New Title');
      expect(copied.portions.value, original.portions.value);
      expect(
        copied.ingredients.value!.length,
        original.ingredients.value!.length,
      );
    });
  });

  group('toRecipeData (Map for storage / Recipe model)', () {
    test('only includes fields that have values', () {
      final r = ParsedRecipe.empty(metadata: _meta());
      final map = r.toRecipeData();

      expect(map.containsKey('title'), isFalse);
      expect(map.containsKey('parseMetadata'), isTrue);
    });

    /// BUT-1228: toRecipeData must carry the parser's structured form so any
    /// consumer building a Recipe from this map can persist it. The entries
    /// must be index-aligned with the raw `ingredients` strings (entry.raw ==
    /// ingredients[i]) — misaligned data is silently discarded by the
    /// Recipe.structuredIngredients facade, so alignment IS the contract.
    test('structuredIngredients key is index-aligned with ingredients and '
        'carries amount/unit/name', () {
      final map = _completeRecipe().toRecipeData();

      final raw = map['ingredients'] as List;
      final structured = map['structuredIngredients'] as List;

      expect(structured.length, raw.length);
      for (var i = 0; i < structured.length; i++) {
        expect(
          (structured[i] as Map)['raw'],
          raw[i],
          reason: 'entry $i must align with its raw ingredient line',
        );
      }
      expect((structured[0] as Map)['amount'], 2);
      expect((structured[0] as Map)['name'], 'tomato');
      // Unstructured line degrades to name-only, raw still present.
      expect((structured[1] as Map)['name'], 'basil');
      expect((structured[1] as Map).containsKey('amount'), isFalse);
    });

    test('structuredIngredients key absent when ingredients failed', () {
      final r = ParsedRecipe.empty(metadata: _meta());
      expect(r.toRecipeData().containsKey('structuredIngredients'), isFalse);
    });

    test('maps every populated field', () {
      final r = _completeRecipe();
      final map = r.toRecipeData();

      expect(map['title'], 'Pasta');
      expect(map['portions'], 4);
      expect(map['ingredients'], isA<List>());
      expect(map['instructions'], ['Cook pasta', 'Add sauce']);
      expect(map['timeMinutes'], 30);
      expect(map['prepTimeMinutes'], 10);
      expect(map['cookTimeMinutes'], 20);
      expect(map['cuisine'], 'Italian');
      expect(map['mealType'], 'Middag');
      expect(map['difficulty'], 'Easy');
      expect(map['nutritionInfo'], isA<Map>());
      expect(map['imageUrl'], 'https://example.com/img.jpg');
      expect(map['description'], 'Tasty pasta');
    });
  });

  group('toJson / fromJson round-trip', () {
    test('preserves title + ingredients identity for equality', () {
      final original = _completeRecipe();
      final json = original.toJson();
      final restored = ParsedRecipe.fromJson(json);

      expect(restored.title.value, original.title.value);
      expect(
        restored.ingredients.value!.length,
        original.ingredients.value!.length,
      );
      expect(restored.portions.value, 4);
      expect(restored.totalTime.value, const Duration(minutes: 30));
      expect(restored.imageUrl, original.imageUrl);
    });

    test('fromJson handles empty / missing field result blocks', () {
      final restored = ParsedRecipe.fromJson(const {
        'metadata': {
          'source': 'url',
          'tierResults': <dynamic>[],
          'totalParseTime': 0,
          'parserVersion': '1.0',
          'timestamp': '2026-01-15T00:00:00.000',
        },
      });
      expect(restored.title.hasValue, isFalse);
      expect(restored.ingredients.hasValue, isFalse);
    });
  });

  group('equality + toString', () {
    test('identical instances are equal', () {
      final r = _completeRecipe();
      expect(r == r, isTrue);
    });

    test('not equal when title differs', () {
      final r1 = _completeRecipe();
      final r2 = r1.copyWith(title: FieldResult.success('Other'));
      expect(r1 == r2, isFalse);
    });

    test('toString includes title and quality%', () {
      final s = _completeRecipe().toString();
      expect(s, contains('Pasta'));
      expect(s, contains('%'));
    });
  });
}
