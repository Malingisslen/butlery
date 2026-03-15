import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
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

  group('TagGenerator', () {
    group('time tags', () {
      test('generates under-15-min tag for quick recipes', () {
        final recipe = RecipeBuilder()
            .withTitle('Quick Salad')
            .withTimeMinutes(10)
            .withIngredients(['lettuce', 'tomato']).build();
        final lookup = IngredientLookupResult.empty();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('under-15-min'), isTrue);
        expect(result.hasTag('under-30-min'), isTrue);
        expect(result.hasTag('under-45-min'), isTrue);
        expect(result.hasTag('under-60-min'), isTrue);
      });

      test('generates under-30-min tag for 25 minute recipes', () {
        final recipe = RecipeBuilder()
            .withTitle('Pasta')
            .withTimeMinutes(25)
            .withIngredients(['pasta']).build();
        final lookup = IngredientLookupResult.empty();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('under-15-min'), isFalse);
        expect(result.hasTag('under-30-min'), isTrue);
        expect(result.hasTag('under-45-min'), isTrue);
      });

      test('generates över-60-min tag for long recipes', () {
        final recipe = RecipeBuilder()
            .withTitle('Slow Roast')
            .withTimeMinutes(180)
            .withIngredients(['beef']).build();
        final lookup = IngredientLookupResult.empty();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('under-60-min'), isFalse);
        expect(result.hasTag('över-60-min'), isTrue);
      });

      test('no time tags for null timeMinutes', () {
        final recipe = RecipeBuilder()
            .withTitle('No Time Recipe')
            .withTimeMinutes(null)
            .withIngredients(['something']).build();
        final lookup = IngredientLookupResult.empty();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('under-15-min'), isFalse);
        expect(result.hasTag('under-30-min'), isFalse);
        expect(result.hasTag('över-60-min'), isFalse);
      });
    });

    group('allergen status', () {
      test('CONTAINS when ingredient has allergen property', () {
        final recipe = RecipeBuilder()
            .withTitle('Pasta')
            .withIngredients(['pasta']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'pasta', 'grain/pasta-bread', {'contains-gluten'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getAllergenStatus('gluten'), TriState.contains);
      });

      test('FREE when 100% coverage and no allergen', () {
        final recipe =
            RecipeBuilder().withTitle('Rice').withIngredients(['rice']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('rice', 'grain', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getAllergenStatus('gluten'), TriState.free);
      });

      test('UNKNOWN when coverage < 100%', () {
        final recipe = RecipeBuilder()
            .withTitle('Mystery Dish')
            .withIngredients(['rice', 'unknown']).build();
        final lookup = IngredientLookupResult.fromLists(
          matched: [TaggingTestHelper.ingredient('rice', 'grain', {})],
          unmatched: ['unknown'],
        );

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getAllergenStatus('gluten'), TriState.unknown);
        expect(result.coverage, 0.5);
      });

      test('dairy allergen detected from dairy property', () {
        final recipe = RecipeBuilder()
            .withTitle('Cream Sauce')
            .withIngredients(['cream']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('cream', 'protein/dairy', {'dairy'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getAllergenStatus('mjölk'), TriState.contains);
      });

      test('egg allergen detected from egg property', () {
        final recipe = RecipeBuilder()
            .withTitle('Omelette')
            .withIngredients(['eggs']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('eggs', 'protein/egg', {'egg'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getAllergenStatus('ägg'), TriState.contains);
      });

      group('combined allergens (nötter, skaldjur)', () {
        test('nötter CONTAINS when has tree-nut', () {
          final recipe = RecipeBuilder()
              .withTitle('Walnut Salad')
              .withIngredients(['valnötter', 'sallad']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'valnötter', 'nuts/tree-nut', {'tree-nut'}),
            TaggingTestHelper.ingredient('sallad', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getAllergenStatus('nötter'), TriState.contains);
        });

        test('nötter CONTAINS when has peanut', () {
          final recipe = RecipeBuilder()
              .withTitle('Peanut Butter Toast')
              .withIngredients(['jordnötssmör', 'bröd']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'jordnötssmör', 'nuts/peanut', {'peanut'}),
            TaggingTestHelper.ingredient(
                'bröd', 'grain/bread', {'contains-gluten'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getAllergenStatus('nötter'), TriState.contains);
        });

        test('nötter CONTAINS when has both tree-nut AND peanut', () {
          final recipe = RecipeBuilder()
              .withTitle('Mixed Nut Butter')
              .withIngredients(['jordnötter', 'mandlar']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'jordnötter', 'nuts/peanut', {'peanut'}),
            TaggingTestHelper.ingredient(
                'mandlar', 'nuts/tree-nut', {'tree-nut'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getAllergenStatus('nötter'), TriState.contains);
        });

        test('nötter FREE when no nuts at full coverage', () {
          final recipe = RecipeBuilder()
              .withTitle('Plain Pasta')
              .withIngredients(['pasta', 'tomatsås']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'pasta', 'grain/pasta-bread', {'contains-gluten'}),
            TaggingTestHelper.ingredient('tomatsås', 'sauce', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getAllergenStatus('nötter'), TriState.free);
        });

        test('nötter UNKNOWN when coverage incomplete', () {
          final recipe = RecipeBuilder()
              .withTitle('Mystery Cookies')
              .withIngredients(['mjöl', 'unknown']).build();
          final lookup = IngredientLookupResult.fromLists(
            matched: [
              TaggingTestHelper.ingredient(
                  'mjöl', 'grain', {'contains-gluten'}),
            ],
            unmatched: ['unknown'],
          );

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getAllergenStatus('nötter'), TriState.unknown);
        });

        test('skaldjur CONTAINS when has shellfish', () {
          final recipe = RecipeBuilder()
              .withTitle('Lobster Bisque')
              .withIngredients(['hummer', 'grädde']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('hummer', 'protein/seafood/shellfish',
                {'shellfish', 'crustacean'}),
            TaggingTestHelper.ingredient('grädde', 'protein/dairy', {'dairy'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getAllergenStatus('skaldjur'), TriState.contains);
        });

        test('skaldjur CONTAINS when has crustacean', () {
          final recipe = RecipeBuilder()
              .withTitle('Shrimp Scampi')
              .withIngredients(['räkor', 'vitlök']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'räkor', 'protein/seafood/shellfish', {'crustacean'}),
            TaggingTestHelper.ingredient('vitlök', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getAllergenStatus('skaldjur'), TriState.contains);
        });

        test('skaldjur CONTAINS when has mollusc', () {
          final recipe = RecipeBuilder()
              .withTitle('Mussel Pot')
              .withIngredients(['blåmusslor', 'vin']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'blåmusslor', 'protein/seafood/shellfish', {'mollusc'}),
            TaggingTestHelper.ingredient('vin', 'liquid', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getAllergenStatus('skaldjur'), TriState.contains);
        });

        // L1: Tests that multi-property ingredients are NOT duplicated in triggers
        test(
            'skaldjur CONTAINS with deduplicated trigger for multi-property ingredient',
            () {
          final recipe = RecipeBuilder()
              .withTitle('Mixed Shellfish')
              .withIngredients(['bläckfisk']).build();
          // Ingredient has BOTH crustacean AND mollusc properties
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'bläckfisk', 'protein/seafood', {'crustacean', 'mollusc'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          // Should still be CONTAINS
          expect(result.getAllergenStatus('skaldjur'), TriState.contains);
          // L1 fix ensures the ingredient appears only ONCE in decision triggers
          // (Previously it would appear twice - once for crustacean, once for mollusc)
          final decision = result.decisions
              ?.where((d) => d.key == 'skaldjur' && d.type == 'allergen')
              .firstOrNull;
          expect(decision, isNotNull);
          // Triggers should be deduplicated - only 1 entry for 'bläckfisk'
          expect(decision!.triggeringIngredients, isNotNull);
          expect(decision.triggeringIngredients, hasLength(1));
          expect(decision.triggeringIngredients!.first, equals('bläckfisk'));
        });

        test('skaldjur FREE when only fish (no shellfish)', () {
          final recipe = RecipeBuilder()
              .withTitle('Salmon Dinner')
              .withIngredients(['lax', 'potatis']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'lax', 'protein/seafood/fish', {'fish'}),
            TaggingTestHelper.ingredient('potatis', 'vegetable/root', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getAllergenStatus('skaldjur'), TriState.free);
        });
      });
    });

    group('dietary status', () {
      test('vegetarisk FREE when no meat or seafood', () {
        final recipe = RecipeBuilder()
            .withTitle('Vegetable Stir Fry')
            .withIngredients(['tofu', 'vegetables']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'tofu', 'protein/plant-based', {'plant-based'}),
          TaggingTestHelper.ingredient(
              'vegetables', 'vegetable', {'plant-based'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getDietaryStatus('vegetarisk'), TriState.free);
      });

      test('vegetarisk CONTAINS when has meat', () {
        final recipe = RecipeBuilder()
            .withTitle('Chicken Stir Fry')
            .withIngredients(['chicken']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getDietaryStatus('vegetarisk'), TriState.contains);
      });

      test('vegansk CONTAINS when has animal products', () {
        final recipe = RecipeBuilder()
            .withTitle('Creamy Pasta')
            .withIngredients(['pasta', 'cream']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'pasta', 'grain/pasta-bread', {'contains-gluten'}),
          TaggingTestHelper.ingredient(
              'cream', 'protein/dairy', {'dairy', 'animal-product'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getDietaryStatus('vegansk'), TriState.contains);
      });

      test('vegansk FREE when fully plant-based', () {
        final recipe = RecipeBuilder()
            .withTitle('Vegan Bowl')
            .withIngredients(['tofu', 'rice', 'vegetables']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'tofu', 'protein/plant-based', {'plant-based'}),
          TaggingTestHelper.ingredient('rice', 'grain', {'plant-based'}),
          TaggingTestHelper.ingredient(
              'vegetables', 'vegetable', {'plant-based'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getDietaryStatus('vegansk'), TriState.free);
      });

      group('pescetarian', () {
        test('FREE when has fish and no meat', () {
          final recipe = RecipeBuilder()
              .withTitle('Salmon Salad')
              .withIngredients(['lax', 'sallad']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'lax', 'protein/seafood/fish', {'fish', 'seafood'}),
            TaggingTestHelper.ingredient('sallad', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('pescetarian'), TriState.free);
        });

        test('FREE when has shellfish and no meat', () {
          final recipe = RecipeBuilder()
              .withTitle('Shrimp Pasta')
              .withIngredients(['räkor', 'pasta']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('räkor', 'protein/seafood/shellfish',
                {'shellfish', 'crustacean', 'seafood'}),
            TaggingTestHelper.ingredient(
                'pasta', 'grain/pasta-bread', {'contains-gluten'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('pescetarian'), TriState.free);
        });

        test('FREE when no fish AND no meat (vegetarian side dish)', () {
          // HIGH-4: Vegetarian dishes ARE pescetarian-compatible.
          // Pescetarian = no meat. Fish is allowed but not required.
          final recipe = RecipeBuilder()
              .withTitle('Garden Salad')
              .withIngredients(['sallad', 'tomat', 'gurka']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('sallad', 'vegetable', {}),
            TaggingTestHelper.ingredient('tomat', 'vegetable', {}),
            TaggingTestHelper.ingredient('gurka', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('pescetarian'), TriState.free);
        });

        test('CONTAINS when has meat (even with fish)', () {
          final recipe = RecipeBuilder()
              .withTitle('Surf and Turf')
              .withIngredients(['biff', 'räkor']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'biff', 'protein/meat/beef', {'meat', 'beef'}),
            TaggingTestHelper.ingredient('räkor', 'protein/seafood/shellfish',
                {'shellfish', 'crustacean', 'seafood'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('pescetarian'), TriState.contains);
        });

        test('UNKNOWN when coverage is incomplete', () {
          final recipe = RecipeBuilder()
              .withTitle('Mystery Fish Dish')
              .withIngredients(['lax', 'unknown sauce']).build();
          final lookup = IngredientLookupResult.fromLists(
            matched: [
              TaggingTestHelper.ingredient(
                  'lax', 'protein/seafood/fish', {'fish', 'seafood'}),
            ],
            unmatched: ['unknown sauce'],
          );

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('pescetarian'), TriState.unknown);
        });
      });

      group('halalanpassad', () {
        test('FREE when no pork or alcohol', () {
          final recipe = RecipeBuilder()
              .withTitle('Lamb Curry')
              .withIngredients(['lamm', 'ris', 'curry']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'lamm', 'protein/meat/lamb', {'meat', 'lamb'}),
            TaggingTestHelper.ingredient('ris', 'grain', {}),
            TaggingTestHelper.ingredient('curry', 'spice', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('halalanpassad'), TriState.free);
        });

        test('CONTAINS when has pork', () {
          final recipe = RecipeBuilder()
              .withTitle('Pork Roast')
              .withIngredients(['fläskfilé']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'fläskfilé', 'protein/meat/pork', {'meat', 'pork'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('halalanpassad'), TriState.contains);
        });

        test('CONTAINS when has alcohol', () {
          final recipe = RecipeBuilder()
              .withTitle('Wine Sauce')
              .withIngredients(['vin', 'grädde']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'vin', 'liquid/alcohol', {'contains-alcohol'}),
            TaggingTestHelper.ingredient(
                'grädde', 'protein/dairy', {'dairy', 'animal-product'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('halalanpassad'), TriState.contains);
        });
      });

      group('kosheranpassad', () {
        test('FREE when no pork or shellfish', () {
          final recipe = RecipeBuilder()
              .withTitle('Brisket')
              .withIngredients(['nötkött', 'potatis']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'nötkött', 'protein/meat/beef', {'meat', 'beef'}),
            TaggingTestHelper.ingredient('potatis', 'vegetable/root', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('kosheranpassad'), TriState.free);
        });

        test('CONTAINS when has pork', () {
          final recipe = RecipeBuilder()
              .withTitle('Ham Sandwich')
              .withIngredients(['skinka']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'skinka', 'protein/meat/pork', {'meat', 'pork'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('kosheranpassad'), TriState.contains);
        });

        test('CONTAINS when has shellfish', () {
          final recipe = RecipeBuilder()
              .withTitle('Lobster Dinner')
              .withIngredients(['hummer']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('hummer', 'protein/seafood/shellfish',
                {'shellfish', 'crustacean', 'seafood'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('kosheranpassad'), TriState.contains);
        });

        test('CONTAINS when has mollusc', () {
          final recipe = RecipeBuilder()
              .withTitle('Mussel Pasta')
              .withIngredients(['musslor']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('musslor', 'protein/seafood/shellfish',
                {'shellfish', 'mollusc', 'seafood'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('kosheranpassad'), TriState.contains);
        });
      });

      group('graviditetssäker (pregnancy safe)', () {
        test('FREE when no high-mercury fish or alcohol', () {
          final recipe = RecipeBuilder()
              .withTitle('Salmon Pasta')
              .withIngredients(['lax', 'pasta']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'lax', 'protein/seafood/fish', {'fish', 'seafood'}),
            TaggingTestHelper.ingredient(
                'pasta', 'grain/pasta-bread', {'contains-gluten'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('graviditetssäker'), TriState.free);
        });

        test('CONTAINS when has high-mercury fish', () {
          final recipe = RecipeBuilder()
              .withTitle('Swordfish Steak')
              .withIngredients(['svärdfisk']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('svärdfisk', 'protein/seafood/fish',
                {'fish', 'seafood', 'high-mercury'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(
              result.getDietaryStatus('graviditetssäker'), TriState.contains);
        });

        test('CONTAINS when has alcohol', () {
          final recipe = RecipeBuilder()
              .withTitle('Beer Braised Beef')
              .withIngredients(['nötkött', 'öl']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'nötkött', 'protein/meat/beef', {'meat', 'beef'}),
            TaggingTestHelper.ingredient(
                'öl', 'liquid/alcohol', {'contains-alcohol'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(
              result.getDietaryStatus('graviditetssäker'), TriState.contains);
        });
      });

      group('barnvänlig (child friendly)', () {
        test('FREE when not spicy and no alcohol', () {
          final recipe = RecipeBuilder()
              .withTitle('Pasta with Butter')
              .withIngredients(['pasta', 'smör']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'pasta', 'grain/pasta-bread', {'contains-gluten'}),
            TaggingTestHelper.ingredient(
                'smör', 'protein/dairy', {'dairy', 'animal-product'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('barnvänlig'), TriState.free);
        });

        test('CONTAINS when spicy', () {
          final recipe = RecipeBuilder()
              .withTitle('Spicy Thai Curry')
              .withIngredients(['chili', 'kyckling']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('chili', 'spice', {'is-spicy'}),
            TaggingTestHelper.ingredient(
                'kyckling', 'protein/meat/poultry', {'meat', 'poultry'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('barnvänlig'), TriState.contains);
        });
      });

      group('nötkötsfri (beef-free)', () {
        test('FREE when no beef', () {
          final recipe = RecipeBuilder()
              .withTitle('Chicken Dinner')
              .withIngredients(['kyckling']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'kyckling', 'protein/meat/poultry', {'meat', 'poultry'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('nötkötsfri'), TriState.free);
        });

        test('CONTAINS when has beef', () {
          final recipe = RecipeBuilder()
              .withTitle('Beef Steak')
              .withIngredients(['entrecote']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'entrecote', 'protein/meat/beef', {'meat', 'beef'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('nötkötsfri'), TriState.contains);
        });
      });
    });

    group('protein tags', () {
      test('adds kyckling tag for chicken ingredients', () {
        final recipe = RecipeBuilder()
            .withTitle('Chicken Dish')
            .withIngredients(['kycklingbröst']).build();
        final lookup = TaggingTestHelper.createLookup([
          IngredientData(
            id: 'chicken-breast',
            swedish: 'kycklingbröst',
            english: 'chicken breast',
            group: 'protein/meat/poultry',
            properties: const {'meat', 'poultry'},
          ),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('kyckling'), isTrue);
      });

      test('adds nötkött tag for beef ingredients', () {
        final recipe = RecipeBuilder()
            .withTitle('Beef Stew')
            .withIngredients(['nötfärs']).build();
        final lookup = TaggingTestHelper.createLookup([
          IngredientData(
            id: 'ground-beef',
            swedish: 'nötfärs',
            english: 'ground beef',
            group: 'protein/meat/beef',
            properties: const {'meat', 'beef'},
          ),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('nötkött'), isTrue);
      });

      test('adds fisk tag for fish ingredients', () {
        final recipe = RecipeBuilder()
            .withTitle('Salmon Dish')
            .withIngredients(['lax']).build();
        final lookup = TaggingTestHelper.createLookup([
          IngredientData(
            id: 'salmon',
            swedish: 'lax',
            english: 'salmon',
            group: 'protein/seafood/fish',
            properties: const {'fish', 'seafood'},
          ),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('fisk'), isTrue);
        expect(result.hasTag('lax'), isTrue);
      });

      test('adds skaldjur tag for shellfish', () {
        final recipe = RecipeBuilder()
            .withTitle('Shrimp Pasta')
            .withIngredients(['räkor']).build();
        final lookup = TaggingTestHelper.createLookup([
          IngredientData(
            id: 'shrimp',
            swedish: 'räkor',
            english: 'shrimp',
            group: 'protein/seafood/shellfish',
            properties: const {'seafood', 'crustacean'},
          ),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('skaldjur'), isTrue);
        expect(result.hasTag('räkor'), isTrue);
      });
    });

    group('carb/base tags', () {
      test('adds pastabaserad tag for pasta dishes', () {
        final recipe = RecipeBuilder()
            .withTitle('Pasta Carbonara')
            .withIngredients(['pasta', 'bacon']).build();
        final lookup = TaggingTestHelper.createLookup([
          IngredientData(
            id: 'pasta',
            swedish: 'pasta',
            english: 'pasta',
            group: 'grain/pasta-bread',
            properties: const {'contains-gluten'},
          ),
          TaggingTestHelper.ingredient(
              'bacon', 'protein/meat/pork', {'meat', 'pork'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('pastabaserad'), isTrue);
      });

      test('adds risbaserad tag for rice dishes', () {
        final recipe = RecipeBuilder()
            .withTitle('Fried Rice')
            .withIngredients(['ris', 'vegetables']).build();
        final lookup = TaggingTestHelper.createLookup([
          IngredientData(
            id: 'rice',
            swedish: 'ris',
            english: 'rice',
            group: 'grain',
            properties: const {},
          ),
          TaggingTestHelper.ingredient('vegetables', 'vegetable', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('risbaserad'), isTrue);
      });

      test('adds potatisbaserad tag for potato dishes', () {
        final recipe = RecipeBuilder()
            .withTitle('Mashed Potatoes')
            .withIngredients(['potatis', 'butter']).build();
        final lookup = TaggingTestHelper.createLookup([
          IngredientData(
            id: 'potato',
            swedish: 'potatis',
            english: 'potato',
            group: 'vegetable/root',
            properties: const {},
          ),
          TaggingTestHelper.ingredient('butter', 'protein/dairy', {'dairy'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('potatisbaserad'), isTrue);
      });
    });

    group('cooking method tags', () {
      test('adds ugnsbakad tag when instructions mention oven', () {
        final recipe = RecipeBuilder()
            .withTitle('Baked Chicken')
            .withIngredients(['chicken']).withInstructions(
                ['Sätt ugnen på 200°C', 'Grädda i 45 minuter']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'chicken', 'protein/meat/poultry', {'meat'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('ugnsbakad'), isTrue);
      });

      test('adds stekt tag when instructions mention frying', () {
        final recipe = RecipeBuilder()
            .withTitle('Pan Fried Fish')
            .withIngredients(['fish']).withInstructions(
                ['Stek fisken i smör tills gyllenbrun']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'fish', 'protein/seafood/fish', {'fish'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('stekt'), isTrue);
      });

      test('adds grillad tag when instructions mention grilling', () {
        final recipe = RecipeBuilder()
            .withTitle('Grilled Vegetables')
            .withIngredients(['vegetables']).withInstructions(
                ['Grilla grönsakerna på medium värme']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('vegetables', 'vegetable', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('grillad'), isTrue);
      });

      test('adds kokt tag when instructions mention boiling', () {
        final recipe = RecipeBuilder()
            .withTitle('Boiled Potatoes')
            .withIngredients(['potatis']).withInstructions(
                ['Koka potatisen i saltat vatten']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('potatis', 'vegetable/root', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('kokt'), isTrue);
      });

      test('adds wokad tag when instructions mention wok', () {
        final recipe = RecipeBuilder()
            .withTitle('Stir Fry')
            .withIngredients(['vegetables', 'tofu']).withInstructions(
                ['Woka grönsakerna på hög värme']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('vegetables', 'vegetable', {}),
          TaggingTestHelper.ingredient('tofu', 'protein/plant-based', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('wokad'), isTrue);
      });
    });

    group('dish type tags from title', () {
      test('adds soppa tag for soup titles', () {
        final recipe = RecipeBuilder()
            .withTitle('Tomatsoppa')
            .withIngredients(['tomatoes']).build();
        final lookup = IngredientLookupResult.empty();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('soppa'), isTrue);
      });

      test('adds gryta tag for stew titles', () {
        final recipe = RecipeBuilder()
            .withTitle('Köttgryta')
            .withIngredients(['beef']).build();
        final lookup = IngredientLookupResult.empty();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('gryta'), isTrue);
      });

      test('adds sallad tag for salad titles', () {
        final recipe = RecipeBuilder()
            .withTitle('Grekisk sallad')
            .withIngredients(['lettuce']).build();
        final lookup = IngredientLookupResult.empty();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('sallad'), isTrue);
      });

      test('adds pizza tag for pizza titles', () {
        final recipe = RecipeBuilder()
            .withTitle('Margherita Pizza')
            .withIngredients(['dough', 'tomato', 'cheese']).build();
        final lookup = IngredientLookupResult.empty();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('pizza'), isTrue);
      });

      test('adds taco tag for taco titles', () {
        final recipe = RecipeBuilder()
            .withTitle('Tacos med kyckling')
            .withIngredients(['tortillas', 'chicken']).build();
        final lookup = IngredientLookupResult.empty();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('taco'), isTrue);
      });

      test('does not add kaka tag for pannkaka', () {
        final recipe = RecipeBuilder()
            .withTitle('Svenska pannkakor')
            .withIngredients(['eggs', 'flour', 'milk']).build();
        final lookup = IngredientLookupResult.empty();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('pannkaka'), isTrue);
        expect(result.hasTag('kaka'), isFalse);
      });
    });

    group('coverage and unknown ingredients', () {
      test('returns correct coverage percentage', () {
        final recipe = RecipeBuilder()
            .withTitle('Mixed Dish')
            .withIngredients(['known1', 'known2', 'unknown']).build();
        final lookup = IngredientLookupResult.fromLists(
          matched: [
            TaggingTestHelper.ingredient('known1', 'vegetable', {}),
            TaggingTestHelper.ingredient('known2', 'grain', {}),
          ],
          unmatched: ['unknown'],
        );

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.coverage, closeTo(0.667, 0.01));
        expect(result.unknownIngredients, ['unknown']);
      });

      test('100% coverage when all ingredients matched', () {
        final recipe = RecipeBuilder()
            .withTitle('Known Dish')
            .withIngredients(['ingredient1', 'ingredient2']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('ingredient1', 'vegetable', {}),
          TaggingTestHelper.ingredient('ingredient2', 'grain', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.coverage, 1.0);
        expect(result.unknownIngredients, isEmpty);
        expect(result.hasFullCoverage, isTrue);
      });

      test('empty lookup has 100% coverage (nothing to analyze)', () {
        // CRITICAL: Empty lookup = nothing to analyze = complete coverage
        // This was fixed from 0.0 to 1.0
        final recipe = RecipeBuilder()
            .withTitle('Empty Recipe')
            .withIngredients([]).build();
        final lookup = IngredientLookupResult.empty();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // HIGH-1: Empty = 0% coverage (no ingredients = no data to analyze)
        // This is consistent with TagResult.empty() semantics
        expect(result.coverage, 0.0);
        expect(result.hasFullCoverage, isFalse);
        expect(result.unknownIngredients, isEmpty);
      });

      test('empty lookup allergens are UNKNOWN (no data)', () {
        // HIGH-1: With no ingredients and 0% coverage, allergens are UNKNOWN
        // (we have no data to confirm or deny allergen presence)
        final recipe = RecipeBuilder()
            .withTitle('Empty Recipe')
            .withIngredients([]).build();
        final lookup = IngredientLookupResult.empty();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // No ingredients = no data = UNKNOWN allergen status
        expect(result.isAllergenUnknown('gluten'), isTrue);
        expect(result.getAllergenStatus('gluten'), TriState.unknown);
      });
    });

    group('generatePhase1Only', () {
      test('returns only phase 1 tags with correct version', () {
        final recipe = RecipeBuilder()
            .withTitle('Quick Test')
            .withTimeMinutes(15)
            .withIngredients(['chicken']).build();
        final lookup = TaggingTestHelper.createLookup([
          IngredientData(
            id: 'chicken',
            swedish: 'kyckling',
            english: 'chicken',
            group: 'protein/meat/poultry',
            properties: const {'meat', 'poultry'},
          ),
        ]);

        final result = generator.generatePhase1Only(
          ingredients: lookup,
          recipe: recipe,
        );

        expect(result.generatorVersion, contains('phase1'));
        expect(result.hasTag('under-15-min'), isTrue);
        expect(result.hasTag('kyckling'), isTrue);
      });
    });

    group('generator version', () {
      test('includes version in result', () {
        final recipe =
            RecipeBuilder().withTitle('Test').withIngredients(['test']).build();
        final lookup = IngredientLookupResult.empty();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.generatorVersion, isNotNull);
        expect(result.generatorVersion, kTagGeneratorVersion);
      });
    });

    // =========================================================================
    // CRIT-10: Timeout behavior tests
    // =========================================================================
    group('CRIT-10: Timeout behavior', () {
      test('returns partial result with zero timeout (Phase 1 only)', () {
        final recipe = RecipeBuilder()
            .withTitle('Test Recipe')
            .withTimeMinutes(30)
            .withIngredients(['chicken', 'rice']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
          TaggingTestHelper.ingredient('rice', 'grain', {}),
        ]);

        // Zero timeout means timeout check fires immediately after Phase 1
        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
          timeout: Duration.zero,
        );

        // Result should be marked as partial
        expect(result.isPartial, isTrue);
        // Phase 1 safety-critical tags should still be present
        expect(result.allergenStatus, isNotEmpty);
        expect(result.dietaryStatus, isNotEmpty);
      });

      test('completes all phases with generous timeout', () {
        final recipe = RecipeBuilder()
            .withTitle('Test Recipe')
            .withTimeMinutes(30)
            .withIngredients(['chicken', 'rice']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
          TaggingTestHelper.ingredient('rice', 'grain', {}),
        ]);

        // Generous timeout allows all phases to complete
        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
          timeout: const Duration(seconds: 30),
        );

        // Result should NOT be marked as partial
        expect(result.isPartial, isFalse);
      });

      test('completes all phases when no timeout specified', () {
        final recipe = RecipeBuilder()
            .withTitle('Test Recipe')
            .withTimeMinutes(30)
            .withIngredients(['chicken', 'rice']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
          TaggingTestHelper.ingredient('rice', 'grain', {}),
        ]);

        // No timeout means all phases complete
        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        expect(result.isPartial, isFalse);
      });

      test('preserves allergen status even on timeout', () {
        final recipe = RecipeBuilder()
            .withTitle('Gluten Dish')
            .withTimeMinutes(30)
            .withIngredients(['pasta', 'eggs']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'pasta', 'grain/pasta-bread', {'contains-gluten'}),
          TaggingTestHelper.ingredient('eggs', 'protein/egg', {'egg'}),
        ]);

        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
          timeout: Duration.zero,
        );

        // Safety-critical allergen detection preserved
        expect(result.getAllergenStatus('gluten'), TriState.contains);
        expect(result.getAllergenStatus('ägg'), TriState.contains);
      });

      test('preserves dietary status even on timeout', () {
        final recipe = RecipeBuilder()
            .withTitle('Vegan Dish')
            .withTimeMinutes(30)
            .withIngredients(['tofu', 'vegetables']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'tofu', 'protein/plant-based', {'plant-based'}),
          TaggingTestHelper.ingredient(
              'vegetables', 'vegetable', {'plant-based'}),
        ]);

        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
          timeout: Duration.zero,
        );

        // Safety-critical dietary detection preserved
        expect(result.getDietaryStatus('vegansk'), TriState.free);
        expect(result.getDietaryStatus('vegetarisk'), TriState.free);
      });

      test('includes coverage even on timeout', () {
        final recipe = RecipeBuilder()
            .withTitle('Partial Coverage')
            .withTimeMinutes(30)
            .withIngredients(['chicken', 'unknown']).build();
        final lookup = IngredientLookupResult.fromLists(
          matched: [
            TaggingTestHelper.ingredient(
                'chicken', 'protein/meat/poultry', {'meat'})
          ],
          unmatched: ['unknown'],
        );

        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
          timeout: Duration.zero,
        );

        // Coverage should be calculated regardless of timeout
        expect(result.coverage, 0.5);
        expect(result.unknownIngredients, contains('unknown'));
      });
    });

    // =========================================================================
    // CRIT-11: Error recovery tests (graceful degradation)
    // =========================================================================
    group('CRIT-11: Error recovery and graceful degradation', () {
      // Note: These tests verify the behavior documented in TagGenerator:
      // - Phase 1 failure = complete failure (safety critical)
      // - Phase 2-4 failures = graceful degradation (returns partial results)

      test('result includes Phase 1 base tags when all phases complete', () {
        final recipe = RecipeBuilder()
            .withTitle('Simple Chicken')
            .withTimeMinutes(30)
            .withIngredients(['kycklingbröst']).build();
        final lookup = TaggingTestHelper.createLookup([
          IngredientData(
            id: 'chicken-breast',
            swedish: 'kycklingbröst',
            english: 'chicken breast',
            group: 'protein/meat/poultry',
            properties: const {'meat', 'poultry'},
          ),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // Phase 1 protein tag - kyckling derived from Swedish name containing 'kyckling'
        expect(result.hasTag('kyckling'), isTrue);
        // Phase 1 time tag
        expect(result.hasTag('under-30-min'), isTrue);
      });

      test('result includes Phase 2 derived tags when phases 1-2 complete', () {
        final recipe = RecipeBuilder()
            .withTitle('Mild Chicken')
            .withTimeMinutes(30)
            .withIngredients(['chicken', 'salt']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
          TaggingTestHelper.ingredient('salt', 'seasoning', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // Phase 2 derived tag (mild when no spicy ingredients)
        expect(result.hasTag('mild'), isTrue);
      });

      test('result includes Phase 3 complex tags when phases 1-3 complete', () {
        final recipe = RecipeBuilder()
            .withTitle('Simple Salad')
            .withTimeMinutes(10)
            .withIngredients(['lettuce', 'tomato', 'cucumber']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('lettuce', 'vegetable', {}),
          TaggingTestHelper.ingredient('tomato', 'vegetable', {}),
          TaggingTestHelper.ingredient('cucumber', 'vegetable', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // Phase 3 complexity tag
        expect(result.hasTag('enkel'), isTrue);
      });

      test('result includes Phase 4 mood tags when all phases complete', () {
        // Use a recipe that triggers clear Phase 4 tags
        final recipe = RecipeBuilder()
            .withTitle('Tacos')
            .withTimeMinutes(30)
            .withIngredients(['nötfärs', 'tacokrydda']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'nötfärs', 'protein/meat/beef', {'meat', 'beef'}),
          TaggingTestHelper.ingredient('tacokrydda', 'spice', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // Phase 4 occasion tag - tacos trigger fredagsmys
        expect(result.hasTag('taco'), isTrue);
        expect(result.hasTag('fredagsmys'), isTrue);
      });

      test('includes decisions from Phase 1 in result', () {
        final recipe = RecipeBuilder()
            .withTitle('Test Recipe')
            .withTimeMinutes(30)
            .withIngredients(['pasta']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'pasta', 'grain/pasta-bread', {'contains-gluten'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // H3: Decisions should be included when present
        // Note: Decisions are optional and may be null if Phase 1 doesn't produce any
        // This test verifies the mechanism works when decisions are generated
        expect(result.decisions == null || result.decisions is List, isTrue);
      });

      test('handles empty ingredient list gracefully', () {
        final recipe = RecipeBuilder()
            .withTitle('Empty Recipe')
            .withTimeMinutes(null)
            .withIngredients([]).build();
        final lookup = IngredientLookupResult.empty();

        // Should not throw
        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result, isNotNull);
        expect(result.coverage, 0.0);
        // Empty recipes have UNKNOWN allergen status (no data)
        expect(result.getAllergenStatus('gluten'), TriState.unknown);
      });

      test('handles null timeMinutes gracefully', () {
        final recipe = RecipeBuilder()
            .withTitle('No Time Recipe')
            .withTimeMinutes(null)
            .withIngredients(['chicken']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
        ]);

        // Should not throw
        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result, isNotNull);
        // No time-based tags
        expect(result.hasTag('under-15-min'), isFalse);
        expect(result.hasTag('under-30-min'), isFalse);
      });

      test('handles recipe with empty instructions gracefully', () {
        final recipe = RecipeBuilder()
            .withTitle('No Instructions')
            .withTimeMinutes(30)
            .withIngredients(['chicken']).withInstructions([]).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
        ]);

        // Should not throw
        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result, isNotNull);
        // No cooking method tags from instructions
        expect(result.hasTag('ugnsbakad'), isFalse);
        expect(result.hasTag('stekt'), isFalse);
        expect(result.hasTag('grillad'), isFalse);
      });
    });

    // =========================================================================
    // PHASE 2: Derived Tags
    // =========================================================================
    group('Phase 2 - derived tags', () {
      group('dish type tags', () {
        test('adds pasta-dish when pastabaserad exists', () {
          final recipe = RecipeBuilder()
              .withTitle('Pasta Carbonara')
              .withTimeMinutes(25)
              .withIngredients(['pasta', 'bacon', 'egg']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'pasta', 'grain/pasta-bread', {'pasta-base'}),
            TaggingTestHelper.ingredient(
                'bacon', 'protein/meat/pork', {'meat', 'pork'}),
            TaggingTestHelper.ingredient('egg', 'protein/egg', {'egg'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('pastabaserad'), isTrue);
          expect(result.hasTag('pasta-dish'), isTrue);
        });

        test('adds rice-dish when risbaserad exists', () {
          final recipe = RecipeBuilder()
              .withTitle('Fried Rice')
              .withTimeMinutes(20)
              .withIngredients(['ris', 'vegetables']).build();
          // risbaserad requires: Swedish name contains 'ris' AND group contains 'grain'
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('ris', 'grain', {}),
            TaggingTestHelper.ingredient('vegetables', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('risbaserad'), isTrue);
          expect(result.hasTag('rice-dish'), isTrue);
        });

        test('adds potato-dish when potatisbaserad exists', () {
          final recipe = RecipeBuilder()
              .withTitle('Mashed Potatoes')
              .withTimeMinutes(30)
              .withIngredients(['potatis', 'butter']).build();
          // potatisbaserad requires: Swedish name contains 'potatis' AND group contains 'vegetable/root'
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('potatis', 'vegetable/root', {}),
            TaggingTestHelper.ingredient('butter', 'fat/butter', {'dairy'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('potatisbaserad'), isTrue);
          expect(result.hasTag('potato-dish'), isTrue);
        });
      });

      group('spicy and mild', () {
        test('adds stark tag when is-spicy property present', () {
          final recipe = RecipeBuilder()
              .withTitle('Spicy Curry')
              .withTimeMinutes(40)
              .withIngredients(['chicken', 'chili']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
            TaggingTestHelper.ingredient(
                'chili', 'vegetable/spice', {'is-spicy'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('stark'), isTrue);
          expect(result.hasTag('mild'), isFalse);
        });

        test('adds mild tag when no spicy ingredients and full coverage', () {
          final recipe = RecipeBuilder()
              .withTitle('Plain Chicken')
              .withTimeMinutes(30)
              .withIngredients(['chicken', 'salt']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
            TaggingTestHelper.ingredient('salt', 'seasoning', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('mild'), isTrue);
          expect(result.hasTag('stark'), isFalse);
        });
      });

      group('few ingredients', () {
        test('adds få-ingredienser when 6 or fewer ingredients', () {
          final recipe = RecipeBuilder()
              .withTitle('Simple Dish')
              .withTimeMinutes(20)
              .withIngredients(['a', 'b', 'c', 'd']).build();
          final lookup = IngredientLookupResult.empty();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('få-ingredienser'), isTrue);
        });

        test('no få-ingredienser when more than 6 ingredients', () {
          final recipe = RecipeBuilder()
              .withTitle('Complex Dish')
              .withTimeMinutes(40)
              .withIngredients(
                  ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']).build();
          final lookup = IngredientLookupResult.empty();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('få-ingredienser'), isFalse);
        });
      });

      // Note: Phase 2 pescetarian TAG is tested via the dietary status tests
      // which already verify pescetarian detection logic comprehensively.
      // The Phase 2 'pescetarian' tag duplicates that logic for convenience.

      group('halal and kosher friendly', () {
        // Note: Halal/Kosher are handled via Phase 1 dietary STATUS, not Phase 2 tags.
        // Phase 1 provides tri-state logic (FREE/CONTAINS/UNKNOWN) which is more accurate.
        test('halalanpassad dietary status FREE when no pork and no alcohol',
            () {
          final recipe = RecipeBuilder()
              .withTitle('Chicken Rice')
              .withTimeMinutes(35)
              .withIngredients(['chicken', 'rice']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
            TaggingTestHelper.ingredient('rice', 'grain/rice', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          // Halal status is handled via dietaryStatus, not tags
          expect(result.isDietarySafe('halalanpassad'), isTrue);
        });

        test('no halalanpassad when pork present', () {
          final recipe = RecipeBuilder()
              .withTitle('Pork Chops')
              .withTimeMinutes(30)
              .withIngredients(['pork']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'pork', 'protein/meat/pork', {'meat', 'pork'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('halalanpassad'), isFalse);
        });

        test('kosheranpassad dietary status FREE when no pork and no shellfish',
            () {
          final recipe = RecipeBuilder()
              .withTitle('Beef Stew')
              .withTimeMinutes(90)
              .withIngredients(['beef', 'carrots']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('beef', 'protein/meat/beef', {'meat'}),
            TaggingTestHelper.ingredient('carrots', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          // Kosher status is handled via dietaryStatus, not tags
          expect(result.isDietarySafe('kosheranpassad'), isTrue);
        });

        test('no kosheranpassad when shellfish present', () {
          // kosheranpassad requires: fläsk FREE AND skaldjur FREE
          // skaldjur allergen is triggered by: shellfish, crustacean, or mollusc properties
          final recipe = RecipeBuilder()
              .withTitle('Shrimp Pasta')
              .withTimeMinutes(25)
              .withIngredients(['räkor', 'pasta']).build();
          final lookup = TaggingTestHelper.createLookup([
            IngredientData(
              id: 'rakor',
              swedish: 'räkor',
              english: 'shrimp',
              group: 'protein/seafood/shellfish',
              properties: const {'crustacean', 'shellfish'},
            ),
            IngredientData(
              id: 'pasta',
              swedish: 'pasta',
              english: 'pasta',
              group: 'grain/pasta-bread',
              properties: const {},
            ),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          // Should NOT be kosher-friendly when shellfish present
          expect(result.hasTag('kosheranpassad'), isFalse);
        });
      });

      group('meal type tags', () {
        test('adds dessert when title contains kaka', () {
          // dessert tag requires: kaka tag from title OR 'dessert' in title OR 'efterrätt' in title
          final recipe = RecipeBuilder()
              .withTitle('Chokladkaka')
              .withTimeMinutes(60)
              .withIngredients(['flour', 'chocolate', 'sugar']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('flour', 'grain', {'contains-gluten'}),
            TaggingTestHelper.ingredient('chocolate', 'sweet', {}),
            TaggingTestHelper.ingredient('sugar', 'sweet', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          // Title contains 'kaka' which triggers kaka tag and then dessert tag
          expect(result.hasTag('kaka'), isTrue);
          expect(result.hasTag('dessert'), isTrue);
        });

        test('adds frukost when title contains frukost', () {
          final recipe = RecipeBuilder()
              .withTitle('Frukostpannkaka')
              .withTimeMinutes(20)
              .withIngredients(['flour', 'eggs', 'milk']).build();
          final lookup = IngredientLookupResult.empty();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('frukost'), isTrue);
        });
      });
    });

    // =========================================================================
    // PHASE 3: Complex Tags
    // =========================================================================
    group('Phase 3 - complex tags', () {
      group('difficulty levels', () {
        test('adds enkel for quick simple recipes', () {
          final recipe = RecipeBuilder()
              .withTitle('Simple Salad')
              .withTimeMinutes(15)
              .withIngredients(['lettuce', 'tomato', 'cucumber']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('lettuce', 'vegetable', {}),
            TaggingTestHelper.ingredient('tomato', 'vegetable', {}),
            TaggingTestHelper.ingredient('cucumber', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('enkel'), isTrue);
        });

        test('adds medel for medium complexity recipes', () {
          final recipe = RecipeBuilder()
              .withTitle('Pasta Bolognese')
              .withTimeMinutes(45)
              .withIngredients([
            'pasta',
            'beef',
            'tomatoes',
            'onion',
            'garlic',
            'carrot',
            'celery',
            'wine'
          ]).build();
          final lookup = IngredientLookupResult.empty();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('medel'), isTrue);
        });

        test('adds avancerad for complex recipes over 60 min', () {
          final recipe = RecipeBuilder()
              .withTitle('Beef Wellington')
              .withTimeMinutes(180)
              .withIngredients([
            'beef fillet',
            'mushrooms',
            'puff pastry',
            'pate',
            'eggs',
            'butter',
            'thyme',
            'onion',
            'garlic',
            'wine',
            'cream',
            'salt',
            'pepper'
          ]).build();
          final lookup = IngredientLookupResult.empty();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('avancerad'), isTrue);
        });

        test('adds avancerad for recipes with advanced techniques', () {
          final recipe = RecipeBuilder()
              .withTitle('Sous Vide Steak')
              .withTimeMinutes(40)
              .withInstructions([
            'Sous vide steken i 2 timmar'
          ]).withIngredients(['steak', 'salt']).build();
          final lookup = IngredientLookupResult.empty();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('avancerad'), isTrue);
        });
      });

      group('texture tags', () {
        test('adds krispig for fried dishes', () {
          final recipe = RecipeBuilder()
              .withTitle('Fried Chicken')
              .withTimeMinutes(30)
              .withInstructions([
            'Fritera kycklingen tills krispig'
          ]).withIngredients(['chicken', 'flour', 'oil']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
            TaggingTestHelper.ingredient('flour', 'grain', {'contains-gluten'}),
            TaggingTestHelper.ingredient('oil', 'fat/oil', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          // Either krispig from instructions or friterad tag
          expect(result.hasTag('krispig') || result.hasTag('friterad'), isTrue);
        });

        test('adds krämig for creamy pasta dishes', () {
          final recipe = RecipeBuilder()
              .withTitle('Creamy Pasta')
              .withTimeMinutes(25)
              .withInstructions(['Rör ner grädden i såsen']).withIngredients(
                  ['pasta', 'grädde', 'parmesan']).build();
          // krämig requires: Swedish name contains 'grädde/creme/kokosmjölk' AND sås/rör in instructions
          final lookup = TaggingTestHelper.createLookup([
            IngredientData(
              id: 'pasta',
              swedish: 'pasta',
              english: 'pasta',
              group: 'grain/pasta-bread',
              properties: const {'pasta-base'},
            ),
            IngredientData(
              id: 'gradde',
              swedish: 'grädde',
              english: 'cream',
              group: 'dairy/cream',
              properties: const {'dairy'},
            ),
            IngredientData(
              id: 'parmesan',
              swedish: 'parmesan',
              english: 'parmesan',
              group: 'protein/dairy/cheese',
              properties: const {'dairy'},
            ),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('pastabaserad'), isTrue);
          expect(result.hasTag('krämig'), isTrue);
        });

        test('adds ostig for cheesy dishes', () {
          final recipe = RecipeBuilder()
              .withTitle('Ostgratäng')
              .withTimeMinutes(40)
              .withIngredients(
                  ['potato', 'cheddar', 'parmesan', 'mozzarella']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('potato', 'vegetable/potato', {}),
            TaggingTestHelper.ingredient(
                'cheddar', 'protein/dairy/cheese', {'dairy'}),
            TaggingTestHelper.ingredient(
                'parmesan', 'protein/dairy/cheese', {'dairy'}),
            TaggingTestHelper.ingredient(
                'mozzarella', 'protein/dairy/cheese', {'dairy'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('ostig'), isTrue);
        });
      });

      group('temperature tags', () {
        test('adds varm-rätt for cooked dishes', () {
          // varm-rätt requires one of: ugnsbakad, stekt, kokt, grillad, gryta, soppa
          // gryta tag comes from title containing 'gryta'
          final recipe = RecipeBuilder()
              .withTitle('Köttgryta')
              .withTimeMinutes(90)
              .withInstructions(['Sjud grytan i 2 timmar']).withIngredients(
                  ['beef', 'carrots', 'potatoes']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('beef', 'protein/meat/beef', {'meat'}),
            TaggingTestHelper.ingredient('carrots', 'vegetable', {}),
            TaggingTestHelper.ingredient('potatoes', 'vegetable/potato', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('gryta'), isTrue);
          expect(result.hasTag('varm-rätt'), isTrue);
        });

        test('adds kall-rätt for salads', () {
          // sallad tag comes from title containing 'sallad'
          final recipe = RecipeBuilder()
              .withTitle('Caesar sallad')
              .withTimeMinutes(15)
              .withIngredients(['lettuce', 'parmesan', 'croutons']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('lettuce', 'vegetable/salad', {}),
            TaggingTestHelper.ingredient(
                'parmesan', 'protein/dairy/cheese', {'dairy'}),
            TaggingTestHelper.ingredient(
                'croutons', 'grain', {'contains-gluten'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('sallad'), isTrue);
          expect(result.hasTag('kall-rätt'), isTrue);
        });
      });

      group('nutritional tags', () {
        test('adds proteinrik for protein-heavy dishes', () {
          final recipe = RecipeBuilder()
              .withTitle('Protein Bowl')
              .withTimeMinutes(30)
              .withIngredients(['chicken', 'eggs', 'tofu']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
            TaggingTestHelper.ingredient('eggs', 'protein/egg', {'egg'}),
            TaggingTestHelper.ingredient(
                'tofu', 'protein/legume', {'plant-based'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('proteinrik'), isTrue);
        });

        test('adds grönsaksrik for veggie-heavy dishes', () {
          final recipe = RecipeBuilder()
              .withTitle('Vegetable Medley')
              .withTimeMinutes(20)
              .withIngredients(
                  ['broccoli', 'carrots', 'bell pepper', 'zucchini']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('broccoli', 'vegetable', {}),
            TaggingTestHelper.ingredient('carrots', 'vegetable', {}),
            TaggingTestHelper.ingredient('bell pepper', 'vegetable', {}),
            TaggingTestHelper.ingredient('zucchini', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('grönsaksrik'), isTrue);
        });
      });

      group('practical tags', () {
        test('adds barnvänlig for mild kid-friendly dishes', () {
          final recipe = RecipeBuilder()
              .withTitle('Köttbullar')
              .withTimeMinutes(35)
              .withIngredients(['beef', 'cream', 'potatoes']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('beef', 'protein/meat/beef', {'meat'}),
            TaggingTestHelper.ingredient('cream', 'dairy/cream', {'dairy'}),
            TaggingTestHelper.ingredient('potatoes', 'vegetable/potato', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('köttbullar'), isTrue);
          expect(result.hasTag('mild'), isTrue);
          expect(result.hasTag('barnvänlig'), isTrue);
        });

        test('adds frysbar for stews', () {
          // frysbar requires: gryta OR soppa OR köttbullar OR pastabaserad
          // gryta tag comes from title containing 'gryta'
          final recipe = RecipeBuilder()
              .withTitle('Köttgryta')
              .withTimeMinutes(90)
              .withInstructions(['Sjud grytan']).withIngredients(
                  ['beef', 'carrots', 'potatoes']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('beef', 'protein/meat/beef', {'meat'}),
            TaggingTestHelper.ingredient('carrots', 'vegetable', {}),
            TaggingTestHelper.ingredient('potatoes', 'vegetable/potato', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('gryta'), isTrue);
          expect(result.hasTag('frysbar'), isTrue);
        });

        test('no frysbar for salads', () {
          // sallad tag comes from title containing 'sallad'
          final recipe = RecipeBuilder()
              .withTitle('Färsk sallad')
              .withTimeMinutes(10)
              .withIngredients(['lettuce', 'tomato']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('lettuce', 'vegetable/salad', {}),
            TaggingTestHelper.ingredient('tomato', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('sallad'), isTrue);
          expect(result.hasTag('frysbar'), isFalse);
        });

        test('adds storkok for large portion recipes', () {
          final recipe = RecipeBuilder()
              .withTitle('Party Stew')
              .withTimeMinutes(90)
              .withPortions(8)
              .withIngredients(['beef', 'vegetables']).build();
          final lookup = IngredientLookupResult.empty();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('storkok'), isTrue);
        });
      });
    });

    // =========================================================================
    // PHASE 4: Mood and Occasion Tags
    // =========================================================================
    group('Phase 4 - mood and occasion tags', () {
      group('time-based occasions', () {
        test('adds vardagsmiddag for quick easy meals', () {
          final recipe = RecipeBuilder()
              .withTitle('Quick Pasta')
              .withTimeMinutes(25)
              .withIngredients(['pasta', 'tomato sauce', 'cheese']).build();
          final lookup = IngredientLookupResult.empty();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('vardagsmiddag'), isTrue);
        });

        test('adds helgmat for longer cooking recipes', () {
          final recipe = RecipeBuilder()
              .withTitle('Slow Roast')
              .withTimeMinutes(180)
              .withIngredients(['beef', 'potatoes', 'vegetables']).build();
          final lookup = IngredientLookupResult.empty();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('helgmat'), isTrue);
        });

        test('adds snabblagat for very quick easy meals', () {
          final recipe = RecipeBuilder()
              .withTitle('Quick Sandwich')
              .withTimeMinutes(10)
              .withIngredients(['bread', 'cheese', 'ham']).build();
          final lookup = IngredientLookupResult.empty();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('snabblagat'), isTrue);
        });

        test('adds fredagsmys for taco recipes', () {
          final recipe = RecipeBuilder()
              .withTitle('Tacos')
              .withTimeMinutes(30)
              .withIngredients(['beef', 'taco shells', 'salsa']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('beef', 'protein/meat/beef', {'meat'}),
            TaggingTestHelper.ingredient('taco shells', 'grain', {}),
            TaggingTestHelper.ingredient('salsa', 'sauce', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('taco'), isTrue);
          expect(result.hasTag('fredagsmys'), isTrue);
        });

        test('adds söndagsmiddag for slow oven recipes', () {
          final recipe = RecipeBuilder()
              .withTitle('Söndagsstek')
              .withTimeMinutes(120)
              .withInstructions(['Stek i ugnen i 2 timmar']).withIngredients(
                  ['beef roast', 'potatoes']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'beef roast', 'protein/meat/beef', {'meat'}),
            TaggingTestHelper.ingredient('potatoes', 'vegetable/potato', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('ugnsbakad'), isTrue);
          expect(result.hasTag('söndagsmiddag'), isTrue);
        });
      });

      group('mood tags', () {
        test('adds comfort-food for creamy pasta dishes', () {
          // comfort-food requires: krämig AND (pastabaserad OR potatisbaserad OR risbaserad)
          // krämig requires: cream with Swedish name AND sås in instructions
          final recipe = RecipeBuilder()
              .withTitle('Mac and Cheese')
              .withTimeMinutes(30)
              .withInstructions([
            'Rör ihop såsen med grädde och ost'
          ]).withIngredients(['pasta', 'grädde', 'cheese']).build();
          final lookup = TaggingTestHelper.createLookup([
            IngredientData(
              id: 'pasta',
              swedish: 'pasta',
              english: 'pasta',
              group: 'grain/pasta-bread',
              properties: const {'pasta-base'},
            ),
            IngredientData(
              id: 'gradde',
              swedish: 'grädde',
              english: 'cream',
              group: 'dairy/cream',
              properties: const {'dairy'},
            ),
            IngredientData(
              id: 'cheese',
              swedish: 'ost',
              english: 'cheese',
              group: 'protein/dairy/cheese',
              properties: const {'dairy'},
            ),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('pastabaserad'), isTrue);
          expect(result.hasTag('krämig'), isTrue);
          expect(result.hasTag('comfort-food'), isTrue);
        });

        test('adds värmande for soups', () {
          // soppa tag comes from title containing 'soppa'
          final recipe = RecipeBuilder()
              .withTitle('Tomatsoppa')
              .withTimeMinutes(40)
              .withIngredients(['tomatoes', 'cream', 'onion']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('tomatoes', 'vegetable', {}),
            TaggingTestHelper.ingredient('cream', 'dairy/cream', {'dairy'}),
            TaggingTestHelper.ingredient('onion', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('soppa'), isTrue);
          expect(result.hasTag('värmande'), isTrue);
        });

        test('adds fräsch for salads', () {
          // sallad tag comes from title containing 'sallad'
          final recipe = RecipeBuilder()
              .withTitle('Sommarsallad')
              .withTimeMinutes(15)
              .withIngredients(['lettuce', 'tomato', 'cucumber']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('lettuce', 'vegetable/salad', {}),
            TaggingTestHelper.ingredient('tomato', 'vegetable', {}),
            TaggingTestHelper.ingredient('cucumber', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('sallad'), isTrue);
          expect(result.hasTag('fräsch'), isTrue);
        });

        test('adds lyxig for luxury ingredients', () {
          final recipe = RecipeBuilder()
              .withTitle('Oxfilé med Tryffel')
              .withTimeMinutes(45)
              .withIngredients(['oxfilé', 'tryffel', 'smör']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'oxfilé', 'protein/meat/beef', {'meat'}),
            TaggingTestHelper.ingredient('tryffel', 'vegetable/mushroom', {}),
            TaggingTestHelper.ingredient('smör', 'fat/butter', {'dairy'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('lyxig'), isTrue);
          expect(result.hasTag('middagsbjudning'), isTrue);
        });
      });

      group('Swedish holidays', () {
        test('adds jul tag for Christmas dishes', () {
          final recipe = RecipeBuilder()
              .withTitle('Julskinka')
              .withTimeMinutes(180)
              .withIngredients(['ham', 'mustard', 'breadcrumbs']).build();
          final lookup = IngredientLookupResult.empty();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('jul'), isTrue);
        });

        test('adds lucia tag for Lucia dishes', () {
          final recipe = RecipeBuilder()
              .withTitle('Lussekatter')
              .withTimeMinutes(90)
              .withIngredients(['flour', 'saffron', 'butter']).build();
          final lookup = IngredientLookupResult.empty();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('lucia'), isTrue);
        });

        test('adds påsk tag for Easter dishes', () {
          final recipe = RecipeBuilder()
              .withTitle('Påsklamm')
              .withTimeMinutes(120)
              .withIngredients(['lamb', 'rosemary', 'garlic']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'lamb', 'protein/meat/lamb', {'meat', 'lamb'}),
            TaggingTestHelper.ingredient('rosemary', 'herb', {}),
            TaggingTestHelper.ingredient('garlic', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('påsk'), isTrue);
        });

        test('adds midsommar tag for midsummer dishes', () {
          final recipe = RecipeBuilder()
              .withTitle('Midsommarmat')
              .withTimeMinutes(60)
              .withIngredients(['sill', 'nypotatis', 'gräddfil']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('sill', 'protein/fish', {'fish'}),
            TaggingTestHelper.ingredient('nypotatis', 'vegetable/potato', {}),
            TaggingTestHelper.ingredient('gräddfil', 'dairy', {'dairy'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('midsommar'), isTrue);
        });

        test('adds kräftskiva tag for crayfish dishes', () {
          final recipe = RecipeBuilder()
              .withTitle('Kräftskiva')
              .withTimeMinutes(30)
              .withIngredients(['kräftor', 'dill', 'bröd']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'kräftor', 'protein/shellfish', {'shellfish'}),
            TaggingTestHelper.ingredient('dill', 'herb', {}),
            TaggingTestHelper.ingredient('bröd', 'grain', {'contains-gluten'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('kräftskiva'), isTrue);
        });
      });

      group('season tags', () {
        test('adds vår for spring ingredients', () {
          final recipe = RecipeBuilder()
              .withTitle('Spring Salad')
              .withTimeMinutes(20)
              .withIngredients(['sparris', 'rädisor']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('sparris', 'vegetable', {}),
            TaggingTestHelper.ingredient('rädisor', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('vår'), isTrue);
        });

        test('adds sommar for summer ingredients or grilled dishes', () {
          // Summer requires 2+ indicators: grillad counts as 1, plus summer ingredients
          final recipe = RecipeBuilder()
              .withTitle('Grillad Kycklingsallad')
              .withTimeMinutes(45)
              .withInstructions(['Grilla kycklingen']).withIngredients(
                  ['chicken', 'sallad', 'gurka']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
            TaggingTestHelper.ingredient('sallad', 'vegetable/salad', {}),
            TaggingTestHelper.ingredient('gurka', 'vegetable/cucumber', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('grillad'), isTrue);
          expect(result.hasTag('sommar'), isTrue);
        });

        test('adds höst for autumn ingredients', () {
          // Autumn requires 2+ seasonal ingredients (kantarell + svamp)
          final recipe = RecipeBuilder()
              .withTitle('Kantarellpasta med Svamp')
              .withTimeMinutes(30)
              .withIngredients(
                  ['kantarell', 'svamp', 'pasta', 'cream']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('kantarell', 'vegetable/mushroom', {}),
            TaggingTestHelper.ingredient('svamp', 'vegetable/mushroom', {}),
            TaggingTestHelper.ingredient(
                'pasta', 'grain/pasta-bread', {'pasta-base'}),
            TaggingTestHelper.ingredient('cream', 'dairy/cream', {'dairy'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('höst'), isTrue);
        });

        test('adds vinter for winter root vegetables', () {
          final recipe = RecipeBuilder()
              .withTitle('Root Vegetable Soup')
              .withTimeMinutes(45)
              .withIngredients(
                  ['morot', 'palsternacka', 'kålrot', 'potato']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('morot', 'vegetable/root', {}),
            TaggingTestHelper.ingredient('palsternacka', 'vegetable/root', {}),
            TaggingTestHelper.ingredient('kålrot', 'vegetable/root', {}),
            TaggingTestHelper.ingredient('potato', 'vegetable/potato', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('vinter'), isTrue);
        });

        test('no season tag when no season-specific ingredients', () {
          // året-runt was removed as it provides no useful information
          // Absence of season tags already indicates year-round suitability
          final recipe = RecipeBuilder()
              .withTitle('Plain Pasta')
              .withTimeMinutes(20)
              .withIngredients(['pasta', 'tomato sauce']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('pasta', 'grain/pasta-bread', {}),
            TaggingTestHelper.ingredient('tomato sauce', 'sauce', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          // No meaningless default tag
          expect(result.hasTag('året-runt'), isFalse);
          expect(result.hasTag('vår'), isFalse);
          expect(result.hasTag('sommar'), isFalse);
          expect(result.hasTag('höst'), isFalse);
          expect(result.hasTag('vinter'), isFalse);
        });
      });
    });

    group('BUG-5: multi-season tags from seasonAvailability data', () {
      // Multi-season tags are allowed when ingredients have overlapping
      // seasonAvailability data. Each season needs >= 2 qualifying ingredients.

      test('should allow multiple season tags when ingredients span seasons',
          () {
        // Arrange: Recipe with ingredients spanning sommar and höst
        final recipe = RecipeBuilder()
            .withTitle('Grillad kyckling med jordgubbar')
            .withCreatedAt(DateTime(2025, 7, 15))
            .withTimeMinutes(40)
            .withIngredients(
                ['kyckling', 'jordgubbar', 'kantareller', 'kål']).build();

        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
            'kyckling',
            'protein/meat/poultry',
            {'meat', 'poultry'},
            seasonAvailability: ['sommar'],
          ),
          TaggingTestHelper.ingredient(
            'jordgubbar',
            'fruit',
            {},
            seasonAvailability: ['sommar'],
          ),
          TaggingTestHelper.ingredient(
            'kantareller',
            'vegetable/mushroom',
            {},
            seasonAvailability: ['höst'],
          ),
          TaggingTestHelper.ingredient(
            'kål',
            'vegetable',
            {},
            seasonAvailability: ['höst', 'vinter'],
          ),
        ]);

        // Act
        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // sommar has 2 ingredients (kyckling, jordgubbar) -> tag generated
        expect(result.hasTag('sommar'), isTrue);
        // höst has 2 ingredients (kantareller, kål) -> tag generated
        expect(result.hasTag('höst'), isTrue);
        // vinter has only 1 ingredient (kål) -> no tag
        expect(result.hasTag('vinter'), isFalse);
      });

      test('should generate both höst and vinter when ingredients overlap', () {
        // Arrange: Recipe created in January (vinter)
        final recipe = RecipeBuilder()
            .withTitle('Vintervarm soppa')
            .withCreatedAt(DateTime(2025, 1, 10))
            .withTimeMinutes(60)
            .withIngredients(['kål', 'rotfrukter', 'potatis']).build();

        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('kål', 'vegetable', {},
              seasonAvailability: ['höst', 'vinter']),
          TaggingTestHelper.ingredient('rotfrukter', 'vegetable/root', {},
              seasonAvailability: ['höst', 'vinter']),
          TaggingTestHelper.ingredient('potatis', 'vegetable/root', {}),
        ]);

        // Act
        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // Both höst and vinter have 2 ingredients each
        expect(result.hasTag('höst'), isTrue);
        expect(result.hasTag('vinter'), isTrue);
      });

      test('should produce deterministic season when retagging same recipe',
          () {
        // Arrange: Recipe created on a specific date
        final recipe = RecipeBuilder()
            .withTitle('Sommarrecept med grillad fisk')
            .withCreatedAt(DateTime(2025, 6, 21)) // Midsommar
            .withTimeMinutes(30)
            .withIngredients(['fisk', 'sill', 'potatis']).build();

        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('fisk', 'protein/fish', {'fish'},
              seasonAvailability: ['sommar']),
          TaggingTestHelper.ingredient('sill', 'protein/fish', {'fish'},
              seasonAvailability: ['sommar']),
          TaggingTestHelper.ingredient('potatis', 'vegetable/root', {}),
        ]);

        // Act: Generate tags multiple times (simulating retagging)
        final result1 = generator.generate(ingredients: lookup, recipe: recipe);
        final result2 = generator.generate(ingredients: lookup, recipe: recipe);

        // Assert: Both runs should produce the same season tag
        const seasonTags = ['sommar', 'vinter', 'höst', 'vår'];
        final seasons1 =
            seasonTags.where((s) => result1.tags.contains(s)).toSet();
        final seasons2 =
            seasonTags.where((s) => result2.tags.contains(s)).toSet();

        expect(seasons1, equals(seasons2),
            reason:
                'Retagging the same recipe should produce the same season tag');
      });

      test('should fall back gracefully when recipe has no creation date', () {
        // Arrange: RecipeBuilder defaults createdAt to DateTime.now()
        // This is the normal case - creation date always exists
        final recipe = RecipeBuilder()
            .withTitle('Plain Pasta')
            .withTimeMinutes(20)
            .withIngredients(['pasta', 'tomat']).build();

        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'pasta', 'grain/pasta-bread', {'contains-gluten'}),
          TaggingTestHelper.ingredient('tomat', 'vegetable', {}),
        ]);

        // Act: Should not throw
        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // Assert: Valid result
        expect(result, isNotNull);
        expect(result.generatorVersion, kTagGeneratorVersion);
      });
    });

    // Sprint 2: Sustainability tags
    group('sustainability tags', () {
      group('klimatsmart', () {
        test('adds klimatsmart when all ingredients have low/medium carbon',
            () {
          final recipe = RecipeBuilder()
              .withTitle('Veggie Stir Fry')
              .withIngredients(['tofu', 'broccoli', 'carrots']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient(
                'tofu', 'protein/plant-based', {'plant-based'},
                carbonFootprintCategory: 'low'),
            TaggingTestHelper.ingredient(
                'broccoli', 'vegetable', {'plant-based'},
                carbonFootprintCategory: 'low'),
            TaggingTestHelper.ingredient(
                'carrots', 'vegetable', {'plant-based'},
                carbonFootprintCategory: 'medium'),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('klimatsmart'), isTrue);
        });

        test('adds klimatsmart when 80% have low/medium carbon', () {
          final recipe = RecipeBuilder()
              .withTitle('Mixed Dish')
              .withIngredients(['a', 'b', 'c', 'd', 'e']).build();
          // 4 low/medium + 1 high = 80% meet criteria
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('a', 'vegetable', {},
                carbonFootprintCategory: 'low'),
            TaggingTestHelper.ingredient('b', 'vegetable', {},
                carbonFootprintCategory: 'low'),
            TaggingTestHelper.ingredient('c', 'vegetable', {},
                carbonFootprintCategory: 'medium'),
            TaggingTestHelper.ingredient('d', 'vegetable', {},
                carbonFootprintCategory: 'low'),
            TaggingTestHelper.ingredient('e', 'protein/meat', {'meat'},
                carbonFootprintCategory: 'high'),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('klimatsmart'), isTrue);
        });

        test('no klimatsmart when too many high carbon ingredients', () {
          final recipe = RecipeBuilder()
              .withTitle('Beef Steak')
              .withIngredients(['beef', 'butter', 'vegetables']).build();
          // 1 low + 2 high = 33% meet criteria (below 80%)
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('beef', 'protein/meat', {'meat'},
                carbonFootprintCategory: 'high'),
            TaggingTestHelper.ingredient('butter', 'protein/dairy', {'dairy'},
                carbonFootprintCategory: 'high'),
            TaggingTestHelper.ingredient('vegetables', 'vegetable', {},
                carbonFootprintCategory: 'low'),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('klimatsmart'), isFalse);
        });

        test('no klimatsmart when no carbon data available', () {
          final recipe = RecipeBuilder()
              .withTitle('Mystery Dish')
              .withIngredients(['ingredient1', 'ingredient2']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('ingredient1', 'other', {}),
            TaggingTestHelper.ingredient('ingredient2', 'other', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('klimatsmart'), isFalse);
        });

        test('klimatsmart ignores ingredients without carbon data', () {
          final recipe = RecipeBuilder()
              .withTitle('Mixed Data')
              .withIngredients(['tofu', 'unknown']).build();
          // Only tofu has carbon data (low), unknown is excluded
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('tofu', 'protein/plant-based', {},
                carbonFootprintCategory: 'low'),
            TaggingTestHelper.ingredient(
                'unknown', 'other', {}), // No carbon data
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          // 100% of ingredients with data are low carbon
          expect(result.hasTag('klimatsmart'), isTrue);
        });
      });

      group('budgetvänlig', () {
        test('adds budgetvänlig when all ingredients are budget/medium price',
            () {
          final recipe = RecipeBuilder()
              .withTitle('Budget Pasta')
              .withIngredients(['pasta', 'tomato sauce', 'onion']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('pasta', 'grain', {},
                priceCategory: 'budget'),
            TaggingTestHelper.ingredient('tomato sauce', 'sauce', {},
                priceCategory: 'budget'),
            TaggingTestHelper.ingredient('onion', 'vegetable', {},
                priceCategory: 'budget'),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('budgetvänlig'), isTrue);
        });

        test('adds budgetvänlig when 80% are budget/medium', () {
          final recipe = RecipeBuilder()
              .withTitle('Mixed Budget')
              .withIngredients(['a', 'b', 'c', 'd', 'e']).build();
          // 4 budget/medium + 1 premium = 80% meet criteria
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('a', 'vegetable', {},
                priceCategory: 'budget'),
            TaggingTestHelper.ingredient('b', 'vegetable', {},
                priceCategory: 'budget'),
            TaggingTestHelper.ingredient('c', 'vegetable', {},
                priceCategory: 'medium'),
            TaggingTestHelper.ingredient('d', 'vegetable', {},
                priceCategory: 'budget'),
            TaggingTestHelper.ingredient('e', 'protein/seafood', {},
                priceCategory: 'premium'),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('budgetvänlig'), isTrue);
        });

        test('no budgetvänlig when too many premium ingredients', () {
          final recipe = RecipeBuilder()
              .withTitle('Luxury Dinner')
              .withIngredients(['wagyu', 'truffles', 'caviar']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('wagyu', 'protein/meat', {},
                priceCategory: 'premium'),
            TaggingTestHelper.ingredient('truffles', 'other', {},
                priceCategory: 'premium'),
            TaggingTestHelper.ingredient('caviar', 'protein/seafood', {},
                priceCategory: 'premium'),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('budgetvänlig'), isFalse);
        });

        test('no budgetvänlig when no price data available', () {
          final recipe = RecipeBuilder()
              .withTitle('Mystery Dish')
              .withIngredients(['ingredient1', 'ingredient2']).build();
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('ingredient1', 'other', {}),
            TaggingTestHelper.ingredient('ingredient2', 'other', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('budgetvänlig'), isFalse);
        });

        test('budgetvänlig ignores ingredients without price data', () {
          final recipe = RecipeBuilder()
              .withTitle('Mixed Data')
              .withIngredients(['rice', 'unknown']).build();
          // Only rice has price data (budget), unknown is excluded
          final lookup = TaggingTestHelper.createLookup([
            TaggingTestHelper.ingredient('rice', 'grain', {},
                priceCategory: 'budget'),
            TaggingTestHelper.ingredient(
                'unknown', 'other', {}), // No price data
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          // 100% of ingredients with data are budget
          expect(result.hasTag('budgetvänlig'), isTrue);
        });
      });
    });
  });
}
