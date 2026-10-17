/// The placement mode as a page: leaving with dishes placed asks first, and
/// the week arrows load the neighbouring week.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/menu_placement/placement_widgets.dart';
import 'package:butlery/views/menu_placement_view.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

class _MockService extends Mock implements WeeklyMenuPlanService {}

class _MockRepo extends Mock implements WeeklyMenuPlanRepository {}

class _MockUserService extends Mock implements UserService {}

class _FakePlan extends Fake implements WeeklyMenuPlan {}

final _sv = AppLocalizationsSv();
final _weekStart = DateTime(2026, 4, 6);

void main() {
  late _MockService service;

  setUpAll(() {
    registerFallbackValue(_weekStart);
    registerFallbackValue(_FakePlan());
    registerFallbackValue(RecipeFactory.build(id: 'fallback'));
    registerFallbackValue(DayOfWeek.mon);
    registerFallbackValue(MealSlot.middag);
  });

  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    service = _MockService();
    when(() => service.readWeek(any())).thenAnswer((inv) async {
      final start = inv.positionalArguments.first as DateTime;
      final now = DateTime(2026, 4, 1, 12);
      return WeeklyMenuPlanRead(
        plan: WeeklyMenuPlan(
          id: IsoWeekUtils.weekIdFor('u-1', start),
          userId: 'u-1',
          weekStartDate: start,
          entries: const [],
          createdAt: now,
          updatedAt: now,
        ),
        readFailed: false,
      );
    });
    final user = _MockUserService();
    when(() => user.currentUserProfile).thenReturn(null);
    // Placing a dish is the service's own pure edit, so the real one answers.
    final real = WeeklyMenuPlanService(
      repository: _MockRepo(),
      userService: user,
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
    TestServiceLocator.registerMock<WeeklyMenuPlanService>(service);
  });

  tearDown(() async => TestServiceLocator.reset());

  Future<void> leave(WidgetTester tester) async {
    await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
    await tester.pumpAndSettle();
  }

  Future<void> openPlacement(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MenuPlacementView(
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
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> placeOneDish(WidgetTester tester) async {
    await tester.tap(
      find
          .descendant(
            of: find.byType(PlacementGrid),
            matching: find.byWidgetPredicate(
              (w) => w is InkWell && w.onTap != null,
            ),
          )
          .first,
    );
    await tester.pump();
  }

  testWidgets('leaving with a dish placed asks first, and staying keeps it', (
    tester,
  ) async {
    await openPlacement(tester);
    await placeOneDish(tester);

    await leave(tester);
    expect(find.text(_sv.recipeUnsavedChangesTitle), findsOneWidget);

    await tester.tap(find.text(_sv.recipeContinueEditing));
    await tester.pumpAndSettle();

    expect(find.text(_sv.recipeUnsavedChangesTitle), findsNothing);
    expect(find.text(_sv.menuPlacementTitle), findsWidgets);
  });

  testWidgets('leaving without saving closes the page', (tester) async {
    await openPlacement(tester);
    await placeOneDish(tester);

    await leave(tester);
    await tester.tap(find.text(_sv.recipeLeaveWithoutSaving));
    await tester.pumpAndSettle();

    expect(find.text(_sv.menuPlacementTitle), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('leaving with nothing placed needs no confirmation', (
    tester,
  ) async {
    await openPlacement(tester);

    await leave(tester);

    expect(find.text(_sv.recipeUnsavedChangesTitle), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('the week arrows load the neighbouring weeks', (tester) async {
    await openPlacement(tester);
    clearInteractions(service);

    await tester.tap(find.byTooltip(_sv.slotPickerNextWeek));
    await tester.pumpAndSettle();
    verify(() => service.readWeek(DateTime(2026, 4, 13))).called(1);

    await tester.tap(find.byTooltip(_sv.slotPickerPreviousWeek));
    await tester.pumpAndSettle();
    verify(() => service.readWeek(DateTime(2026, 4, 6))).called(1);
  });
}
