import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/builders/recipe_builder.dart';

/// Sprint 4: Tests for cuisine detection (Phase 5).
///
/// Tests 17 world cuisines detection via title keywords and ingredient patterns.
void main() {
  late TagGenerator generator;

  setUp(() {
    generator = TagGenerator();
  });

  group('Cuisine Detection - Phase 5', () {
    group('Swedish/Nordic cuisines', () {
      test('detects svensk cuisine from title keyword', () {
        final recipe = RecipeBuilder()
            .withTitle('Svenska Köttbullar')
            .withTimeMinutes(45)
            .withIngredients(['nötfärs', 'lök', 'ströbröd']).build();
        final lookup = _createLookup([
          _ingredient('nötfärs', 'protein/meat/beef', {}),
          _ingredient('lök', 'vegetable/allium', {}),
          _ingredient('ströbröd', 'grain', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('svensk'), isTrue);
      });

      test('detects svensk cuisine from lingon + dill', () {
        final recipe = RecipeBuilder()
            .withTitle('Laxfilé')
            .withTimeMinutes(30)
            .withIngredients(['lax', 'lingon', 'dill']).build();
        final lookup = _createLookup([
          _ingredient('lax', 'protein/seafood/fish', {}),
          _ingredient('lingon', 'fruit/berry', {}),
          _ingredient('dill', 'herb', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('svensk'), isTrue);
      });

      test('detects nordisk cuisine from title', () {
        final recipe = RecipeBuilder()
            .withTitle('Nordisk Gravad Lax')
            .withTimeMinutes(20)
            .withIngredients(['lax', 'dill', 'salt']).build();
        final lookup = _createLookup([
          _ingredient('lax', 'protein/seafood/fish', {}),
          _ingredient('dill', 'herb', {}),
          _ingredient('salt', 'spice', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('nordisk'), isTrue);
      });
    });

    group('Mediterranean cuisines', () {
      test('detects italiensk cuisine from pasta title', () {
        final recipe = RecipeBuilder()
            .withTitle('Pasta Carbonara')
            .withTimeMinutes(25)
            .withIngredients(['pasta', 'ägg', 'pancetta']).build();
        final lookup = _createLookup([
          _ingredient('pasta', 'grain/pasta-bread', {}),
          _ingredient('ägg', 'protein/egg', {}),
          _ingredient('pancetta', 'protein/meat/pork', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('italiensk'), isTrue);
      });

      test('detects italiensk cuisine from parmesan + mozzarella', () {
        final recipe = RecipeBuilder()
            .withTitle('Caprese Sallad')
            .withTimeMinutes(10)
            .withIngredients(['mozzarella', 'tomat', 'basilika']).build();
        final lookup = _createLookup([
          _ingredient('mozzarella', 'dairy/cheese', {}),
          _ingredient('tomat', 'vegetable', {}),
          _ingredient('basilika', 'herb', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('italiensk'), isTrue);
      });

      test('detects grekisk cuisine from tzatziki title', () {
        final recipe = RecipeBuilder()
            .withTitle('Tzatziki med Pitabröd')
            .withTimeMinutes(15)
            .withIngredients(['yoghurt', 'gurka', 'vitlök']).build();
        final lookup = _createLookup([
          _ingredient('yoghurt', 'dairy/yogurt', {}),
          _ingredient('gurka', 'vegetable', {}),
          _ingredient('vitlök', 'vegetable/allium', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('grekisk'), isTrue);
      });

      test('detects spansk cuisine from paella title', () {
        final recipe = RecipeBuilder()
            .withTitle('Spansk Paella')
            .withTimeMinutes(60)
            .withIngredients(['ris', 'saffran', 'räkor']).build();
        final lookup = _createLookup([
          _ingredient('ris', 'grain', {}),
          _ingredient('saffran', 'spice', {}),
          _ingredient('räkor', 'protein/seafood', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('spansk'), isTrue);
      });

      test('detects fransk cuisine from coq au vin title', () {
        final recipe = RecipeBuilder()
            .withTitle('Coq au Vin')
            .withTimeMinutes(90)
            .withIngredients(['kyckling', 'rödvin', 'champinjoner']).build();
        final lookup = _createLookup([
          _ingredient('kyckling', 'protein/meat/poultry', {}),
          _ingredient('rödvin', 'liquid/wine', {}),
          _ingredient('champinjoner', 'vegetable/mushroom', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('fransk'), isTrue);
      });

      test('detects medelhavsmat from multiple Mediterranean ingredients', () {
        final recipe = RecipeBuilder()
            .withTitle('Medelhavssallad')
            .withTimeMinutes(20)
            .withIngredients(
                ['olivolja', 'citron', 'vitlök', 'rosmarin']).build();
        final lookup = _createLookup([
          _ingredient('olivolja', 'fat/oil', {}),
          _ingredient('citron', 'fruit/citrus', {}),
          _ingredient('vitlök', 'vegetable/allium', {}),
          _ingredient('rosmarin', 'herb', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('medelhavsmat'), isTrue);
      });
    });

    group('Asian cuisines', () {
      test('detects thailändsk cuisine from pad thai title', () {
        final recipe = RecipeBuilder()
            .withTitle('Pad Thai')
            .withTimeMinutes(30)
            .withIngredients(['risnudlar', 'räkor', 'jordnötter']).build();
        final lookup = _createLookup([
          _ingredient('risnudlar', 'grain/pasta-bread', {}),
          _ingredient('räkor', 'protein/seafood', {}),
          _ingredient('jordnötter', 'nut', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('thailändsk'), isTrue);
      });

      test('detects indisk cuisine from tikka masala title', () {
        final recipe = RecipeBuilder()
            .withTitle('Chicken Tikka Masala')
            .withTimeMinutes(45)
            .withIngredients(['kyckling', 'yoghurt', 'garam masala']).build();
        final lookup = _createLookup([
          _ingredient('kyckling', 'protein/meat/poultry', {}),
          _ingredient('yoghurt', 'dairy/yogurt', {}),
          _ingredient('garam masala', 'spice', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('indisk'), isTrue);
      });

      test('detects kinesisk cuisine from dim sum title', () {
        final recipe = RecipeBuilder()
            .withTitle('Dim Sum')
            .withTimeMinutes(60)
            .withIngredients(['fläsk', 'sojasås', 'ingefära']).build();
        final lookup = _createLookup([
          _ingredient('fläsk', 'protein/meat/pork', {}),
          _ingredient('sojasås', 'sauce', {}),
          _ingredient('ingefära', 'vegetable/root', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('kinesisk'), isTrue);
      });

      test('detects japansk cuisine from sushi title', () {
        final recipe = RecipeBuilder()
            .withTitle('Sushi')
            .withTimeMinutes(45)
            .withIngredients(['ris', 'lax', 'nori']).build();
        final lookup = _createLookup([
          _ingredient('ris', 'grain', {}),
          _ingredient('lax', 'protein/seafood/fish', {}),
          _ingredient('nori', 'vegetable/seaweed', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('japansk'), isTrue);
      });

      test('detects koreansk cuisine from bibimbap title', () {
        final recipe = RecipeBuilder()
            .withTitle('Bibimbap')
            .withTimeMinutes(40)
            .withIngredients(['ris', 'nötkött', 'gochujang']).build();
        final lookup = _createLookup([
          _ingredient('ris', 'grain', {}),
          _ingredient('nötkött', 'protein/meat/beef', {}),
          _ingredient('gochujang', 'sauce', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('koreansk'), isTrue);
      });

      test('detects vietnamesisk cuisine from pho title', () {
        final recipe = RecipeBuilder()
            .withTitle('Pho Bo')
            .withTimeMinutes(180)
            .withIngredients(['risnudlar', 'nötkött', 'koriander']).build();
        final lookup = _createLookup([
          _ingredient('risnudlar', 'grain/pasta-bread', {}),
          _ingredient('nötkött', 'protein/meat/beef', {}),
          _ingredient('koriander', 'herb', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('vietnamesisk'), isTrue);
      });
    });

    group('Americas cuisines', () {
      test('detects mexikansk cuisine from taco title', () {
        final recipe = RecipeBuilder()
            .withTitle('Tacos')
            .withTimeMinutes(30)
            .withIngredients(['nötfärs', 'tortilla', 'koriander']).build();
        final lookup = _createLookup([
          _ingredient('nötfärs', 'protein/meat/beef', {}),
          _ingredient('tortilla', 'grain/bread', {}),
          _ingredient('koriander', 'herb', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('mexikansk'), isTrue);
      });

      test('detects amerikansk cuisine from burger title', () {
        final recipe = RecipeBuilder()
            .withTitle('Classic Burger')
            .withTimeMinutes(25)
            .withIngredients(['nötfärs', 'cheddar', 'bacon']).build();
        final lookup = _createLookup([
          _ingredient('nötfärs', 'protein/meat/beef', {}),
          _ingredient('cheddar', 'dairy/cheese', {}),
          _ingredient('bacon', 'protein/meat/pork', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('amerikansk'), isTrue);
      });
    });

    group('Middle Eastern cuisine', () {
      test('detects mellanöstern cuisine from falafel title', () {
        final recipe = RecipeBuilder()
            .withTitle('Falafel')
            .withTimeMinutes(45)
            .withIngredients(['kikärtor', 'persilja', 'kummin']).build();
        final lookup = _createLookup([
          _ingredient('kikärtor', 'legume', {}),
          _ingredient('persilja', 'herb', {}),
          _ingredient('kummin', 'spice', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('mellanöstern'), isTrue);
      });

      test('detects mellanöstern cuisine from tahini + hummus', () {
        final recipe = RecipeBuilder()
            .withTitle('Hummusbowl')
            .withTimeMinutes(20)
            .withIngredients(['hummus', 'tahini', 'pitabröd']).build();
        final lookup = _createLookup([
          _ingredient('hummus', 'dip', {}),
          _ingredient('tahini', 'sauce', {}),
          _ingredient('pitabröd', 'grain/bread', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('mellanöstern'), isTrue);
      });
    });

    group('edge cases', () {
      test('no cuisine tag when no matching patterns', () {
        final recipe = RecipeBuilder()
            .withTitle('Enkel Sallad')
            .withTimeMinutes(10)
            .withIngredients(['sallad', 'tomat', 'gurka']).build();
        final lookup = _createLookup([
          _ingredient('sallad', 'vegetable/salad', {}),
          _ingredient('tomat', 'vegetable', {}),
          _ingredient('gurka', 'vegetable', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // Should not have any cuisine tags
        expect(result.hasTag('svensk'), isFalse);
        expect(result.hasTag('italiensk'), isFalse);
        expect(result.hasTag('asiatisk'), isFalse);
      });

      test('multiple cuisines can be detected', () {
        // A fusion dish might match multiple cuisines
        final recipe = RecipeBuilder()
            .withTitle('Asian Fusion Pasta')
            .withTimeMinutes(30)
            .withIngredients(['pasta', 'sojasås', 'sesamolja']).build();
        final lookup = _createLookup([
          _ingredient('pasta', 'grain/pasta-bread', {}),
          _ingredient('sojasås', 'sauce', {}),
          _ingredient('sesamolja', 'fat/oil', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // Could match both Italian (pasta) and Asian (soy + sesame)
        expect(result.hasTag('italiensk'), isTrue);
        expect(result.hasTag('asiatisk'), isTrue);
      });
    });
  });
}

// Helper functions

IngredientData _ingredient(
  String name,
  String group,
  Set<String> properties,
) {
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
