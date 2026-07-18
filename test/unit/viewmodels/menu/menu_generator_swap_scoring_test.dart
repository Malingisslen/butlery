/// Unit tests for the smart-swap scoring path in [MenuGenerator.swapSingleRecipe].
///
/// This test proves that the three scoring tiers produce the right ordering:
///   +3 cuisine match  >  +2 category match  >  +1 seasonal match
/// and that a candidate with the highest score is always preferred over lower
/// scorers — the random tie-break only applies within a single score bucket.
///
/// The existing menu_generator_test.dart covers: cuisine-match preferred over
/// non-match (probabilistic, 20 runs), random path when useSmartSwap=false,
/// no-candidates exhausted case. This file pins the HIERARCHY explicitly:
///   - cuisine beats category-only (3 > 2)
///   - category beats seasonal-only (2 > 1)
///   - all three together: cuisine+category+seasonal beats each lesser combination
///   - deterministic when exactly one candidate holds the top score
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

TagResult _tagResult({Set<String> tags = const {}}) => TagResult(
  tags: tags,
  allergenStatus: const {},
  dietaryStatus: const {},
  coverage: 1.0,
  generatedAt: DateTime(2026),
);

/// Build a Recipe with a specific id, mealType and tag set.
/// Uses [RecipeFactory.build] so that required core fields are populated.
Recipe _recipe(
  String id, {
  String mealType = 'Middag',
  Set<String> tags = const {},
}) {
  final base = RecipeFactory.build(id: id, title: id, mealType: mealType);
  return Recipe(
    core: base.core.copyWith(tagResult: _tagResult(tags: tags)),
    type: base.type,
  );
}

// The current Swedish season tag for a winter date (January).
// withClock pins this in every test so results are deterministic.
const _kWinterDate = 2026; // January 2026 → SeasonUtils returns 'vinter'

