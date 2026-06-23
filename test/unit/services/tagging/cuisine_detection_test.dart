import 'package:butlery/services/tagging/tag_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/helpers/tagging_test_helper.dart';

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
            .withIngredients(['nötfärs', 'lök', 'ströbröd'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('nötfärs', 'protein/meat/beef', {}),
          TaggingTestHelper.ingredient('lök', 'vegetable/allium', {}),
          TaggingTestHelper.ingredient('ströbröd', 'grain', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('svensk'), isTrue);
      });

      test('detects svensk cuisine from lingon + dill', () {
        final recipe = RecipeBuilder()
            .withTitle('Laxfilé')
            .withTimeMinutes(30)
            .withIngredients(['lax', 'lingon', 'dill'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('lax', 'protein/seafood/fish', {}),
          TaggingTestHelper.ingredient('lingon', 'fruit/berry', {}),
          TaggingTestHelper.ingredient('dill', 'herb', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('svensk'), isTrue);
      });

      test('detects nordisk cuisine from title', () {
        final recipe = RecipeBuilder()
            .withTitle('Nordisk Gravad Lax')
            .withTimeMinutes(20)
            .withIngredients(['lax', 'dill', 'salt'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('lax', 'protein/seafood/fish', {}),
          TaggingTestHelper.ingredient('dill', 'herb', {}),
          TaggingTestHelper.ingredient('salt', 'spice', {}),
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
            .withIngredients(['pasta', 'ägg', 'pancetta'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('pasta', 'grain/pasta-bread', {}),
          TaggingTestHelper.ingredient('ägg', 'protein/egg', {}),
          TaggingTestHelper.ingredient('pancetta', 'protein/meat/pork', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('italiensk'), isTrue);
      });

      test('detects italiensk cuisine from parmesan + mozzarella', () {
        final recipe = RecipeBuilder()
            .withTitle('Caprese Sallad')
            .withTimeMinutes(10)
            .withIngredients(['mozzarella', 'tomat', 'basilika'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('mozzarella', 'dairy/cheese', {}),
          TaggingTestHelper.ingredient('tomat', 'vegetable', {}),
          TaggingTestHelper.ingredient('basilika', 'herb', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('italiensk'), isTrue);
      });

      test('detects grekisk cuisine from tzatziki title', () {
        final recipe = RecipeBuilder()
            .withTitle('Tzatziki med Pitabröd')
            .withTimeMinutes(15)
            .withIngredients(['yoghurt', 'gurka', 'vitlök'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('yoghurt', 'dairy/yogurt', {}),
          TaggingTestHelper.ingredient('gurka', 'vegetable', {}),
          TaggingTestHelper.ingredient('vitlök', 'vegetable/allium', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('grekisk'), isTrue);
      });

      test('detects spansk cuisine from paella title', () {
        final recipe = RecipeBuilder()
            .withTitle('Spansk Paella')
            .withTimeMinutes(60)
            .withIngredients(['ris', 'saffran', 'räkor'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('ris', 'grain', {}),
          TaggingTestHelper.ingredient('saffran', 'spice', {}),
          TaggingTestHelper.ingredient('räkor', 'protein/seafood', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('spansk'), isTrue);
      });

      test('detects fransk cuisine from coq au vin title', () {
        final recipe = RecipeBuilder()
            .withTitle('Coq au Vin')
            .withTimeMinutes(90)
            .withIngredients(['kyckling', 'rödvin', 'champinjoner'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('kyckling', 'protein/meat/poultry', {}),
          TaggingTestHelper.ingredient('rödvin', 'liquid/wine', {}),
          TaggingTestHelper.ingredient(
            'champinjoner',
            'vegetable/mushroom',
            {},
          ),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('fransk'), isTrue);
      });

      test('detects medelhavsmat from multiple Mediterranean ingredients', () {
        final recipe = RecipeBuilder()
            .withTitle('Medelhavssallad')
            .withTimeMinutes(20)
            .withIngredients(['olivolja', 'citron', 'vitlök', 'rosmarin'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('olivolja', 'fat/oil', {}),
          TaggingTestHelper.ingredient('citron', 'fruit/citrus', {}),
          TaggingTestHelper.ingredient('vitlök', 'vegetable/allium', {}),
          TaggingTestHelper.ingredient('rosmarin', 'herb', {}),
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
            .withIngredients(['risnudlar', 'räkor', 'jordnötter'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('risnudlar', 'grain/pasta-bread', {}),
          TaggingTestHelper.ingredient('räkor', 'protein/seafood', {}),
          TaggingTestHelper.ingredient('jordnötter', 'nut', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('thailändsk'), isTrue);
      });

      test('detects indisk cuisine from tikka masala title', () {
        final recipe = RecipeBuilder()
            .withTitle('Chicken Tikka Masala')
            .withTimeMinutes(45)
            .withIngredients(['kyckling', 'yoghurt', 'garam masala'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('kyckling', 'protein/meat/poultry', {}),
          TaggingTestHelper.ingredient('yoghurt', 'dairy/yogurt', {}),
          TaggingTestHelper.ingredient('garam masala', 'spice', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('indisk'), isTrue);
      });

      test('detects kinesisk cuisine from dim sum title', () {
        final recipe = RecipeBuilder()
            .withTitle('Dim Sum')
            .withTimeMinutes(60)
            .withIngredients(['fläsk', 'sojasås', 'ingefära'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('fläsk', 'protein/meat/pork', {}),
          TaggingTestHelper.ingredient('sojasås', 'sauce', {}),
          TaggingTestHelper.ingredient('ingefära', 'vegetable/root', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('kinesisk'), isTrue);
      });

      test('detects japansk cuisine from sushi title', () {
        final recipe = RecipeBuilder()
            .withTitle('Sushi')
            .withTimeMinutes(45)
            .withIngredients(['ris', 'lax', 'nori'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('ris', 'grain', {}),
          TaggingTestHelper.ingredient('lax', 'protein/seafood/fish', {}),
          TaggingTestHelper.ingredient('nori', 'vegetable/seaweed', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('japansk'), isTrue);
      });

      test('detects koreansk cuisine from bibimbap title', () {
        final recipe = RecipeBuilder()
            .withTitle('Bibimbap')
            .withTimeMinutes(40)
            .withIngredients(['ris', 'nötkött', 'gochujang'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('ris', 'grain', {}),
          TaggingTestHelper.ingredient('nötkött', 'protein/meat/beef', {}),
          TaggingTestHelper.ingredient('gochujang', 'sauce', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('koreansk'), isTrue);
      });

      test('detects vietnamesisk cuisine from pho title', () {
        final recipe = RecipeBuilder()
            .withTitle('Pho Bo')
            .withTimeMinutes(180)
            .withIngredients(['risnudlar', 'nötkött', 'koriander'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('risnudlar', 'grain/pasta-bread', {}),
          TaggingTestHelper.ingredient('nötkött', 'protein/meat/beef', {}),
          TaggingTestHelper.ingredient('koriander', 'herb', {}),
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
            .withIngredients(['nötfärs', 'tortilla', 'koriander'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('nötfärs', 'protein/meat/beef', {}),
          TaggingTestHelper.ingredient('tortilla', 'grain/bread', {}),
          TaggingTestHelper.ingredient('koriander', 'herb', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('mexikansk'), isTrue);
      });

      test('detects amerikansk cuisine from burger title', () {
        final recipe = RecipeBuilder()
            .withTitle('Classic Burger')
            .withTimeMinutes(25)
            .withIngredients(['nötfärs', 'cheddar', 'bacon'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('nötfärs', 'protein/meat/beef', {}),
          TaggingTestHelper.ingredient('cheddar', 'dairy/cheese', {}),
          TaggingTestHelper.ingredient('bacon', 'protein/meat/pork', {}),
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
            .withIngredients(['kikärtor', 'persilja', 'kummin'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('kikärtor', 'legume', {}),
          TaggingTestHelper.ingredient('persilja', 'herb', {}),
          TaggingTestHelper.ingredient('kummin', 'spice', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('mellanöstern'), isTrue);
      });

      test('detects mellanöstern cuisine from tahini + hummus', () {
        final recipe = RecipeBuilder()
            .withTitle('Hummusbowl')
            .withTimeMinutes(20)
            .withIngredients(['hummus', 'tahini', 'pitabröd'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('hummus', 'dip', {}),
          TaggingTestHelper.ingredient('tahini', 'sauce', {}),
          TaggingTestHelper.ingredient('pitabröd', 'grain/bread', {}),
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
            .withIngredients(['sallad', 'tomat', 'gurka'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('sallad', 'vegetable/salad', {}),
          TaggingTestHelper.ingredient('tomat', 'vegetable', {}),
          TaggingTestHelper.ingredient('gurka', 'vegetable', {}),
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
            .withIngredients(['pasta', 'sojasås', 'sesamolja'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('pasta', 'grain/pasta-bread', {}),
          TaggingTestHelper.ingredient('sojasås', 'sauce', {}),
          TaggingTestHelper.ingredient('sesamolja', 'fat/oil', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // Could match both Italian (pasta) and Asian (soy + sesame)
        expect(result.hasTag('italiensk'), isTrue);
        expect(result.hasTag('asiatisk'), isTrue);
      });
    });
  });
}
