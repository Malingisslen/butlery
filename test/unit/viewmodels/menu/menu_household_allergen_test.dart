// test/unit/viewmodels/menu/menu_household_allergen_test.dart
//
// BUT-1464: household allergen filtering wired into the PUBLIC generation
// entry points (generateMenuFromPrompt / swapSingleRecipe). The 2026-07-01
// audit found getAvailableRecipesAsync had zero production callers and tests
// exercised it directly — every test here goes through the public surface
// instead. Own file (fresh isolate) because the generator resolves
// HouseholdService via the global ServiceLocator (same isolation reasoning
// as menu_generator_present_aware_test.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/viewmodels/menu/menu_generator.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _MockHouseholdService extends Mock implements HouseholdService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MenuGenerator generator;
  late MockMenuService menuService;
  late MockUnifiedRecipeService recipeService;
  late MockUserService userService;
  late _MockHouseholdService household;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  /// [version] controls staleness: the current generator version is fresh
  /// (trusted), anything else makes needsRetagging true (stale).
  TagResult tag(
    Map<String, TriState> allergen, {
    String version = kTagGeneratorVersion,
  }) => TagResult(
    tags: const {},
    allergenStatus: allergen,
    dietaryStatus: const {},
    coverage: 1.0,
    generatedAt: DateTime(2026),
    generatorVersion: version,
  );

  Recipe recipeWith(String id, TagResult t, {TagOverrides? overrides}) {
    final base = RecipeFactory.build(id: id, title: id);
    return Recipe(
      core: base.core.copyWith(tagResult: t),
      type: base.type,
    ).copyWith(tagOverrides: overrides);
  }

  void stubHousehold({bool includeUnknownInMenu = true}) {
    when(() => household.hasHousehold).thenReturn(true);
    when(() => household.aggregateAllergenPreferences()).thenAnswer(
      (_) async => HouseholdAllergenAggregate.complete(
        UserAllergenPreferences(
          trackedAllergens: const {'gluten'},
          trackedDietary: const {},
          includeUnknownInMenu: includeUnknownInMenu,
        ),
      ),
    );
  }

  setUp(() {
    menuService = MockMenuService();
    recipeService = MockUnifiedRecipeService();
    userService = MockUserService();
    // Single-user prefs deliberately EMPTY — if any test passes with these,
    // filtering came from the household union, not the user's own prefs.
    when(() => userService.allergenPreferences).thenReturn(
      const UserAllergenPreferences(trackedAllergens: {}, trackedDietary: {}),
    );

    // Mirrors MenuViewModel's production wiring (filter flags on) and keeps
    // useHouseholdAllergens at its BUT-1464 default (true).
    generator = MenuGenerator(
      menuService: menuService,
      recipeService: recipeService,
      userService: userService,
      filterByAllergens: true,
      filterByDietary: true,
    );

    household = _MockHouseholdService();
    TestServiceLocator.registerSingleton<HouseholdService>(household);
  });

  test(
    'household member allergy excludes CONTAINS recipes from a generated '
    'menu by default (no flag setup)',
    () async {
      stubHousehold();
      final safe = recipeWith('safe', tag({'gluten': TriState.free}));
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [
          recipeWith('unsafe', tag({'gluten': TriState.contains})),
          safe,
        ],
      );
      menuService.setGenerateMenuResult({
        'middag': [safe],
      });

      await generator.generateMenuFromPrompt('veckomeny');

      // The selection service can only pick from what it is handed — the
      // unsafe recipe must never reach it.
      expect(menuService.lastGenerateRecipes!.map((r) => r.id), ['safe']);
      // PM condition 1: the hidden count feeding the UI hint is populated.
      expect(generator.lastPoolStats?.hiddenByAllergenFilter, 1);
      expect(generator.lastPoolStats?.trackedAllergenCount, 1);
    },
  );

  test(
    'BUT-1465: with useHouseholdAllergens OFF, a household user filters by the '
    'OWNER allergens only — the household union is never consulted',
    () async {
      // A household exists, but the user has opted out via the settings toggle
      // (profile.useHouseholdAllergens == false, which the generator reads live).
      when(() => household.hasHousehold).thenReturn(true);
      when(() => userService.currentUserProfile).thenReturn(
        UserProfile(
          uid: 'u1',
          displayName: 'Test',
          email: 't@example.com',
          joinedAt: DateTime(2026),
          lastActiveAt: DateTime(2026),
          useHouseholdAllergens: false,
        ),
      );
      // The OWNER tracks gluten. If the household union were (wrongly) consulted
      // it would also hide gluten — so the discriminators are prefSource AND
      // that aggregateAllergenPreferences is never called.
      when(() => userService.allergenPreferences).thenReturn(
        const UserAllergenPreferences(
          trackedAllergens: {'gluten'},
          trackedDietary: {},
        ),
      );

      final safe = recipeWith('safe', tag({'gluten': TriState.free}));
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [
          recipeWith('unsafe', tag({'gluten': TriState.contains})),
          safe,
        ],
      );
      menuService.setGenerateMenuResult({
        'middag': [safe],
      });

      await generator.generateMenuFromPrompt('veckomeny');

      // The owner's own gluten allergy still hides the CONTAINS recipe...
      expect(menuService.lastGenerateRecipes!.map((r) => r.id), ['safe']);
      // ...but the filtering source is single-user (owner), NOT the household.
      expect(generator.lastPoolStats?.prefSource, MenuPrefSource.singleUser);
      // The household union must never be consulted when the user opts out.
      verifyNever(() => household.aggregateAllergenPreferences());
    },
  );

  test(
    'manual override CONTAINS excludes a recipe even though the auto-tag '
    'said FREE (human wins)',
    () async {
      stubHousehold();
      final safe = recipeWith('safe', tag({'gluten': TriState.free}));
      final corrected = recipeWith(
        'corrected',
        tag({'gluten': TriState.free}),
        overrides: const TagOverrides(
          allergenOverrides: {'gluten': TriState.contains},
        ),
      );
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [corrected, safe],
      );
      menuService.setGenerateMenuResult({
        'middag': [safe],
      });

      await generator.generateMenuFromPrompt('veckomeny');

      expect(menuService.lastGenerateRecipes!.map((r) => r.id), ['safe']);
    },
  );

  test(
    'stale CONTAINS (needsRetagging) is never downgraded — recipe stays '
    'excluded (Data/ML condition 2)',
    () async {
      stubHousehold();
      final safe = recipeWith('safe', tag({'gluten': TriState.free}));
      final staleDanger = recipeWith(
        'stale-danger',
        tag({'gluten': TriState.contains}, version: '1.0.0'),
      );
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [staleDanger, safe],
      );
      menuService.setGenerateMenuResult({
        'middag': [safe],
      });

      await generator.generateMenuFromPrompt('veckomeny');

      expect(menuService.lastGenerateRecipes!.map((r) => r.id), ['safe']);
    },
  );

  test(
    'stale FREE is treated as UNKNOWN: included when includeUnknownInMenu is '
    'true and marked unknown-soft for the UI chip',
    () async {
      stubHousehold(includeUnknownInMenu: true);
      final staleFree = recipeWith(
        'stale-free',
        tag({'gluten': TriState.free}, version: '1.0.0'),
      );
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [staleFree],
      );
      menuService.setGenerateMenuResult({
        'middag': [staleFree],
      });

      await generator.generateMenuFromPrompt('veckomeny');

      expect(menuService.lastGenerateRecipes!.map((r) => r.id), [
        'stale-free',
      ]);
      // PM condition 2: the soft-include is surfaced, not silent.
      expect(
        generator.lastPoolStats?.unknownSoftRecipeIds,
        contains('stale-free'),
      );
    },
  );

  test(
    'stale FREE is excluded when includeUnknownInMenu is false '
    '(PM condition 5 — pins the deliberate list/menu divergence)',
    () async {
      stubHousehold(includeUnknownInMenu: false);
      final safe = recipeWith('safe', tag({'gluten': TriState.free}));
      final staleFree = recipeWith(
        'stale-free',
        tag({'gluten': TriState.free}, version: '1.0.0'),
      );
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [staleFree, safe],
      );
      menuService.setGenerateMenuResult({
        'middag': [safe],
      });

      await generator.generateMenuFromPrompt('veckomeny');

      expect(menuService.lastGenerateRecipes!.map((r) => r.id), ['safe']);
      expect(generator.lastPoolStats?.hiddenByAllergenFilter, 1);
    },
  );

  test(
    'swap never returns a recipe containing a household-tracked allergen',
    () async {
      stubHousehold();
      final current = recipeWith('current', tag({'gluten': TriState.free}));
      final unsafeAlt = recipeWith(
        'unsafe-alt',
        tag({'gluten': TriState.contains}),
      );
      final safeAlt = recipeWith('safe-alt', tag({'gluten': TriState.free}));
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [current, unsafeAlt, safeAlt],
      );

      // RecipeFactory defaults mealType to 'Lunch' — swap in that category.
      final result = await generator.swapSingleRecipe(current, 'lunch', {
        'lunch': [current],
      });

      expect(result.recipe?.id, 'safe-alt');
      expect(result.alternativesRemaining, 0);
    },
  );

  test(
    'swap returns exhausted (not an unsafe recipe) when every alternative '
    'contains the tracked allergen',
    () async {
      stubHousehold();
      final current = recipeWith('current', tag({'gluten': TriState.free}));
      final unsafeA = recipeWith(
        'unsafe-a',
        tag({'gluten': TriState.contains}),
      );
      final unsafeB = recipeWith(
        'unsafe-b',
        tag({'gluten': TriState.contains}),
      );
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [current, unsafeA, unsafeB],
      );

      final result = await generator.swapSingleRecipe(current, 'lunch', {
        'lunch': [current],
      });

      expect(result.recipe, isNull);
      expect(result.alternativesRemaining, 0);
    },
  );

  test(
    'analytics: generation fires menu_recipes_hidden_by_household once, '
    'with count + tracked allergens + pref source',
    () async {
      stubHousehold();
      final analytics = MockAnalyticsService();
      TestServiceLocator.registerSingleton<AnalyticsService>(analytics);
      final safe = recipeWith('safe', tag({'gluten': TriState.free}));
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [
          recipeWith('unsafe', tag({'gluten': TriState.contains})),
          safe,
        ],
      );
      menuService.setGenerateMenuResult({
        'middag': [safe],
      });

      await generator.generateMenuFromPrompt('veckomeny');

      final events = analytics.capturedEvents
          .where((e) => e.name == 'menu_recipes_hidden_by_household')
          .toList();
      expect(events, hasLength(1));
      expect(events.single.parameters, {
        'hidden_count': 1,
        'tracked_allergen_count': 1,
        'pref_source': 'household',
      });
    },
  );

  test(
    'BUT-1663: a DEGRADED aggregate filters on the widened set and is '
    'reported as householdIncomplete, not as a healthy household run',
    () async {
      // Every other test in this file stubs `.complete`, so the degraded
      // branch of _resolveActivePrefs had no coverage at all — the enum value
      // could have been reverted to `household` and nothing would have gone
      // red, hiding the one signal that says the menu was built without
      // seeing the whole family.
      when(() => household.hasHousehold).thenReturn(true);
      when(() => household.aggregateAllergenPreferences()).thenAnswer(
        (_) async => HouseholdAllergenAggregate.degraded(
          // The shape HouseholdService actually produces when a member's read
          // fails: the resolved member's allergen PLUS the common-allergen
          // safety floor, with the UNKNOWN escape hatch shut.
          preferences: UserAllergenPreferences(
            trackedAllergens: {
              'gluten',
              ...UserAllergenPreferences.defaults.trackedAllergens,
            },
            trackedDietary: const {},
            includeUnknownInMenu: false,
          ),
          unresolvedMemberIds: const ['kid'],
        ),
      );
      final analytics = MockAnalyticsService();
      TestServiceLocator.registerSingleton<AnalyticsService>(analytics);

      // Must be proven free of the FLOOR allergens too, not just gluten —
      // with includeUnknownInMenu false, an unproven floor allergen is enough
      // to withhold a recipe. That is the whole point of cautious mode, and it
      // is why a degraded household sees a visibly smaller pool.
      final safe = recipeWith(
        'safe',
        tag({
          for (final a in {
            'gluten',
            ...UserAllergenPreferences.defaults.trackedAllergens,
          })
            a: TriState.free,
        }),
      );
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [
          recipeWith('unsafe', tag({'gluten': TriState.contains})),
          // With includeUnknownInMenu false a stale/unknown recipe must also
          // be kept out — that is what "cautious" buys.
          recipeWith('unknown', tag({'gluten': TriState.unknown})),
          safe,
        ],
      );
      menuService.setGenerateMenuResult({
        'middag': [safe],
      });

      await generator.generateMenuFromPrompt('veckomeny');

      final events = analytics.capturedEvents
          .where((e) => e.name == 'menu_recipes_hidden_by_household')
          .toList();
      expect(events, hasLength(1));
      // Whole map, like the sibling test above — asserting only the two keys
      // this test is "about" would let a regression in the third through.
      expect(events.single.parameters, {
        'hidden_count': 2,
        'tracked_allergen_count': {
          'gluten',
          ...UserAllergenPreferences.defaults.trackedAllergens,
        }.length,
        'pref_source': 'householdIncomplete',
      });
      // The direct proof of what reached the selection service, as every other
      // test in this file does it.
      expect(menuService.lastGenerateRecipes?.map((r) => r.id), ['safe']);
    },
  );
}
