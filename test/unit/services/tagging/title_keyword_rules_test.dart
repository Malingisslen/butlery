import 'package:butlery/services/tagging/tag_generator.dart';
import 'package:butlery/services/tagging/title_keyword_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/helpers/tagging_test_helper.dart';

/// Title keywords (kärnflöde steg 5, Malin's decision 1, 2026-10-30): SET adds
/// the tag on the title alone, BOOST and CONFIRM only when the recipe already
/// points the same way, and no title ever sets an allergy or diet tag.
void main() {
  late TagGenerator generator;

  setUp(() => generator = TagGenerator());

  Set<String> tagsFor(
    String title, {
    int? timeMinutes = 40,
    List<({String name, String group, Set<String> props, String? price})>
        ingredients =
        const [],
  }) {
    final recipe = RecipeBuilder()
        .withTitle(title)
        .withTimeMinutes(timeMinutes)
        .withIngredients([
          for (final i in ingredients) i.name,
          if (ingredients.isEmpty) 'ris',
        ])
        .build();
    final lookup = TaggingTestHelper.createLookup([
      for (final i in ingredients)
        TaggingTestHelper.ingredient(
          i.name,
          i.group,
          i.props,
          priceCategory: i.price,
        ),
      if (ingredients.isEmpty) TaggingTestHelper.ingredient('ris', 'grain', {}),
    ]);
    return generator.generate(ingredients: lookup, recipe: recipe).tags;
  }

  group('SET', () {
    test('a SET word makes the dish strong and drops mild', () {
      final tags = tagsFor('Lamm vindaloo');
      expect(tags, contains('stark'));
      expect(tags, isNot(contains('mild')));
    });

    test('a SET word for luxury needs nothing else', () {
      expect(tagsFor('Gourmetburgare'), contains('lyxig'));
    });

    test('15 min in the title sets snabblagat', () {
      expect(
        tagsFor('Pasta på 15 min', timeMinutes: null),
        contains('snabblagat'),
      );
    });
  });

  test('the pipeline path applies title words too', () {
    // The app tags through assembleResult (TaggingPipelineRunner), not
    // generate, so the title rules must run there as well.
    final recipe = RecipeBuilder()
        .withTitle('Lamm vindaloo')
        .withTimeMinutes(40)
        .withIngredients(['ris'])
        .build();
    final lookup = TaggingTestHelper.createLookup([
      TaggingTestHelper.ingredient('ris', 'grain', {}),
    ]);
    final phase1 = generator.resolveConfigPhases().phase1.calculate(
      lookup,
      recipe,
    );
    final phase2 = generator.runPhase2(phase1, recipe);
    final tags = generator
        .assembleResult(
          ingredients: lookup,
          recipe: recipe,
          phase1Result: phase1,
          phase2Result: phase2,
          isPartial: true,
          configVersion: null,
        )
        .tags;
    expect(tags, contains('stark'));
    expect(tags, isNot(contains('mild')));
  });

  group('BOOST', () {
    test('a BOOST word alone adds nothing', () {
      expect(tagsFor('Het kycklinggryta'), isNot(contains('stark')));
    });

    test('a BOOST word plus a strong ingredient makes the dish strong', () {
      // Too few known ingredients for Phase 2 to call the dish strong on its
      // own, so only the title can.
      Set<String> tags(String title) {
        final recipe = RecipeBuilder()
            .withTitle(title)
            .withTimeMinutes(40)
            .withIngredients(['kyckling', 'chili', 'a', 'b', 'c'])
            .build();
        final lookup = TaggingTestHelper.createLookup(
          [
            TaggingTestHelper.ingredient(
              'kyckling',
              'protein/meat/poultry',
              {'meat'},
            ),
            TaggingTestHelper.ingredient('chili', 'spice', {'is-spicy'}),
          ],
          unmatched: ['a', 'b', 'c'],
        );
        return generator.generate(ingredients: lookup, recipe: recipe).tags;
      }

      expect(tags('Kycklinggryta'), isNot(contains('stark')));
      expect(tags('Het kycklinggryta'), contains('stark'));
    });

    test('lyx needs a premium ingredient', () {
      expect(tagsFor('Lyxpasta'), isNot(contains('lyxig')));
      expect(
        tagsFor(
          'Lyxpasta',
          ingredients: [
            (name: 'pasta', group: 'grain/pasta-bread', props: {}, price: null),
            (
              name: 'havskräfta',
              group: 'protein/seafood/shellfish',
              props: {},
              price: 'high',
            ),
          ],
        ),
        contains('lyxig'),
      );
    });

    test('snabb needs a stated time of at most 30 minutes', () {
      expect(tagsFor('Snabb soppa', timeMinutes: 25), contains('snabblagat'));
      expect(
        tagsFor('Snabb soppa', timeMinutes: 50),
        isNot(contains('snabblagat')),
      );
      expect(
        tagsFor('Snabb soppa', timeMinutes: null),
        isNot(contains('snabblagat')),
      );
    });
  });

  group('comfort food', () {
    test('a SET word needs nothing else', () {
      expect(tagsFor('Husmanskost med kålpudding'), contains('comfort-food'));
    });

    test('a BOOST word needs a hearty dish', () {
      const cucumber = [
        (name: 'gurka', group: 'vegetable', props: <String>{}, price: null),
      ];
      expect(
        tagsFor('Klassisk sallad', ingredients: cucumber),
        isNot(contains('comfort-food')),
      );
      expect(
        tagsFor('Klassisk gratäng', ingredients: cucumber),
        contains('comfort-food'),
      );
    });
  });

  group('child friendly', () {
    test('för barn adds the tag when nothing is strong or alcoholic', () {
      expect(tagsFor('Pannkakor för barn'), contains('barnvänlig'));
    });

    test('a strong title wins over för barn', () {
      final tags = tagsFor('Vindaloo för barn');
      expect(tags, contains('stark'));
      expect(tags, isNot(contains('barnvänlig')));
    });

    test('an ingredient not found in the database withholds the tag', () {
      final recipe = RecipeBuilder()
          .withTitle('Pannkakor för barn')
          .withIngredients(['mjöl', 'okänd vara'])
          .build();
      final lookup = TaggingTestHelper.createLookup(
        [TaggingTestHelper.ingredient('mjöl', 'grain', {})],
        unmatched: ['okänd vara'],
      );
      final tags = generator.generate(ingredients: lookup, recipe: recipe).tags;
      expect(tags, isNot(contains('barnvänlig')));
    });
  });

  test('a title never sets an allergy or diet tag', () {
    final tags = tagsFor(
      'Glutenfri vegansk pannkaka',
      ingredients: [
        (
          name: 'vetemjöl',
          group: 'grain',
          props: {'contains-gluten'},
          price: null,
        ),
        (
          name: 'mjölk',
          group: 'dairy',
          props: {'dairy', 'animal-product'},
          price: null,
        ),
      ],
    );
    expect(tags, isNot(contains('glutenfri')));
    expect(tags, isNot(contains('vegansk')));
  });

  group('titleHasWord', () {
    test('finds a word at the start of a word, not inside one', () {
      expect(
        TitleKeywordRules.titleHasWord('kyckling i chilisås', 'chili'),
        isTrue,
      );
      expect(
        TitleKeywordRules.titleHasWord('pasta all\'arrabbiata', 'arrabbiata'),
        isTrue,
      );
      expect(TitleKeywordRules.titleHasWord('veckans nyhet', 'het'), isFalse);
      expect(TitleKeywordRules.titleHasWord('het soppa', 'het'), isTrue);
      expect(
        TitleKeywordRules.titleHasWord('gryta på 115 min', '15 min'),
        isFalse,
      );
    });
  });
}
