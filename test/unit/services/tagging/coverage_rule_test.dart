/// BUT-2247: an unmatched ingredient row withholds FREE, never CONTAINS.
///
/// Before this rule one unrecognised row ("1 kruka koriander") made every
/// allergen and diet of the recipe UNKNOWN, and the menu let UNKNOWN
/// recipes through to a milk-allergic diner even when grädde was matched.
/// A matched trigger is known whatever the rest of the list is; only
/// "fritt från" needs every row read.
///
/// Runs the whole generator on the static config, and Phase 1 on the
/// seeded Firebase artifacts, so both config branches carry the rule.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_allergen.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_dietary.dart';
import 'package:butlery/services/tagging/tag_generator.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/helpers/tagging_test_helper.dart';

IngredientData _gradde() => TaggingTestHelper.ingredient(
  'grädde',
  'protein/dairy',
  {'animal-product', 'dairy'},
);

IngredientData _ris() => TaggingTestHelper.ingredient('ris', 'grain', const {});

IngredientData _kott() => TaggingTestHelper.ingredient(
  'nötfärs',
  'protein/meat',
  {'animal-product', 'meat', 'beef'},
);

IngredientData _lax() => TaggingTestHelper.ingredient(
  'lax',
  'protein/seafood/fish',
  {'animal-product', 'fish', 'seafood'},
);

/// [rows] matched plus one row the register did not recognise.
IngredientLookupResult _withUnknown(List<IngredientData> rows) =>
    IngredientLookupResult.fromLists(
      matched: rows,
      unmatched: const ['kruka koriand'],
    );

FirebaseTagConfig _seededConfig() {
  Map<String, dynamic> load(String name) =>
      jsonDecode(
            File('scripts/output/tagConfigs/$name.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  return FirebaseTagConfig.fromDocuments(
    allergensData: load('allergens'),
    dietaryData: load('dietary'),
    cuisinesData: load('cuisines'),
    propertiesData: load('properties'),
    displayData: load('display'),
  );
}

void main() {
  final generator = TagGenerator();
  final recipe = RecipeBuilder().withTitle('Gräddsås').withIngredients([
    'grädde',
    'ris',
    'kruka koriander',
  ]).build();

  group('BUT-2247 acceptance, whole generator (static config)', () {
    test(
      'grädde + unknown row → mjölk CONTAINS, and the verdict names grädde',
      () {
        final lookup = _withUnknown([_gradde(), _ris()]);
        expect(lookup.coverage, lessThan(1.0));

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.getAllergenStatus('mjölk'), TriState.contains);
        final decision = result.decisions!.firstWhere(
          (d) => d.type == 'allergen' && d.key == 'mjölk',
        );
        expect(decision.triggeringIngredients, ['grädde']);
        expect(result.coverage, lessThan(1.0));
      },
    );

    test('only read rows, none with mjölk → mjölk FREE', () {
      final lookup = IngredientLookupResult.fromLists(
        matched: [_ris()],
        unmatched: const [],
      );

      final result = generator.generate(ingredients: lookup, recipe: recipe);

      expect(result.getAllergenStatus('mjölk'), TriState.free);
    });

    test('no mjölk among the read rows + unknown row → mjölk UNKNOWN', () {
      final result = generator.generate(
        ingredients: _withUnknown([_ris()]),
        recipe: recipe,
      );

      expect(result.getAllergenStatus('mjölk'), TriState.unknown);
    });

    test('the same rule for diets: kött + unknown row → vegetarisk and '
        'vegansk CONTAINS; ris + unknown row → UNKNOWN', () {
      final withMeat = generator.generate(
        ingredients: _withUnknown([_kott()]),
        recipe: recipe,
      );
      expect(withMeat.getDietaryStatus('vegetarisk'), TriState.contains);
      expect(withMeat.getDietaryStatus('vegansk'), TriState.contains);
      expect(withMeat.getDietaryStatus('pescetarian'), TriState.contains);

      final noMeat = generator.generate(
        ingredients: _withUnknown([_ris()]),
        recipe: recipe,
      );
      expect(noMeat.getDietaryStatus('vegetarisk'), TriState.unknown);
      expect(noMeat.getDietaryStatus('vegansk'), TriState.unknown);
    });

    test('a required-property diet still needs full coverage for FREE: '
        'lax + unknown row → pescetarian UNKNOWN', () {
      final result = generator.generate(
        ingredients: _withUnknown([_lax()]),
        recipe: recipe,
      );

      expect(result.getDietaryStatus('pescetarian'), TriState.unknown);
      expect(result.getAllergenStatus('fisk'), TriState.contains);
    });
  });

  group('BUT-2247 on the seeded Firebase config', () {
    final config = _seededConfig();

    test('grädde + unknown row → mjölk CONTAINS; gluten UNKNOWN', () {
      final result = Phase1AllergenCalculator.calculate(
        _withUnknown([_gradde()]),
        config,
      );
      expect(result.status['mjölk'], TriState.contains);
      expect(result.status['gluten'], TriState.unknown);
    });

    test(
      'kött + unknown row → vegetarisk CONTAINS; ris + unknown → UNKNOWN',
      () {
        final withMeat = Phase1DietaryCalculator.calculate(
          _withUnknown([_kott()]),
          config,
        );
        expect(withMeat.status['vegetarisk'], TriState.contains);

        final noMeat = Phase1DietaryCalculator.calculate(
          _withUnknown([_ris()]),
          config,
        );
        expect(noMeat.status['vegetarisk'], TriState.unknown);
      },
    );
  });
}
