/// Unit tests for Phase 4 holiday detection in the tagging system.
///
/// Tests Swedish holiday ingredient detection for:
/// - Jul (Christmas) - julskinka, lutfisk, jansson, etc.
/// - Midsommar (Midsummer) - pickled herring, new potatoes, strawberries
/// - Påsk (Easter) - lamb, eggs, Easter candy
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import '../../../infrastructure/builders/recipe_builder.dart';

void main() {
  late TagGenerator generator;

  setUp(() {
    generator = TagGenerator();
  });

  group('TagGenerator - Holiday Detection (Phase 4)', () {
    group('jul (Christmas) detection', () {
      test('detects jul from title containing jul', () {
        final recipe = RecipeBuilder()
            .withTitle('Julskinka med senap')
            .withIngredients(['skinka', 'senap', 'ägg']).build();
        final lookup = _createLookup([
          _ingredient('skinka', 'protein/meat/pork', {'meat', 'pork'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('jul'), isTrue);
      });

      test('detects jul from julskinka ingredient', () {
        final recipe = RecipeBuilder()
            .withTitle('Klassisk julmat')
            .withIngredients(['julskinka', 'brödsmulor', 'senap']).build();
        final lookup = _createLookup([
          _ingredient('julskinka', 'protein/meat/pork', {'meat', 'pork'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('jul'), isTrue);
      });

      test('detects jul from lutfisk ingredient', () {
        final recipe = RecipeBuilder()
            .withTitle('Traditionell Lutfisk')
            .withIngredients(['lutfisk', 'vitsås', 'ärtor']).build();
        final lookup = _createLookup([
          _ingredient('lutfisk', 'protein/seafood/fish', {'fish'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('jul'), isTrue);
      });

      test('detects jul from janssons frestelse', () {
        final recipe = RecipeBuilder()
            .withTitle('Janssons frestelse')
            .withIngredients(['potatis', 'ansjovis', 'grädde', 'lök']).build();
        final lookup = _createLookup([
          _ingredient('potatis', 'vegetable/root', {}),
          _ingredient('ansjovis', 'protein/seafood/fish', {'fish'}),
          _ingredient('grädde', 'protein/dairy', {'dairy', 'cream'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('jul'), isTrue);
      });

      test('does not detect jul from regular recipes', () {
        final recipe = RecipeBuilder()
            .withTitle('Pasta med köttfärssås')
            .withIngredients(['pasta', 'köttfärs', 'tomatsås']).build();
        final lookup = _createLookup([
          _ingredient('pasta', 'grain/pasta-bread', {'contains-gluten'}),
          _ingredient('köttfärs', 'protein/meat/beef', {'meat', 'beef'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('jul'), isFalse);
      });
    });

    group('midsommar (Midsummer) detection', () {
      test('detects midsommar from title', () {
        final recipe = RecipeBuilder()
            .withTitle('Midsommarmat - Sill och potatis')
            .withIngredients(
                ['inlagd sill', 'färskpotatis', 'gräddfil']).build();
        final lookup = _createLookup([
          _ingredient('inlagd sill', 'protein/seafood/fish', {'fish'}),
          _ingredient('färskpotatis', 'vegetable/root', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('midsommar'), isTrue);
      });

      test('does not detect midsommar from single ingredient', () {
        final recipe = RecipeBuilder()
            .withTitle('Kokt potatis')
            .withIngredients(['potatis', 'smör', 'dill']).build();
        final lookup = _createLookup([
          _ingredient('potatis', 'vegetable/root', {}),
          _ingredient('smör', 'protein/dairy', {'dairy'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('midsommar'), isFalse);
      });
    });

    group('påsk (Easter) detection', () {
      test('detects påsk from title', () {
        final recipe = RecipeBuilder()
            .withTitle('Påskmiddag med lamm')
            .withIngredients(['lammkotlett', 'rosmarin', 'vitlök']).build();
        final lookup = _createLookup([
          _ingredient('lammkotlett', 'protein/meat/lamb', {'meat', 'lamb'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('påsk'), isTrue);
      });

      test('detects påsk from lamb ingredient (Swedish Easter tradition)', () {
        // System intentionally tags lamb dishes as Easter (cultural association)
        final recipe = RecipeBuilder()
            .withTitle('Vardaglig lammgryta')
            .withIngredients(['lammkött', 'tomat', 'vitlök']).build();
        final lookup = _createLookup([
          _ingredient('lammkött', 'protein/meat/lamb', {'meat', 'lamb'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // Lamb triggers påsk tag due to Swedish Easter tradition
        expect(result.hasTag('påsk'), isTrue);
      });
    });

    group('edge cases', () {
      test('does not false-detect holidays from similar words', () {
        final recipe = RecipeBuilder()
            .withTitle('Julienne skurna grönsaker')
            .withIngredients(['morot', 'selleri', 'purjolök']).build();
        final lookup = _createLookup([
          _ingredient('morot', 'vegetable', {}),
          _ingredient('selleri', 'vegetable', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // Julienne should not trigger jul detection
        expect(result.hasTag('jul'), isFalse);
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
    priceCategory: null,
    carbonFootprintCategory: null,
    seasonAvailability: const [],
  );
}

IngredientLookupResult _createLookup(List<IngredientData> ingredients) {
  return IngredientLookupResult.fromLists(
    matched: ingredients,
    unmatched: [],
  );
}
