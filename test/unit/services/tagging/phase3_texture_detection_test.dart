/// Unit tests for Phase 3 texture/flavor detection in the tagging system.
///
/// Tests comprehensive detection of:
/// - Creamy (krämig) recipes from cream-based ingredients
/// - Crispy (krispig) recipes from cooking methods
/// - Cheesy (ostig) recipes from cheese ingredients
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

  group('TagGenerator - Texture Detection (Phase 3)', () {
    group('krämig (creamy) detection', () {
      test('detects creamy from grädde ingredient', () {
        final recipe = RecipeBuilder()
            .withTitle('Pasta med grädde')
            .withIngredients(['pasta', 'grädde', 'salt']).withInstructions(
                ['Koka pastan', 'Tillsätt grädde']).build();
        final lookup = _createLookup([
          _ingredient('pasta', 'grain/pasta-bread', {'contains-gluten'}),
          _ingredient(
              'grädde', 'protein/dairy', {'dairy', 'animal-product', 'cream'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('krämig'), isTrue);
      });

      test('detects creamy from crème fraiche in sauce', () {
        // Krämig requires creamy ingredient + instructions with 'sås' or 'rör'
        final recipe = RecipeBuilder()
            .withTitle('Lax med crème fraiche')
            .withIngredients(['lax', 'crème fraiche', 'dill']).withInstructions(
                ['Stek laxen', 'Gör en sås med crème fraiche']).build();
        final lookup = _createLookup([
          _ingredient('lax', 'protein/seafood/fish', {'fish'}),
          _ingredient('crème fraiche', 'protein/dairy',
              {'dairy', 'animal-product', 'cream'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('krämig'), isTrue);
      });

      test('detects creamy from coconut milk in curry', () {
        // Krämig requires creamy ingredient + instructions with 'sås' or 'rör'
        final recipe = RecipeBuilder().withTitle('Currygryta').withIngredients([
          'kokosmjölk',
          'kyckling',
          'curry'
        ]).withInstructions(
            ['Fräs kycklingen', 'Rör ner kokosmjölken']).build();
        final lookup = _createLookup([
          _ingredient('kokosmjölk', 'liquid', {'cream', 'plant-based'}),
          _ingredient('kyckling', 'protein/poultry', {'poultry', 'meat'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('krämig'), isTrue);
      });

      test('does not detect creamy without cream ingredients', () {
        final recipe = RecipeBuilder()
            .withTitle('Pasta med tomatsås')
            .withIngredients(['pasta', 'tomatsås', 'basilika']).build();
        final lookup = _createLookup([
          _ingredient('pasta', 'grain/pasta-bread', {'contains-gluten'}),
          _ingredient('tomatsås', 'sauce', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('krämig'), isFalse);
      });
    });

    group('krispig (crispy) detection', () {
      test('detects crispy from instruction keywords', () {
        final recipe = RecipeBuilder()
            .withTitle('Panerad kyckling')
            .withIngredients(['kyckling', 'panko', 'ägg']).withInstructions([
          'Panera kycklingen',
          'Fritera tills den blir krispig'
        ]).build();
        final lookup = _createLookup([
          _ingredient('kyckling', 'protein/poultry', {'poultry', 'meat'}),
          _ingredient('panko', 'grain', {'contains-gluten'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('krispig'), isTrue);
      });

      test('detects crispy from frying methods', () {
        final recipe = RecipeBuilder()
            .withTitle('Pommes frites')
            .withIngredients(['potatis', 'olja']).withInstructions(
                ['Fritera potatisen i het olja']).build();
        final lookup = _createLookup([
          _ingredient('potatis', 'vegetable/root', {}),
          _ingredient('olja', 'fat/oil', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('krispig'), isTrue);
      });

      test('does not detect crispy from boiling methods', () {
        final recipe = RecipeBuilder()
            .withTitle('Kokt pasta')
            .withIngredients(['pasta', 'vatten', 'salt']).withInstructions(
                ['Koka pastan i saltat vatten']).build();
        final lookup = _createLookup([
          _ingredient('pasta', 'grain/pasta-bread', {'contains-gluten'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('krispig'), isFalse);
      });
    });

    group('ostig (cheesy) detection', () {
      test('detects cheesy from parmesan', () {
        final recipe = RecipeBuilder()
            .withTitle('Pasta med parmesan')
            .withIngredients(['pasta', 'parmesan', 'smör']).build();
        final lookup = _createLookup([
          _ingredient('pasta', 'grain/pasta-bread', {'contains-gluten'}),
          _ingredient('parmesan', 'protein/dairy/cheese', {'dairy', 'cheese'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('ostig'), isTrue);
      });

      test('detects cheesy from mozzarella', () {
        final recipe = RecipeBuilder()
            .withTitle('Pizza Margherita')
            .withIngredients(['pizzadeg', 'tomatsås', 'mozzarella']).build();
        final lookup = _createLookup([
          _ingredient('pizzadeg', 'grain/pasta-bread', {'contains-gluten'}),
          _ingredient(
              'mozzarella', 'protein/dairy/cheese', {'dairy', 'cheese'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('ostig'), isTrue);
      });

      test('does not detect cheesy without cheese', () {
        final recipe = RecipeBuilder()
            .withTitle('Smörgås med skinka')
            .withIngredients(['bröd', 'smör', 'skinka']).build();
        final lookup = _createLookup([
          _ingredient('bröd', 'grain/pasta-bread', {'contains-gluten'}),
          _ingredient('skinka', 'protein/meat/pork', {'meat', 'pork'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('ostig'), isFalse);
      });
    });

    group('combined texture detection', () {
      test('can have multiple textures (creamy and cheesy)', () {
        final recipe = RecipeBuilder()
            .withTitle('Krämig ostpasta')
            .withIngredients(['pasta', 'grädde', 'parmesan']).build();
        final lookup = _createLookup([
          _ingredient('pasta', 'grain/pasta-bread', {'contains-gluten'}),
          _ingredient(
              'grädde', 'protein/dairy', {'dairy', 'animal-product', 'cream'}),
          _ingredient('parmesan', 'protein/dairy/cheese', {'dairy', 'cheese'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('krämig'), isTrue);
        expect(result.hasTag('ostig'), isTrue);
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
