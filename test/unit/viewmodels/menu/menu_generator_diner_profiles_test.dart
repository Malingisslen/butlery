// test/unit/viewmodels/menu/menu_generator_diner_profiles_test.dart
//
// Family diner profiles (children, guests without an account) in the
// whole-household menu filter. Found in the app on 2026-10-05: a child with a
// fish allergy added under "Min familj" got salmon, because the household
// union only read ACCOUNTS. Own file (fresh isolate) for the same reason as
// menu_household_allergen_test.dart — the generator resolves its household
// collaborators through the global ServiceLocator.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/viewmodels/menu/menu_generator.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/helpers/own_preferences_stub.dart';

class _MockHouseholdService extends Mock implements HouseholdService {}

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _MockDinerProfileRepository extends Mock
    implements DinerProfileRepository {}

class _MockPermissionService extends Mock implements PermissionService {}

const _self = 'u1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MenuGenerator generator;
  late MockMenuService menuService;
  late MockUnifiedRecipeService recipeService;
  late MockUserService userService;
  late _MockHouseholdService household;
  late _MockHouseholdRepository householdRepo;
  late _MockDinerProfileRepository dinerRepo;

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
    generatorVersion: kTagGeneratorVersion,
  );

  // Every allergen the tests (or the safety floor) can track is stated, FREE
  // unless overridden, so a missing key never decides a test.
  Recipe recipeWith(String id, Map<String, TriState> allergen) {
    final base = RecipeFactory.build(id: id, title: id);
    final full = {
      for (final k in ['fisk', 'gluten', 'mjölk', 'nötter', 'jordnötter'])
        k: TriState.free,
      ...allergen,
    };
    return Recipe(
      core: base.core.copyWith(tagResult: tag(full)),
      type: base.type,
    );
  }

  DinerProfile child(Set<String> allergens, {bool includeUnknown = true}) =>
      DinerProfile(
        id: 'kid',
        householdId: 'hh1',
        name: 'Testbarn',
        ageBand: DinerAgeBand.child,
        allergenPreferences: UserAllergenPreferences(
          trackedAllergens: allergens,
          trackedDietary: const {},
          includeUnknownInMenu: includeUnknown,
        ),
        createdBy: _self,
      );

  void familyOf(List<DinerProfile> diners) {
    when(() => householdRepo.getActiveForUser(_self)).thenAnswer(
      (_) async => Household(
        id: 'hh1',
        name: Household.defaultName,
        members: const [],
        createdBy: _self,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    when(() => dinerRepo.getByHousehold('hh1')).thenAnswer((_) async => diners);
  }

  void householdToggle({required bool on}) {
    stubOwnPreferences(
      userService,
      const UserAllergenPreferences(trackedAllergens: {}, trackedDietary: {}),
      uid: _self,
      useHouseholdAllergens: on,
    );
  }

  final salmon = recipeWith('salmon', {'fisk': TriState.contains});
  final pasta = recipeWith('pasta', {'fisk': TriState.free});
  final unknown = recipeWith('unknown', {'fisk': TriState.unknown});

  setUp(() {
    menuService = MockMenuService();
    recipeService = MockUnifiedRecipeService();
    userService = MockUserService();
    // The adult has no allergies, so every exclusion below comes from the
    // child's diner profile.
    stubOwnPreferences(
      userService,
      const UserAllergenPreferences(trackedAllergens: {}, trackedDietary: {}),
    );
    generator = MenuGenerator(
      menuService: menuService,
      recipeService: recipeService,
      userService: userService,
      filterByAllergens: true,
      filterByDietary: true,
    );
    recipeService.setRecipeState(
      isInitialized: true,
      recipes: [salmon, pasta, unknown],
    );

    household = _MockHouseholdService();
    when(() => household.hasHousehold).thenReturn(false);
    householdRepo = _MockHouseholdRepository();
    dinerRepo = _MockDinerProfileRepository();
    final perm = _MockPermissionService();
    when(() => perm.currentUserId).thenReturn(_self);
    familyOf(const []);

    TestServiceLocator.registerSingleton<HouseholdService>(household);
    TestServiceLocator.registerSingleton<HouseholdRepository>(householdRepo);
    TestServiceLocator.registerSingleton<DinerProfileRepository>(dinerRepo);
    TestServiceLocator.registerSingleton<PermissionService>(perm);
  });

  Future<Set<String>> pool() async =>
      (await generator.getAvailableRecipesAsync()).map((r) => r.id).toSet();

  test('a child with a fish allergy keeps the fish recipe out of the pool, '
      'with no friend-based household', () async {
    familyOf([
      child({'fisk'}),
    ]);

    expect(await pool(), {'pasta', 'unknown'});
    expect(generator.lastPoolStats?.prefSource, MenuPrefSource.household);
  });

  test('a member who joined someone else\'s household keeps the children of '
      'the household they created', () async {
    familyOf([
      child({'fisk'}),
    ]);
    final joined = Household(
      id: 'hh-joined',
      name: Household.defaultName,
      members: const [],
      createdBy: 'host',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final own = Household(
      id: 'hh1',
      name: Household.defaultName,
      members: const [],
      createdBy: _self,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    when(
      () => householdRepo.getActiveForUser(_self),
    ).thenAnswer((_) async => joined);
    when(
      () => householdRepo.getForUser(_self),
    ).thenAnswer((_) async => [joined, own]);
    when(
      () => dinerRepo.getByHousehold('hh-joined'),
    ).thenAnswer((_) async => const []);

    expect(await pool(), {'pasta', 'unknown'});
  });

  test('no family profiles: the pool and source are what the user alone '
      'gives', () async {
    expect(await pool(), {'salmon', 'pasta', 'unknown'});
    expect(generator.lastPoolStats?.prefSource, MenuPrefSource.singleUser);
  });

  test('a diner profile without allergens adds nothing', () async {
    familyOf([
      DinerProfile(
        id: 'kid',
        householdId: 'hh1',
        name: 'Testbarn',
        ageBand: DinerAgeBand.child,
        createdBy: _self,
      ),
    ]);

    expect(await pool(), {'salmon', 'pasta', 'unknown'});
    expect(generator.lastPoolStats?.prefSource, MenuPrefSource.singleUser);
  });

  test('an unreadable family widens with the floor, closes UNKNOWN and '
      'reports the household incomplete', () async {
    when(() => dinerRepo.getByHousehold('hh1')).thenThrow(Exception('down'));
    final glutenUnknown = recipeWith('glutenUnknown', {
      'gluten': TriState.unknown,
    });
    final glutenFull = recipeWith('glutenFull', {'gluten': TriState.contains});
    recipeService.setRecipeState(
      isInitialized: true,
      recipes: [pasta, glutenUnknown, glutenFull],
    );

    // The floor's gluten now filters (the adult tracks nothing), and the
    // UNKNOWN recipe goes too because the hatch is shut.
    expect(await pool(), {'pasta'});
    expect(
      generator.lastPoolStats?.prefSource,
      MenuPrefSource.householdIncomplete,
    );
  });

  test('one cautious diner shuts the UNKNOWN hatch for the whole household '
      '(a state the app does not write itself; guards the rule)', () async {
    familyOf([
      child({'fisk'}, includeUnknown: false),
    ]);

    expect(await pool(), {'pasta'});
  });

  test('a diner\'s diet joins the union too (a state the app does not write '
      'yet; guards the rule)', () async {
    familyOf([
      DinerProfile(
        id: 'kid',
        householdId: 'hh1',
        name: 'Testbarn',
        ageBand: DinerAgeBand.child,
        allergenPreferences: const UserAllergenPreferences(
          trackedAllergens: {},
          trackedDietary: {'vegetarisk'},
        ),
        createdBy: _self,
      ),
    ]);
    final meat = RecipeFactory.build(id: 'meat', title: 'meat');
    final veg = RecipeFactory.build(id: 'veg', title: 'veg');
    TagResult dietTag(TriState vegetarian) => TagResult(
      tags: const {},
      allergenStatus: const {},
      dietaryStatus: {'vegetarisk': vegetarian},
      coverage: 1.0,
      generatedAt: DateTime(2026),
      generatorVersion: kTagGeneratorVersion,
    );
    recipeService.setRecipeState(
      isInitialized: true,
      recipes: [
        Recipe(
          core: meat.core.copyWith(tagResult: dietTag(TriState.contains)),
          type: meat.type,
        ),
        Recipe(
          core: veg.core.copyWith(tagResult: dietTag(TriState.free)),
          type: veg.type,
        ),
      ],
    );

    expect(await pool(), {'veg'});
  });

  test('without a friend-based household a stale OFF toggle does not drop '
      'the child — the toggle is not shown there', () async {
    householdToggle(on: false);
    familyOf([
      child({'fisk'}),
    ]);

    expect(await pool(), {'pasta', 'unknown'});
  });

  test('with a friend-based household and the toggle OFF, diner profiles '
      'are not added', () async {
    when(() => household.hasHousehold).thenReturn(true);
    householdToggle(on: false);
    familyOf([
      child({'fisk'}),
    ]);

    expect(await pool(), {'salmon', 'pasta', 'unknown'});
    verifyNever(() => dinerRepo.getByHousehold(any()));
  });

  test('a friend-based household and diner profiles both count, and an '
      'incomplete household stays incomplete', () async {
    when(() => household.hasHousehold).thenReturn(true);
    when(() => household.aggregateAllergenPreferences()).thenAnswer(
      (_) async => HouseholdAllergenAggregate.degraded(
        preferences: const UserAllergenPreferences(
          trackedAllergens: {'gluten'},
          trackedDietary: {},
          includeUnknownInMenu: false,
        ),
      ),
    );
    familyOf([
      child({'fisk'}),
    ]);
    final bread = recipeWith('bread', {
      'gluten': TriState.contains,
      'fisk': TriState.free,
    });
    recipeService.setRecipeState(
      isInitialized: true,
      recipes: [salmon, pasta, unknown, bread],
    );

    expect(await pool(), {'pasta'});
    expect(
      generator.lastPoolStats?.prefSource,
      MenuPrefSource.householdIncomplete,
    );
  });
}