// Season tag that SeasonUtils.currentSeasonTag() returns for January.
const _kWinterTag = 'vinter';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MenuGenerator generator;
  late MockUnifiedRecipeService mockRecipeService;
  late MockMenuService mockMenuService;
  late MockUserService mockUserService;

  setUpAll(() async {
    registerFallbackValue(DateTime(2026));
    await TestServiceLocator.initialize();
    // The production DIContainer reads off the same GetIt that
    // TestServiceLocator populates. Bridging it lets production code's
    // `AnalyticsService.tryLog` (which resolves via the production
    // ServiceLocator) see mocks we register — needed to observe the
    // BUT-1474 swap event. Safe here: every test only exercises the swap
    // path, which never touches the scoring context / feature flags.
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() {
    mockMenuService = MockMenuService();
    mockRecipeService = MockUnifiedRecipeService();
    mockUserService = MockUserService();

    when(() => mockUserService.allergenPreferences).thenReturn(
      const UserAllergenPreferences(
        trackedAllergens: {},
        trackedDietary: {},
      ),
    );

    generator = MenuGenerator(
      menuService: mockMenuService,
      recipeService: mockRecipeService,
      userService: mockUserService,
    );
    generator.useSmartSwap = true;
  });

  tearDownAll(() async {
    production.ServiceLocator.reset();
    await TestServiceLocator.reset();
  });

  // Convenience: load [pool] into the mock and call swapSingleRecipe with
  // [current] already in the menu so it is excluded. Async since BUT-1464
  // (swap draws from the allergen-safe async pool).
  Future<SwapResult> doSwap(Recipe current, List<Recipe> pool) {
    mockRecipeService.setRecipeState(
      recipes: [current, ...pool],
      isInitialized: true,
    );
    return generator.swapSingleRecipe(
      current,
      current.mealType,
      {
        current.mealType: [current],
      },
    );
  }

  // -------------------------------------------------------------------------
  // Tier 1: cuisine beats category
  // -------------------------------------------------------------------------

  group('scoring — cuisine (+3) beats category-only (+2)', () {
    test(
      'always picks the cuisine-matching candidate over the category-only one',
      () async {
        await withClock(Clock.fixed(DateTime(_kWinterDate, 1)), () async {
          // current: italiensk middag
          final current = _recipe(
            'current',
            mealType: 'Middag',
            tags: {'italiensk'},
          );
          // best: same cuisine + same category = 3+2 = 5
          final cuisineAndCategory = _recipe(
            'cuisine_and_category',
            mealType: 'Middag',
            tags: {'italiensk'},
          );
          // lesser: same category only = 2
          final categoryOnly = _recipe('category_only', mealType: 'Middag');

          // Run 15 times — if scoring is wrong and both go in the same bucket
          // the probabilistic test would still pass occasionally; but with a
          // clear 5 vs 2 gap the winner must be deterministic.
          final picks = <String>{};
          for (var i = 0; i < 15; i++) {
            picks.add(
              (await doSwap(current, [
                cuisineAndCategory,
                categoryOnly,
              ])).recipe!.id,
            );
          }

          // Only the cuisine+category candidate should ever win.
          expect(
            picks,
            equals({'cuisine_and_category'}),
            reason:
                'A recipe scoring 5 (cuisine+category) must always beat a recipe '
                'scoring 2 (category only); score gap is 3 points.',
          );
        });
      },
    );
  });

  // -------------------------------------------------------------------------
  // Tier 2: category beats seasonal
  // -------------------------------------------------------------------------

  group('scoring — category (+2) beats seasonal-only (+1)', () {
    test(
      'always picks the category-matching candidate over the seasonal-only one',
      () async {
        await withClock(Clock.fixed(DateTime(_kWinterDate, 1)), () async {
          // current: no cuisine tag, Middag → so +3 path is inactive for all candidates
          final current = _recipe('current', mealType: 'Middag');
          // best: same category = 2
          final categoryMatch = _recipe('category_match', mealType: 'Middag');
          // lesser: empty mealType keeps it eligible (isEmpty branch) but earns
          // no category point; only the seasonal tag scores = 1.
          final seasonalOnly = _recipe(
            'seasonal_only',
            mealType: '',
            tags: {_kWinterTag},
          );

          final picks = <String>{};
          for (var i = 0; i < 15; i++) {
            picks.add(
              (await doSwap(current, [categoryMatch, seasonalOnly])).recipe!.id,
            );
          }

          expect(
            picks,
            equals({'category_match'}),
            reason:
                'A recipe scoring 2 (same mealType/category) must always beat a '
                'recipe scoring 1 (seasonal tag only).',
          );
        });
      },
    );
  });

  // -------------------------------------------------------------------------
  // Tier 3: seasonal is the weakest tiebreaker but still ranks above zero
  // -------------------------------------------------------------------------

  group('scoring — seasonal (+1) beats zero-score candidate', () {
    test(
      'prefers the seasonal candidate when no cuisine or category matches',
      () async {
        await withClock(Clock.fixed(DateTime(_kWinterDate, 1)), () async {
          // current: no cuisine tag, Middag. Both candidates use an empty mealType
          // so they stay eligible (isEmpty branch of the swap filter) but earn no
          // category point — isolating the seasonal tier (1) vs zero.
          final current = _recipe('current', mealType: 'Middag');
          // one candidate has seasonal tag = 1
          final seasonal = _recipe(
            'seasonal',
            mealType: '',
            tags: {_kWinterTag},
          );
          // other has no advantage = 0
          final noMatch = _recipe('no_match', mealType: '');

          final picks = <String>{};
          for (var i = 0; i < 15; i++) {
            picks.add((await doSwap(current, [seasonal, noMatch])).recipe!.id);
          }

          expect(
            picks,
            equals({'seasonal'}),
            reason:
                'A seasonal-tagged recipe (score 1) must always beat a zero-score '
                'recipe when no cuisine or category match exists.',
          );
        });
      },
    );
  });

  // -------------------------------------------------------------------------
  // Full hierarchy: cuisine+category+seasonal beats every lesser combination
  // -------------------------------------------------------------------------

  group('scoring — full-score winner (cuisine+category+seasonal = 6)', () {
    test('is always chosen when all three criteria are met', () async {
      await withClock(Clock.fixed(DateTime(_kWinterDate, 1)), () async {
        final current = _recipe(
          'current',
          mealType: 'Middag',
          tags: {'italiensk'},
        );

        // Perfect: all three = 3+2+1 = 6
        final perfect = _recipe(
          'perfect',
          mealType: 'Middag',
          tags: {'italiensk', _kWinterTag},
        );
        // Partial: cuisine+category = 5
        final cuisineCategory = _recipe(
          'cuisine_cat',
          mealType: 'Middag',
          tags: {'italiensk'},
        );
        // Partial: category+seasonal = 3
        final categorySeasonal = _recipe(
          'cat_seasonal',
          mealType: 'Middag',
          tags: {_kWinterTag},
        );
        // Partial: cuisine only = 3
        final cuisineOnly = _recipe(
          'cuisine_only',
          mealType: 'Lunch',
          tags: {'italiensk'},
        );

        final picks = <String>{};
        for (var i = 0; i < 15; i++) {
          picks.add(
            (await doSwap(current, [
              perfect,
              cuisineCategory,
              categorySeasonal,
              cuisineOnly,
            ])).recipe!.id,
          );
        }

        expect(
          picks,
          equals({'perfect'}),
          reason:
              'The candidate scoring 6 (cuisine+category+seasonal) must always '
              'beat all partial scorers.',
        );
      });
    });
  });

  // -------------------------------------------------------------------------
  // Tie-break: two equal-score candidates share the tie bucket
  // -------------------------------------------------------------------------

  group('scoring — tie-break uses random shuffle within the tied bucket', () {
    test('two equal-score candidates are both reachable', () async {
      await withClock(Clock.fixed(DateTime(_kWinterDate, 1)), () async {
        // current: no cuisine, Middag
        final current = _recipe('current', mealType: 'Middag');
        // Two candidates with identical scores (same category, no seasonal) = 2 each
        final tieA = _recipe('tie_a', mealType: 'Middag');
        final tieB = _recipe('tie_b', mealType: 'Middag');

        final picked = <String>{};
        for (var i = 0; i < 50; i++) {
          picked.add((await doSwap(current, [tieA, tieB])).recipe!.id);
        }

        // Both must appear — the tie is resolved by shuffle, not insertion order.
        expect(
          picked,
          containsAll(['tie_a', 'tie_b']),
          reason:
              'Tied-score candidates must all be reachable via random shuffle; '
              'insertion-order bias would make one unreachable.',
        );
      });
    });
  });

  // -------------------------------------------------------------------------
  // BUT-1474: swap-rate analytics chokepoint
  // -------------------------------------------------------------------------
  //
  // These tests prove that a completed single-recipe swap emits exactly one
  // `menu_recipe_swapped` event carrying the swapped category, and that an
  // exhausted swap (no eligible replacement) emits nothing — so the swap-rate
  // metric counts real swaps only. They fail if the tryLog call is dropped,
  // the `category` param is renamed, or the event leaks onto the exhausted
  // path. (registerSingleton unregisters-first, so each test gets a fresh
  // capture with no cross-test bleed.)
  group('BUT-1474 — menu_recipe_swapped analytics', () {
    test(
      'a completed swap fires menu_recipe_swapped once with the category',
      () async {
        final analytics = MockAnalyticsService();
        TestServiceLocator.registerSingleton<AnalyticsService>(analytics);

        final current = _recipe('current', mealType: 'Middag');
        final replacement = _recipe('replacement', mealType: 'Middag');

        final result = await doSwap(current, [replacement]);

        expect(result.recipe, isNotNull);
        final events = analytics.capturedEvents
            .where((e) => e.name == 'menu_recipe_swapped')
            .toList();
        expect(events, hasLength(1));
        expect(events.single.parameters, {'category': 'Middag'});
      },
    );

    test(
      'an exhausted swap (no eligible replacement) fires no event',
      () async {
        final analytics = MockAnalyticsService();
        TestServiceLocator.registerSingleton<AnalyticsService>(analytics);

        // The only candidate is a breakfast recipe — ineligible for a Middag
        // swap — so the pool is exhausted and no replacement is produced.
        final current = _recipe('current', mealType: 'Middag');
        final wrongCategory = _recipe('breakfast', mealType: 'Frukost');

        final result = await doSwap(current, [wrongCategory]);

        expect(result.recipe, isNull);
        expect(
          analytics.capturedEvents.where(
            (e) => e.name == 'menu_recipe_swapped',
          ),
          isEmpty,
          reason: 'no swap happened, so the swap-rate metric must not count it',
        );
      },
    );
  });
}
