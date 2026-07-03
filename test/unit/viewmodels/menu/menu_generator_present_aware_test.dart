// test/unit/viewmodels/menu/menu_generator_present_aware_test.dart
//
// Present-aware allergen filtering (family Phase 4). Kept in its own file
// because the generator resolves the family roster via the global
// ServiceLocator, and the large menu_generator_test.dart's 60+ prior tests
// leave shared TestServiceLocator state that makes those resolutions flaky. A
// dedicated file = a fresh isolate = a clean locator.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/viewmodels/menu/menu_generator.dart';
import 'package:butlery/models/family_rating.dart' show HouseholdMemberType;
import 'package:butlery/models/household.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/permission_service.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _MockHouseholdRosterService extends Mock
    implements HouseholdRosterService {}

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _MockPermissionService extends Mock implements PermissionService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MenuGenerator generator;
  late MockMenuService menuService;
  late MockUnifiedRecipeService recipeService;
  late MockUserService userService;
  late _MockHouseholdRepository hhRepo;
  late _MockHouseholdRosterService roster;

  // Bridge the PRODUCTION ServiceLocator (DIContainer-backed) — MenuGenerator
  // resolves the family roster via ServiceLocator.tryGet, which reads the
  // production container, not TestServiceLocator's GetIt directly.
  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  TagResult tag(Map<String, TriState> allergen) => TagResult(
    tags: const {},
    allergenStatus: allergen,
    dietaryStatus: const {},
    coverage: 1.0,
    generatedAt: DateTime(2026),
  );

  Recipe recipeWith(String id, TagResult t) {
    final base = RecipeFactory.build(id: id, title: id);
    return Recipe(
      core: base.core.copyWith(tagResult: t),
      type: base.type,
    );
  }

  setUp(() {
    menuService = MockMenuService();
    recipeService = MockUnifiedRecipeService();
    userService = MockUserService();
    when(() => userService.allergenPreferences).thenReturn(
      const UserAllergenPreferences(trackedAllergens: {}, trackedDietary: {}),
    );

    generator = MenuGenerator(
      menuService: menuService,
      recipeService: recipeService,
      userService: userService,
    );

    final perm = _MockPermissionService();
    when(() => perm.currentUserId).thenReturn('u1');
    hhRepo = _MockHouseholdRepository();
    when(() => hhRepo.getForUser(any())).thenAnswer(
      (_) async => [
        Household(
          id: 'hh1',
          name: Household.defaultName,
          members: const [],
          createdBy: 'u1',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
    roster = _MockHouseholdRosterService();
    when(() => roster.getRoster(any())).thenAnswer(
      (_) async => [
        HouseholdRosterMember.fromUser(userId: 'm-adult', displayName: 'A'),
        // A present child whose profile carries a gluten allergy.
        const HouseholdRosterMember(
          memberId: 'm-kid',
          type: HouseholdMemberType.profile,
          displayName: 'Kid',
          isMinor: true,
          allergenPreferences: UserAllergenPreferences(
            trackedAllergens: {'gluten'},
            trackedDietary: {},
          ),
        ),
      ],
    );
    TestServiceLocator.registerSingleton<PermissionService>(perm);
    TestServiceLocator.registerSingleton<HouseholdRepository>(hhRepo);
    TestServiceLocator.registerSingleton<HouseholdRosterService>(roster);
  });

  test(
    'a present child with a gluten allergy excludes gluten recipes from a '
    'generated menu (public entry point)',
    () async {
      // Re-anchored on generateMenuFromPrompt (BUT-1464): the audit's exact
      // complaint was that tests exercised getAvailableRecipesAsync directly
      // while production never called it. The contract now: the pool handed
      // to the selection service contains no unsafe recipe.
      generator.filterByAllergens = true;
      generator.presentMemberIds = ['m-kid'];
      final safe = recipeWith('safe', tag({'gluten': TriState.free}));
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [
          recipeWith('gluten', tag({'gluten': TriState.contains})),
          safe,
        ],
      );
      menuService.setGenerateMenuResult({
        'middag': [safe],
      });

      await generator.generateMenuFromPrompt('veckomeny');

      expect(menuService.lastGenerateRecipes!.map((r) => r.id), ['safe']);
    },
  );

  test(
    'when only the allergy-free adult is present, gluten recipes stay '
    '(present-aware, not whole-household)',
    () async {
      generator.filterByAllergens = true;
      generator.presentMemberIds = ['m-adult']; // the kid is NOT present
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [
          recipeWith('gluten', tag({'gluten': TriState.contains})),
        ],
      );

      final available = await generator.getAvailableRecipesAsync();
      expect(
        available.map((r) => r.id),
        ['gluten'],
        reason:
            "the absent child's allergy must not filter a menu they're not eating",
      );
    },
  );

  test(
    'both present: the allergic child still excludes gluten (union)',
    () async {
      // Adult (no allergy) + child (gluten) both present → the union must still
      // protect the child. Guards a "take-first member" or null-prefs regression.
      generator.filterByAllergens = true;
      generator.presentMemberIds = ['m-adult', 'm-kid'];
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [
          recipeWith('gluten', tag({'gluten': TriState.contains})),
          recipeWith('safe', tag({'gluten': TriState.free})),
        ],
      );

      final available = await generator.getAvailableRecipesAsync();
      expect(available.map((r) => r.id), ['safe']);
    },
  );

  test('an EMPTY present set does not disable filtering (safety)', () async {
    // "No one selected" must NOT present-filter to an unfiltered pool — it
    // falls through to the existing path (here single-user, no allergens).
    generator.filterByAllergens = true;
    generator.presentMemberIds = [];
    recipeService.setRecipeState(
      isInitialized: true,
      recipes: [
        recipeWith('gluten', tag({'gluten': TriState.contains})),
      ],
    );

    final available = await generator.getAvailableRecipesAsync();
    // Falls through to single-user (empty prefs) → unfiltered, but crucially it
    // did NOT short-circuit the present-aware branch with empty prefs.
    expect(available.map((r) => r.id), ['gluten']);
  });

  test(
    'roster unresolvable falls back to single-user filtering, not unfiltered',
    () async {
      // If the household can't be resolved, the present path returns null and we
      // fall through to single-user filtering — which must still apply the user's
      // own allergens (here gluten), never silently ship an unfiltered menu.
      when(() => hhRepo.getForUser(any())).thenAnswer((_) async => []);
      when(() => userService.allergenPreferences).thenReturn(
        const UserAllergenPreferences(
          trackedAllergens: {'gluten'},
          trackedDietary: {},
        ),
      );
      generator.filterByAllergens = true;
      generator.presentMemberIds = ['m-kid'];
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [
          recipeWith('gluten', tag({'gluten': TriState.contains})),
          recipeWith('safe', tag({'gluten': TriState.free})),
        ],
      );

      final available = await generator.getAvailableRecipesAsync();
      expect(
        available.map((r) => r.id),
        ['safe'],
        reason: 'fall-through must still filter via single-user allergens',
      );
    },
  );
}
