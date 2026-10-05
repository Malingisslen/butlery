// test/unit/viewmodels/menu/menu_generator_undeclared_user_test.dart
//
// BUT-2085 / BUT-1694: what the personal menu generator filters by for a
// user who has NEVER opened the allergen screen (profile loaded, private
// settings read, `allergenPreferences` null).
//
// The generator is wired exactly as MenuViewModel wires it (both filter
// flags on, menu_viewmodel.dart) and reads a REAL UserService, not a mock,
// so the defaults substitution in `UserService.allergenPreferences` is on
// the measured path. The household path is a mock HouseholdService, as in
// menu_household_allergen_test.dart.
//
// The generator reads the PROFILE, not `UserService.allergenPreferences`
// (BUT-1663: an untouched screen means "no allergies", never the default
// diets); the first group pins that the getter still substitutes defaults
// for the settings screen, the second what the menu filters by.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockHouseholdService extends Mock implements HouseholdService {}

const _uid = 'undeclared_user';

void main() {
  late MenuGenerator generator;
  late MockMenuService menuService;
  late MockUnifiedRecipeService recipeService;
  late MockUserRepository userRepository;
  late _MockAuthRepository authRepository;
  late UserService userService;
  late _MockHouseholdService household;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  TagResult tag({
    Map<String, TriState> allergen = const {},
    Map<String, TriState> dietary = const {},
  }) => TagResult(
    tags: const {},
    allergenStatus: allergen,
    dietaryStatus: dietary,
    coverage: 1.0,
    generatedAt: DateTime(2026),
    generatorVersion: kTagGeneratorVersion,
  );

  Recipe recipeWith(String id, TagResult t) {
    final base = RecipeFactory.build(id: id, title: id, mealType: 'Middag');
    return Recipe(
      core: base.core.copyWith(tagResult: t),
      type: base.type,
    );
  }

  /// Every default allergen proven absent, so the only thing that can drop
  /// the dish is a DIET the user never asked for.
  Recipe meatDish() => recipeWith(
    'meat',
    tag(
      allergen: {
        for (final a in UserAllergenPreferences.defaults.trackedAllergens)
          a: TriState.free,
      },
      dietary: {
        'vegetarisk': TriState.contains,
        'vegansk': TriState.contains,
      },
    ),
  );

  Recipe veganDish() => recipeWith(
    'vegan',
    tag(
      allergen: {
        for (final a in UserAllergenPreferences.defaults.trackedAllergens)
          a: TriState.free,
      },
      dietary: {'vegetarisk': TriState.free, 'vegansk': TriState.free},
    ),
  );

  Recipe nutDish() => recipeWith(
    'nuts',
    tag(
      allergen: {
        for (final a in UserAllergenPreferences.defaults.trackedAllergens)
          a: a == 'nötter' ? TriState.contains : TriState.free,
      },
      dietary: {'vegetarisk': TriState.free, 'vegansk': TriState.free},
    ),
  );

  UserProfile profile({
    UserAllergenPreferences? prefs,
    // The private settings doc WAS read and carried no preferences: this is
    // the declaration BUT-1663 distinguishes from a failed read.
    bool settingsMerged = true,
  }) => UserProfile(
    uid: _uid,
    displayName: 'Ny användare',
    email: 'ny@example.com',
    isOnline: false,
    joinedAt: DateTime(2026),
    lastActiveAt: DateTime(2026),
    allergenPreferences: prefs,
    settingsMerged: settingsMerged,
  );

  /// Signs in [_uid] and loads [p] through the real UserService.
  Future<void> signInWith(UserProfile p) async {
    final user = MockFactory.createMockUser(uid: _uid, email: p.email);
    when(() => authRepository.currentUser).thenReturn(user);
    when(() => authRepository.currentUserId).thenReturn(_uid);
    when(
      () => authRepository.authStateChanges(),
    ).thenAnswer((_) => Stream.value(user));
    when(() => userRepository.ensureBaseUserDocument(_uid)).thenAnswer(
      (_) async {},
    );
    when(() => userRepository.fetchProfile(_uid)).thenAnswer((_) async => p);
    await userService.initialize();
    // Precondition for everything below: the profile really is loaded and
    // carries exactly the preferences the test handed it.
    expect(userService.currentUserProfile?.uid, _uid);
    expect(
      userService.currentUserProfile?.allergenPreferences,
      p.allergenPreferences,
    );
  }

  Future<List<String>> pool() async =>
      (await generator.getAvailableRecipesAsync()).map((r) => r.id).toList();

  List<String> syncPool() =>
      generator.availableRecipes.map((r) => r.id).toList();

  void stubHousehold({required bool exists}) {
    when(() => household.hasHousehold).thenReturn(exists);
    // An EMPTY household aggregate: the signed-in user's own undeclared
    // profile contributes nothing on this path (BUT-1663 part 1). The real
    // service adds the common-allergen floor for OTHER members it cannot
    // read, never a diet; the mock leaves that out to isolate the diet half.
    when(() => household.aggregateAllergenPreferences()).thenAnswer(
      (_) async => const HouseholdAllergenAggregate.complete(
        UserAllergenPreferences(trackedAllergens: {}, trackedDietary: {}),
      ),
    );
  }

  setUp(() async {
    menuService = MockMenuService();
    recipeService = MockUnifiedRecipeService();
    userRepository = MockFactory.createUserRepository(currentUserId: _uid);
    authRepository = _MockAuthRepository();
    userService = UserService(
      repository: userRepository,
      authRepository: authRepository,
    );
    household = _MockHouseholdService();
    stubHousehold(exists: false);
    TestServiceLocator.registerSingleton<HouseholdService>(household);

    // Mirrors MenuViewModel's production wiring: both filters on, household
    // toggle at its default (true).
    generator = MenuGenerator(
      menuService: menuService,
      recipeService: recipeService,
      userService: userService,
      filterByAllergens: true,
      filterByDietary: true,
    );
    recipeService.setRecipeState(
      isInitialized: true,
      recipes: [meatDish(), veganDish(), nutDish()],
    );
  });

  tearDown(() => userService.dispose());

  group('mechanism (measured on the real UserService)', () {
    test('a profile created at signup carries no allergenPreferences, and the '
        'getter substitutes defaults that include the vegan diet', () async {
      await signInWith(profile());

      final prefs = userService.allergenPreferences;
      expect(prefs, same(UserAllergenPreferences.defaults));
      expect(prefs.trackedDietary, containsAll(['vegetarisk', 'vegansk']));
      expect(prefs.trackedAllergens, hasLength(4));
    });

    test('a DECLARED user is filtered by what they declared', () async {
      await signInWith(
        profile(
          prefs: const UserAllergenPreferences(
            trackedAllergens: {'nötter'},
            trackedDietary: {},
          ),
        ),
      );

      expect(syncPool(), ['meat', 'vegan']);
      expect(await pool(), ['meat', 'vegan']);
      expect(generator.lastPoolStats?.prefSource, MenuPrefSource.singleUser);
    });
  });

  group('menu filtering (BUT-1663: untouched screen = no allergies)', () {
    test(
      'BUT-2085: an undeclared user with no household gets the unfiltered '
      'pool — no diet and no allergen is imposed',
      () async {
        await signInWith(profile());

        expect(syncPool(), ['meat', 'vegan', 'nuts']);
        expect(await pool(), ['meat', 'vegan', 'nuts']);
        expect(generator.lastPoolStats?.prefSource, MenuPrefSource.singleUser);
        expect(generator.lastPoolStats?.trackedAllergenCount, 0);
      },
    );

    test(
      'BUT-1694: an undeclared user is filtered identically with and without '
      'an empty household aggregate',
      () async {
        await signInWith(profile());

        final withoutHousehold = await pool();
        stubHousehold(exists: true);
        final withHousehold = await pool();

        expect(withoutHousehold, withHousehold);
      },
    );

    test(
      'a profile whose settings read FAILED is filtered by the common-allergen '
      'floor with UNKNOWN shut, never by a diet',
      () async {
        await signInWith(profile(settingsMerged: false));

        expect(syncPool(), ['meat', 'vegan']);
        expect(await pool(), ['meat', 'vegan']);
        expect(
          generator.lastPoolStats?.trackedAllergenCount,
          UserAllergenPreferences.defaults.trackedAllergens.length,
        );
      },
    );
  });
}
