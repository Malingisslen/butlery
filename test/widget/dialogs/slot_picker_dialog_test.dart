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
    when(() => planService.readWeek(any())).thenAnswer(
      (invocation) async => WeeklyMenuPlanRead(
        plan: WeeklyMenuPlan.empty(
          userId: 'u',
          date: IsoWeekUtils.weekStartOf(
            invocation.positionalArguments.single as DateTime,
          ),
        ),
        readFailed: false,
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

        expect(
          find.textContaining('(3)'),
          findsOneWidget,
          reason: 'Confirm button must disclose the selection count',
        );

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
      },
    );

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

      expect(result!.targets, const <SlotTarget>[
        (day: DayOfWeek.tue, slot: MealSlot.lunch),
      ]);
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

  group('failed read (BUT-1962)', () {
    testWidgets('a week that could not be read shows the refusal and draws NO '
        'placeable cells', (tester) async {
      // Before BUT-1962 this dialog called `getWeek`, which reported a failed
      // read as an empty plan — so the grid rendered a full week of free cells
      // and the user placed a recipe onto a week the app had never read. No
      // cell means no placement.
      when(() => planService.readWeek(any())).thenAnswer(
        (_) async => WeeklyMenuPlanRead(
          plan: WeeklyMenuPlan.empty(
            userId: 'u',
            date: IsoWeekUtils.weekStartOf(DateTime(2026, 8, 28)),
          ),
          readFailed: true,
        ),
      );

      await pumpHost(
        tester,
        open: (context) => showSlotPickerDialog(context),
        onResult: (_) {},
      );

      expect(find.text(weeklyPlanReadFailedMessage), findsOneWidget);
      expect(
        find.text('fre'),
        findsNothing,
        reason: 'a slot grid over a week we never read is the whole defect',
      );
    });

    testWidgets('the refusal\'s retry re-reads the week and the grid comes '
        'back', (tester) async {
      // First read fails, second answers.
      var reads = 0;
      when(() => planService.readWeek(any())).thenAnswer((invocation) async {
        final week = IsoWeekUtils.weekStartOf(
          invocation.positionalArguments.single as DateTime,
        );
        reads++;
        return WeeklyMenuPlanRead(
          plan: WeeklyMenuPlan.empty(userId: 'u', date: week),
          readFailed: reads == 1,
        );
      });

      await pumpHost(
        tester,
        open: (context) => showSlotPickerDialog(context),
        onResult: (_) {},
      );
      expect(find.text(weeklyPlanReadFailedMessage), findsOneWidget);

      await tester.tap(find.text('Försök igen'));
      await tester.pumpAndSettle();

      expect(reads, 2, reason: 'the retry must actually re-read the week');
      expect(find.text(weeklyPlanReadFailedMessage), findsNothing);
      expect(
        find.text('fre'),
        findsWidgets,
        reason: 'a successful retry restores the placeable grid',
      );
    });
  });

  group('single-select mode (BUT-1029 regression)', () {
    testWidgets('one tap pops immediately with the (day, slot) triple', (
      tester,
    ) async {
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
      expect(
        find.byType(SlotPickerDialog),
        findsNothing,
        reason: 'Single-select must pop on first tap, exactly as before',
      );
    });
  });
}
