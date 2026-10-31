import 'package:butlery/services/tagging/config/cuisine_config.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/helpers/tagging_test_helper.dart';

/// Cuisine by points (kärnflöde steg 5, Malin's decision 4, 2026-10-30): the
/// title counts most, a word that does not belong rules a cuisine out, and a
/// recipe gets at most two cuisines.
void main() {
  late TagGenerator generator;

  setUp(() => generator = TagGenerator());

  Set<String> cuisinesFor(
    String title,
    List<(String, String)> ingredients, {
    String? schemaCuisine,
    List<String> unmatched = const [],
  }) {
    final recipe = RecipeBuilder()
        .withTitle(title)
        .withTimeMinutes(30)
        .withIngredients([for (final (n, _) in ingredients) n])
        .build();
    recipe.core.cuisine = schemaCuisine;
    final lookup = TaggingTestHelper.createLookup([
      for (final (n, g) in ingredients) TaggingTestHelper.ingredient(n, g, {}),
    ], unmatched: unmatched);
    final tags = generator.generate(ingredients: lookup, recipe: recipe).tags;
    return tags.where(CuisineConfig.allTags.contains).toSet();
  }

  test('a negative word rules a cuisine out even when the title names it', () {
    final cuisines = cuisinesFor('Pasta med sojasås', [
      ('pasta', 'grain/pasta-bread'),
      ('sojasås', 'sauce'),
    ]);
    expect(cuisines, isNot(contains('italiensk')));
  });

  test('a recipe gets at most two cuisines', () {
    final cuisines = cuisinesFor('Tacos med kimchi och tzatziki', [
      ('tortilla', 'grain'),
      ('kimchi', 'vegetable'),
      ('gochujang', 'sauce'),
      ('tzatziki', 'dairy'),
      ('fetaost', 'dairy'),
    ]);
    expect(cuisines.length, lessThanOrEqualTo(2));
  });

  test('the title outweighs a single matching ingredient set', () {
    final cuisines = cuisinesFor('Pad thai', [
      ('risnudlar', 'grain/pasta-bread'),
      ('fisksås', 'sauce'),
      ('lime', 'fruit/citrus'),
    ]);
    expect(cuisines.first, 'thailändsk');
  });

  test('a schema.org cuisine counts but does not stop the scoring', () {
    final cuisines = cuisinesFor(
      'Kycklinggryta',
      [('kyckling', 'protein/meat/poultry')],
      schemaCuisine: 'Italian',
    );
    expect(cuisines, contains('italiensk'));
  });

  test('one ingredient that matches both by name and group counts once', () {
    // Ricotta ravioli hits Italian by name (ricotta) and by group (pasta);
    // Italian needs two matches, which one ingredient must not reach alone.
    final cuisines = cuisinesFor('Gratäng', [
      ('ricottaravioli', 'grain/pasta-bread'),
    ]);
    expect(cuisines, isNot(contains('italiensk')));
  });

  test('on equal points a specific cuisine goes before a general one', () {
    // Medelhavsmat, kinesisk and japansk all score 3; medelhavsmat comes first
    // in the config but is general, so the two specific ones are kept.
    final cuisines = cuisinesFor('Middag', [
      ('olivolja', 'fat/oil'),
      ('citron', 'fruit/citrus'),
      ('vitlök', 'vegetable'),
      ('hoisin', 'sauce'),
      ('ostronsås', 'sauce'),
      ('böngroddar', 'vegetable'),
      ('miso', 'other'),
      ('wasabi', 'other'),
      ('nori', 'other'),
    ]);
    expect(cuisines, {'kinesisk', 'japansk'});
  });

  test('schema.org points can lift a cuisine past an ingredient-only one', () {
    // Thai by title (3); Mexican by schema plus avocado (2 + 1); Greek by two
    // ingredients (2). The cap keeps two.
    final cuisines = cuisinesFor(
      'Pad thai',
      [
        ('avokado', 'fruit'),
        ('fetaost', 'dairy/cheese'),
        ('oregano', 'spice'),
      ],
      schemaCuisine: 'Mexican',
    );
    expect(cuisines, {'thailändsk', 'mexikansk'});
  });

  group('coverage bar (COV-06)', () {
    const pastaAndParmesan = [
      ('pasta', 'grain/pasta-bread'),
      ('parmesan', 'dairy/cheese'),
    ];

    test('pasta and parmesan are Italian when every line is known', () {
      expect(
        cuisinesFor('Middag', pastaAndParmesan),
        contains('italiensk'),
        reason: 'precondition: the fixture is eligible at full coverage',
      );
    });

    test('below 0.60 the ingredients alone do not name a cuisine', () {
      final cuisines = cuisinesFor(
        'Middag',
        pastaAndParmesan,
        unmatched: ['okänd 1', 'okänd 2'],
      );
      expect(cuisines, isNot(contains('italiensk')));
    });

    test('at exactly 0.60 the ingredients count again', () {
      final cuisines = cuisinesFor(
        'Middag',
        [...pastaAndParmesan, ('lök', 'vegetable')],
        unmatched: ['okänd 1', 'okänd 2'],
      );
      expect(cuisines, contains('italiensk'));
    });

    test('a title keyword still names the cuisine at low coverage', () {
      final cuisines = cuisinesFor(
        'Pizza',
        [pastaAndParmesan.first],
        unmatched: ['okänd 1', 'okänd 2'],
      );
      expect(cuisines, contains('italiensk'));
    });

    test('a schema.org cuisine still names it at low coverage', () {
      final cuisines = cuisinesFor(
        'Middag',
        [pastaAndParmesan.first],
        schemaCuisine: 'Italian',
        unmatched: ['okänd 1', 'okänd 2'],
      );
      expect(cuisines, contains('italiensk'));
    });

    test('a negative word still rules the cuisine out at low coverage', () {
      final cuisines = cuisinesFor(
        'Pasta med sojasås',
        [pastaAndParmesan.first],
        unmatched: ['okänd 1', 'okänd 2'],
      );
      expect(cuisines, isNot(contains('italiensk')));
    });
  });
}
