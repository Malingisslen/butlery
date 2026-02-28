import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/ingredient_correction.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/parsing/feedback/recipe_diff_calculator.dart';

void main() {
  late RecipeDiffCalculator calculator;

  setUp(() {
    calculator = RecipeDiffCalculator();
  });

  Recipe makeRecipe({
    List<String> ingredients = const [],
    String title = 'Test',
    int portions = 4,
    int timeMinutes = 30,
    List<String> instructions = const ['Step 1'],
  }) {
    return Recipe(
      core: RecipeCore(
        id: 'test-recipe',
        title: title,
        description: '',
        ingredients: ingredients,
        instructions: instructions,
        mealType: 'Middag',
        portions: portions,
        timeMinutes: timeMinutes,
      ),
      type: RecipeType.personal,
    );
  }

  ParsedRecipe makeParsedRecipe({
    List<ParsedIngredient> ingredients = const [],
    String title = 'Test',
    int portions = 4,
    Duration totalTime = const Duration(minutes: 30),
    List<String> instructions = const ['Step 1'],
  }) {
    return ParsedRecipe(
      title: FieldResult.success(title),
      portions: FieldResult.success(portions),
      ingredients: FieldResult.success(ingredients),
      instructions: FieldResult.success(instructions),
      totalTime: FieldResult.success(totalTime),
      metadata: ParseMetadata(
        source: ImportSource.url,
        domain: 'test.se',
        tierResults: const [],
        totalParseTime: Duration.zero,
        parserVersion: '1.0',
        timestamp: DateTime(2026),
      ),
    );
  }

  group('RecipeDiffCalculator correctedName', () {
    test('name change sets correctedName to corrected ingredient name', () {
      final parsed = makeParsedRecipe(
        ingredients: [
          const ParsedIngredient(
            name: 'potatsi',
            originalLine: '3 dl potatsi',
            confidence: ParseConfidence.high,
            quantity: '3',
            unit: 'dl',
          ),
        ],
      );

      final corrected = makeRecipe(
        ingredients: ['3 dl potatis'],
      );

      final diff = calculator.calculateDiff(
        original: parsed,
        corrected: corrected,
        userId: 'user1',
      );

      expect(diff, isNotNull);
      final ingredientDiffs = diff!.ingredientCorrections;
      expect(ingredientDiffs, hasLength(1));
      expect(ingredientDiffs.first.nameChanged, isTrue);
      expect(ingredientDiffs.first.correctedName, 'potatis');
      expect(ingredientDiffs.first.originalName, 'potatsi');
    });

    test('no name change leaves correctedName null', () {
      final parsed = makeParsedRecipe(
        ingredients: [
          const ParsedIngredient(
            name: 'potatis',
            originalLine: '3 dl potatis',
            confidence: ParseConfidence.high,
            quantity: '3',
            unit: 'dl',
          ),
        ],
      );

      // Same name, different quantity
      final corrected = makeRecipe(
        ingredients: ['5 dl potatis'],
      );

      final diff = calculator.calculateDiff(
        original: parsed,
        corrected: corrected,
        userId: 'user1',
      );

      expect(diff, isNotNull);
      final ingredientDiffs = diff!.ingredientCorrections;
      expect(ingredientDiffs, hasLength(1));
      expect(ingredientDiffs.first.quantityChanged, isTrue);
      expect(ingredientDiffs.first.nameChanged, isFalse);
      expect(ingredientDiffs.first.correctedName, isNull);
    });

    test('added ingredient has correctedName as null', () {
      final parsed = makeParsedRecipe(
        ingredients: [],
      );

      final corrected = makeRecipe(
        ingredients: ['2 dl mjöl'],
      );

      final diff = calculator.calculateDiff(
        original: parsed,
        corrected: corrected,
        userId: 'user1',
      );

      expect(diff, isNotNull);
      final ingredientDiffs = diff!.ingredientCorrections;
      expect(ingredientDiffs, hasLength(1));
      expect(ingredientDiffs.first.type, IngredientCorrectionType.added);
      expect(ingredientDiffs.first.correctedName, isNull);
    });

    test('removed ingredient has correctedName as null', () {
      final parsed = makeParsedRecipe(
        ingredients: [
          const ParsedIngredient(
            name: 'mjöl',
            originalLine: '2 dl mjöl',
            confidence: ParseConfidence.high,
            quantity: '2',
            unit: 'dl',
          ),
        ],
      );

      final corrected = makeRecipe(
        ingredients: [],
      );

      final diff = calculator.calculateDiff(
        original: parsed,
        corrected: corrected,
        userId: 'user1',
      );

      expect(diff, isNotNull);
      final ingredientDiffs = diff!.ingredientCorrections;
      expect(ingredientDiffs, hasLength(1));
      expect(ingredientDiffs.first.type, IngredientCorrectionType.removed);
      expect(ingredientDiffs.first.correctedName, isNull);
    });
  });
}
