/// BUT-2362: the calendar marks a dish someone eating that meal cannot eat,
/// whether or not the per-meal allergen choice is on.
///
/// Drives the real [WeeklyMenuPlanViewModel] (so the scope really resolves
/// asynchronously) under a [DayCell], with a mocked plan service.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/menu/meal_allergen_scope.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/menu/calendar/calendar_cells.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

class _MockService extends Mock implements WeeklyMenuPlanService {
  @override
  Stream<String?> get weekWrites => const Stream.empty();
}

class _MockRecipes extends Mock implements UnifiedRecipeService {}

class _MockShopping extends Mock implements MenuShoppingListGenerator {}

class _FakePlan extends Fake implements WeeklyMenuPlan {}

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

const _tracksNuts = UserAllergenPreferences(
  trackedAllergens: {'nötter'},
  trackedDietary: {},
);

final _monday = DateTime(2026, 4, 13);
final _nutDish = _dish('nutdish', nuts: TriState.contains);
final _freeDish = _dish('freedish', nuts: TriState.free);

WeeklyMenuPlanEntry _entry(
  MealSlot slot,
  Recipe recipe, {
  DayOfWeek day = DayOfWeek.mon,
}) => WeeklyMenuPlanEntry.create(
  day: day,
  slot: slot,
  recipeId: recipe.id,
  recipeTitle: recipe.id,
);

HouseholdRosterMember _member(String id) =>
    HouseholdRosterMember.fromUser(userId: id, displayName: 'Person $id');

void main() {
  final sv = AppLocalizationsSv();
  const warning = ValueKey('menu-allergen-warning');

  late _MockService service;
  late _MockRecipes recipes;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(_FakePlan());
  });

  setUp(() {
    service = _MockService();
    recipes = _MockRecipes();
    when(() => recipes.stateStream).thenAnswer((_) => const Stream.empty());
    when(() => service.overflowTrayOwnerId).thenReturn(null);
    when(() => recipes.getRecipeById('nutdish')).thenReturn(_nutDish);
    when(() => recipes.getRecipeById('freedish')).thenReturn(_freeDish);
  });

  /// Loads [entries] into a real view model whose scope is the household
  /// avoiding nuts, with the per-meal choice off, and pumps the Monday cell.
  Future<List<(DayOfWeek, MealSlot)>> pumpMonday(
    WidgetTester tester,
    List<WeeklyMenuPlanEntry> entries, {
    List<HouseholdRosterMember>? roster,
  }) async {
    final plan = WeeklyMenuPlan(
      id: 'u1_2026-W16',
      userId: 'u1',
      weekStartDate: _monday,
      entries: entries,
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
    );
    when(() => service.readWeek(any())).thenAnswer(
      (_) async => WeeklyMenuPlanRead(plan: plan, readFailed: false),
    );
    final vm = WeeklyMenuPlanViewModel(
      service: service,
      recipeService: recipes,
      shoppingListGenerator: _MockShopping(),
      allergenScope: (_) async => MealAllergenScope(household: _tracksNuts),
      allergenScopeOn: () => false,
    );
    addTearDown(vm.dispose);
    await vm.loadWeek(_monday);

    final presenceTaps = <(DayOfWeek, MealSlot)>[];
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScrollView: true,
        child: ListenableBuilder(
          listenable: vm,
          builder: (_, _) => DayCell(
            vm: vm,
            plan: vm.plan!,
            day: DayOfWeek.mon,
            isToday: false,
            onTapEmptySlot: (_, _) {},
            onTapRecipe: (_, {presentServings}) {},
            roster: roster ?? [_member('a'), _member('b')],
            onTapPresence: (day, slot) => presenceTaps.add((day, slot)),
          ),
        ),
      ),
    );
    // The scope resolves after the week is shown.
    await tester.pump();
    return presenceTaps;
  }

  testWidgets(
    'a dish the household cannot eat is marked and announced, with the '
    'per-meal choice off',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpMonday(tester, [_entry(MealSlot.lunch, _nutDish)]);

      expect(find.byKey(warning), findsOneWidget);
      expect(
        find.bySemanticsLabel(sv.menuAllergenUnsafeAtMeal),
        findsOneWidget,
      );
      handle.dispose();
    },
  );

  testWidgets('a dish free of the allergen is not marked', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpMonday(tester, [
      _entry(MealSlot.lunch, _freeDish),
      _entry(MealSlot.middag, _freeDish),
    ]);

    // Positive control: both dishes rendered, so the absence is a verdict.
    expect(find.text('freedish'), findsNWidgets(2));
    expect(find.byKey(warning), findsNothing);
    expect(find.bySemanticsLabel(sv.menuAllergenUnsafeAtMeal), findsNothing);
    handle.dispose();
  });

  testWidgets('only the unsafe meal of the day is marked', (tester) async {
    await pumpMonday(tester, [
      _entry(MealSlot.lunch, _freeDish),
      _entry(MealSlot.middag, _nutDish),
    ]);

    expect(find.byKey(warning), findsOneWidget);
    final mark = tester.getCenter(find.byKey(warning));
    // The mark sits in the middag cell, not the lunch one.
    expect(
      (mark - tester.getCenter(find.text('nutdish'))).distance,
      lessThan((mark - tester.getCenter(find.text('freedish'))).distance),
    );
  });

  testWidgets('an unsafe övrigt entry is marked too', (tester) async {
    await pumpMonday(tester, [_entry(MealSlot.ovrigt, _nutDish)]);

    expect(find.byKey(warning), findsOneWidget);
  });

  testWidgets('tapping the warning with a roster opens who is home for that '
      'meal', (tester) async {
    final taps = await pumpMonday(tester, [_entry(MealSlot.middag, _nutDish)]);

    await tester.tap(find.byKey(warning));
    await tester.pump();

    expect(taps, [(DayOfWeek.mon, MealSlot.middag)]);
  });

  testWidgets('a solo account sees the warning but it opens nothing', (
    tester,
  ) async {
    final taps = await pumpMonday(
      tester,
      [
        _entry(MealSlot.middag, _nutDish),
      ],
      roster: [_member('a')],
    );

    expect(find.byKey(warning), findsOneWidget);
    await tester.tap(find.byKey(warning), warnIfMissed: false);
    await tester.pump();

    expect(taps, isEmpty);
  });
}
