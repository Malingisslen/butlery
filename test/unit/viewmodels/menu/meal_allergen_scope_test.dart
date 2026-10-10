/// BUT-2362: the per-meal allergen scope — which allergens a dish has to
/// avoid at each meal, and the generator seam that keeps a dish some meal
/// can still take in the pool.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/family_rating.dart' show HouseholdMemberType;
import 'package:butlery/models/household.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/menu/meal_allergen_scope.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/helpers/own_preferences_stub.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../test_support/base_unit_test.dart';

Recipe _dish(
  String id, {
  Map<String, TriState> allergen = const {},
  String mealType = 'Middag',
}) {
  final base = RecipeFactory.build(id: id, title: id, mealType: mealType);
  return Recipe(
    core: base.core.copyWith(
      tagResult: TagResult(
        tags: const {},
        allergenStatus: allergen,
        dietaryStatus: const {},
        coverage: 1.0,
        generatedAt: DateTime(2026),
        generatorVersion: kTagGeneratorVersion,
      ),
    ),
    type: base.type,
  );
}

const _nuts = UserAllergenPreferences(
  trackedAllergens: {'nötter'},
  trackedDietary: {},
);
const _nothing = UserAllergenPreferences.none;

final _nutDish = _dish('nuts', allergen: {'nötter': TriState.contains});
final _safeDish = _dish('safe', allergen: {'nötter': TriState.free});

class _MockRoster extends Mock implements HouseholdRosterService {}

class _MockHouseholdRepo extends Mock implements HouseholdRepository {}

class _MockPermission extends Mock implements PermissionService {}

class _MockUsers extends Mock implements UserService {}

/// A real in-memory stand-in for the household: [hasHousehold] and the
/// whole-household read are switchable, and the per-meal read records every
/// call so the test can count how many distinct away sets were resolved.
class _FakeHousehold extends Fake implements HouseholdService {
  _FakeHousehold({required this.everyone});

  final UserAllergenPreferences everyone;
  bool inHousehold = true;
  bool wholeReadThrows = false;
  int? mealReadThrowsOnCall;
  int mealReads = 0;

  static const accountPrefs = {
    'u1': UserAllergenPreferences(
      trackedAllergens: {'selleri'},
      trackedDietary: {},
    ),
    'u2': UserAllergenPreferences(
      trackedAllergens: {'mjölk'},
      trackedDietary: {},
    ),
  };

  @override
  bool get hasHousehold => inHousehold;

  @override
  List<String> getHouseholdMemberIds() => ['u1', 'u2'];

  @override
  Future<HouseholdAllergenAggregate> aggregateAllergenPreferences() async {
    if (wholeReadThrows) throw StateError('household unreadable');
    return HouseholdAllergenAggregate.complete(everyone);
  }

