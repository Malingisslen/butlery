// test/unit/viewmodels/menu/menu_generator_present_aware_test.dart
//
// Present-aware allergen filtering (family Phase 4). Kept in its own file
// because the generator resolves the family roster via the global
// ServiceLocator, and the large menu_generator_test.dart's 60+ prior tests
// leave shared TestServiceLocator state that makes those resolutions flaky. A
// dedicated file = a fresh isolate = a clean locator.
//
// The present ADULTS resolve through a REAL HouseholdService (BUT-2076): the
// floor for another account holder lives there, and a mocked service would
// let these tests pass with that floor deleted.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/viewmodels/menu/menu_generator.dart';
import 'package:butlery/models/family_rating.dart' show HouseholdMemberType;
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _MockHouseholdRosterService extends Mock
    implements HouseholdRosterService {}

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _MockPermissionService extends Mock implements PermissionService {}

class _MockFriendsService extends Mock implements UnifiedFriendsService {}

class _MockCategoriesOps extends Mock implements FriendsCategoriesOperations {}

class _MockFeatureFlags extends Mock implements FeatureFlagService {}

const _self = 'u1';
const _partner = 'm-partner';
const _kid = 'm-kid';

UserProfile _profile(
  String uid, {
  UserAllergenPreferences? prefs,
  bool settingsMerged = false,
}) => UserProfile(
  uid: uid,
  displayName: uid,
  email: '$uid@example.com',
  joinedAt: DateTime(2026, 1, 1),
  lastActiveAt: DateTime(2026, 1, 1),
  allergenPreferences: prefs,
  settingsMerged: settingsMerged,
);

