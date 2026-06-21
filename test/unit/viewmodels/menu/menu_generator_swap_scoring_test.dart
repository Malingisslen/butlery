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
import 'package:butlery/models/user_allergen_preferences.dart';
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
    await TestServiceLocator.reset();
  });

  // Convenience: load [pool] into the mock and call swapSingleRecipe with
  // [current] already in the menu so it is excluded.
  SwapResult doSwap(Recipe current, List<Recipe> pool) {
    mockRecipeService.setRecipeState(
      recipes: [current, ...pool],
      isInitialized: true,
    );
    return generator.swapSingleRecipe(
      current,
      current.mealType,
      {
        current.mealType: [current]
      },
    );
  }

  // -------------------------------------------------------------------------
  // Tier 1: cuisine beats category
  // -------------------------------------------------------------------------

  group('scoring — cuisine (+3) beats category-only (+2)', () {
    test(
        'always picks the cuisine-matching candidate over the category-only one',
        () {
      withClock(Clock.fixed(DateTime(_kWinterDate, 1)), () {
        // current: italiensk middag
        final current =
            _recipe('current', mealType: 'Middag', tags: {'italiensk'});
        // best: same cuisine + same category = 3+2 = 5
        final cuisineAndCategory = _recipe('cuisine_and_category',
            mealType: 'Middag', tags: {'italiensk'});
        // lesser: same category only = 2
        final categoryOnly = _recipe('category_only', mealType: 'Middag');

        // Run 15 times — if scoring is wrong and both go in the same bucket
        // the probabilistic test would still pass occasionally; but with a
        // clear 5 vs 2 gap the winner must be deterministic.
        final picks = <String>{};
        for (var i = 0; i < 15; i++) {
          picks.add(
              doSwap(current, [cuisineAndCategory, categoryOnly]).recipe!.id);
        }

        // Only the cuisine+category candidate should ever win.
        expect(picks, equals({'cuisine_and_category'}),
            reason:
                'A recipe scoring 5 (cuisine+category) must always beat a recipe '
                'scoring 2 (category only); score gap is 3 points.');
      });
    });
  });

  // -------------------------------------------------------------------------
  // Tier 2: category beats seasonal
  // -------------------------------------------------------------------------

  group('scoring — category (+2) beats seasonal-only (+1)', () {
    test(
        'always picks the category-matching candidate over the seasonal-only one',
        () {
      withClock(Clock.fixed(DateTime(_kWinterDate, 1)), () {
        // current: no cuisine tag, Middag → so +3 path is inactive for all candidates
        final current = _recipe('current', mealType: 'Middag');
        // best: same category = 2
        final categoryMatch = _recipe('category_match', mealType: 'Middag');
        // lesser: empty mealType keeps it eligible (isEmpty branch) but earns
        // no category point; only the seasonal tag scores = 1.
        final seasonalOnly =
            _recipe('seasonal_only', mealType: '', tags: {_kWinterTag});

        final picks = <String>{};
        for (var i = 0; i < 15; i++) {
          picks.add(doSwap(current, [categoryMatch, seasonalOnly]).recipe!.id);
        }

        expect(picks, equals({'category_match'}),
            reason:
                'A recipe scoring 2 (same mealType/category) must always beat a '
                'recipe scoring 1 (seasonal tag only).');
      });
    });
  });

  // -------------------------------------------------------------------------
  // Tier 3: seasonal is the weakest tiebreaker but still ranks above zero
  // -------------------------------------------------------------------------

  group('scoring — seasonal (+1) beats zero-score candidate', () {
    test('prefers the seasonal candidate when no cuisine or category matches',
        () {
      withClock(Clock.fixed(DateTime(_kWinterDate, 1)), () {
        // current: no cuisine tag, Middag. Both candidates use an empty mealType
        // so they stay eligible (isEmpty branch of the swap filter) but earn no
        // category point — isolating the seasonal tier (1) vs zero.
        final current = _recipe('current', mealType: 'Middag');
        // one candidate has seasonal tag = 1
        final seasonal = _recipe('seasonal', mealType: '', tags: {_kWinterTag});
        // other has no advantage = 0
        final noMatch = _recipe('no_match', mealType: '');

        final picks = <String>{};
        for (var i = 0; i < 15; i++) {
          picks.add(doSwap(current, [seasonal, noMatch]).recipe!.id);
        }

        expect(picks, equals({'seasonal'}),
            reason:
                'A seasonal-tagged recipe (score 1) must always beat a zero-score '
                'recipe when no cuisine or category match exists.');
      });
    });
  });

  // -------------------------------------------------------------------------
  // Full hierarchy: cuisine+category+seasonal beats every lesser combination
  // -------------------------------------------------------------------------

  group('scoring — full-score winner (cuisine+category+seasonal = 6)', () {
    test('is always chosen when all three criteria are met', () {
      withClock(Clock.fixed(DateTime(_kWinterDate, 1)), () {
        final current =
            _recipe('current', mealType: 'Middag', tags: {'italiensk'});

        // Perfect: all three = 3+2+1 = 6
        final perfect = _recipe('perfect',
            mealType: 'Middag', tags: {'italiensk', _kWinterTag});
        // Partial: cuisine+category = 5
        final cuisineCategory =
            _recipe('cuisine_cat', mealType: 'Middag', tags: {'italiensk'});
        // Partial: category+seasonal = 3
        final categorySeasonal =
            _recipe('cat_seasonal', mealType: 'Middag', tags: {_kWinterTag});
        // Partial: cuisine only = 3
        final cuisineOnly =
            _recipe('cuisine_only', mealType: 'Lunch', tags: {'italiensk'});

        final picks = <String>{};
        for (var i = 0; i < 15; i++) {
          picks.add(doSwap(current, [
            perfect,
            cuisineCategory,
            categorySeasonal,
            cuisineOnly,
          ]).recipe!.id);
        }

        expect(picks, equals({'perfect'}),
            reason:
                'The candidate scoring 6 (cuisine+category+seasonal) must always '
                'beat all partial scorers.');
      });
    });
  });

  // -------------------------------------------------------------------------
  // Tie-break: two equal-score candidates share the tie bucket
  // -------------------------------------------------------------------------

  group('scoring — tie-break uses random shuffle within the tied bucket', () {
    test('two equal-score candidates are both reachable', () {
      withClock(Clock.fixed(DateTime(_kWinterDate, 1)), () {
        // current: no cuisine, Middag
        final current = _recipe('current', mealType: 'Middag');
        // Two candidates with identical scores (same category, no seasonal) = 2 each
        final tieA = _recipe('tie_a', mealType: 'Middag');
        final tieB = _recipe('tie_b', mealType: 'Middag');

        final picked = <String>{};
        for (var i = 0; i < 50; i++) {
          picked.add(doSwap(current, [tieA, tieB]).recipe!.id);
        }

        // Both must appear — the tie is resolved by shuffle, not insertion order.
        expect(picked, containsAll(['tie_a', 'tie_b']),
            reason:
                'Tied-score candidates must all be reachable via random shuffle; '
                'insertion-order bias would make one unreachable.');
      });
    });
  });
}
