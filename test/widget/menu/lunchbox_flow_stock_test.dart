/// BUT-2486 part 5b: the week menu's lunch flow hands the sheet the boxes in
/// the fridge and freezer through the production locator, and only when the
/// flag is on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/menu/meal_box_service.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/menu/calendar/lunchbox_flow.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

class _MockVm extends Mock implements WeeklyMenuPlanViewModel {}

class _MockBoxes extends Mock implements MealBoxService {}

class _MockFlags extends Mock implements FeatureFlagService {}

final _chili = MealBox(
  id: 'a',
  recipeId: 'r-a',
  recipeTitle: 'Chili',
  location: MealBoxLocation.freezer,
  storedOn: DateTime(2026, 11, 20),
  count: 3,
);

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(DayOfWeek.wed);
    registerFallbackValue(Lunchbox.fromStock(_chili));
  });

  late _MockVm vm;
  late _MockBoxes boxes;
  late _MockFlags flags;

  setUp(() async {
    await TestServiceLocator.initialize();
    vm = _MockVm();
    when(() => vm.plan).thenReturn(
      WeeklyMenuPlan.empty(userId: 'u', date: DateTime(2026, 11, 23)),
    );
    when(() => vm.lunchboxAt(any())).thenReturn(null);
    when(() => vm.lunchboxTitle(any())).thenReturn(null);
    when(() => vm.lunchboxSuggestions).thenReturn(const []);
    when(() => vm.resolveForNavigation(any())).thenReturn(null);
    when(() => vm.setLunchbox(any(), any())).thenAnswer((_) async => true);

    boxes = _MockBoxes();
    when(() => boxes.list()).thenAnswer((_) async => [_chili]);
    TestServiceLocator.registerMock<MealBoxService>(boxes);

    flags = _MockFlags();
    when(() => flags.isEnabled(any())).thenReturn(false);
    TestServiceLocator.registerMock<FeatureFlagService>(flags);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => openLunchboxFlow(
              context,
              vm: vm,
              day: DayOfWeek.wed,
              roster: const [],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('with the flag on, a box can be taken as the lunch', (
    tester,
  ) async {
    when(
      () => flags.isEnabled(FeatureFlags.enableMealBoxes),
    ).thenReturn(true);
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('lunchbox-stock-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lunchbox-save')));
    await tester.pumpAndSettle();

    final box =
        verify(
              () => vm.setLunchbox(DayOfWeek.wed, captureAny()),
            ).captured.single
            as Lunchbox;
    expect(box.mealBoxId, 'a');
    verify(() => boxes.list()).called(1);
  });

  testWidgets('with the flag off, the boxes are never read', (tester) async {
    await open(tester);

    expect(find.byKey(const ValueKey('lunchbox-stock-a')), findsNothing);
    expect(find.byKey(const ValueKey('lunchbox-save')), findsWidgets);
    verifyZeroInteractions(boxes);
  });
}
