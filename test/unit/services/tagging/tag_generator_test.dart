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
