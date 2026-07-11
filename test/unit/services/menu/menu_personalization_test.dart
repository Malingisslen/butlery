import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/menu/menu_scoring.dart';
import 'package:butlery/services/menu/parser/code_lexicon_provider.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';

/// Builds a never-cooked dinner (recency weight 90) with the given cook time
/// and optional single cuisine tag, so the pantry nudge can be tested against a
/// clean baseline (no season boost, no recency variation).
Recipe _dinner(
  String id, {
  int? timeMinutes = 30,
  String? cuisineTag,
}) {
  final base = RecipeFactory.build(
    id: id,
    title: id,
    mealType: 'middag',
    timeMinutes: timeMinutes,
    lastCookedAt: null,
  );
  final tagResult = cuisineTag != null
      ? TagResult(
          tags: {cuisineTag},
          allergenStatus: const {},
          dietaryStatus: const {},
          coverage: 1.0,
          generatedAt: DateTime.utc(2026, 1, 1),
        )
      : null;
  return Recipe(
    core: base.core.copyWith(tagResult: tagResult),
    type: base.type,
  );
}

double _weight(
  Recipe r, {
  MenuScoringContext context = MenuScoringContext.empty,
}) =>
    MenuService.debugRecipeWeight(r, seasonTag: 'no_season', context: context);

