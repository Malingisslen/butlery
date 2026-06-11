// test/widget/dialogs/slot_picker_dialog_test.dart
//
// BUT-999: pins the multi-select slot picker wiring — toggling N day/slot
// cells, confirm-button count disclosure, and the popped MultiSlotSelection
// payload — plus the single-select regression (one tap pops immediately,
// exactly the BUT-1029 behavior the bulk-add flow depends on).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/widgets/common/dialogs/slot_picker_dialog.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

class _MockPlanService extends Mock implements WeeklyMenuPlanService {}

void main() {
  late _MockPlanService planService;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    planService = _MockPlanService();
    when(() => planService.getWeek(any())).thenAnswer(
      (invocation) async => WeeklyMenuPlan.empty(
        userId: 'u',
        date: IsoWeekUtils.weekStartOf(
            invocation.positionalArguments.single as DateTime),
      ),
    );
    TestServiceLocator.registerMock<WeeklyMenuPlanService>(planService);
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  /// Pumps a host app whose button opens the picker and records the result.
  Future<void> pumpHost(
    WidgetTester tester, {
    required Future<Object?> Function(BuildContext) open,
    required void Function(Object?) onResult,
  }) async {
    // Tall surface so all three slot rows + confirm bar are tappable
    // without scrolling the draggable sheet.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async => onResult(await open(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('multi-select mode (BUT-999)', () {
    testWidgets(
        '3 cell taps → confirm shows count and pops all 3 targets for the week',
        (tester) async {
      MultiSlotSelection? result;
      await pumpHost(
        tester,
        open: (context) => showMultiSlotPickerDialog(context),
        onResult: (r) => result = r as MultiSlotSelection?,
      );

      // Rows render in MealSlot.values order (lunch, middag, övrigt), so
      // the Nth occurrence of a day label addresses a specific slot row.
      await tester.tap(find.text('mån').at(0)); // (mon, lunch)
      await tester.pump();
      await tester.tap(find.text('tis').at(1)); // (tue, middag)
      await tester.pump();
      await tester.tap(find.text('ons').at(2)); // (wed, övrigt)
      await tester.pump();

      expect(find.textContaining('(3)'), findsOneWidget,
          reason: 'Confirm button must disclose the selection count');

      await tester.tap(find.textContaining('(3)'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.targets, hasLength(3));
      expect(
        result!.targets,
        containsAll(const <SlotTarget>[
          (day: DayOfWeek.mon, slot: MealSlot.lunch),
          (day: DayOfWeek.tue, slot: MealSlot.middag),
          (day: DayOfWeek.wed, slot: MealSlot.ovrigt),
        ]),
      );
      // One save per confirm requires one week per selection.
      expect(result!.weekStart.weekday, DateTime.monday);
    });

    testWidgets('re-tapping a selected cell deselects it', (tester) async {
      MultiSlotSelection? result;
      await pumpHost(
        tester,
        open: (context) => showMultiSlotPickerDialog(context),
        onResult: (r) => result = r as MultiSlotSelection?,
      );

      await tester.tap(find.text('mån').at(0));
      await tester.pump();
      await tester.tap(find.text('tis').at(0));
      await tester.pump();
      await tester.tap(find.text('mån').at(0)); // toggle off
      await tester.pump();

      expect(find.textContaining('(1)'), findsOneWidget);

      await tester.tap(find.textContaining('(1)'));
      await tester.pumpAndSettle();

      expect(result!.targets,
          const <SlotTarget>[(day: DayOfWeek.tue, slot: MealSlot.lunch)]);
    });

    testWidgets('confirm is disabled at zero selections', (tester) async {
      await pumpHost(
        tester,
        open: (context) => showMultiSlotPickerDialog(context),
        onResult: (_) {},
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.text('Lägg till (0)'), findsOneWidget);
    });
  });

  group('single-select mode (BUT-1029 regression)', () {
    testWidgets('one tap pops immediately with the (day, slot) triple',
        (tester) async {
      SlotSelection? result;
      await pumpHost(
        tester,
        open: (context) => showSlotPickerDialog(context),
        onResult: (r) => result = r as SlotSelection?,
      );

      // No confirm bar in single-select mode.
      expect(find.byType(FilledButton), findsNothing);

      await tester.tap(find.text('fre').at(1)); // (fri, middag)
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.day, DayOfWeek.fri);
      expect(result!.slot, MealSlot.middag);
      expect(find.byType(SlotPickerDialog), findsNothing,
          reason: 'Single-select must pop on first tap, exactly as before');
    });
  });
}
