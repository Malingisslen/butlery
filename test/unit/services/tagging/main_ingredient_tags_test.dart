import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/helpers/tagging_test_helper.dart';

typedef _Line = (IngredientData, double?);

_Line _r(
  String name,
  String group,
  double? grams, {
  Set<String> props = const {},
  String? price,
  String? carbon,
}) => (
  TaggingTestHelper.ingredient(
    name,
    group,
    props,
    priceCategory: price,
    carbonFootprintCategory: carbon,
  ),
  grams,
);

Recipe _recipe({
  int? portions = 4,
  int? prep,
  int lineCount = 3,
  String? title,
}) {
  final recipe = RecipeBuilder()
      .withTitle(title ?? 'Testrätt')
      .withPortions(portions)
      .withIngredients([for (var i = 0; i < lineCount; i++) 'rad $i'])
      .build();
  recipe.core.prepTimeMinutes = prep;
  return recipe;
}

Set<String> _tags(
  List<_Line> rows, {
  Recipe? recipe,
  List<String> unmatched = const [],
}) => TagGenerator()
    .generate(
      ingredients: TaggingTestHelper.weighedLookup(rows, unmatched: unmatched),
      recipe: recipe ?? _recipe(lineCount: rows.length + unmatched.length),
    )
    .tags;

