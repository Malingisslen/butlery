import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/menu/menu_scoring.dart';
import 'package:butlery/services/menu/parser/code_lexicon_provider.dart';
import 'package:butlery/services/tagging/config/cuisine_config.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';

/// Builds a never-cooked dinner (recency weight 90) with the given cook time
/// and optional single cuisine tag, so the personalisation nudges can be tested
/// against a clean baseline (no season boost, no recency variation).
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
  group('Menu personalisation (BUT-1320 + BUT-1321)', () {
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

    group('Cuisine affinity boost', () {
      test('an affinity-cuisine recipe outweighs a non-affinity sibling', () {
        final favourite = _dinner('fav', cuisineTag: 'italiensk');
        final other = _dinner('other', cuisineTag: 'thailändsk');

        // Guard against a coincidental pass: the "no boost" outcome for `other`
        // must be because its cuisine is a REAL, recognised cuisine that simply
        // isn't a favourite — NOT because `extractCuisineTag` returned null for
        // an unknown tag. The enum member is spelled `thailandsk`, but the
        // actual config tag string is `thailändsk` (with ä); pin the real one.
        expect(
          CuisineConfig.extractCuisineTag(favourite),
          equals('italiensk'),
        );
        expect(
          CuisineConfig.extractCuisineTag(other),
          equals('thailändsk'),
          reason:
              'the non-affinity recipe must carry a genuine (recognised) '
              'cuisine, so "not boosted" proves non-favourite, not unknown',
        );

        final context = const MenuScoringContext(
          cuisineAffinities: {'italiensk'},
        );

        expect(
          _weight(favourite, context: context),
          greaterThan(_weight(other, context: context)),
          reason: 'a favourite cuisine should nudge the recipe up',
        );
        // The non-affinity recipe is not penalised — same as no context.
        expect(_weight(other, context: context), equals(_weight(other)));
      });
    });

    group('Cooking-skill bias', () {
      test('for a beginner, a simpler recipe outweighs a complex one', () {
        final simple = _dinner('simple', timeMinutes: 15);
        final complex = _dinner('complex', timeMinutes: 90);

        final context = const MenuScoringContext(
          skill: CookingSkillLevel.beginner,
        );

        expect(
          _weight(simple, context: context),
          greaterThan(_weight(complex, context: context)),
          reason: 'beginners are nudged toward simpler/faster recipes',
        );
        // Direction check: `simple > complex` alone is satisfiable by the
        // complex *down-weight* even if the simple boost were silently 1.0.
        // Pin the actual up-weight so a dropped beginnerSimpleBoost fails here.
        expect(
          _weight(simple, context: context),
          greaterThan(_weight(simple)),
          reason:
              'a beginner sees a genuine lift on a simple recipe, '
              'not merely a penalty on the complex one',
        );
      });

      test('a complex recipe is down-weighted but never excluded', () {
        final complex = _dinner('complex', timeMinutes: 120);
        final context = const MenuScoringContext(
          skill: CookingSkillLevel.beginner,
        );
        final w = _weight(complex, context: context);
        expect(w, greaterThan(0), reason: 'still selectable, just less likely');
        expect(
          w,
          lessThan(_weight(complex)),
          reason:
              'a beginner sees a gentle down-weight on very complex recipes',
        );
        // The combined-boost cap only clamps the UPPER end — the beginner
        // down-weight (0.85×) must survive it intact.
        expect(
          context.multiplierFor(complex),
          MenuScoringContext.beginnerComplexPenalty,
          reason: 'the cap must not clamp away the complex down-weight',
        );
      });

      test('for an advanced cook, a complex recipe gets a slight lift', () {
        final complex = _dinner('complex', timeMinutes: 90);
        final context = const MenuScoringContext(
          skill: CookingSkillLevel.advanced,
        );
        expect(
          _weight(complex, context: context),
          greaterThan(_weight(complex)),
        );
      });

      test('intermediate skill is neutral across complexity', () {
        final simple = _dinner('simple', timeMinutes: 15);
        final complex = _dinner('complex', timeMinutes: 90);
        final context = const MenuScoringContext(
          skill: CookingSkillLevel.intermediate,
        );
        expect(_weight(simple, context: context), equals(_weight(simple)));
        expect(_weight(complex, context: context), equals(_weight(complex)));
      });

      test('falls back to step count when a recipe has no cook time', () {
        final base = RecipeFactory.build(
          id: 'nostep',
          title: 'nostep',
          mealType: 'middag',
          timeMinutes: null,
          instructions: List.generate(12, (i) => 'Step $i'),
          lastCookedAt: null,
        );
        final manySteps = Recipe(core: base.core, type: base.type);
        final context = const MenuScoringContext(
          skill: CookingSkillLevel.beginner,
        );
        expect(
          _weight(manySteps, context: context),
          lessThan(_weight(manySteps)),
          reason: '12 steps reads as complex for a beginner',
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
        'a populated context that matches no field still yields 1.0',
        () {
          final r = _dinner('r', timeMinutes: 45); // moderate → skill-neutral
          final context = const MenuScoringContext(
            pantryMatchByRecipeId: {'other': 1.0},
            cuisineAffinities: {'italiensk'}, // recipe has no cuisine tag
            skill: CookingSkillLevel.beginner,
          );
          expect(_weight(r, context: context), equals(_weight(r)));
        },
      );
    });

    // Product-Manager condition (A): no single personalisation signal may
    // dominate the rating signal — each ceiling must stay below the rating
    // boost, so personalisation is a tiebreaker, never a filter that hides
    // recipes a user could grow into.
    group('Signal ceilings stay below the rating ceiling', () {
      test('the max skill boost is strictly below the rating ceiling', () {
        expect(
          MenuScoringContext.maxSkillBoost,
          lessThan(MenuService.debugMaxRatingBoost),
        );
      });

      test('every personalisation ceiling is <= the rating ceiling', () {
        final ratingCeiling = MenuService.debugMaxRatingBoost;
        expect(
          MenuScoringContext.pantryMaxBoost,
          lessThanOrEqualTo(ratingCeiling),
        );
        expect(
          MenuScoringContext.cuisineAffinityBoost,
          lessThanOrEqualTo(ratingCeiling),
        );
        expect(
          MenuScoringContext.maxSkillBoost,
          lessThanOrEqualTo(ratingCeiling),
        );
      });

      test(
        'the COMBINED nudge is capped below the rating ceiling, so a 5★ '
        'favourite still out-weights a max-personalised unrated recipe',
        () {
          // Max every signal at once: full pantry overlap + favourite cuisine +
          // a beginner cooking a simple/fast recipe.
          final maxed = _dinner(
            'maxed',
            timeMinutes: 15,
            cuisineTag: 'italiensk',
          );
          final context = const MenuScoringContext(
            pantryMatchByRecipeId: {'maxed': 1.0},
            cuisineAffinities: {'italiensk'},
            skill: CookingSkillLevel.beginner,
          );

          // The uncapped product would exceed the rating ceiling — proving the
          // cap actually bites (this is the whole reason the cap exists).
          final uncapped =
              MenuScoringContext.pantryMaxBoost *
              MenuScoringContext.cuisineAffinityBoost *
              MenuScoringContext.beginnerSimpleBoost;
          expect(
            uncapped,
            greaterThan(MenuService.debugMaxRatingBoost),
            reason:
                'without the cap, stacked personalisation would overtake rating',
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

  // Product-Manager condition (B): the compounding gentle boosts must not
  // collapse the weekly menu to the same few recipes. Runs the REAL generation
  // entry (seeded RNG) with pantry + cuisine + skill boosts all stacked on a
  // narrow-taste user, and asserts no recipe dominates the 20 generated weeks.
  group('Diversity floor with stacked boosts', () {
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
      // Two Italian, fast, pantry-stocked recipes get the full stacked boost;
      // ten plain moderate recipes get nothing. A narrow-taste beginner.
      pool = [
        _dinner('ita_0', timeMinutes: 15, cuisineTag: 'italiensk'),
        _dinner('ita_1', timeMinutes: 15, cuisineTag: 'italiensk'),
        for (var i = 0; i < 10; i++) _dinner('plain_$i', timeMinutes: 45),
      ];
      stacked = const MenuScoringContext(
        pantryMatchByRecipeId: {'ita_0': 1.0, 'ita_1': 1.0},
        cuisineAffinities: {'italiensk'},
        skill: CookingSkillLevel.beginner,
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

    // Observed margin (recorded so a later gentle-boost tweak can't quietly
    // erode variety without failing): across the three seeds below the worst
    // single-recipe share is ~0.40 (8 of 20 weeks), comfortably under the 0.60
    // bar. If a boost change pushes any seed's maxShare over 0.60 this fails —
    // that's the signal to re-check the ceilings, not to relax the threshold.
    // Three fixed seeds (not one) guard against a single lucky RNG draw hiding
    // a real collapse.
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
              'stacked gentle boosts must not collapse the menu to a few '
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
