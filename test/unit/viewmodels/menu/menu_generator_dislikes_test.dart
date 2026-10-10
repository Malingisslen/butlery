// BUT-1625: dislikes steer generation and swaps but never the allergen-safe
// pool. The generator asks its `unplaceableIds` provider on EVERY generate,
// re-roll and swap (so a presence change is seen), after the pool exists, and
// treats a throwing provider as "no dislikes".
//
// Own file for the same reason as the present-aware suite: the generator
// resolves collaborators through the production ServiceLocator.

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/viewmodels/menu/menu_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/helpers/own_preferences_stub.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../test_support/base_unit_test.dart';

Recipe _dish(String id, {required TriState nuts}) {
  final base = RecipeFactory.build(id: id, title: id, mealType: 'Middag');
  return Recipe(
    core: base.core.copyWith(
      tagResult: TagResult(
        tags: const {},
        allergenStatus: {'nötter': nuts},
        dietaryStatus: const {},
        coverage: 1.0,
        generatedAt: DateTime(2026),
        generatorVersion: kTagGeneratorVersion,
      ),
    ),
    type: base.type,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MenuGenerator generator;
  late MockMenuService menuService;
  late MockUnifiedRecipeService recipeService;
  late MockUserService userService;

  late Recipe current;
  late Recipe a;
  late Recipe b;
  late Recipe c;
  late Recipe nutty;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
    menuService = MockMenuService();
    recipeService = MockUnifiedRecipeService();
    userService = MockUserService();
    stubOwnPreferences(
      userService,
      const UserAllergenPreferences(
        trackedAllergens: {'nötter'},
        trackedDietary: {},
      ),
      useHouseholdAllergens: false,
    );

    current = _dish('current', nuts: TriState.free);
    a = _dish('a', nuts: TriState.free);
    b = _dish('b', nuts: TriState.free);
    c = _dish('c', nuts: TriState.free);
    // Hidden by the allergen filter: no dislike answer may bring it back.
    nutty = _dish('nutty', nuts: TriState.contains);

    recipeService.setRecipeState(
      isInitialized: true,
      recipes: [current, a, b, c, nutty],
    );
    menuService.setGenerateMenuResult({
      'middag': [a],
    });

    generator = MenuGenerator(
      menuService: menuService,
      recipeService: recipeService,
      userService: userService,
      filterByAllergens: true,
    )..useSmartSwap = true;
  });

  Future<List<String>> poolIds() async =>
      (await generator.getAvailableRecipesAsync()).map((r) => r.id).toList();

  Map<String, List<Recipe>> menuWithCurrent() => {
    'middag': [current],
  };

  group('the allergen-safe pool is never touched by dislikes (req 2/6)', () {
    test('getAvailableRecipesAsync and lastPoolStats are identical with a '
        'provider that dislikes everything', () async {
      final baseline = await poolIds();
      final baseStats = generator.lastPoolStats!;
      expect(baseline, isNot(contains('nutty')), reason: 'premise: filtered');
      expect(baseStats.hiddenByAllergenFilter, 1, reason: 'premise');

      generator.unplaceableIds = (pool) async => {
        for (final r in pool) r.id,
        'nutty',
      };
      final withProvider = await poolIds();
      final stats = generator.lastPoolStats!;

      expect(withProvider, baseline);
      expect(stats.hiddenByAllergenFilter, baseStats.hiddenByAllergenFilter);
      expect(stats.unknownSoftRecipeIds, baseStats.unknownSoftRecipeIds);
      expect(stats.trackedAllergenCount, baseStats.trackedAllergenCount);
      expect(stats.prefSource, baseStats.prefSource);
    });

    test('generation hands the menu service the same pool, and the provider '
        'sees only that allergen-safe pool', () async {
      final baseline = await poolIds();
      List<String>? seen;
      generator.unplaceableIds = (pool) async {
        seen = pool.map((r) => r.id).toList();
        return {for (final r in pool) r.id};
      };

      await generator.generateMenuFromPrompt('veckomeny');

      expect(menuService.lastGenerateRecipes!.map((r) => r.id), baseline);
      expect(seen, baseline);
      expect(seen, isNot(contains('nutty')));
    });

    test('a throwing provider still generates, on an identical pool with '
        'no dislikes', () async {
      final baseline = await poolIds();
      generator.unplaceableIds = (pool) async => throw StateError('no roster');

      final menu = await generator.generateMenuFromPrompt('veckomeny');

      expect(menu['middag'], isNotEmpty);
      expect(menuService.lastGenerateRecipes!.map((r) => r.id), baseline);
      expect(menuService.lastScoringContext!.dislikedRecipeIds, isEmpty);
      expect(await poolIds(), baseline);
    });

    test('the provider answer reaches the scoring context as a 0.05x '
        'weight on those dishes only', () async {
      generator.unplaceableIds = (pool) async => {'a'};

      await generator.generateMenuFromPrompt('veckomeny');

      final context = menuService.lastScoringContext!;
      expect(context.dislikedRecipeIds, {'a'});
      expect(context.multiplierFor(a), closeTo(0.05, 1e-9));
      expect(context.multiplierFor(b), 1.0);
    });

    test('no provider: scoring context carries no dislikes', () async {
      await generator.generateMenuFromPrompt('veckomeny');
      expect(menuService.lastScoringContext!.dislikedRecipeIds, isEmpty);
    });
  });

  group('swapSingleRecipe with dislikes', () {
    test('prefers a replacement nobody at home dislikes', () async {
      generator.unplaceableIds = (pool) async => {'a', 'b'};

      // Run repeatedly: an ordering bug would show up as a random miss.
      for (var i = 0; i < 15; i++) {
        final result = await generator.swapSingleRecipe(
          current,
          'middag',
          menuWithCurrent(),
        );
        expect(result.recipe!.id, 'c');
      }
    });

    test('alternativesRemaining counts every eligible dish, disliked or '
        'not', () async {
      generator.unplaceableIds = (pool) async => {'a', 'b'};

      final result = await generator.swapSingleRecipe(
        current,
        'middag',
        menuWithCurrent(),
      );

      // a, b and c are eligible, so two remain after the one chosen.
      expect(result.alternativesRemaining, 2);
    });

    test(
      'falls back to a disliked dish when every candidate is disliked',
      () async {
        generator.unplaceableIds = (pool) async => {'a', 'b', 'c'};
        final chosen = <String>{};

        for (var i = 0; i < 25; i++) {
          final result = await generator.swapSingleRecipe(
            current,
            'middag',
            menuWithCurrent(),
          );
          expect(result.recipe, isNotNull);
          chosen.add(result.recipe!.id);
          expect(result.alternativesRemaining, 2);
        }
        expect(chosen, isNot(contains('current')));
        expect(chosen, isNot(contains('nutty')));
      },
    );

    test('a lone candidate that is disliked is still offered', () async {
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [current, a, nutty],
      );
      generator.unplaceableIds = (pool) async => {'a'};

      final result = await generator.swapSingleRecipe(
        current,
        'middag',
        menuWithCurrent(),
      );

      expect(result.recipe!.id, 'a');
      expect(result.alternativesRemaining, 0);
    });

    test('never returns a dish outside the allergen-safe pool, even if the '
        'provider names one', () async {
      final safePool = await poolIds();
      generator.unplaceableIds = (pool) async => {'a', 'b', 'c', 'nutty'};

      for (var i = 0; i < 25; i++) {
        final result = await generator.swapSingleRecipe(
          current,
          'middag',
          menuWithCurrent(),
        );
        expect(safePool, contains(result.recipe!.id));
      }
    });

    test('a throwing provider leaves the swap exactly as it was', () async {
      generator.unplaceableIds = (pool) async => throw StateError('no roster');
      final chosen = <String>{};

      for (var i = 0; i < 40; i++) {
        final result = await generator.swapSingleRecipe(
          current,
          'middag',
          menuWithCurrent(),
        );
        chosen.add(result.recipe!.id);
        expect(result.alternativesRemaining, 2);
      }
      // Nothing was filtered out by the failed provider.
      expect(chosen, {'a', 'b', 'c'});
    });

    test('the provider is asked about the allergen-safe candidates only, '
        'not the dish being replaced or a filtered one', () async {
      List<String>? seen;
      generator.unplaceableIds = (pool) async {
        seen = pool.map((r) => r.id).toList();
        return {};
      };

      await generator.swapSingleRecipe(current, 'middag', menuWithCurrent());

      expect(seen, unorderedEquals(['a', 'b', 'c']));
    });

    test('with no provider, alternativesRemaining is unchanged', () async {
      final result = await generator.swapSingleRecipe(
        current,
        'middag',
        menuWithCurrent(),
      );
      expect(result.alternativesRemaining, 2);
    });
  });

  group('the provider is asked afresh on every call (req 3)', () {
    test('generate, re-roll and swap each invoke it and use the new '
        'answer', () async {
      final answers = <Set<String>>[
        {'a'},
        {'b'},
        {'a', 'b'},
      ];
      var calls = 0;
      generator.unplaceableIds = (pool) async => answers[calls++];

      await generator.generateMenuFromPrompt('veckomeny');
      expect(calls, 1);
      expect(menuService.lastScoringContext!.dislikedRecipeIds, {'a'});

      await generator.regenerateMenuSection('middag', menuWithCurrent());
      expect(calls, 2);
      expect(menuService.lastScoringContext!.dislikedRecipeIds, {'b'});

      final swap = await generator.swapSingleRecipe(
        current,
        'middag',
        menuWithCurrent(),
      );
      expect(calls, 3);
      // The third answer dislikes a and b, so the swap must take c.
      expect(swap.recipe!.id, 'c');
    });

    test('two swaps in a row see two different answers', () async {
      var dislikeA = true;
      var calls = 0;
      generator.unplaceableIds = (pool) async {
        calls++;
        return dislikeA ? {'a', 'b'} : {'b', 'c'};
      };

      for (var i = 0; i < 10; i++) {
        dislikeA = true;
        final first = await generator.swapSingleRecipe(
          current,
          'middag',
          menuWithCurrent(),
        );
        dislikeA = false;
        final second = await generator.swapSingleRecipe(
          current,
          'middag',
          menuWithCurrent(),
        );
        expect(first.recipe!.id, 'c');
        expect(second.recipe!.id, 'a');
      }
      expect(calls, 20);
    });
  });
}