void main() {
  group('proteinrik: 200 g weighed protein per portion', () {
    test('199 g per portion is not enough, 200 g is', () {
      final recipe = _recipe(portions: 4);

      expect(
        _tags([_r('kyckling', 'protein/meat/poultry', 796)], recipe: recipe),
        isNot(contains('proteinrik')),
      );
      expect(
        _tags([_r('kyckling', 'protein/meat/poultry', 800)], recipe: recipe),
        contains('proteinrik'),
      );
    });

    test('the threshold follows the portions', () {
      final rows = [_r('kyckling', 'protein/meat/poultry', 400)];

      expect(_tags(rows, recipe: _recipe(portions: 2)), contains('proteinrik'));
      expect(
        _tags(rows, recipe: _recipe(portions: 4)),
        isNot(contains('proteinrik')),
      );
    });

    test('protein from several lines and kinds adds up', () {
      final tags = _tags([
        _r('lax', 'protein/seafood/fish', 150),
        _r('ägg', 'protein/egg', 100),
        _r('tofu', 'protein/plant-based', 150),
      ], recipe: _recipe(portions: 2));

      expect(tags, contains('proteinrik'));
    });

    test('no portions, no tag, however much protein', () {
      final rows = [_r('kyckling', 'protein/meat/poultry', 5000)];

      expect(
        _tags(rows, recipe: _recipe(portions: null)),
        isNot(contains('proteinrik')),
      );
      expect(
        _tags(rows, recipe: _recipe(portions: 0)),
        isNot(contains('proteinrik')),
      );
    });

    test('an unweighed protein line adds nothing', () {
      final tags = _tags([
        _r('kyckling', 'protein/meat/poultry', 300),
        _r('ägg', 'protein/egg', null),
        _r('lax', 'protein/seafood/fish', null),
      ], recipe: _recipe(portions: 2));

      expect(tags, isNot(contains('proteinrik')));
    });

    test('dairy is not protein for this tag', () {
      final tags = _tags([
        _r('mjölk', 'protein/dairy', 2000),
        _r('mozzarella', 'protein/dairy/cheese', 1000),
      ], recipe: _recipe(portions: 2));

      expect(tags, isNot(contains('proteinrik')));
    });

    test('weighed non-protein lines do not count', () {
      final tags = _tags([
        _r('potatis', 'vegetable/root', 3000),
        _r('kyckling', 'protein/meat/poultry', 100),
      ], recipe: _recipe(portions: 2));

      expect(tags, isNot(contains('proteinrik')));
    });
  });

  group('ostig: 100 g weighed cheese', () {
    IngredientData cheese(String name) =>
        TaggingTestHelper.ingredient(name, 'protein/dairy/cheese', {'dairy'});

    test('100 g is ostig, 99 g is not', () {
      expect(
        _tags([(cheese('parmesan'), 100)]),
        contains('ostig'),
      );
      expect(
        _tags([(cheese('parmesan'), 99)]),
        isNot(contains('ostig')),
      );
    });

    test('cheese from several lines adds up', () {
      final tags = _tags([(cheese('cheddar'), 60), (cheese('mozzarella'), 60)]);

      expect(tags, contains('ostig'));
    });

    test('the title does not make a dish ostig', () {
      final recipe = _recipe(title: 'Ostgratäng', lineCount: 2);

      expect(
        _tags([
          _r('pasta', 'grain', 300),
          (cheese('ost'), null),
        ], recipe: recipe),
        isNot(contains('ostig')),
      );
      expect(
        _tags([_r('pasta', 'grain', 300), (cheese('ost'), 30)], recipe: recipe),
        isNot(contains('ostig')),
      );
    });

    test('milk, cream, butter and yoghurt are dairy but not cheese', () {
      for (final name in ['mjölk', 'grädde', 'smör', 'yoghurt', 'kvarg']) {
        final tags = _tags([_r(name, 'protein/dairy', 500)]);

        expect(tags, isNot(contains('ostig')), reason: name);
      }
    });

    test('a heavy non-cheese line does not make cheese out of the rest', () {
      final tags = _tags([
        _r('mjölk', 'protein/dairy', 100),
        (cheese('feta'), 50),
      ]);

      expect(tags, isNot(contains('ostig')));
    });
  });

  group('klimatsmart: every main ingredient known and low/medium carbon', () {
    test('low and medium carbon mains give the tag', () {
      final tags = _tags([
        _r('pasta', 'grain', 300, carbon: 'low'),
        _r('ost', 'protein/dairy/cheese', 300, carbon: 'medium'),
      ]);

      expect(tags, contains('klimatsmart'));
    });

    test('a high-carbon line blocks it only when it is a main ingredient', () {
      _Line beef(double grams) =>
          _r('nötfärs', 'protein/meat/beef', grams, carbon: 'high');

      // 50 / 550 = 9 %: a pinch, not a main.
      expect(
        _tags([_r('pasta', 'grain', 500, carbon: 'low'), beef(50)]),
        contains('klimatsmart'),
      );
      expect(
        _tags([_r('pasta', 'grain', 100, carbon: 'low'), beef(500)]),
        isNot(contains('klimatsmart')),
      );
    });

    test('a main with no carbon category blocks it', () {
      final tags = _tags([
        _r('pasta', 'grain', 300, carbon: 'low'),
        _r('mysterium', 'other', 300),
      ]);

      expect(tags, isNot(contains('klimatsmart')));
    });

    test('an unknown main ingredient blocks it', () {
      final tags = _tags(
        [_r('pasta', 'grain', 400, carbon: 'low')],
        unmatched: ['mystisk sås'],
      );

      expect(tags, isNot(contains('klimatsmart')));
    });

    test('an unknown ingredient far down the list does not', () {
      final tags = _tags(
        [
          _r('a', 'grain', 100, carbon: 'low'),
          _r('b', 'grain', 100, carbon: 'low'),
          _r('c', 'grain', 100, carbon: 'low'),
        ],
        unmatched: ['mystisk sås'],
      );

      expect(tags, contains('klimatsmart'));
    });

    test('a staple with no carbon data is not a main ingredient', () {
      final tags = _tags([
        _r('salt', 'spice', null),
        _r('pasta', 'grain', 300, carbon: 'low'),
      ]);

      expect(tags, contains('klimatsmart'));
    });

    test('a recipe of only staples has no main to call climate-smart', () {
      expect(
        _tags([_r('salt', 'spice', null, carbon: 'low')]),
        isNot(contains('klimatsmart')),
      );
    });
  });

  group('budgetvänlig: every main known, priced, and not premium or high', () {
    test('priced low and medium mains give the tag', () {
      final tags = _tags([
        _r('pasta', 'grain', 300, price: 'low'),
        _r('tomat', 'vegetable', 300, price: 'medium'),
      ]);

      expect(tags, contains('budgetvänlig'));
    });

    test('a premium ingredient keeps it while it is not a main', () {
      // 40 / 540 = 7 %.
      final tags = _tags([
        _r('pasta', 'grain', 500, price: 'low'),
        _r('saffran', 'spice', 40, price: 'premium'),
      ]);

      expect(tags, contains('budgetvänlig'));
    });

    test('a premium main blocks it', () {
      final tags = _tags([
        _r('pasta', 'grain', 100, price: 'low'),
        _r('hummer', 'protein/seafood/shellfish', 500, price: 'premium'),
      ]);

      expect(tags, isNot(contains('budgetvänlig')));
    });

    test('a high-price main blocks it', () {
      final tags = _tags([
        _r('pasta', 'grain', 100, price: 'low'),
        _r('lammfilé', 'protein/meat/lamb', 500, price: 'high'),
      ]);

      expect(tags, isNot(contains('budgetvänlig')));
    });

    test('a main with no price blocks it', () {
      final tags = _tags([
        _r('pasta', 'grain', 300, price: 'low'),
        _r('mysterium', 'other', 300),
      ]);

      expect(tags, isNot(contains('budgetvänlig')));
    });

    test('an unknown main ingredient blocks it', () {
      final tags = _tags(
        [_r('pasta', 'grain', 400, price: 'low')],
        unmatched: ['mystisk sås'],
      );

      expect(tags, isNot(contains('budgetvänlig')));
    });

    test(
      'a priced staple does not matter, an unpriced one does not either',
      () {
        final tags = _tags([
          _r('olivolja', 'fat/oil', null, price: 'premium'),
          _r('pasta', 'grain', 300, price: 'low'),
        ]);

        expect(tags, contains('budgetvänlig'));
      },
    );
  });

  group('fisk-och-skaldjur: a main ingredient is seafood', () {
    test('a main fish or shellfish gives the tag', () {
      expect(
        _tags([
          _r('lax', 'protein/seafood/fish', 300),
          _r('potatis', 'vegetable/root', 300),
        ]),
        contains('fisk-och-skaldjur'),
      );
      expect(
        _tags([
          _r('räkor', 'protein/seafood/shellfish', 300),
          _r('pasta', 'grain', 300),
        ]),
        contains('fisk-och-skaldjur'),
      );
    });

    test('the same fish as a pinch is not a main ingredient', () {
      // 10 / 510 = 2 %.
      final tags = _tags([
        _r('pasta', 'grain', 500),
        _r('ansjovis', 'protein/seafood/fish', 10),
      ]);

      expect(tags, isNot(contains('fisk-och-skaldjur')));
    });

    test('an unweighed seafood line counts only among the first three', () {
      expect(
        _tags([
          _r('lax', 'protein/seafood/fish', null),
          _r('a', 'grain', null),
          _r('b', 'grain', null),
        ]),
        contains('fisk-och-skaldjur'),
      );
      expect(
        _tags([
          _r('a', 'grain', null),
          _r('b', 'grain', null),
          _r('c', 'grain', null),
          _r('lax', 'protein/seafood/fish', null),
        ]),
        isNot(contains('fisk-och-skaldjur')),
      );
    });

    test('a staple in front does not push an unweighed fish out', () {
      final tags = _tags([
        _r('salt', 'spice', null),
        _r('a', 'grain', null),
        _r('b', 'grain', null),
        _r('lax', 'protein/seafood/fish', null),
      ]);

      expect(tags, contains('fisk-och-skaldjur'));
    });

    test('meat as the main gives no seafood tag', () {
      expect(
        _tags([_r('kyckling', 'protein/meat/poultry', 500)]),
        isNot(contains('fisk-och-skaldjur')),
      );
    });
  });

  group('lite-jobb: a stated preparation time under 15 minutes', () {
    Set<String> withPrep(int? prep, {int? total}) {
      final recipe = _recipe(prep: prep);
      recipe.core.timeMinutes = total;
      return _tags([_r('pasta', 'grain', 300)], recipe: recipe);
    }

    test('1 and 14 minutes qualify', () {
      expect(withPrep(1), contains('lite-jobb'));
      expect(withPrep(14), contains('lite-jobb'));
    });

    test('15 minutes does not', () {
      expect(withPrep(15), isNot(contains('lite-jobb')));
    });

    test('zero or no stated time does not', () {
      expect(withPrep(0), isNot(contains('lite-jobb')));
      expect(withPrep(null), isNot(contains('lite-jobb')));
    });

    test('a short total time without a stated preparation time does not', () {
      expect(withPrep(null, total: 10), isNot(contains('lite-jobb')));
    });
  });

  group('örtig: two different fresh herbs', () {
    test('two distinct fresh herbs give the tag', () {
      final tags = _tags([
        _r('dill', 'spice/herb-fresh', 5),
        _r('persilja', 'spice/herb-fresh', 5),
      ]);

      expect(tags, contains('örtig'));
    });

    test('one fresh herb does not', () {
      final tags = _tags([
        _r('dill', 'spice/herb-fresh', 5),
        _r('timjan', 'spice/herb-dried', 5),
        _r('pasta', 'grain', 300),
      ]);

      expect(tags, isNot(contains('örtig')));
    });

    test('the same herb on two lines is still one herb', () {
      final tags = _tags([
        _r('dill', 'spice/herb-fresh', 5),
        _r('dill', 'spice/herb-fresh', 3),
      ]);

      expect(tags, isNot(contains('örtig')));
    });
  });

  group('barnvänlig: not strong, no spicy row, alcohol known to be absent', () {
    List<_Line> pancakes() => [
      _r('vetemjöl', 'grain', 250, props: {'contains-gluten'}),
      _r('mjölk', 'protein/dairy', 600, props: {'dairy'}),
      _r('ägg', 'protein/egg', 150, props: {'egg'}),
    ];

    test('pancakes from flour, milk and egg qualify with no protein rule', () {
      expect(_tags(pancakes()), contains('barnvänlig'));
    });

    test('an alcohol row blocks it', () {
      final tags = _tags([
        ...pancakes(),
        _r('rödvin', 'beverage/alcohol', 100, props: {'contains-alcohol'}),
      ]);

      expect(tags, isNot(contains('barnvänlig')));
    });

    test('a spicy row blocks it', () {
      final tags = _tags([
        ...pancakes(),
        _r('chili', 'spice/hot', 5, props: {'is-spicy'}),
      ]);

      expect(tags, isNot(contains('barnvänlig')));
    });

    test(
      'an unknown ingredient blocks it, since alcohol cannot be ruled out',
      () {
        final tags = _tags(pancakes(), unmatched: ['mystisk sås']);

        expect(tags, isNot(contains('barnvänlig')));
      },
    );
  });

  group('få-ingredienser: at most 6 lines that are not staples', () {
    List<_Line> nonStaples(int count) => [
      for (var i = 0; i < count; i++) _r('ingrediens $i', 'vegetable', 100),
    ];

    test('six plain lines qualify, seven do not', () {
      expect(
        _tags(nonStaples(6), recipe: _recipe(lineCount: 6)),
        contains('få-ingredienser'),
      );
      expect(
        _tags(nonStaples(7), recipe: _recipe(lineCount: 7)),
        isNot(contains('få-ingredienser')),
      );
    });

    test('salt, pepper, water and oil on the list do not count', () {
      final rows = [
        ...nonStaples(6),
        _r('salt', 'spice', null),
        _r('svartpeppar', 'spice', null),
        _r('vatten', 'liquid', null),
        _r('olivolja', 'fat/oil', null),
      ];

      expect(
        _tags(rows, recipe: _recipe(lineCount: 10)),
        contains('få-ingredienser'),
      );
    });

    test('unmatched staple names do not count, unmatched others do', () {
      final recipe = _recipe(lineCount: 9);

      expect(
        _tags(nonStaples(6), recipe: recipe, unmatched: ['salt', 'rapsolja']),
        contains('få-ingredienser'),
      );
      expect(
        _tags(
          nonStaples(6),
          recipe: recipe,
          unmatched: ['salt', 'mystisk sås'],
        ),
        isNot(contains('få-ingredienser')),
      );
    });
  });
}
