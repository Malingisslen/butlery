import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/tag_generator.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/helpers/tagging_test_helper.dart';

void main() {
  late TagGenerator generator;

  setUp(() {
    generator = TagGenerator();
  });

  group('Tagging edge cases', () {
    test(
      'compound ingredient hiding allergens — bechamel with milk+gluten → CONTAINS for both',
      () {
        final recipe = RecipeBuilder().withTitle('Gratäng').withIngredients([
          'bechamelsås',
          'potatis',
        ]).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('bechamelsås', 'sauce', {
            'dairy',
            'contains-gluten',
            'animal-product',
          }),
          TaggingTestHelper.ingredient('potatis', 'vegetable/root', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getAllergenStatus('gluten'), TriState.contains);
        expect(result.getAllergenStatus('mjölk'), TriState.contains);
      },
    );

    test(
      'combined allergen OR-logic — skaldjur = crustacean OR mollusc, only crustacean → CONTAINS',
      () {
        final recipe = RecipeBuilder().withTitle('Räkgryta').withIngredients([
          'räkor',
          'ris',
        ]).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('räkor', 'protein/seafood/shellfish', {
            'crustacean',
            'seafood',
          }),
          TaggingTestHelper.ingredient('ris', 'grain', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getAllergenStatus('skaldjur'), TriState.contains);
      },
    );

    test('combined allergen OR-logic — skaldjur, only mollusc → CONTAINS', () {
      final recipe = RecipeBuilder().withTitle('Musselgryta').withIngredients([
        'musslor',
        'vin',
      ]).build();
      final lookup = TaggingTestHelper.createLookup([
        TaggingTestHelper.ingredient('musslor', 'protein/seafood/shellfish', {
          'mollusc',
          'seafood',
        }),
        TaggingTestHelper.ingredient('vin', 'liquid/alcohol', {
          'contains-alcohol',
        }),
      ]);

      final result = generator.generate(ingredients: lookup, recipe: recipe);

      expect(result.getAllergenStatus('skaldjur'), TriState.contains);
    });

    test('nötter = tree-nut OR peanut, only peanut → nötter CONTAINS', () {
      final recipe = RecipeBuilder().withTitle('Jordnötsgryta').withIngredients(
        ['jordnötssmör', 'kyckling'],
      ).build();
      final lookup = TaggingTestHelper.createLookup([
        TaggingTestHelper.ingredient('jordnötssmör', 'protein/plant-based', {
          'peanut',
        }),
        TaggingTestHelper.ingredient('kyckling', 'protein/meat/poultry', {
          'meat',
        }),
      ]);

      final result = generator.generate(ingredients: lookup, recipe: recipe);

      expect(result.getAllergenStatus('nötter'), TriState.contains);
    });

    test(
      '100% coverage but all ingredients have empty properties → allergens FREE',
      () {
        final recipe = RecipeBuilder()
            .withTitle('Enkel sallad')
            .withIngredients(['sallad', 'tomat', 'gurka'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('sallad', 'vegetable/leafy', {}),
          TaggingTestHelper.ingredient('tomat', 'vegetable/fruit', {}),
          TaggingTestHelper.ingredient('gurka', 'vegetable/fruit', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // 100% coverage, no allergen properties → all allergens should be FREE
        expect(result.getAllergenStatus('gluten'), TriState.free);
        expect(result.getAllergenStatus('mjölk'), TriState.free);
        expect(result.getAllergenStatus('ägg'), TriState.free);
        expect(result.getAllergenStatus('nötter'), TriState.free);
        expect(result.coverage, 1.0);
      },
    );

    test('recipe with 0 ingredients → handles gracefully', () {
      final recipe = RecipeBuilder()
          .withTitle('Tom receptplacering')
          .withIngredients([])
          .build();
      final lookup = IngredientLookupResult.empty();

      final result = generator.generate(ingredients: lookup, recipe: recipe);

      // Should not crash and should return a valid result
      expect(result.coverage, 0.0);
      // With 0 coverage, all allergens/dietary should be UNKNOWN
      expect(
        result.allergenStatus.values.every((s) => s == TriState.unknown),
        isTrue,
      );
    });

    test('single-ingredient recipe → coverage = 1.0 if matched', () {
      final recipe = RecipeBuilder().withTitle('Bara ris').withIngredients([
        'ris',
      ]).build();
      final lookup = TaggingTestHelper.createLookup([
        TaggingTestHelper.ingredient('ris', 'grain', {}),
      ]);

      final result = generator.generate(ingredients: lookup, recipe: recipe);

      expect(result.coverage, 1.0);
    });

    test('very long ingredient list (50+) → no crash, correct coverage', () {
      final ingredientNames = List.generate(55, (i) => 'ingrediens_$i');
      final matchedIngredients = ingredientNames.take(50).map((name) {
        return TaggingTestHelper.ingredient(name, 'vegetable', {});
      }).toList();
      final unmatchedIngredients = ingredientNames.skip(50).toList();

      final recipe = RecipeBuilder()
          .withTitle('Stor recept')
          .withIngredients(ingredientNames)
          .build();
      final lookup = TaggingTestHelper.createLookup(
        matchedIngredients,
        unmatched: unmatchedIngredients,
      );

      final result = generator.generate(ingredients: lookup, recipe: recipe);

      // 50 matched out of 55 total
      expect(result.coverage, closeTo(50 / 55, 0.01));
      expect(result.unknownIngredients.length, 5);
    });
  });
}
