import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/tag_generator.dart';

import '../../../infrastructure/builders/recipe_builder.dart';

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
        final lookup = _createEmptyLookup();

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
        final lookup = _createEmptyLookup();

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
        final lookup = _createEmptyLookup();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('under-60-min'), isFalse);
        expect(result.hasTag('över-60-min'), isTrue);
      });

      test('no time tags for null timeMinutes', () {
        final recipe = RecipeBuilder()
            .withTitle('No Time Recipe')
            .withTimeMinutes(null)
            .withIngredients(['something']).build();
        final lookup = _createEmptyLookup();

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
        final lookup = _createLookup([
          _ingredient('pasta', 'grain/pasta-bread', {'contains-gluten'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getAllergenStatus('gluten'), TriState.contains);
      });

      test('FREE when 100% coverage and no allergen', () {
        final recipe =
            RecipeBuilder().withTitle('Rice').withIngredients(['rice']).build();
        final lookup = _createLookup([
          _ingredient('rice', 'grain', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getAllergenStatus('gluten'), TriState.free);
      });

      test('UNKNOWN when coverage < 100%', () {
        final recipe = RecipeBuilder()
            .withTitle('Mystery Dish')
            .withIngredients(['rice', 'unknown']).build();
        final lookup = IngredientLookupResult.fromLists(
          matched: [_ingredient('rice', 'grain', {})],
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
        final lookup = _createLookup([
          _ingredient('cream', 'protein/dairy', {'dairy'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getAllergenStatus('mjölk'), TriState.contains);
      });

      test('egg allergen detected from egg property', () {
        final recipe = RecipeBuilder()
            .withTitle('Omelette')
            .withIngredients(['eggs']).build();
        final lookup = _createLookup([
          _ingredient('eggs', 'protein/egg', {'egg'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getAllergenStatus('ägg'), TriState.contains);
      });

      group('combined allergens (nötter, skaldjur)', () {
        test('nötter CONTAINS when has tree-nut', () {
          final recipe = RecipeBuilder()
              .withTitle('Walnut Salad')
              .withIngredients(['valnötter', 'sallad']).build();
          final lookup = _createLookup([
            _ingredient('valnötter', 'nuts/tree-nut', {'tree-nut'}),
            _ingredient('sallad', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getAllergenStatus('nötter'), TriState.contains);
        });

        test('nötter CONTAINS when has peanut', () {
          final recipe = RecipeBuilder()
              .withTitle('Peanut Butter Toast')
              .withIngredients(['jordnötssmör', 'bröd']).build();
          final lookup = _createLookup([
            _ingredient('jordnötssmör', 'nuts/peanut', {'peanut'}),
            _ingredient('bröd', 'grain/bread', {'contains-gluten'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getAllergenStatus('nötter'), TriState.contains);
        });

        test('nötter CONTAINS when has both tree-nut AND peanut', () {
          final recipe = RecipeBuilder()
              .withTitle('Mixed Nut Butter')
              .withIngredients(['jordnötter', 'mandlar']).build();
          final lookup = _createLookup([
            _ingredient('jordnötter', 'nuts/peanut', {'peanut'}),
            _ingredient('mandlar', 'nuts/tree-nut', {'tree-nut'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getAllergenStatus('nötter'), TriState.contains);
        });

        test('nötter FREE when no nuts at full coverage', () {
          final recipe = RecipeBuilder()
              .withTitle('Plain Pasta')
              .withIngredients(['pasta', 'tomatsås']).build();
          final lookup = _createLookup([
            _ingredient('pasta', 'grain/pasta-bread', {'contains-gluten'}),
            _ingredient('tomatsås', 'sauce', {}),
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
              _ingredient('mjöl', 'grain', {'contains-gluten'}),
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
          final lookup = _createLookup([
            _ingredient('hummer', 'protein/seafood/shellfish',
                {'shellfish', 'crustacean'}),
            _ingredient('grädde', 'protein/dairy', {'dairy'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getAllergenStatus('skaldjur'), TriState.contains);
        });

        test('skaldjur CONTAINS when has crustacean', () {
          final recipe = RecipeBuilder()
              .withTitle('Shrimp Scampi')
              .withIngredients(['räkor', 'vitlök']).build();
          final lookup = _createLookup([
            _ingredient('räkor', 'protein/seafood/shellfish', {'crustacean'}),
            _ingredient('vitlök', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getAllergenStatus('skaldjur'), TriState.contains);
        });

        test('skaldjur CONTAINS when has mollusc', () {
          final recipe = RecipeBuilder()
              .withTitle('Mussel Pot')
              .withIngredients(['blåmusslor', 'vin']).build();
          final lookup = _createLookup([
            _ingredient('blåmusslor', 'protein/seafood/shellfish', {'mollusc'}),
            _ingredient('vin', 'liquid', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getAllergenStatus('skaldjur'), TriState.contains);
        });

        test('skaldjur FREE when only fish (no shellfish)', () {
          final recipe = RecipeBuilder()
              .withTitle('Salmon Dinner')
              .withIngredients(['lax', 'potatis']).build();
          final lookup = _createLookup([
            _ingredient('lax', 'protein/seafood/fish', {'fish'}),
            _ingredient('potatis', 'vegetable/root', {}),
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
        final lookup = _createLookup([
          _ingredient('tofu', 'protein/plant-based', {'plant-based'}),
          _ingredient('vegetables', 'vegetable', {'plant-based'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getDietaryStatus('vegetarisk'), TriState.free);
      });

      test('vegetarisk CONTAINS when has meat', () {
        final recipe = RecipeBuilder()
            .withTitle('Chicken Stir Fry')
            .withIngredients(['chicken']).build();
        final lookup = _createLookup([
          _ingredient('chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getDietaryStatus('vegetarisk'), TriState.contains);
      });

      test('vegansk CONTAINS when has animal products', () {
        final recipe = RecipeBuilder()
            .withTitle('Creamy Pasta')
            .withIngredients(['pasta', 'cream']).build();
        final lookup = _createLookup([
          _ingredient('pasta', 'grain/pasta-bread', {'contains-gluten'}),
          _ingredient('cream', 'protein/dairy', {'dairy', 'animal-product'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getDietaryStatus('vegansk'), TriState.contains);
      });

      test('vegansk FREE when fully plant-based', () {
        final recipe = RecipeBuilder()
            .withTitle('Vegan Bowl')
            .withIngredients(['tofu', 'rice', 'vegetables']).build();
        final lookup = _createLookup([
          _ingredient('tofu', 'protein/plant-based', {'plant-based'}),
          _ingredient('rice', 'grain', {'plant-based'}),
          _ingredient('vegetables', 'vegetable', {'plant-based'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getDietaryStatus('vegansk'), TriState.free);
      });

      group('pescetarian', () {
        test('FREE when has fish and no meat', () {
          final recipe = RecipeBuilder()
              .withTitle('Salmon Salad')
              .withIngredients(['lax', 'sallad']).build();
          final lookup = _createLookup([
            _ingredient('lax', 'protein/seafood/fish', {'fish', 'seafood'}),
            _ingredient('sallad', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('pescetarian'), TriState.free);
        });

        test('FREE when has shellfish and no meat', () {
          final recipe = RecipeBuilder()
              .withTitle('Shrimp Pasta')
              .withIngredients(['räkor', 'pasta']).build();
          final lookup = _createLookup([
            _ingredient('räkor', 'protein/seafood/shellfish',
                {'shellfish', 'crustacean', 'seafood'}),
            _ingredient('pasta', 'grain/pasta-bread', {'contains-gluten'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('pescetarian'), TriState.free);
        });

        test('UNKNOWN when no fish AND no meat (vegetarian side dish)', () {
          // CRITICAL: A vegetable dish is UNKNOWN for pescetarian, not CONTAINS
          // It could be a side dish for a pescetarian meal
          final recipe = RecipeBuilder()
              .withTitle('Garden Salad')
              .withIngredients(['sallad', 'tomat', 'gurka']).build();
          final lookup = _createLookup([
            _ingredient('sallad', 'vegetable', {}),
            _ingredient('tomat', 'vegetable', {}),
            _ingredient('gurka', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          // Should be UNKNOWN, not CONTAINS - this was the bug we fixed
          expect(result.getDietaryStatus('pescetarian'), TriState.unknown);
        });

        test('CONTAINS when has meat (even with fish)', () {
          final recipe = RecipeBuilder()
              .withTitle('Surf and Turf')
              .withIngredients(['biff', 'räkor']).build();
          final lookup = _createLookup([
            _ingredient('biff', 'protein/meat/beef', {'meat', 'beef'}),
            _ingredient('räkor', 'protein/seafood/shellfish',
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
              _ingredient('lax', 'protein/seafood/fish', {'fish', 'seafood'}),
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
          final lookup = _createLookup([
            _ingredient('lamm', 'protein/meat/lamb', {'meat', 'lamb'}),
            _ingredient('ris', 'grain', {}),
            _ingredient('curry', 'spice', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('halalanpassad'), TriState.free);
        });

        test('CONTAINS when has pork', () {
          final recipe = RecipeBuilder()
              .withTitle('Pork Roast')
              .withIngredients(['fläskfilé']).build();
          final lookup = _createLookup([
            _ingredient('fläskfilé', 'protein/meat/pork', {'meat', 'pork'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('halalanpassad'), TriState.contains);
        });

        test('CONTAINS when has alcohol', () {
          final recipe = RecipeBuilder()
              .withTitle('Wine Sauce')
              .withIngredients(['vin', 'grädde']).build();
          final lookup = _createLookup([
            _ingredient('vin', 'liquid/alcohol', {'contains-alcohol'}),
            _ingredient('grädde', 'protein/dairy', {'dairy', 'animal-product'}),
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
          final lookup = _createLookup([
            _ingredient('nötkött', 'protein/meat/beef', {'meat', 'beef'}),
            _ingredient('potatis', 'vegetable/root', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('kosheranpassad'), TriState.free);
        });

        test('CONTAINS when has pork', () {
          final recipe = RecipeBuilder()
              .withTitle('Ham Sandwich')
              .withIngredients(['skinka']).build();
          final lookup = _createLookup([
            _ingredient('skinka', 'protein/meat/pork', {'meat', 'pork'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('kosheranpassad'), TriState.contains);
        });

        test('CONTAINS when has shellfish', () {
          final recipe = RecipeBuilder()
              .withTitle('Lobster Dinner')
              .withIngredients(['hummer']).build();
          final lookup = _createLookup([
            _ingredient('hummer', 'protein/seafood/shellfish',
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
          final lookup = _createLookup([
            _ingredient('musslor', 'protein/seafood/shellfish',
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
          final lookup = _createLookup([
            _ingredient('lax', 'protein/seafood/fish', {'fish', 'seafood'}),
            _ingredient('pasta', 'grain/pasta-bread', {'contains-gluten'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('graviditetssäker'), TriState.free);
        });

        test('CONTAINS when has high-mercury fish', () {
          final recipe = RecipeBuilder()
              .withTitle('Swordfish Steak')
              .withIngredients(['svärdfisk']).build();
          final lookup = _createLookup([
            _ingredient('svärdfisk', 'protein/seafood/fish',
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
          final lookup = _createLookup([
            _ingredient('nötkött', 'protein/meat/beef', {'meat', 'beef'}),
            _ingredient('öl', 'liquid/alcohol', {'contains-alcohol'}),
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
          final lookup = _createLookup([
            _ingredient('pasta', 'grain/pasta-bread', {'contains-gluten'}),
            _ingredient('smör', 'protein/dairy', {'dairy', 'animal-product'}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.getDietaryStatus('barnvänlig'), TriState.free);
        });

        test('CONTAINS when spicy', () {
          final recipe = RecipeBuilder()
              .withTitle('Spicy Thai Curry')
              .withIngredients(['chili', 'kyckling']).build();
          final lookup = _createLookup([
            _ingredient('chili', 'spice', {'is-spicy'}),
            _ingredient(
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
          final lookup = _createLookup([
            _ingredient(
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
          final lookup = _createLookup([
            _ingredient('entrecote', 'protein/meat/beef', {'meat', 'beef'}),
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
        final lookup = _createLookup([
          IngredientData(
            id: 'chicken-breast',
            swedish: 'kycklingbröst',
            english: 'chicken breast',
            group: 'protein/meat/poultry',
            properties: {'meat', 'poultry'},
          ),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('kyckling'), isTrue);
      });

      test('adds nötkött tag for beef ingredients', () {
        final recipe = RecipeBuilder()
            .withTitle('Beef Stew')
            .withIngredients(['nötfärs']).build();
        final lookup = _createLookup([
          IngredientData(
            id: 'ground-beef',
            swedish: 'nötfärs',
            english: 'ground beef',
            group: 'protein/meat/beef',
            properties: {'meat', 'beef'},
          ),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('nötkött'), isTrue);
      });

      test('adds fisk tag for fish ingredients', () {
        final recipe = RecipeBuilder()
            .withTitle('Salmon Dish')
            .withIngredients(['lax']).build();
        final lookup = _createLookup([
          IngredientData(
            id: 'salmon',
            swedish: 'lax',
            english: 'salmon',
            group: 'protein/seafood/fish',
            properties: {'fish', 'seafood'},
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
        final lookup = _createLookup([
          IngredientData(
            id: 'shrimp',
            swedish: 'räkor',
            english: 'shrimp',
            group: 'protein/seafood/shellfish',
            properties: {'seafood', 'crustacean'},
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
        final lookup = _createLookup([
          IngredientData(
            id: 'pasta',
            swedish: 'pasta',
            english: 'pasta',
            group: 'grain/pasta-bread',
            properties: {'contains-gluten'},
          ),
          _ingredient('bacon', 'protein/meat/pork', {'meat', 'pork'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('pastabaserad'), isTrue);
      });

      test('adds risbaserad tag for rice dishes', () {
        final recipe = RecipeBuilder()
            .withTitle('Fried Rice')
            .withIngredients(['ris', 'vegetables']).build();
        final lookup = _createLookup([
          IngredientData(
            id: 'rice',
            swedish: 'ris',
            english: 'rice',
            group: 'grain',
            properties: {},
          ),
          _ingredient('vegetables', 'vegetable', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('risbaserad'), isTrue);
      });

      test('adds potatisbaserad tag for potato dishes', () {
        final recipe = RecipeBuilder()
            .withTitle('Mashed Potatoes')
            .withIngredients(['potatis', 'butter']).build();
        final lookup = _createLookup([
          IngredientData(
            id: 'potato',
            swedish: 'potatis',
            english: 'potato',
            group: 'vegetable/root',
            properties: {},
          ),
          _ingredient('butter', 'protein/dairy', {'dairy'}),
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
        final lookup = _createLookup([
          _ingredient('chicken', 'protein/meat/poultry', {'meat'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('ugnsbakad'), isTrue);
      });

      test('adds stekt tag when instructions mention frying', () {
        final recipe = RecipeBuilder()
            .withTitle('Pan Fried Fish')
            .withIngredients(['fish']).withInstructions(
                ['Stek fisken i smör tills gyllenbrun']).build();
        final lookup = _createLookup([
          _ingredient('fish', 'protein/seafood/fish', {'fish'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('stekt'), isTrue);
      });

      test('adds grillad tag when instructions mention grilling', () {
        final recipe = RecipeBuilder()
            .withTitle('Grilled Vegetables')
            .withIngredients(['vegetables']).withInstructions(
                ['Grilla grönsakerna på medium värme']).build();
        final lookup = _createLookup([
          _ingredient('vegetables', 'vegetable', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('grillad'), isTrue);
      });

      test('adds kokt tag when instructions mention boiling', () {
        final recipe = RecipeBuilder()
            .withTitle('Boiled Potatoes')
            .withIngredients(['potatis']).withInstructions(
                ['Koka potatisen i saltat vatten']).build();
        final lookup = _createLookup([
          _ingredient('potatis', 'vegetable/root', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('kokt'), isTrue);
      });

      test('adds wokad tag when instructions mention wok', () {
        final recipe = RecipeBuilder()
            .withTitle('Stir Fry')
            .withIngredients(['vegetables', 'tofu']).withInstructions(
                ['Woka grönsakerna på hög värme']).build();
        final lookup = _createLookup([
          _ingredient('vegetables', 'vegetable', {}),
          _ingredient('tofu', 'protein/plant-based', {}),
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
        final lookup = _createEmptyLookup();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('soppa'), isTrue);
      });

      test('adds gryta tag for stew titles', () {
        final recipe = RecipeBuilder()
            .withTitle('Köttgryta')
            .withIngredients(['beef']).build();
        final lookup = _createEmptyLookup();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('gryta'), isTrue);
      });

      test('adds sallad tag for salad titles', () {
        final recipe = RecipeBuilder()
            .withTitle('Grekisk sallad')
            .withIngredients(['lettuce']).build();
        final lookup = _createEmptyLookup();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('sallad'), isTrue);
      });

      test('adds pizza tag for pizza titles', () {
        final recipe = RecipeBuilder()
            .withTitle('Margherita Pizza')
            .withIngredients(['dough', 'tomato', 'cheese']).build();
        final lookup = _createEmptyLookup();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('pizza'), isTrue);
      });

      test('adds taco tag for taco titles', () {
        final recipe = RecipeBuilder()
            .withTitle('Tacos med kyckling')
            .withIngredients(['tortillas', 'chicken']).build();
        final lookup = _createEmptyLookup();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('taco'), isTrue);
      });

      test('does not add kaka tag for pannkaka', () {
        final recipe = RecipeBuilder()
            .withTitle('Svenska pannkakor')
            .withIngredients(['eggs', 'flour', 'milk']).build();
        final lookup = _createEmptyLookup();

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
            _ingredient('known1', 'vegetable', {}),
            _ingredient('known2', 'grain', {}),
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
        final lookup = _createLookup([
          _ingredient('ingredient1', 'vegetable', {}),
          _ingredient('ingredient2', 'grain', {}),
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
        final lookup = _createEmptyLookup();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // Empty = 100% coverage (nothing to match = all matched)
        expect(result.coverage, 1.0);
        expect(result.hasFullCoverage, isTrue);
        expect(result.unknownIngredients, isEmpty);
      });

      test('empty lookup allergens are FREE (no triggers)', () {
        // With no ingredients and 100% coverage, allergens are FREE
        // (no ingredients means no allergen triggers)
        final recipe = RecipeBuilder()
            .withTitle('Empty Recipe')
            .withIngredients([]).build();
        final lookup = _createEmptyLookup();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // No ingredients = no allergen triggers = FREE
        expect(result.isAllergenFree('gluten'), isTrue);
        expect(result.getAllergenStatus('gluten'), TriState.free);
      });
    });

    group('generatePhase1Only', () {
      test('returns only phase 1 tags with correct version', () {
        final recipe = RecipeBuilder()
            .withTitle('Quick Test')
            .withTimeMinutes(15)
            .withIngredients(['chicken']).build();
        final lookup = _createLookup([
          IngredientData(
            id: 'chicken',
            swedish: 'kyckling',
            english: 'chicken',
            group: 'protein/meat/poultry',
            properties: {'meat', 'poultry'},
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
        final lookup = _createEmptyLookup();

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.generatorVersion, isNotNull);
        expect(result.generatorVersion, kTagGeneratorVersion);
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
          final lookup = _createLookup([
            _ingredient('pasta', 'grain/pasta-bread', {'pasta-base'}),
            _ingredient('bacon', 'protein/meat/pork', {'meat', 'pork'}),
            _ingredient('egg', 'protein/egg', {'egg'}),
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
          final lookup = _createLookup([
            _ingredient('ris', 'grain', {}),
            _ingredient('vegetables', 'vegetable', {}),
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
          final lookup = _createLookup([
            _ingredient('potatis', 'vegetable/root', {}),
            _ingredient('butter', 'fat/butter', {'dairy'}),
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
          final lookup = _createLookup([
            _ingredient('chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
            _ingredient('chili', 'vegetable/spice', {'is-spicy'}),
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
          final lookup = _createLookup([
            _ingredient('chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
            _ingredient('salt', 'seasoning', {}),
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
          final lookup = _createEmptyLookup();

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
          final lookup = _createEmptyLookup();

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
          final lookup = _createLookup([
            _ingredient('chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
            _ingredient('rice', 'grain/rice', {}),
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
          final lookup = _createLookup([
            _ingredient('pork', 'protein/meat/pork', {'meat', 'pork'}),
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
          final lookup = _createLookup([
            _ingredient('beef', 'protein/meat/beef', {'meat'}),
            _ingredient('carrots', 'vegetable', {}),
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
          final lookup = _createLookup([
            IngredientData(
              id: 'rakor',
              swedish: 'räkor',
              english: 'shrimp',
              group: 'protein/seafood/shellfish',
              properties: {'crustacean', 'shellfish'},
            ),
            IngredientData(
              id: 'pasta',
              swedish: 'pasta',
              english: 'pasta',
              group: 'grain/pasta-bread',
              properties: {},
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
          final lookup = _createLookup([
            _ingredient('flour', 'grain', {'contains-gluten'}),
            _ingredient('chocolate', 'sweet', {}),
            _ingredient('sugar', 'sweet', {}),
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
          final lookup = _createEmptyLookup();

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
          final lookup = _createLookup([
            _ingredient('lettuce', 'vegetable', {}),
            _ingredient('tomato', 'vegetable', {}),
            _ingredient('cucumber', 'vegetable', {}),
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
          final lookup = _createEmptyLookup();

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
          final lookup = _createEmptyLookup();

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
          final lookup = _createEmptyLookup();

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
          final lookup = _createLookup([
            _ingredient('chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
            _ingredient('flour', 'grain', {'contains-gluten'}),
            _ingredient('oil', 'fat/oil', {}),
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
          final lookup = _createLookup([
            IngredientData(
              id: 'pasta',
              swedish: 'pasta',
              english: 'pasta',
              group: 'grain/pasta-bread',
              properties: {'pasta-base'},
            ),
            IngredientData(
              id: 'gradde',
              swedish: 'grädde',
              english: 'cream',
              group: 'dairy/cream',
              properties: {'dairy'},
            ),
            IngredientData(
              id: 'parmesan',
              swedish: 'parmesan',
              english: 'parmesan',
              group: 'protein/dairy/cheese',
              properties: {'dairy'},
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
          final lookup = _createLookup([
            _ingredient('potato', 'vegetable/potato', {}),
            _ingredient('cheddar', 'protein/dairy/cheese', {'dairy'}),
            _ingredient('parmesan', 'protein/dairy/cheese', {'dairy'}),
            _ingredient('mozzarella', 'protein/dairy/cheese', {'dairy'}),
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
          final lookup = _createLookup([
            _ingredient('beef', 'protein/meat/beef', {'meat'}),
            _ingredient('carrots', 'vegetable', {}),
            _ingredient('potatoes', 'vegetable/potato', {}),
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
          final lookup = _createLookup([
            _ingredient('lettuce', 'vegetable/salad', {}),
            _ingredient('parmesan', 'protein/dairy/cheese', {'dairy'}),
            _ingredient('croutons', 'grain', {'contains-gluten'}),
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
          final lookup = _createLookup([
            _ingredient('chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
            _ingredient('eggs', 'protein/egg', {'egg'}),
            _ingredient('tofu', 'protein/legume', {'plant-based'}),
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
          final lookup = _createLookup([
            _ingredient('broccoli', 'vegetable', {}),
            _ingredient('carrots', 'vegetable', {}),
            _ingredient('bell pepper', 'vegetable', {}),
            _ingredient('zucchini', 'vegetable', {}),
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
          final lookup = _createLookup([
            _ingredient('beef', 'protein/meat/beef', {'meat'}),
            _ingredient('cream', 'dairy/cream', {'dairy'}),
            _ingredient('potatoes', 'vegetable/potato', {}),
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
          final lookup = _createLookup([
            _ingredient('beef', 'protein/meat/beef', {'meat'}),
            _ingredient('carrots', 'vegetable', {}),
            _ingredient('potatoes', 'vegetable/potato', {}),
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
          final lookup = _createLookup([
            _ingredient('lettuce', 'vegetable/salad', {}),
            _ingredient('tomato', 'vegetable', {}),
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
          final lookup = _createEmptyLookup();

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
          final lookup = _createEmptyLookup();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('vardagsmiddag'), isTrue);
        });

        test('adds helgmat for longer cooking recipes', () {
          final recipe = RecipeBuilder()
              .withTitle('Slow Roast')
              .withTimeMinutes(180)
              .withIngredients(['beef', 'potatoes', 'vegetables']).build();
          final lookup = _createEmptyLookup();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('helgmat'), isTrue);
        });

        test('adds snabblagat for very quick easy meals', () {
          final recipe = RecipeBuilder()
              .withTitle('Quick Sandwich')
              .withTimeMinutes(10)
              .withIngredients(['bread', 'cheese', 'ham']).build();
          final lookup = _createEmptyLookup();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('snabblagat'), isTrue);
        });

        test('adds fredagsmys for taco recipes', () {
          final recipe = RecipeBuilder()
              .withTitle('Tacos')
              .withTimeMinutes(30)
              .withIngredients(['beef', 'taco shells', 'salsa']).build();
          final lookup = _createLookup([
            _ingredient('beef', 'protein/meat/beef', {'meat'}),
            _ingredient('taco shells', 'grain', {}),
            _ingredient('salsa', 'sauce', {}),
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
          final lookup = _createLookup([
            _ingredient('beef roast', 'protein/meat/beef', {'meat'}),
            _ingredient('potatoes', 'vegetable/potato', {}),
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
          final lookup = _createLookup([
            IngredientData(
              id: 'pasta',
              swedish: 'pasta',
              english: 'pasta',
              group: 'grain/pasta-bread',
              properties: {'pasta-base'},
            ),
            IngredientData(
              id: 'gradde',
              swedish: 'grädde',
              english: 'cream',
              group: 'dairy/cream',
              properties: {'dairy'},
            ),
            IngredientData(
              id: 'cheese',
              swedish: 'ost',
              english: 'cheese',
              group: 'protein/dairy/cheese',
              properties: {'dairy'},
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
          final lookup = _createLookup([
            _ingredient('tomatoes', 'vegetable', {}),
            _ingredient('cream', 'dairy/cream', {'dairy'}),
            _ingredient('onion', 'vegetable', {}),
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
          final lookup = _createLookup([
            _ingredient('lettuce', 'vegetable/salad', {}),
            _ingredient('tomato', 'vegetable', {}),
            _ingredient('cucumber', 'vegetable', {}),
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
          final lookup = _createLookup([
            _ingredient('oxfilé', 'protein/meat/beef', {'meat'}),
            _ingredient('tryffel', 'vegetable/mushroom', {}),
            _ingredient('smör', 'fat/butter', {'dairy'}),
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
          final lookup = _createEmptyLookup();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('jul'), isTrue);
        });

        test('adds lucia tag for Lucia dishes', () {
          final recipe = RecipeBuilder()
              .withTitle('Lussekatter')
              .withTimeMinutes(90)
              .withIngredients(['flour', 'saffron', 'butter']).build();
          final lookup = _createEmptyLookup();

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('lucia'), isTrue);
        });

        test('adds påsk tag for Easter dishes', () {
          final recipe = RecipeBuilder()
              .withTitle('Påsklamm')
              .withTimeMinutes(120)
              .withIngredients(['lamb', 'rosemary', 'garlic']).build();
          final lookup = _createLookup([
            _ingredient('lamb', 'protein/meat/lamb', {'meat', 'lamb'}),
            _ingredient('rosemary', 'herb', {}),
            _ingredient('garlic', 'vegetable', {}),
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
          final lookup = _createLookup([
            _ingredient('sill', 'protein/fish', {'fish'}),
            _ingredient('nypotatis', 'vegetable/potato', {}),
            _ingredient('gräddfil', 'dairy', {'dairy'}),
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
          final lookup = _createLookup([
            _ingredient('kräftor', 'protein/shellfish', {'shellfish'}),
            _ingredient('dill', 'herb', {}),
            _ingredient('bröd', 'grain', {'contains-gluten'}),
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
          final lookup = _createLookup([
            _ingredient('sparris', 'vegetable', {}),
            _ingredient('rädisor', 'vegetable', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('vår'), isTrue);
        });

        test('adds sommar for summer ingredients or grilled dishes', () {
          final recipe = RecipeBuilder()
              .withTitle('Grillad Kyckling')
              .withTimeMinutes(45)
              .withInstructions(['Grilla kycklingen']).withIngredients(
                  ['chicken', 'marinade']).build();
          final lookup = _createLookup([
            _ingredient('chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
            _ingredient('marinade', 'sauce', {}),
          ]);

          final result =
              generator.generate(ingredients: lookup, recipe: recipe);

          expect(result.hasTag('grillad'), isTrue);
          expect(result.hasTag('sommar'), isTrue);
        });

        test('adds höst for autumn ingredients', () {
          final recipe = RecipeBuilder()
              .withTitle('Kantarellpasta')
              .withTimeMinutes(30)
              .withIngredients(['kantarell', 'pasta', 'cream']).build();
          final lookup = _createLookup([
            _ingredient('kantarell', 'vegetable/mushroom', {}),
            _ingredient('pasta', 'grain/pasta-bread', {'pasta-base'}),
            _ingredient('cream', 'dairy/cream', {'dairy'}),
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
          final lookup = _createLookup([
            _ingredient('morot', 'vegetable/root', {}),
            _ingredient('palsternacka', 'vegetable/root', {}),
            _ingredient('kålrot', 'vegetable/root', {}),
            _ingredient('potato', 'vegetable/potato', {}),
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
          final lookup = _createLookup([
            _ingredient('pasta', 'grain/pasta-bread', {}),
            _ingredient('tomato sauce', 'sauce', {}),
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
  });
}

// Helper functions

IngredientData _ingredient(String name, String group, Set<String> properties) {
  return IngredientData(
    id: name.toLowerCase().replaceAll(' ', '-'),
    swedish: name,
    english: name,
    group: group,
    properties: properties,
  );
}

IngredientLookupResult _createLookup(List<IngredientData> ingredients) {
  return IngredientLookupResult.fromLists(
    matched: ingredients,
    unmatched: [],
  );
}

IngredientLookupResult _createEmptyLookup() {
  return IngredientLookupResult.empty();
}
