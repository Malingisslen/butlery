/// BUT-2522: the preview of a week template and putting it on a week.
///
/// The calendar and the week service are the real ones over a faked
/// repository, so a test reads what was actually saved and what the calendar
/// shows afterwards.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/week_template_entry.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/week_template_apply.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/menu/meal_allergen_scope.dart';
import 'package:butlery/viewmodels/menu/week_template_viewmodel.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockRepo extends Mock implements WeeklyMenuPlanRepository {}

class _MockUserService extends Mock implements UserService {}

class _MockRecipes extends Mock implements UnifiedRecipeService {}

class _MockShopping extends Mock implements MenuShoppingListGenerator {}

class _FakeWeeklyMenuPlan extends Fake implements WeeklyMenuPlan {}

UserProfile _profile(String uid) => UserProfile(
  uid: uid,
  displayName: 'Test',
  email: 't@example.com',
  joinedAt: DateTime(2026, 1, 1),
  lastActiveAt: DateTime(2026, 1, 1),
);

Recipe _recipe(String id, {required TriState gluten}) {
  final base = RecipeFactory.build(id: id, title: 'Nu $id', mealType: 'middag');
  return Recipe(
    core: base.core.copyWith(
      tagResult: TagResult(
        tags: const {},
        allergenStatus: {'gluten': gluten},
        dietaryStatus: const {},
        coverage: 1.0,
        generatedAt: DateTime(2026),
        generatorVersion: kTagGeneratorVersion,
      ),
    ),
    type: base.type,
  );
}

WeekTemplateEntry _entry(DayOfWeek day, String id) => WeekTemplateEntry(
  day: day,
  slot: MealSlot.middag,
  recipeId: id,
  recipeTitle: 'Sparat $id',
);

const _tracksGluten = UserAllergenPreferences(
  trackedAllergens: {'gluten'},
  trackedDietary: {},
);