UserAllergenPreferences _prefs(Set<String> allergens) =>
    UserAllergenPreferences(trackedAllergens: allergens, trackedDietary: {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MenuGenerator generator;
  late MockMenuService menuService;
  late MockUnifiedRecipeService recipeService;
  late MockUserService userService;
  late _MockHouseholdRepository hhRepo;
  late _MockHouseholdRosterService roster;
  late _MockCategoriesOps categoriesOps;

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

  // Fresh tags: a stale FREE is read as UNKNOWN, which would make every
  // "stays in the pool" assertion below depend on the UNKNOWN hatch.
  TagResult tag(
    Map<String, TriState> allergen, {
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
    final base = RecipeFactory.build(id: id, title: id);
    return Recipe(
      core: base.core.copyWith(tagResult: t),
      type: base.type,
    );
  }

  /// A recipe proven free of every floor allergen, with [overrides] on top.
  Recipe floorSafe(String id, [Map<String, TriState> overrides = const {}]) =>
      recipeWith(
        id,
        tag({
          for (final a in UserAllergenPreferences.defaults.trackedAllergens)
            a: TriState.free,
          ...overrides,
        }),
      );

  void stubLookup(String uid, ProfileLookup lookup) {
    when(
      () => userService.lookupUserProfile(uid),
    ).thenAnswer((_) async => lookup);
  }

  void usePool(List<Recipe> recipes) =>
      recipeService.setRecipeState(isInitialized: true, recipes: recipes);

  Future<List<String>> pool() async =>
      (await generator.getAvailableRecipesAsync()).map((r) => r.id).toList();

  setUp(() {
    menuService = MockMenuService();
    recipeService = MockUnifiedRecipeService();
    userService = MockUserService();
    when(() => userService.allergenPreferences).thenReturn(
      const UserAllergenPreferences(trackedAllergens: {}, trackedDietary: {}),
    );
    // The signed-in user's settings were read and hold no allergies — a
    // declaration. Another account holder resolves with their settings
    // unread, which is the only shape this device ever sees for them.
    stubLookup(
      _self,
      ProfileLookup.found(_profile(_self, settingsMerged: true)),
    );
    stubLookup(_partner, ProfileLookup.found(_profile(_partner)));
    TestServiceLocator.registerSingleton<UserService>(userService);

    generator = MenuGenerator(
      menuService: menuService,
      recipeService: recipeService,
      userService: userService,
    );

    final perm = _MockPermissionService();
    when(() => perm.currentUserId).thenReturn(_self);
    hhRepo = _MockHouseholdRepository();
    when(() => hhRepo.getForUser(any())).thenAnswer(
      (_) async => [
        Household(
          id: 'hh1',
          name: Household.defaultName,
          members: const [],
          createdBy: _self,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
    roster = _MockHouseholdRosterService();
    when(() => roster.tryGetRoster(any())).thenAnswer(
      (_) async => [
        HouseholdRosterMember.fromUser(userId: _self, displayName: 'Jag'),
        HouseholdRosterMember.fromUser(userId: _partner, displayName: 'P'),
        // A present child whose profile carries a gluten allergy.
        const HouseholdRosterMember(
          memberId: _kid,
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

    // Sharing off: nobody can have shared, which is knowledge, not an outage.
    final flags = _MockFeatureFlags();
    when(() => flags.isEnabled(any())).thenReturn(false);

    // No friend-category household unless a test says so.
    final friends = _MockFriendsService();
    categoriesOps = _MockCategoriesOps();
    when(() => friends.categories).thenReturn(categoriesOps);
    when(() => categoriesOps.categoriesList).thenReturn(const []);

    TestServiceLocator.registerSingleton<PermissionService>(perm);
    TestServiceLocator.registerSingleton<HouseholdRepository>(hhRepo);
    TestServiceLocator.registerSingleton<HouseholdRosterService>(roster);
    TestServiceLocator.registerSingleton<FeatureFlagService>(flags);
    TestServiceLocator.registerSingleton<UnifiedFriendsService>(friends);
    TestServiceLocator.registerSingleton<HouseholdService>(HouseholdService());
    (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
        .setAuthState(userId: _self);
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
      generator.presentMemberIds = [_kid];
      final safe = recipeWith('safe', tag({'gluten': TriState.free}));
      usePool([
        recipeWith('gluten', tag({'gluten': TriState.contains})),
        safe,
      ]);
      menuService.setGenerateMenuResult({
        'middag': [safe],
      });

      await generator.generateMenuFromPrompt('veckomeny');

      expect(menuService.lastGenerateRecipes!.map((r) => r.id), ['safe']);
    },
  );

  test(
    'when only the allergy-free signed-in adult is present, gluten recipes '
    'stay (present-aware, not whole-household)',
    () async {
      generator.filterByAllergens = true;
      generator.presentMemberIds = [_self]; // the kid is NOT present
      usePool([
        recipeWith('gluten', tag({'gluten': TriState.contains})),
      ]);

      expect(
        await pool(),
        ['gluten'],
        reason:
            "the absent child's allergy must not filter a menu they're not eating",
      );
      expect(generator.lastPoolStats?.prefSource, MenuPrefSource.present);
    },
  );

  test(
    'both present: the allergic child still excludes gluten (union)',
    () async {
      // Adult (no allergy) + child (gluten) both present → the union must still
      // protect the child. Guards a "take-first member" or null-prefs regression.
      generator.filterByAllergens = true;
      generator.presentMemberIds = [_self, _kid];
      usePool([
        recipeWith('gluten', tag({'gluten': TriState.contains})),
        recipeWith('safe', tag({'gluten': TriState.free})),
      ]);

      expect(await pool(), ['safe']);
    },
  );

  test('an EMPTY present set does not disable filtering (safety)', () async {
    // "No one selected" must NOT present-filter to an unfiltered pool — it
    // falls through to the existing path (here single-user, no allergens).
    generator.filterByAllergens = true;
    generator.presentMemberIds = [];
    usePool([
      recipeWith('gluten', tag({'gluten': TriState.contains})),
    ]);

    // Falls through to single-user (empty prefs) → unfiltered, but crucially it
    // did NOT short-circuit the present-aware branch with empty prefs.
    expect(await pool(), ['gluten']);
  });

  test(
    'no household at all falls back to single-user filtering, not unfiltered',
    () async {
      // With no household the present path cannot run, so we fall through to
      // single-user filtering — which must still apply the user's own
      // allergens (here gluten), never silently ship an unfiltered menu.
      when(() => hhRepo.getForUser(any())).thenAnswer((_) async => []);
      when(
        () => userService.allergenPreferences,
      ).thenReturn(_prefs({'gluten'}));
      generator.filterByAllergens = true;
      generator.presentMemberIds = [_kid];
      usePool([
        recipeWith('gluten', tag({'gluten': TriState.contains})),
        recipeWith('safe', tag({'gluten': TriState.free})),
      ]);

      expect(
        await pool(),
        ['safe'],
        reason: 'fall-through must still filter via single-user allergens',
      );
    },
  );

  group('BUT-2076: an unreadable diner is never "no allergies"', () {
    setUp(() => generator.filterByAllergens = true);

    test('full resolution: the signed-in user and a present child are both '
        'filtered for, and the run is reported complete', () async {
      stubLookup(
        _self,
        ProfileLookup.found(
          _profile(_self, prefs: _prefs({'sesam'}), settingsMerged: true),
        ),
      );
      generator.presentMemberIds = [_self, _kid];
      usePool([
        recipeWith('sesam', tag({'sesam': TriState.contains})),
        recipeWith('gluten', tag({'gluten': TriState.contains})),
        recipeWith(
          'safe',
          tag({'sesam': TriState.free, 'gluten': TriState.free}),
        ),
      ]);

      expect(await pool(), ['safe']);
      expect(generator.lastPoolStats?.prefSource, MenuPrefSource.present);
    });

    test('M4: another adult present, found, settings unreadable, no share — '
        'the floor filters for them and the run is NOT incomplete', () async {
      generator.presentMemberIds = [_self, _partner];
      usePool([
        floorSafe('nuts', {'jordnötter': TriState.contains}),
        floorSafe('unknownNuts', {'jordnötter': TriState.unknown}),
        floorSafe('safe'),
      ]);

      final ids = await pool();

      expect(
        ids,
        isNot(contains('nuts')),
        reason:
            "the other adult's allergies cannot be read; the floor stands "
            'in for them',
      );
      // Not degraded, so the UNKNOWN hatch stays as the diners left it.
      expect(ids, containsAll(['safe', 'unknownNuts']));
      expect(generator.lastPoolStats?.prefSource, MenuPrefSource.present);
    });

    test('partial failure: one present adult unreadable widens with the floor, '
        'closes UNKNOWN and reports the run incomplete', () async {
      stubLookup(_partner, const ProfileLookup.unavailable());
      generator.presentMemberIds = [_self, _partner, _kid];
      usePool([
        floorSafe('nuts', {'jordnötter': TriState.contains}),
        floorSafe('unknownNuts', {'jordnötter': TriState.unknown}),
        floorSafe('safe'),
      ]);

      expect(await pool(), ['safe']);
      expect(
        generator.lastPoolStats?.prefSource,
        MenuPrefSource.presentIncomplete,
      );
    });

    test('a present member whose profile does not exist neither adds the '
        'floor nor degrades the run', () async {
      stubLookup(_partner, const ProfileLookup.missing());
      generator.presentMemberIds = [_self, _partner];
      usePool([
        floorSafe('nuts', {'jordnötter': TriState.contains}),
      ]);

      expect(await pool(), ['nuts']);
      expect(generator.lastPoolStats?.prefSource, MenuPrefSource.present);
    });

    test(
      'total failure with no household: the user\'s own preferences, '
      'widened with the floor, UNKNOWN closed, reported incomplete',
      () async {
        when(() => roster.tryGetRoster(any())).thenAnswer((_) async => null);
        stubLookup(
          _self,
          ProfileLookup.found(
            _profile(_self, prefs: _prefs({'selleri'}), settingsMerged: true),
          ),
        );
        generator.presentMemberIds = [_self, _kid];
        usePool([
          floorSafe('selleri', {'selleri': TriState.contains}),
          floorSafe('gluten', {
            'gluten': TriState.contains,
            'selleri': TriState.free,
          }),
          floorSafe('unknown', {'selleri': TriState.unknown}),
          floorSafe('safe', {'selleri': TriState.free}),
        ]);

        expect(await pool(), ['safe']);
        expect(
          generator.lastPoolStats?.prefSource,
          MenuPrefSource.presentIncomplete,
        );
      },
    );

    test('total failure with no household, user never set preferences: the '
        'floor applies but no diet is imposed', () async {
      // What UserService.allergenPreferences returns for an unset profile —
      // it carries tracked diets, which must not reach this path.
      when(
        () => userService.allergenPreferences,
      ).thenReturn(UserAllergenPreferences.defaults);
      when(() => roster.tryGetRoster(any())).thenAnswer((_) async => null);
      generator
        ..filterByDietary = true
        ..presentMemberIds = [_self];
      usePool([
        recipeWith(
          'meat',
          tag(
            {
              for (final a in UserAllergenPreferences.defaults.trackedAllergens)
                a: TriState.free,
            },
            dietary: {
              'vegansk': TriState.contains,
              'vegetarisk': TriState.contains,
            },
          ),
        ),
        floorSafe('nuts', {'jordnötter': TriState.contains}),
      ]);

      expect(await pool(), ['meat']);
      expect(
        generator.lastPoolStats?.prefSource,
        MenuPrefSource.presentIncomplete,
      );
    });

    test('total failure inside a household: the household union, widened '
        'with the floor, reported incomplete', () async {
      when(() => roster.tryGetRoster(any())).thenAnswer((_) async => null);
      when(() => categoriesOps.categoriesList).thenReturn([
        FriendCategory(
          id: 'hh',
          ownerId: _self,
          name: 'Familjen',
          friendUserIds: const [],
          isHousehold: true,
        ),
      ]);
      // The household union is {sesam} and nothing else, so each exclusion
      // below has exactly one cause: sesam by the union, nuts by the widen,
      // unknownSesam by the closed hatch.
      stubLookup(
        _self,
        ProfileLookup.found(
          _profile(_self, prefs: _prefs({'sesam'}), settingsMerged: true),
        ),
      );
      generator.presentMemberIds = [_self];
      usePool([
        floorSafe('sesam', {'sesam': TriState.contains}),
        floorSafe('nuts', {
          'jordnötter': TriState.contains,
          'sesam': TriState.free,
        }),
        floorSafe('unknownSesam', {'sesam': TriState.unknown}),
        floorSafe('safe', {'sesam': TriState.free}),
      ]);

      expect(await pool(), ['safe']);
      expect(
        generator.lastPoolStats?.prefSource,
        MenuPrefSource.presentIncomplete,
      );
    });

    test("a present child's floor-covered allergy survives a total roster "
        'failure', () async {
      // Gluten is in the floor. An allergy OUTSIDE the floor cannot survive
      // this path: the diner documents are exactly what failed to load.
      when(() => roster.tryGetRoster(any())).thenAnswer((_) async => null);
      generator.presentMemberIds = [_kid];
      usePool([
        floorSafe('gluten', {'gluten': TriState.contains}),
        floorSafe('safe'),
      ]);

      expect(await pool(), ['safe']);
    });

    test('a household lookup that throws is treated as a total failure, not '
        'as an error or an empty union', () async {
      when(() => hhRepo.getForUser(any())).thenThrow(StateError('offline'));
      generator.presentMemberIds = [_self];
      usePool([
        floorSafe('nuts', {'jordnötter': TriState.contains}),
        floorSafe('safe'),
      ]);

      expect(await pool(), ['safe']);
      expect(
        generator.lastPoolStats?.prefSource,
        MenuPrefSource.presentIncomplete,
      );
    });

    test('present ids that match nobody on the roster are not an empty '
        'union', () async {
      generator.presentMemberIds = ['someone-else'];
      usePool([
        floorSafe('nuts', {'jordnötter': TriState.contains}),
        floorSafe('safe'),
      ]);

      expect(await pool(), ['safe']);
      expect(
        generator.lastPoolStats?.prefSource,
        MenuPrefSource.presentIncomplete,
      );
    });
  });
}
