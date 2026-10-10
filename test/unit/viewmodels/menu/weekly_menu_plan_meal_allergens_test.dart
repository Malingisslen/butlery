/// BUT-2362: how [WeeklyMenuPlanViewModel] hands the per-meal allergen scope
/// to placement, and which dishes it says some meal can still take.
///
/// Placement runs through the real [WeeklyMenuPlanService] so the test reads
/// where a dish actually lands; only the repository is faked.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/menu/meal_allergen_scope.dart';
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

_MockRecipes _quietRecipes() {
  final recipes = _MockRecipes();
  when(() => recipes.stateStream).thenAnswer((_) => const Stream.empty());
  return recipes;
}

UserProfile _profile(String uid) => UserProfile(
  uid: uid,
  displayName: 'Test',
  email: 't@example.com',
  joinedAt: DateTime(2026, 1, 1),
  lastActiveAt: DateTime(2026, 1, 1),
);

Recipe _dish(String id, {required TriState nuts}) {
  final base = RecipeFactory.build(id: id, title: id, mealType: 'middag');
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

const _tracksNuts = UserAllergenPreferences(
  trackedAllergens: {'nötter'},
  trackedDietary: {},
);

void main() {
  // Monday of week 15, 2026: not the current week, so placement starts on
  // Monday whatever day the suite runs.
  final mon = DateTime(2026, 4, 6);
  final nutDish = _dish('nutdish', nuts: TriState.contains);
  final soup = _dish('soup', nuts: TriState.free);

  late _MockRepo repo;
  late WeeklyMenuPlanService service;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    registerFallbackValue(_FakeWeeklyMenuPlan());
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
    repo = _MockRepo();
    final userService = _MockUserService();
    when(() => userService.currentUserProfile).thenReturn(_profile('u'));
    when(() => repo.save(any())).thenAnswer((_) async {});
    when(
      () => repo.fetchForWeek(
        userId: any(named: 'userId'),
        weekStart: any(named: 'weekStart'),
      ),
    ).thenAnswer((_) async => null);
    (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
        .setAuthState(userId: 'u');
    service = WeeklyMenuPlanService(repository: repo, userService: userService);
  });

  tearDown(() => service.onDispose());

  // The kid who reacts to nuts is away at Thursday middag only.
  Future<MealAllergenScope> thursdayScope(WeeklyMenuPlan _) async =>
      MealAllergenScope(
        household: _tracksNuts,
        byMeal: {
          (DayOfWeek.thu, MealSlot.middag): UserAllergenPreferences.none,
        },
      );

  WeeklyMenuPlanViewModel viewModel({required bool scopeOn}) {
    final vm = WeeklyMenuPlanViewModel(
      service: service,
      recipeService: _quietRecipes(),
      shoppingListGenerator: _MockShopping(),
      readDislikes: () async => const {},
      allergenScope: thursdayScope,
      allergenScopeOn: () => scopeOn,
    );
    addTearDown(vm.dispose);
    return vm;
  }

  Future<Map<String, DayOfWeek>> place(
    WeeklyMenuPlanViewModel vm,
    List<Recipe> dishes,
  ) async {
    await vm.loadWeek(mon);
    await vm.applyGeneratedMenu({'middag': dishes}, now: mon);
    return {for (final e in vm.plan!.entries) e.recipeId: e.day};
  }

  group('applyGeneratedMenu', () {
    test('with the per-meal choice on, a nut dish goes only where the '
        'person who cannot eat it is away', () async {
      final placed = await place(viewModel(scopeOn: true), [nutDish, soup]);

      expect(placed['nutdish'], DayOfWeek.thu);
      // Control: the dish the guard does not touch still takes the first day.
      expect(placed['soup'], DayOfWeek.mon);
    });

    test('with the choice off, placement ignores the scope', () async {
      final placed = await place(viewModel(scopeOn: false), [nutDish, soup]);

      expect(placed['nutdish'], DayOfWeek.mon);
      expect(placed['soup'], DayOfWeek.tue);
    });
  });

  group('placeOverflowInNextWeek', () {
    final nextMon = mon.add(const Duration(days: 7));
    final otherNutDish = _dish('nutdish2', nuts: TriState.contains);

    // The first nut dish takes this week's only safe place (Thursday), so the
    // second one ends up in the tray.
    Future<WeeklyMenuPlanViewModel> withNutDishInTray() async {
      final vm = viewModel(scopeOn: true);
      await vm.loadWeek(mon);
      await vm.applyGeneratedMenu({
        'middag': [nutDish, otherNutDish],
      }, now: mon);
      expect(
        vm.overflow.map((r) => r.id),
        ['nutdish2'],
        reason: 'premise: the second nut dish has no safe day left',
      );
      return vm;
    }

    WeeklyMenuPlan lastSaved() =>
        verify(() => repo.save(captureAny())).captured.last as WeeklyMenuPlan;

    test('with the choice on, a tray nut dish lands only where the person '
        'who cannot eat it is away', () async {
      final vm = await withNutDishInTray();

      final moved = await vm.placeOverflowInNextWeek(now: mon);

      expect(moved, 1);
      final entry = lastSaved().entries.single;
      expect(entry.recipeId, 'nutdish2');
      expect(entry.day, DayOfWeek.thu);
      expect(vm.overflow, isEmpty);
    });

    test('when no day of that week allows it, it stays in the tray and the '
        'tray says allergens are why', () async {
      when(
        () => repo.fetchForWeek(
          userId: any(named: 'userId'),
          weekStart: nextMon,
        ),
      ).thenAnswer(
        (_) async => WeeklyMenuPlan.empty(userId: 'u', date: nextMon).copyWith(
          entries: [
            const WeeklyMenuPlanEntry(
              id: 'taken',
              day: DayOfWeek.thu,
              slot: MealSlot.middag,
              recipeId: 'soup',
              recipeTitle: 'soup',
            ),
          ],
        ),
      );
      final vm = await withNutDishInTray();

      final moved = await vm.placeOverflowInNextWeek(now: mon);

      expect(moved, 0);
      expect(vm.overflow.map((r) => r.id), ['nutdish2']);
      expect(vm.overflowReason!.allergenBlocked, isTrue);
    });
  });

  group('mealScopedRecipeIds', () {
    test('names a removed dish some meal of the week can take', () async {
      final vm = viewModel(scopeOn: true);
      await vm.loadWeek(mon);

      expect(await vm.mealScopedRecipeIds([nutDish]), {'nutdish'});
    });

    test('is empty while the per-meal choice is off', () async {
      final vm = viewModel(scopeOn: false);
      await vm.loadWeek(mon);

      expect(await vm.mealScopedRecipeIds([nutDish]), isEmpty);
    });

    test(
      'is empty when no meal follows fewer people than the household',
      () async {
        final vm = WeeklyMenuPlanViewModel(
          service: service,
          recipeService: _quietRecipes(),
          shoppingListGenerator: _MockShopping(),
          readDislikes: () async => const {},
          allergenScope: (_) async => MealAllergenScope(household: _tracksNuts),
          allergenScopeOn: () => true,
        );
        addTearDown(vm.dispose);
        await vm.loadWeek(mon);

        expect(await vm.mealScopedRecipeIds([nutDish]), isEmpty);
      },
    );
  });

  group('when the scope read goes wrong', () {
    test('who is home changing during the read is judged on the new '
        'selection', () async {
      // The calendar marks read the same scope, so only the read the apply
      // starts is held back.
      Completer<MealAllergenScope>? held;
      final vm = WeeklyMenuPlanViewModel(
        service: service,
        recipeService: _quietRecipes(),
        shoppingListGenerator: _MockShopping(),
        readDislikes: () async => const {},
        allergenScope: (plan) {
          final read = held;
          if (read != null && !read.isCompleted) return read.future;
          return thursdayScope(plan);
        },
        allergenScopeOn: () => true,
      );
      addTearDown(vm.dispose);
      await vm.loadWeek(mon);

      held = Completer<MealAllergenScope>();
      final applying = vm.applyGeneratedMenu({
        'middag': [nutDish],
      }, now: mon);
      await pumpEventQueue();
      final heldRead = held;
      held = null;
      await vm.setSlotPresence(
        DayOfWeek.thu,
        MealSlot.middag,
        ['mom'],
        away: ['kid'],
      );
      // The held read answers for the selection before the change: nobody
      // away, so nuts fit no meal.
      heldRead.complete(MealAllergenScope(household: _tracksNuts));
      await applying;

      expect(vm.plan!.entries.single.day, DayOfWeek.thu);
    });

    test('a read that throws places nothing, and the next apply still '
        'runs', () async {
      var failing = true;
      final vm = WeeklyMenuPlanViewModel(
        service: service,
        recipeService: _quietRecipes(),
        shoppingListGenerator: _MockShopping(),
        readDislikes: () async => const {},
        allergenScope: (plan) async {
          if (failing) throw StateError('offline');
          return thursdayScope(plan);
        },
        allergenScopeOn: () => true,
      );
      addTearDown(vm.dispose);
      await vm.loadWeek(mon);

      final refused = await vm.applyGeneratedMenu({
        'middag': [nutDish],
      }, now: mon);
      expect(refused, isNull);
      expect(vm.plan?.entries ?? const [], isEmpty);

      failing = false;
      final placed = await vm.applyGeneratedMenu({
        'middag': [nutDish],
      }, now: mon);
      expect(placed, 1);
      expect(vm.plan!.entries.single.day, DayOfWeek.thu);
    });
  });

  test('a dish whose recipe loads after the week is marked once the recipe '
      'list arrives', () async {
    final recipes = _MockRecipes();
    final recipeList = StreamController<RecipeServiceState>.broadcast();
    addTearDown(recipeList.close);
    Recipe? loaded;
    when(() => recipes.stateStream).thenAnswer((_) => recipeList.stream);
    when(() => recipes.getRecipeById(any())).thenAnswer((_) => loaded);
    final vm = WeeklyMenuPlanViewModel(
      service: service,
      recipeService: recipes,
      shoppingListGenerator: _MockShopping(),
      readDislikes: () async => const {},
      allergenScope: (_) async => MealAllergenScope(household: _tracksNuts),
      allergenScopeOn: () => false,
    );
    addTearDown(vm.dispose);
    await vm.loadWeek(mon);
    await vm.applyGeneratedMenu({
      'middag': [nutDish],
    }, now: mon);
    await pumpEventQueue();
    final entryId = vm.plan!.entries.single.id;
    expect(vm.isAllergenUnsafe(entryId), isFalse);

    loaded = nutDish;
    recipeList.add(RecipeStateData(recipes: [nutDish]));
    await pumpEventQueue();

    expect(vm.isAllergenUnsafe(entryId), isTrue);
  });
}