void main() {
  final mon = DateTime(2026, 4, 6);
  final pizza = _recipe('pizza', gluten: TriState.contains);
  final soup = _recipe('soup', gluten: TriState.free);

  late _MockRepo repo;
  late _MockRecipes recipes;
  late WeeklyMenuPlanService service;
  WeeklyMenuPlan? stored;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    registerFallbackValue(_FakeWeeklyMenuPlan());
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
    stored = null;
    repo = _MockRepo();
    final userService = _MockUserService();
    when(() => userService.currentUserProfile).thenReturn(_profile('u'));
    when(() => repo.save(any())).thenAnswer((inv) async {
      stored = inv.positionalArguments.first as WeeklyMenuPlan;
    });
    when(
      () => repo.fetchForWeek(
        userId: any(named: 'userId'),
        weekStart: any(named: 'weekStart'),
      ),
    ).thenAnswer((_) async => stored);
    (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
        .setAuthState(userId: 'u');
    service = WeeklyMenuPlanService(repository: repo, userService: userService);

    recipes = _MockRecipes();
    when(() => recipes.stateStream).thenAnswer((_) => const Stream.empty());
    when(() => recipes.getRecipeById(any())).thenReturn(null);
    when(() => recipes.getRecipeById('pizza')).thenReturn(pizza);
    when(() => recipes.getRecipeById('soup')).thenReturn(soup);
    when(
      () => recipes.fetchFriendRecipe(
        ownerId: any(named: 'ownerId'),
        recipeId: any(named: 'recipeId'),
      ),
    ).thenAnswer((_) async => null);
  });

  tearDown(() => service.onDispose());

  (WeeklyMenuPlanViewModel, WeekTemplateViewModel) build({
    MealAllergenScope? scope,
  }) {
    final calendar = WeeklyMenuPlanViewModel(
      service: service,
      recipeService: recipes,
      shoppingListGenerator: _MockShopping(),
      readDislikes: () async => const {},
    );
    final vm = WeekTemplateViewModel(
      calendar: calendar,
      weekService: service,
      recipes: recipes,
      currentUserId: () => 'u',
      allergenScope: (_) async =>
          scope ?? MealAllergenScope(household: _tracksGluten),
      readDislikes: () async => const {},
    );
    addTearDown(vm.dispose);
    addTearDown(calendar.dispose);
    return (calendar, vm);
  }

  group('preview', () {
    test('a dish the household cannot eat is flagged with its allergen, and '
        'a safe one is not', () async {
      final (_, vm) = build();

      await vm.preview([
        _entry(DayOfWeek.mon, 'pizza'),
        _entry(DayOfWeek.tue, 'soup'),
      ], mon);

      final byId = {for (final r in vm.rows) r.dish.entry.recipeId: r};
      expect(byId['pizza']!.finding!.containsAllergens, ['gluten']);
      expect(byId['soup']!.finding!.containsAllergens, isEmpty);
      expect(byId['soup']!.isUnchecked, isFalse);
    });

    test('each dish is checked against the people eating that meal', () async {
      const tracksNothing = UserAllergenPreferences(
        trackedAllergens: {},
        trackedDietary: {},
      );
      final (_, vm) = build(
        scope: MealAllergenScope(
          household: tracksNothing,
          byMeal: {(DayOfWeek.mon, MealSlot.middag): _tracksGluten},
        ),
      );

      await vm.preview([
        _entry(DayOfWeek.mon, 'pizza'),
        _entry(DayOfWeek.tue, 'pizza'),
      ], mon);

      final byDay = {for (final r in vm.rows) r.dish.entry.day: r.finding!};
      expect(byDay[DayOfWeek.mon]!.containsAllergens, ['gluten']);
      expect(byDay[DayOfWeek.tue]!.containsAllergens, isEmpty);
    });

    test(
      'a known recipe whose allergen is unknown is unchecked, never fine',
      () async {
        when(
          () => recipes.getRecipeById('pasta'),
        ).thenReturn(_recipe('pasta', gluten: TriState.unknown));
        final (_, vm) = build();

        await vm.preview([_entry(DayOfWeek.mon, 'pasta')], mon);

        final row = vm.rows.single;
        expect(row.finding!.uncheckedAllergens, ['gluten']);
        expect(row.finding!.containsAllergens, isEmpty);
        expect(row.isUnchecked, isTrue);
      },
    );

    test('a recipe whose read finds nothing is missing', () async {
      final (_, vm) = build();

      await vm.preview([_entry(DayOfWeek.wed, 'gone')], mon);

      final row = vm.rows.single;
      expect(row.isMissing, isTrue);
      verify(
        () => recipes.fetchFriendRecipe(ownerId: 'u', recipeId: 'gone'),
      ).called(1);
    });

    test('a recipe whose read fails is unchecked, never fine, and is still '
        'placed under its saved name', () async {
      when(
        () => recipes.fetchFriendRecipe(
          ownerId: any(named: 'ownerId'),
          recipeId: 'offline',
        ),
      ).thenThrow(Exception('unavailable'));
      final (calendar, vm) = build();

      await vm.preview([_entry(DayOfWeek.thu, 'offline')], mon);
      final row = vm.rows.single;
      expect(row.isMissing, isFalse);
      expect(row.isUnchecked, isTrue);
      expect(row.finding, isNull);

      await vm.apply(WeekTemplateApplyMode.fillEmpty);
      expect(calendar.plan!.entries.single.recipeTitle, 'Sparat offline');
    });

    test('a week that cannot be read fails the preview and nothing can be '
        'applied', () async {
      when(
        () => repo.fetchForWeek(
          userId: any(named: 'userId'),
          weekStart: any(named: 'weekStart'),
        ),
      ).thenThrow(Exception('offline'));
      final (_, vm) = build();

      await vm.preview([_entry(DayOfWeek.mon, 'soup')], mon);

      expect(vm.previewFailed, isTrue);
      expect(await vm.apply(WeekTemplateApplyMode.fillEmpty), isNull);
      verifyNever(() => repo.save(any()));
    });
  });

  group('apply and undo', () {
    test('applies to the shown week, the calendar shows it without another '
        'read, and undo takes it back', () async {
      final (calendar, vm) = build();
      await vm.preview([
        _entry(DayOfWeek.mon, 'soup'),
        _entry(DayOfWeek.tue, 'gone'),
      ], mon);
      expect(vm.needsChoice, isFalse);

      final result = await vm.apply(WeekTemplateApplyMode.fillEmpty);

      expect(result!.addedEntryIds, hasLength(1));
      expect(result.missingCount, 1);
      expect(stored!.entries.map((e) => e.recipeId), ['soup']);
      expect(calendar.plan!.entries.map((e) => e.recipeTitle), ['Nu soup']);
      verify(
        () => repo.fetchForWeek(
          userId: any(named: 'userId'),
          weekStart: any(named: 'weekStart'),
        ),
      ).called(1);

      expect(await vm.undo(result), isTrue);
      expect(stored!.entries, isEmpty);
      expect(calendar.plan!.entries, isEmpty);
    });

    test('a week with a dish where the template has one asks first, and '
        'replace overwrites only that place', () async {
      final (calendar, vm) = build();
      await calendar.loadWeek(mon);
      await calendar.assignRecipe(
        day: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipe: pizza,
      );
      await calendar.assignRecipe(
        day: DayOfWeek.wed,
        slot: MealSlot.middag,
        recipe: pizza,
      );

      await vm.preview([_entry(DayOfWeek.mon, 'soup')], mon);
      expect(vm.needsChoice, isTrue);

      await vm.apply(WeekTemplateApplyMode.replace);

      final byDay = {for (final e in stored!.entries) e.day: e.recipeId};
      expect(byDay, {DayOfWeek.mon: 'soup', DayOfWeek.wed: 'pizza'});
    });
  });
}
