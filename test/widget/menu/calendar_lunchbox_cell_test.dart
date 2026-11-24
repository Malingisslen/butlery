/// BUT-2486 del 3: a lunch that is a lunchbox is drawn in the week table as
/// the box's dish, marked "Matlåda", checked against the allergens of the
/// people taking it, and "ej bedömd" when its dish cannot be checked.
///
/// Drives the real [WeeklyMenuPlanViewModel] with a mocked plan service, so
/// the allergen answer really arrives after the week is shown.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/menu/lunchbox_plan.dart';
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
import 'package:butlery/widgets/menu/calendar/calendar_drag.dart';
import 'package:butlery/widgets/menu/calendar/calendar_markers.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

class _MockService extends Mock implements WeeklyMenuPlanService {
  @override
  Stream<String?> get weekWrites => const Stream.empty();

  @override
  Stream<LateWeekConflict> get lateConflicts => const Stream.empty();
}

class _MockRecipes extends Mock implements UnifiedRecipeService {}

class _MockShopping extends Mock implements MenuShoppingListGenerator {}

class _FakePlan extends Fake implements WeeklyMenuPlan {}

Recipe _dish(String id, TriState nuts) {
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

const _nuts = UserAllergenPreferences(
  trackedAllergens: {'nötter'},
  trackedDietary: {},
);

final _monday = DateTime(2026, 4, 13);

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
    when(() => recipes.getRecipeById(any())).thenReturn(null);
    when(
      () => recipes.getRecipeById('nutdish'),
    ).thenReturn(_dish('nutdish', TriState.contains));
    when(
      () => recipes.getRecipeById('freedish'),
    ).thenReturn(_dish('freedish', TriState.free));
  });

  /// Loads a week whose Tuesday lunch is [box] and whose Monday middag is
  /// the free dish, where the box's takers avoid nuts and the household does
  /// not, and pumps the table. Returns the days whose box was tapped.
  Future<List<DayOfWeek>> pumpWeek(
    WidgetTester tester,
    Lunchbox box, {
    double? width,
  }) async {
    if (width != null) {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final plan = WeeklyMenuPlan(
      id: 'u1_2026-W16',
      userId: 'u1',
      weekStartDate: _monday,
      entries: [
        WeeklyMenuPlanEntry.create(
          day: DayOfWeek.mon,
          slot: MealSlot.middag,
          recipeId: 'freedish',
          recipeTitle: 'freedish',
        ),
      ],
      lunchboxes: {DayOfWeek.tue: box},
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
      allergenScope: (_) async => MealAllergenScope(
        household: UserAllergenPreferences.none,
        byLunchbox: {
          DayOfWeek.tue: const LunchboxTakerPrefs(_nuts, alone: true),
        },
      ),
      allergenScopeOn: () => true,
    );
    addTearDown(vm.dispose);
    await vm.loadWeek(_monday);

    final taps = <DayOfWeek>[];
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScrollView: true,
        child: ListenableBuilder(
          listenable: vm,
          builder: (_, _) => CalendarWeekTable(
            vm: vm,
            plan: vm.plan!,
            todayIndex: -1,
            onTapEmptySlot: (_, _) {},
            onTapRecipe: (_, {presentServings}) {},
            onTapOvrigt: (_) {},
            onTapLunchbox: taps.add,
            roster: [_member('a'), _member('b')],
            onTapPresence: (_, _) =>
                fail('a lunchbox tap must not open who is home'),
          ),
        ),
      ),
    );
    await tester.pump();
    return taps;
  }

  testWidgets('a box is drawn as its dish with the lunchbox mark, and a tap '
      'opens the box, not who is home', (tester) async {
    final handle = tester.ensureSemantics();
    final taps = await pumpWeek(
      tester,
      const Lunchbox(
        source: LunchboxSource.leftovers,
        fromDay: DayOfWeek.mon,
        takerIds: ['a'],
      ),
    );

    // The Monday middag and the Tuesday box that follows it.
    expect(find.text('freedish'), findsNWidgets(2));
    expect(find.byKey(CalendarLunchboxMark.markKey), findsOneWidget);
    expect(find.byKey(warning), findsNothing);
    expect(find.byKey(CalendarUnjudgedMark.markKey), findsNothing);

    await tester.tap(
      find.bySemanticsLabel(
        RegExp(sv.a11yLunchboxOpen(DayOfWeek.tue.displayLabel)),
      ),
    );
    expect(taps, [DayOfWeek.tue]);
    handle.dispose();
  });

  testWidgets('a lunchbox cell accepts no dropped dish, unlike a dish cell '
      'beside it', (tester) async {
    await pumpWeek(
      tester,
      const Lunchbox(source: LunchboxSource.leftovers, fromDay: DayOfWeek.mon),
    );
    final dropTarget = find.byType(DragTarget<CalendarDragPayload>);

    expect(
      find.ancestor(
        of: find.byKey(CalendarLunchboxMark.markKey),
        matching: dropTarget,
      ),
      findsNothing,
    );
    // Control: the Monday middag cell is a drop target, so the finder can
    // see one.
    expect(
      find.ancestor(of: find.text('freedish').first, matching: dropTarget),
      findsOneWidget,
    );
  });

  testWidgets('a dish the box\'s takers cannot eat is marked, and the legend '
      'names the mark', (tester) async {
    await pumpWeek(
      tester,
      const Lunchbox(
        source: LunchboxSource.prepDay,
        recipeId: 'nutdish',
        recipeTitle: 'nutdish',
        takerIds: ['a'],
      ),
    );

    expect(find.text('nutdish'), findsOneWidget);
    expect(find.byKey(warning), findsOneWidget);
    expect(find.text(sv.weeklyMenuLegendAllergen), findsOneWidget);
    expect(find.text(sv.lunchboxMark), findsOneWidget);
  });

  testWidgets('a box whose dish cannot be found is "ej bedömd", never shown '
      'as safe', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpWeek(
      tester,
      const Lunchbox(
        source: LunchboxSource.leftovers,
        fromDay: DayOfWeek.sun,
        takerIds: ['a'],
      ),
    );

    expect(find.text(sv.lunchboxNoDish), findsOneWidget);
    expect(find.byKey(CalendarUnjudgedMark.markKey), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(sv.lunchboxUnjudgedMark)),
      findsWidgets,
    );
    handle.dispose();
  });

  testWidgets('at 320 dp the box, its marks and a long name fit without '
      'overflow', (tester) async {
    when(() => recipes.getRecipeById('long')).thenReturn(
      _dish(
        'Krämig svamppasta med grön ärtsås och rostade nötter',
        TriState.contains,
      ),
    );
    await pumpWeek(
      tester,
      const Lunchbox(
        source: LunchboxSource.suggestion,
        recipeId: 'long',
        takerIds: ['a'],
      ),
      width: 320,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(warning), findsOneWidget);
    expect(find.byKey(CalendarLunchboxMark.markKey), findsOneWidget);
  });
}
