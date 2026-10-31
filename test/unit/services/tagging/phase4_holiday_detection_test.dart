/// Unit tests for Phase 4 holiday detection in the tagging system.
///
/// Tests Swedish holiday ingredient detection for:
/// - Jul (Christmas) - julskinka, lutfisk, jansson, etc.
/// - Midsommar (Midsummer) - pickled herring, new potatoes, strawberries
/// - Påsk (Easter) - lamb, eggs, Easter candy
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/helpers/tagging_test_helper.dart';

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
            .withIngredients(['skinka', 'senap', 'ägg'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('skinka', 'protein/meat/pork', {
            'meat',
            'pork',
          }),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('jul'), isTrue);
      });

      test('detects jul from julskinka ingredient', () {
        final recipe = RecipeBuilder()
            .withTitle('Klassisk julmat')
            .withIngredients(['julskinka', 'brödsmulor', 'senap'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('julskinka', 'protein/meat/pork', {
            'meat',
            'pork',
          }),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('jul'), isTrue);
      });

      test('detects jul from lutfisk ingredient', () {
        final recipe = RecipeBuilder()
            .withTitle('Traditionell Lutfisk')
            .withIngredients(['lutfisk', 'vitsås', 'ärtor'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('lutfisk', 'protein/seafood/fish', {
            'fish',
          }),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('jul'), isTrue);
      });

      test('detects jul from janssons frestelse', () {
        final recipe = RecipeBuilder()
            .withTitle('Janssons frestelse')
            .withIngredients(['potatis', 'ansjovis', 'grädde', 'lök'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('potatis', 'vegetable/root', {}),
          TaggingTestHelper.ingredient('ansjovis', 'protein/seafood/fish', {
            'fish',
          }),
          TaggingTestHelper.ingredient('grädde', 'protein/dairy', {
            'dairy',
            'cream',
          }),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('jul'), isTrue);
      });

      test('does not detect jul from regular recipes', () {
        final recipe = RecipeBuilder()
            .withTitle('Pasta med köttfärssås')
            .withIngredients(['pasta', 'köttfärs', 'tomatsås'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('pasta', 'grain/pasta-bread', {
            'contains-gluten',
          }),
          TaggingTestHelper.ingredient('köttfärs', 'protein/meat/beef', {
            'meat',
            'beef',
          }),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('jul'), isFalse);
      });
    });

    group('midsommar (Midsummer) detection', () {
      test('detects midsommar from title', () {
        final recipe = RecipeBuilder()
            .withTitle('Midsommarmat - Sill och potatis')
            .withIngredients(['inlagd sill', 'färskpotatis', 'gräddfil'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('inlagd sill', 'protein/seafood/fish', {
            'fish',
          }),
          TaggingTestHelper.ingredient('färskpotatis', 'vegetable/root', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('midsommar'), isTrue);
      });

      test('does not detect midsommar from single ingredient', () {
        final recipe = RecipeBuilder()
            .withTitle('Kokt potatis')
            .withIngredients(['potatis', 'smör', 'dill'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('potatis', 'vegetable/root', {}),
          TaggingTestHelper.ingredient('smör', 'protein/dairy', {'dairy'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('midsommar'), isFalse);
      });
    });

    group('påsk (Easter) detection', () {
      test('detects påsk from title', () {
        final recipe = RecipeBuilder()
            .withTitle('Påskmiddag med lamm')
            .withIngredients(['lammkotlett', 'rosmarin', 'vitlök'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('lammkotlett', 'protein/meat/lamb', {
            'meat',
            'lamb',
          }),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('påsk'), isTrue);
      });

      test('lamb alone is not Easter food (beslut 6)', () {
        final recipe = RecipeBuilder()
            .withTitle('Vardaglig lammgryta')
            .withIngredients(['lammkött', 'tomat', 'vitlök'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('lammkött', 'protein/meat/lamb', {
            'meat',
            'lamb',
          }),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('påsk'), isFalse);
      });

      test('lamb with eggs is Easter food', () {
        final recipe = RecipeBuilder()
            .withTitle('Lammstek med ägghalvor')
            .withIngredients(['lammstek', 'ägg'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('lammstek', 'protein/meat/lamb', {
            'meat',
          }),
          TaggingTestHelper.ingredient('ägg', 'protein/egg', {'egg'}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('påsk'), isTrue);
      });
    });

    group('edge cases', () {
      test('does not false-detect holidays from similar words', () {
        final recipe = RecipeBuilder()
            .withTitle('Julienne skurna grönsaker')
            .withIngredients(['morot', 'selleri', 'purjolök'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('morot', 'vegetable', {}),
          TaggingTestHelper.ingredient('selleri', 'vegetable', {}),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // Julienne should not trigger jul detection
        expect(result.hasTag('jul'), isFalse);
      });
    });

    group('one ingredient never makes a holiday (beslut 6)', () {
      bool hasTag(String tag, List<String> names) {
        final recipe = RecipeBuilder()
            .withTitle('Rätt')
            .withIngredients(names)
            .build();
        final lookup = TaggingTestHelper.createLookup([
          for (final n in names) TaggingTestHelper.ingredient(n, 'other', {}),
        ]);
        return generator
            .generate(ingredients: lookup, recipe: recipe)
            .hasTag(tag);
      }

      test('nyår needs two festive ingredients', () {
        expect(hasTag('nyår', ['hummer']), isFalse);
        expect(hasTag('nyår', ['hummer', 'ostron']), isTrue);
      });

      test('kräftskiva needs crayfish with dill', () {
        expect(hasTag('kräftskiva', ['kräftor']), isFalse);
        expect(hasTag('kräftskiva', ['kräftor', 'krondill']), isTrue);
      });

      test('jul needs a Christmas main with a Christmas side', () {
        expect(hasTag('jul', ['rödbetor', 'sill']), isFalse);
        expect(hasTag('jul', ['julskinka', 'rödbetssallad']), isTrue);
      });

      test('a side word inside another word does not count', () {
        expect(hasTag('jul', ['julskinka', 'blomkål']), isFalse);
      });

      test('påsk from eggs with herring', () {
        expect(hasTag('påsk', ['ägg']), isFalse);
        expect(hasTag('påsk', ['ägg', 'inlagd sill']), isTrue);
      });

      test(
        'midsommar needs strawberries with cream, or herring with new potatoes',
        () {
          expect(hasTag('midsommar', ['jordgubbar']), isFalse);
          expect(hasTag('midsommar', ['jordgubbar', 'vispgrädde']), isTrue);
          expect(hasTag('midsommar', ['sill', 'färskpotatis']), isTrue);
        },
      );

      test('saffron alone is not lucia', () {
        expect(hasTag('lucia', ['saffran']), isFalse);
      });

      test('lucia needs saffron in a bake', () {
        final recipe = RecipeBuilder()
            .withTitle('Saffransbullar')
            .withIngredients(['saffran', 'vetemjöl'])
            .build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('saffran', 'spice', {}),
          TaggingTestHelper.ingredient('vetemjöl', 'grain', {}),
        ]);
        expect(
          generator
              .generate(ingredients: lookup, recipe: recipe)
              .hasTag('lucia'),
          isTrue,
        );
      });
    });
  });
}
