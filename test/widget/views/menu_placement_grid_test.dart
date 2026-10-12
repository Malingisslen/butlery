/// The placement mode's week (approved picture 78-menu-placement): a free
/// place is a dashed frame with a plus, tapping one while a dish is chosen
/// places it, and a placed dish is a bordered cell carrying the NY mark.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/menu/menu_placement_viewmodel.dart';
import 'package:butlery/views/menu_placement/placement_widgets.dart';
import 'package:butlery/views/menu_placement_view.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

class _MockService extends Mock implements WeeklyMenuPlanService {}

class _MockRepo extends Mock implements WeeklyMenuPlanRepository {}

class _MockUserService extends Mock implements UserService {}

class _FakePlan extends Fake implements WeeklyMenuPlan {}

final _weekStart = DateTime(2026, 4, 6);

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(_FakePlan());
    registerFallbackValue(RecipeFactory.build(id: 'fallback'));
    registerFallbackValue(DayOfWeek.mon);
    registerFallbackValue(MealSlot.middag);
  });

  late MenuPlacementViewModel vm;

  Future<void> buildVm(List<WeeklyMenuPlanEntry> entries) async {
    final service = _MockService();
    final user = _MockUserService();
    when(() => user.currentUserProfile).thenReturn(null);
    final real = WeeklyMenuPlanService(
      repository: _MockRepo(),
      userService: user,
    );
    final now = DateTime(2026, 4, 1, 12);
    final plan = WeeklyMenuPlan(
      id: IsoWeekUtils.weekIdFor('u-1', _weekStart),
      userId: 'u-1',
      weekStartDate: _weekStart,
      entries: entries,
      createdAt: now,
      updatedAt: now,
    );
    when(() => service.readWeek(any())).thenAnswer(
      (_) async => WeeklyMenuPlanRead(plan: plan, readFailed: false),
    );
    when(
      () => service.addEntry(
        plan: any(named: 'plan'),
        day: any(named: 'day'),
        slot: any(named: 'slot'),
        recipe: any(named: 'recipe'),
      ),
    ).thenAnswer(
      (inv) => real.addEntry(
        plan: inv.namedArguments[#plan] as WeeklyMenuPlan,
        day: inv.namedArguments[#day] as DayOfWeek,
        slot: inv.namedArguments[#slot] as MealSlot,
        recipe: inv.namedArguments[#recipe] as Recipe,
      ),
    );
    when(
      () => service.removeEntry(
        plan: any(named: 'plan'),
        entryId: any(named: 'entryId'),
      ),
    ).thenAnswer(
      (inv) => real.removeEntry(
        plan: inv.namedArguments[#plan] as WeeklyMenuPlan,
        entryId: inv.namedArguments[#entryId] as String,
      ),
    );
    vm = MenuPlacementViewModel(
      service: service,
      generated: {
        'middag': [
          RecipeFactory.build(
            id: 'm1',
            title: 'Tacos med svartbönor',
            mealType: 'middag',
          ),
        ],
      },
      weekStart: _weekStart,
    );
    addTearDown(vm.dispose);
    await vm.init();
  }

  setUp(() => buildVm(const []));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScrollView: true,
        child: ListenableBuilder(
          listenable: vm,
          builder: (_, _) => PlacementGrid(vm: vm),
        ),
      ),
    );
  }

  Finder plus() => find.byWidgetPredicate(
    (w) => w is ButleryIcon && w.icon == ButleryIcons.plus,
  );

  testWidgets('every place is free and shows a plus, the days are dated', (
    tester,
  ) async {
    await pump(tester);
    expect(plus(), findsNWidgets(21));
    expect(find.text('MÅN'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('only the places the chosen dish fits are tappable', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    // The chosen dish is a dinner: seven middag places answer to a tap.
    expect(find.bySemanticsLabel(RegExp('^Placera på')), findsNWidgets(7));
    handle.dispose();
  });

  testWidgets('tapping a free place places the chosen dish there', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) => w is InkWell && w.onTap != null,
          )
          .first,
    );
    await tester.pump();

    expect(find.text('Tacos med svartbönor'), findsOneWidget);
    expect(plus(), findsNWidgets(20));
    expect(vm.placedCount, 1);
  });

  testWidgets('tapping a dish placed in this session takes it back', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(
      find.byWidgetPredicate((w) => w is InkWell && w.onTap != null).first,
    );
    await tester.pump();
    expect(vm.placedCount, 1);

    await tester.tap(find.text('Tacos med svartbönor'));
    await tester.pump();

    expect(vm.placedCount, 0);
    expect(plus(), findsNWidgets(21));
    expect(vm.selectedIndex, 0);
  });

  testWidgets('a dish that was already in the plan is not tappable', (
    tester,
  ) async {
    await buildVm([
      WeeklyMenuPlanEntry.create(
        day: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipeId: 'old',
        recipeTitle: 'Gammal gryta',
      ),
    ]);
    await pump(tester);
    // Premise: the earlier dish is drawn, one place short of 21 free ones.
    expect(find.text('Gammal gryta'), findsOneWidget);
    expect(plus(), findsNWidgets(20));

    await tester.tap(find.text('Gammal gryta'));
    await tester.pump();

    expect(find.text('Gammal gryta'), findsOneWidget);
    expect(plus(), findsNWidgets(20));
    expect(vm.placedCount, 0);
  });

  testWidgets('tapping a tray card selects it and tapping again lets go', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ListenableBuilder(
          listenable: vm,
          builder: (_, _) =>
              PlacementTray(vm: vm, onAutoRest: () {}, onConfirm: () {}),
        ),
      ),
    );
    expect(vm.selectedIndex, 0);

    await tester.tap(find.text('Tacos med svartbönor'));
    await tester.pump();
    expect(vm.selectedIndex, isNull);

    await tester.tap(find.text('Tacos med svartbönor'));
    await tester.pump();
    expect(vm.selectedIndex, 0);
  });
}