void main() {
  // BUT-1594 removed the cuisine-affinity + cooking-skill menu nudges (the
  // weekly menu is drawn from the user's own recipes, so weighting by taste
  // double-counted it). Pantry overlap (BUT-1321) is the only remaining nudge.
  group('Menu personalisation (BUT-1321 pantry overlap)', () {
    group('Pantry overlap boost', () {
      test('a pantry-match recipe outweighs an identical no-match sibling', () {
        final match = _dinner('match');
        final noMatch = _dinner('no_match');

        final context = MenuScoringContext(
          pantryMatchByRecipeId: {'match': 1.0},
        );

        expect(
          _weight(match, context: context),
          greaterThan(_weight(noMatch, context: context)),
          reason: 'full pantry overlap should nudge the recipe up',
        );
      });

      test('no pantry data leaves the weight unchanged (never penalised)', () {
        final r = _dinner('r');
        // Recipe not present in the (empty) pantry map.
        final context = MenuScoringContext(
          pantryMatchByRecipeId: {'someone_else': 1.0},
        );
        expect(_weight(r, context: context), equals(_weight(r)));
      });

      test('zero overlap present in the map is parity (never penalised)', () {
        // Distinct from the "absent from map" case above: the recipe IS in the
        // pantry map, but with 0.0 overlap. Exercises the `overlap <= 0` guard,
        // not the `overlap == null` one — this is condition 1's exact wording
        // ("zero match → weight unchanged").
        final r = _dinner('r');
        final context = MenuScoringContext(
          pantryMatchByRecipeId: {'r': 0.0},
        );
        expect(_weight(r, context: context), equals(_weight(r)));
      });

      test('partial overlap boosts less than full overlap', () {
        final full = _dinner('full');
        final partial = _dinner('partial');
        final context = MenuScoringContext(
          pantryMatchByRecipeId: {'full': 1.0, 'partial': 0.4},
        );
        expect(
          _weight(full, context: context),
          greaterThan(_weight(partial, context: context)),
        );
        expect(
          _weight(partial, context: context),
          greaterThan(_weight(partial)),
          reason: 'partial overlap still gets some boost',
        );
      });
    });

    group('Parity — empty context is byte-for-byte unchanged', () {
      test('empty context equals the pre-change weight for varied recipes', () {
        final recipes = [
          _dinner('never', timeMinutes: 45),
          _dinner('ita', timeMinutes: 20, cuisineTag: 'italiensk'),
        ];
        for (final r in recipes) {
          // Default (no context) and explicit empty context are identical, and
          // both equal the raw recency baseline (never-cooked, no season = 90).
          expect(
            MenuService.debugRecipeWeight(r, seasonTag: 'no_season'),
            equals(_weight(r, context: MenuScoringContext.empty)),
          );
          expect(
            _weight(r, context: MenuScoringContext.empty),
            equals(90.0),
            reason: 'never-cooked, no season, unrated → recency weight 90',
          );
        }
      });

      test(
        'a populated context that matches no recipe still yields 1.0',
        () {
          final r = _dinner('r', timeMinutes: 45);
          final context = const MenuScoringContext(
            pantryMatchByRecipeId: {'other': 1.0},
          );
          expect(_weight(r, context: context), equals(_weight(r)));
        },
      );
    });

    // Product-Manager condition: the pantry nudge may not dominate the rating
    // signal — its ceiling (and the combined-nudge cap) must stay below the
    // rating boost, so personalisation is a tiebreaker, never a filter that
    // hides recipes a user could grow into.
    group('Pantry ceiling stays below the rating ceiling', () {
      test('the pantry boost ceiling is <= the rating ceiling', () {
        expect(
          MenuScoringContext.pantryMaxBoost,
          lessThanOrEqualTo(MenuService.debugMaxRatingBoost),
        );
      });

      test(
        'the combined-nudge cap is strictly below the rating ceiling, so a 5★ '
        'favourite still out-weights a max-personalised unrated recipe',
        () {
          // Max the pantry signal: full overlap.
          final maxed = _dinner('maxed', timeMinutes: 15);
          final context = const MenuScoringContext(
            pantryMatchByRecipeId: {'maxed': 1.0},
          );

          // The applied multiplier is capped at maxCombinedBoost...
          expect(
            context.multiplierFor(maxed),
            lessThanOrEqualTo(MenuScoringContext.maxCombinedBoost),
          );
          // ...which is strictly below the rating ceiling, so an unrated but
          // perfectly-personalised recipe can never beat a 5★ favourite whose
          // rating alone lifts it by up to debugMaxRatingBoost.
          expect(
            MenuScoringContext.maxCombinedBoost,
            lessThan(MenuService.debugMaxRatingBoost),
          );
        },
      );
    });
  });

  // Product-Manager condition: the gentle pantry boost must not collapse the
  // weekly menu to the same few recipes. Runs the REAL generation entry (seeded
  // RNG) with the pantry boost stacked on two recipes, and asserts no recipe
  // dominates the 20 generated weeks.
  group('Diversity floor with pantry boost', () {
    late List<Recipe> pool;
    late MenuScoringContext stacked;
    late ParsedMenuRequest parsed;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    setUp(() {
      // Two pantry-stocked recipes get the full boost; ten plain ones get
      // nothing.
      pool = [
        _dinner('stocked_0', timeMinutes: 15),
        _dinner('stocked_1', timeMinutes: 15),
        for (var i = 0; i < 10; i++) _dinner('plain_$i', timeMinutes: 45),
      ];
      stacked = const MenuScoringContext(
        pantryMatchByRecipeId: {'stocked_0': 1.0, 'stocked_1': 1.0},
      );
      parsed = ParsedMenuRequest(
        slotRequests: [
          SlotRequest(
            mealType: 'middag',
            subRequests: [RecipeConstraint(count: 4)],
          ),
        ],
        globalAllergenAvoid: const {},
        globalDietaryRequire: const {},
        dayPins: const [],
        trace: const ExtractionTrace(),
        rawPrompt: 'fyra middagar',
      );
    });

    // Three fixed seeds (not one) guard against a single lucky RNG draw hiding
    // a real collapse. If a boost change pushes any seed's maxShare over 0.60
    // this fails — that's the signal to re-check the ceiling, not to relax the
    // threshold.
    test('no recipe exceeds 60% of 20 weeks across several seeds', () async {
      const weeks = 20;
      for (final seed in [20260701, 42, 1337]) {
        // Seeded so the probabilistic selection is deterministic and non-flaky.
        final service = MenuService(
          lexiconProvider: const CodeLexiconProvider(),
          random: Random(seed),
        );

        final appearances = <String, int>{};
        for (var w = 0; w < weeks; w++) {
          final menu = await service.generateMenuFromParsedRequest(
            parsed,
            pool,
            scoringContext: stacked,
          );
          for (final r in menu['middag'] ?? const <Recipe>[]) {
            appearances[r.id] = (appearances[r.id] ?? 0) + 1;
          }
        }

        final maxShare = appearances.values.fold<int>(0, max) / weeks;
        expect(
          maxShare,
          lessThanOrEqualTo(0.6),
          reason:
              'the gentle pantry boost must not collapse the menu to a few '
              'recipes (seed $seed, distribution: $appearances)',
        );
        // Sanity: the menu still fills and draws on a healthy spread of recipes.
        expect(
          appearances.keys.length,
          greaterThanOrEqualTo(6),
          reason:
              'a healthy variety of recipes should appear across the weeks '
              '(seed $seed)',
        );
      }
    });
  });
}