  @override
  Future<HouseholdAllergenAggregate> aggregateAllergenPreferencesFor(
    Set<String> memberIds,
  ) async {
    mealReads++;
    if (mealReads == mealReadThrowsOnCall) throw StateError('profile read');
    return HouseholdAllergenAggregate.complete(
      UserAllergenPreferences(
        trackedAllergens: {
          for (final id in memberIds) ...?accountPrefs[id]?.trackedAllergens,
        },
        trackedDietary: const {},
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MealAllergenScope', () {
    // The kid who reacts to nuts is away at Tuesday middag only.
    final scope = MealAllergenScope(
      household: _nuts,
      byMeal: {(DayOfWeek.tue, MealSlot.middag): _nothing},
    );

    test('a meal with someone away follows the people still home', () {
      expect(scope.safeAt(_nutDish, DayOfWeek.tue, MealSlot.middag), isTrue);
    });

    test('every other meal follows the whole household', () {
      expect(scope.safeAt(_nutDish, DayOfWeek.mon, MealSlot.middag), isFalse);
      expect(scope.safeAt(_nutDish, DayOfWeek.tue, MealSlot.lunch), isFalse);
    });

    test('övrigt follows the whole household on every day', () {
      final ovrigtScope = MealAllergenScope(
        household: _nuts,
        byMeal: {(DayOfWeek.tue, MealSlot.ovrigt): _nothing},
      );
      expect(
        ovrigtScope.safeAt(_nutDish, DayOfWeek.tue, MealSlot.ovrigt),
        isFalse,
      );
    });

    test('safeAtSomeMeal looks only from fromDay on, and never at övrigt', () {
      expect(scope.safeAtSomeMeal(_nutDish, MealSlot.middag), isTrue);
      expect(
        scope.safeAtSomeMeal(
          _nutDish,
          MealSlot.middag,
          fromDay: DayOfWeek.wed,
        ),
        isFalse,
      );
      expect(scope.safeAtSomeMeal(_nutDish, MealSlot.ovrigt), isFalse);
      expect(scope.safeAtSomeMeal(_safeDish, MealSlot.ovrigt), isTrue);
    });

    test(
      'an unknown allergen status is judged as menu generation judges it',
      () {
        final unknown = _dish(
          'unknown',
          allergen: {'nötter': TriState.unknown},
        );
        final cautious = MealAllergenScope(
          household: const UserAllergenPreferences(
            trackedAllergens: {'nötter'},
            trackedDietary: {},
            includeUnknownInMenu: false,
          ),
        );
        final lenient = MealAllergenScope(
          household: const UserAllergenPreferences(
            trackedAllergens: {'nötter'},
            trackedDietary: {},
            includeUnknownInMenu: true,
          ),
        );
        expect(cautious.safeForHousehold(unknown), isFalse);
        expect(lenient.safeForHousehold(unknown), isTrue);
      },
    );

    test('unsafeEntryIds marks the entries someone at that meal cannot eat, '
        'and leaves out a recipe it cannot find', () {
      final week = WeeklyMenuPlan.empty(
        userId: 'u1',
        date: DateTime(2026, 3, 2),
      );
      final onTue = WeeklyMenuPlanEntry.create(
        day: DayOfWeek.tue,
        slot: MealSlot.middag,
        recipeId: 'nuts',
        recipeTitle: 'nuts',
      );
      final onMon = WeeklyMenuPlanEntry.create(
        day: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipeId: 'nuts',
        recipeTitle: 'nuts',
      );
      final gone = WeeklyMenuPlanEntry.create(
        day: DayOfWeek.wed,
        slot: MealSlot.middag,
        recipeId: 'deleted',
        recipeTitle: 'deleted',
      );
      final plan = week.copyWith(entries: [onTue, onMon, gone]);

      final unsafe = scope.unsafeEntryIds(
        plan,
        (id) => id == 'nuts' ? _nutDish : null,
      );

      expect(unsafe, {onMon.id});
    });
  });

  group('MenuGenerator.mealScopedIds (BUT-2362)', () {
    setUpAll(() => TestServiceLocator.initialize());
    tearDownAll(() => TestServiceLocator.reset());

    MenuGenerator generator() {
      final users = MockUserService();
      stubOwnPreferences(users, _nuts, useHouseholdAllergens: false);
      final recipes = MockUnifiedRecipeService()
        ..setRecipeState(isInitialized: true, recipes: [_safeDish, _nutDish]);
      return MenuGenerator(
        menuService: MockMenuService(),
        recipeService: recipes,
        userService: users,
        filterByAllergens: true,
      );
    }

    test('without a source the pool is the household-safe pool', () async {
      final pool = await generator().getAvailableRecipesAsync();
      expect(pool.map((r) => r.id), ['safe']);
    });

    test('a dish the source says some meal can take stays in the pool, and '
        'the source is only shown what the household filter removed', () async {
      final g = generator();
      List<String>? asked;
      g.mealScopedIds = (removed) async {
        asked = removed.map((r) => r.id).toList();
        return {'nuts'};
      };

      final pool = await g.getAvailableRecipesAsync();

      expect(asked, ['nuts']);
      expect(pool.map((r) => r.id), ['safe', 'nuts']);
    });

    test(
      'an id the source returns that was never removed adds nothing',
      () async {
        final g = generator()..mealScopedIds = (_) async => {'other'};
        final pool = await g.getAvailableRecipesAsync();
        expect(pool.map((r) => r.id), ['safe']);
      },
    );

    test('a source that throws keeps the household-safe pool', () async {
      final g = generator()
        ..mealScopedIds = (_) async => throw StateError('offline');
      final pool = await g.getAvailableRecipesAsync();
      expect(pool.map((r) => r.id), ['safe']);
    });
  });

  group('MealAllergenScope.resolve (BUT-2362)', () {
    const kid = 'm-kid';
    const kid2 = 'm-kid2';

    late _MockUsers users;
    late _MockRoster roster;
    late _FakeHousehold household;

    setUpAll(() => BaseUnitTest.setupUnitWithProductionLocator());
    tearDownAll(() async {
      await TestServiceLocator.reset();
      await BaseUnitTest.teardownUnit();
    });

    HouseholdRosterMember child(String id, String allergen) =>
        HouseholdRosterMember(
          memberId: id,
          type: HouseholdMemberType.profile,
          displayName: id,
          isMinor: true,
          allergenPreferences: UserAllergenPreferences(
            trackedAllergens: {allergen},
            trackedDietary: const {},
          ),
        );

    void useProfile({
      bool scope = true,
      bool householdAllergens = true,
    }) {
      when(() => users.currentUserProfile).thenReturn(
        UserProfile(
          uid: 'u1',
          displayName: 'Jag',
          email: 'u1@example.com',
          joinedAt: DateTime(2026),
          lastActiveAt: DateTime(2026),
          allergenPreferences: const UserAllergenPreferences(
            trackedAllergens: {'selleri'},
            trackedDietary: {},
          ),
          useMealAllergenScope: scope,
          useHouseholdAllergens: householdAllergens,
          settingsMerged: true,
        ),
      );
    }

    // Mon lunch and Mon middag share one away set; Tue middag has another.
    WeeklyMenuPlan planWithAway() {
      final base = WeeklyMenuPlan.empty(
        userId: 'u1',
        date: DateTime(2026, 3, 2),
      );
      return base.copyWith(
        awayBySlot: {
          DayOfWeek.mon: {
            MealSlot.lunch: [kid],
            MealSlot.middag: [kid],
          },
          DayOfWeek.tue: {
            MealSlot.middag: [kid2],
          },
        },
      );
    }

    WeeklyMenuPlan withPresence(WeeklyMenuPlan plan) => plan.copyWith(
      presenceBySlot: {
        DayOfWeek.mon: {
          MealSlot.lunch: ['u1', 'u2', kid2],
          MealSlot.middag: ['u1', 'u2', kid2],
        },
        DayOfWeek.tue: {
          MealSlot.middag: ['u1', 'u2', kid],
        },
      },
    );

    Future<MealAllergenScope> resolve({WeeklyMenuPlan? plan}) =>
        MealAllergenScope.resolve(
          userService: users,
          plan: plan ?? withPresence(planWithAway()),
        );

    setUp(() {
      users = _MockUsers();
      useProfile();
      when(() => users.lookupUserProfile('u1')).thenAnswer(
        (_) async => ProfileLookup.found(users.currentUserProfile!),
      );

      final perm = _MockPermission();
      when(() => perm.currentUserId).thenReturn('u1');
      final hhRepo = _MockHouseholdRepo();
      when(() => hhRepo.getActiveForUser('u1')).thenAnswer(
        (_) async => Household(
          id: 'hh1',
          name: Household.defaultName,
          members: const [],
          createdBy: 'u1',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      roster = _MockRoster();
      when(() => roster.tryGetRoster('hh1')).thenAnswer(
        (_) async => [
          HouseholdRosterMember.fromUser(userId: 'u1', displayName: 'Jag'),
          HouseholdRosterMember.fromUser(userId: 'u2', displayName: 'Partner'),
          child(kid, 'sesam'),
          child(kid2, 'fisk'),
        ],
      );
      household = _FakeHousehold(
        everyone: const UserAllergenPreferences(
          trackedAllergens: {'selleri', 'mjölk', 'sesam', 'fisk'},
          trackedDietary: {},
        ),
      );

      TestServiceLocator.registerSingleton<UserService>(users);
      TestServiceLocator.registerSingleton<PermissionService>(perm);
      TestServiceLocator.registerSingleton<HouseholdRepository>(hhRepo);
      TestServiceLocator.registerSingleton<HouseholdRosterService>(roster);
      TestServiceLocator.registerSingleton<HouseholdService>(household);
    });

    group('isOn needs all three of the choice, household allergens and a '
        'household', () {
      test('all three hold', () {
        expect(MealAllergenScope.isOn(users), isTrue);
      });

      test('a stored choice with household allergens off is ignored', () {
        useProfile(householdAllergens: false);
        expect(MealAllergenScope.isOn(users), isFalse);
      });

      test('the choice itself off', () {
        useProfile(scope: false);
        expect(MealAllergenScope.isOn(users), isFalse);
      });

      test('no household', () {
        household.inHousehold = false;
        expect(MealAllergenScope.isOn(users), isFalse);
      });

      test('no household service registered', () {
        TestServiceLocator.unregister<HouseholdService>();
        expect(MealAllergenScope.isOn(users), isFalse);
      });
    });

    test('each distinct away set is resolved once, and meals with different '
        'away sets get different allergens', () async {
      final scope = await resolve();

      expect(household.mealReads, 2);
      expect(
        scope.prefsAt(DayOfWeek.mon, MealSlot.lunch).trackedAllergens,
        {'selleri', 'mjölk', 'fisk'},
      );
      expect(
        scope.prefsAt(DayOfWeek.mon, MealSlot.middag).trackedAllergens,
        {'selleri', 'mjölk', 'fisk'},
      );
      expect(
        scope.prefsAt(DayOfWeek.tue, MealSlot.middag).trackedAllergens,
        {'selleri', 'mjölk', 'sesam'},
      );
      // A meal nobody is away from follows everyone.
      expect(
        scope.prefsAt(DayOfWeek.wed, MealSlot.middag).trackedAllergens,
        {'selleri', 'mjölk', 'sesam', 'fisk'},
      );
    });

    test(
      'a meal whose people cannot be read follows the whole household',
      () async {
        when(() => roster.tryGetRoster('hh1')).thenAnswer((_) async => null);

        final scope = await resolve();

        expect(scope.isScoped, isFalse);
        expect(
          scope.prefsAt(DayOfWeek.mon, MealSlot.lunch),
          same(scope.household),
        );
        expect(
          scope.prefsAt(DayOfWeek.tue, MealSlot.middag),
          same(scope.household),
        );
      },
    );

    test('a read that throws for one meal leaves only that meal on the '
        'household', () async {
      household.mealReadThrowsOnCall = 2;

      final scope = await resolve();

      expect(
        scope.prefsAt(DayOfWeek.mon, MealSlot.lunch).trackedAllergens,
        {'selleri', 'mjölk', 'fisk'},
      );
      expect(
        scope.prefsAt(DayOfWeek.tue, MealSlot.middag),
        same(scope.household),
      );
    });

    test(
      'with the choice off no meal is scoped and nobody is looked up',
      () async {
        useProfile(scope: false);

        final scope = await resolve();

        expect(scope.isScoped, isFalse);
        expect(household.mealReads, 0);
        expect(
          scope.prefsAt(DayOfWeek.mon, MealSlot.lunch),
          same(scope.household),
        );
        expect(scope.household.trackedAllergens, {
          'selleri',
          'mjölk',
          'sesam',
          'fisk',
        });
      },
    );

    test('an unreadable household is the user\'s own allergens with the '
        'common-allergen floor', () async {
      household.wholeReadThrows = true;
      final expected = HouseholdService.widenWithSafetyFloor(
        const UserAllergenPreferences(
          trackedAllergens: {'selleri'},
          trackedDietary: {},
        ),
      );

      final scope = await resolve();

      expect(scope.household.trackedAllergens, expected.trackedAllergens);
      expect(scope.household.trackedAllergens, contains('selleri'));
      expect(scope.household.includeUnknownInMenu, isFalse);
    });
  });
}
