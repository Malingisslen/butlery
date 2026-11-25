/// BUT-2486 part 5: the "MATLÅDOR" block at the top of Skafferiet, in every
/// pantry state, behind the meal-box flag.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/keyboard/app_actions.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/menu/meal_box_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/pantry_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/offline_banner_support.dart';
import '../../../test_support/base_unit_test.dart';

class _MockPantryViewModel extends Mock implements PantryViewModel {}

class _MockMealBoxService extends Mock implements MealBoxService {}

class _MockFlags extends Mock implements FeatureFlagService {}

MealBox _box(String id, String title, int count, {Map<String, int>? takes}) =>
    MealBox(
      id: id,
      recipeTitle: title,
      location: MealBoxLocation.fridge,
      storedOn: DateTime(2026, 11, 20),
      count: count,
      takes: takes ?? const {},
    );

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
    ensureOfflineService();
    registerFallbackValue(PantryLocation.fridge);
    registerFallbackValue(_box('x', 'x', 1));
    registerFallbackValue(MealBoxLocation.fridge);
    registerFallbackValue(DateTime(2026));
  });

  late _MockPantryViewModel vm;
  late _MockMealBoxService boxes;
  late _MockFlags flags;

  setUp(() async {
    await TestServiceLocator.initialize();
    ensureOfflineService();
    vm = _MockPantryViewModel();
    when(() => vm.isLoading).thenReturn(false);
    when(() => vm.error).thenReturn(null);
    when(() => vm.hasError).thenReturn(false);
    when(() => vm.items).thenReturn(const []);
    when(() => vm.expiringItems).thenReturn(const []);
    when(() => vm.itemsByLocation(any())).thenReturn(const []);
    when(() => vm.loadPantry()).thenAnswer((_) async {});
    TestServiceLocator.registerFactory<PantryViewModel>(() => vm);

    boxes = _MockMealBoxService();
    when(() => boxes.list()).thenAnswer(
      (_) async => [_box('a', 'Chili', 2), _box('b', 'Linsgryta', 1)],
    );
    when(() => boxes.setRemaining(any(), any())).thenAnswer((_) async {});
    when(() => boxes.move(any(), any())).thenAnswer((_) async => 'moved1');
    when(() => boxes.undoMove(any(), any())).thenAnswer((_) async {});
    when(() => boxes.remove(any())).thenAnswer((_) async {});
    when(() => boxes.restore(any())).thenAnswer((_) async {});
    when(() => boxes.setStoredOn(any(), any())).thenAnswer((_) async {});
    TestServiceLocator.registerMock<MealBoxService>(boxes);

    flags = _MockFlags();
    when(() => flags.isEnabled(any())).thenReturn(false);
    when(
      () => flags.isEnabled(FeatureFlags.enableMealBoxes),
    ).thenReturn(true);
    TestServiceLocator.registerMock<FeatureFlagService>(flags);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Finder inSheet(Key key) =>
      find.descendant(of: find.byType(BottomSheet), matching: find.byKey(key));

  String? sheetValue(WidgetTester tester) =>
      tester.widget<Text>(inSheet(const ValueKey('meal-box-value'))).data;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: PantryView()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the block shows above an EMPTY pantry', (tester) async {
    await pump(tester);

    expect(find.byKey(const ValueKey('meal-boxes-block')), findsOneWidget);
    expect(find.text('Chili'), findsOneWidget);
    expect(find.text('Linsgryta'), findsOneWidget);
    // Remaining 2 + 1.
    expect(find.text('MATLÅDOR · 3'), findsOneWidget);
  });

  group('while the pantry itself is not showing rows', () {
    final item = PantryItem(
      id: 'i',
      ingredientName: 'Mjöl',
      quantity: 1,
      unit: 'kg',
      location: PantryLocation.pantry,
      addedAt: DateTime(2026, 1, 1),
    );

    testWidgets('the block shows while the pantry loads', (tester) async {
      when(() => vm.isLoading).thenReturn(true);

      await pump(tester);

      expect(find.byKey(const ValueKey('meal-boxes-block')), findsOneWidget);
      expect(find.text('Chili'), findsOneWidget);
    });

    testWidgets('the block shows once while a stocked pantry reloads', (
      tester,
    ) async {
      when(() => vm.isLoading).thenReturn(true);
      when(() => vm.items).thenReturn([item]);

      await pump(tester);

      expect(find.byKey(const ValueKey('meal-boxes-block')), findsOneWidget);
      expect(find.text('Chili'), findsOneWidget);
    });

    testWidgets('the block shows when the pantry failed to load', (
      tester,
    ) async {
      when(() => vm.error).thenReturn('offline');
      when(() => vm.hasError).thenReturn(true);

      await pump(tester);

      expect(find.byKey(const ValueKey('meal-boxes-block')), findsOneWidget);
      expect(find.text('Chili'), findsOneWidget);
    });

    testWidgets(
      'a failed pantry load keeps the stocked rows out, the block in',
      (
        tester,
      ) async {
        when(() => vm.error).thenReturn('offline');
        when(() => vm.hasError).thenReturn(true);
        when(() => vm.items).thenReturn([item]);

        await pump(tester);

        expect(find.byKey(const ValueKey('meal-boxes-block')), findsOneWidget);
        expect(find.text('Mjöl'), findsNothing);
      },
    );
  });

  testWidgets('the block sits in the list of a stocked pantry', (tester) async {
    final item = PantryItem(
      id: 'i',
      ingredientName: 'Mjöl',
      quantity: 1,
      unit: 'kg',
      location: PantryLocation.pantry,
      addedAt: DateTime(2026, 1, 1),
    );
    when(() => vm.items).thenReturn([item]);
    when(() => vm.itemsByLocation(PantryLocation.pantry)).thenReturn([item]);

    await pump(tester);

    expect(find.byKey(const ValueKey('meal-boxes-block')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byKey(const ValueKey('meal-boxes-block')),
      ),
      findsOneWidget,
    );
    expect(find.text('Mjöl'), findsOneWidget);
  });

  testWidgets('minus to zero hides the box and Ångra brings it back', (
    tester,
  ) async {
    await pump(tester);
    final minus = find.descendant(
      of: find.byKey(const ValueKey('meal-box-b')),
      matching: find.byKey(const ValueKey('meal-box-minus')),
    );

    await tester.tap(minus);
    await tester.pump();
    await tester.pump();

    verify(() => boxes.setRemaining(any(), 0)).called(1);
    expect(find.text('Linsgryta'), findsNothing);
    expect(find.text('Chili'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Ångra'));
    await tester.pump();
    await tester.pump();

    verify(() => boxes.setRemaining(any(), 1)).called(1);
    expect(find.text('Linsgryta'), findsOneWidget);
  });

  testWidgets('plus stops where remaining plus taken reaches 99', (
    tester,
  ) async {
    when(() => boxes.list()).thenAnswer(
      (_) async => [
        _box('a', 'Chili', 99, takes: {'2026-11-27': 2}),
      ],
    );
    await pump(tester);

    // 97 left + 2 taken = 99.
    expect(find.text('97'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meal-box-plus')));
    await tester.pump();
    verifyNever(() => boxes.setRemaining(any(), any()));
  });

  testWidgets('a refused write puts the old number back and says so', (
    tester,
  ) async {
    when(
      () => boxes.setRemaining(any(), any()),
    ).thenThrow(StateError('refused'));
    await pump(tester);
    final plus = find.descendant(
      of: find.byKey(const ValueKey('meal-box-a')),
      matching: find.byKey(const ValueKey('meal-box-plus')),
    );

    await tester.tap(plus);
    await tester.pump();
    await tester.pump();

    expect(find.text('Kunde inte ändra antalet matlådor'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('meal-box-a')),
                  matching: find.byKey(const ValueKey('meal-box-value')),
                )
                .first,
          )
          .data,
      '2',
    );
  });

  testWidgets('a failed read is one row with a retry', (tester) async {
    when(() => boxes.list()).thenThrow(StateError('offline'));
    await pump(tester);

    expect(find.text('Kunde inte hämta matlådorna'), findsOneWidget);
    when(() => boxes.list()).thenAnswer((_) async => [_box('a', 'Chili', 2)]);
    await tester.tap(find.byKey(const ValueKey('meal-boxes-retry')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Chili'), findsOneWidget);
  });

  testWidgets('no boxes: the block draws nothing', (tester) async {
    when(() => boxes.list()).thenAnswer((_) async => []);
    await pump(tester);

    expect(find.byKey(const ValueKey('meal-boxes-block')), findsNothing);
    expect(find.textContaining('MATLÅDOR'), findsNothing);
  });

  testWidgets('flag off: no read and no block', (tester) async {
    when(
      () => flags.isEnabled(FeatureFlags.enableMealBoxes),
    ).thenReturn(false);
    await pump(tester);

    verifyNever(() => boxes.list());
    expect(find.byKey(const ValueKey('meal-boxes-block')), findsNothing);
  });

  group('the stepper buttons', () {
    Finder button(String boxId, String key) => find.descendant(
      of: find.byKey(ValueKey('meal-box-$boxId')),
      matching: find.byKey(ValueKey(key)),
    );

    testWidgets('minus is off at 0 remaining while lunches are planned', (
      tester,
    ) async {
      when(() => boxes.list()).thenAnswer(
        (_) async => [
          _box('p', 'Pannkaka', 1, takes: {'2026-11-27': 1}),
        ],
      );
      await pump(tester);
      expect(find.text('Pannkaka'), findsOneWidget);

      final handle = tester.ensureSemantics();
      try {
        expect(
          tester.getSemantics(button('p', 'meal-box-minus')),
          matchesSemantics(
            label: 'Färre matlådor av Pannkaka',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
          ),
        );
        expect(
          tester.getSemantics(button('p', 'meal-box-plus')),
          matchesSemantics(
            label: 'Fler matlådor av Pannkaka',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
      } finally {
        handle.dispose();
      }

      await tester.tap(button('p', 'meal-box-minus'));
      await tester.pump();
      verifyNever(() => boxes.setRemaining(any(), any()));
    });

    testWidgets('both buttons are enabled while boxes are left', (
      tester,
    ) async {
      await pump(tester);

      final handle = tester.ensureSemantics();
      try {
        expect(
          tester.getSemantics(button('a', 'meal-box-minus')),
          matchesSemantics(
            label: 'Färre matlådor av Chili',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(button('a', 'meal-box-plus')),
          matchesSemantics(
            label: 'Fler matlådor av Chili',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
      } finally {
        handle.dispose();
      }
    });
  });

  group('the per-box menu', () {
    Future<void> openMenu(WidgetTester tester, String title) async {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }

    testWidgets('a tap on the card opens it, titled with what is left', (
      tester,
    ) async {
      await pump(tester);
      await openMenu(tester, 'Chili');

      expect(find.text('Chili · 2 lådor'), findsOneWidget);
      expect(find.text('Välj dag i veckomenyn'), findsOneWidget);
      expect(find.text('Datumet blir i dag'), findsOneWidget);
    });

    testWidgets('Planera som lunch switches to the Meny tab', (tester) async {
      mainTabSwitchRequest.value = 0;
      addTearDown(() => mainTabSwitchRequest.value = 0);
      await pump(tester);
      await openMenu(tester, 'Chili');

      await tester.tap(find.byKey(const ValueKey('meal-box-action-plan')));
      await tester.pumpAndSettle();

      expect(mainTabSwitchRequest.value, 1);
      expect(find.text('Chili · 2 lådor'), findsNothing);
    });

    testWidgets('Flytta till frysen moves, reloads, and Ångra undoes it', (
      tester,
    ) async {
      await pump(tester);
      await openMenu(tester, 'Chili');
      expect(find.text('Flytta till frysen'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('meal-box-action-move')));
      await tester.pumpAndSettle();

      final moved =
          verify(
                () => boxes.move(captureAny(), MealBoxLocation.freezer),
              ).captured.single
              as MealBox;
      expect(moved.id, 'a');
      // Once on load, once after the move.
      verify(() => boxes.list()).called(2);
      expect(find.text('Chili flyttad till frysen'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Ångra'));
      await tester.pump();
      await tester.pump();
      verify(() => boxes.undoMove(any(), 'moved1')).called(1);
    });

    testWidgets('a box in the freezer offers Flytta till kylen, and a box '
        'with nothing left offers no move', (tester) async {
      when(() => boxes.list()).thenAnswer(
        (_) async => [
          MealBox(
            id: 'f',
            recipeTitle: 'Gryta',
            location: MealBoxLocation.freezer,
            storedOn: DateTime(2026, 11, 9),
            count: 1,
          ),
          _box('p', 'Pannkaka', 1, takes: {'2026-11-27': 1}),
        ],
      );
      await pump(tester);

      await openMenu(tester, 'Gryta');
      expect(find.text('Flytta till kylen'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await openMenu(tester, 'Pannkaka');
      expect(find.byKey(const ValueKey('meal-box-action-move')), findsNothing);
    });

    testWidgets('a refused move says so', (tester) async {
      when(() => boxes.move(any(), any())).thenThrow(StateError('refused'));
      await pump(tester);
      await openMenu(tester, 'Chili');

      await tester.tap(find.byKey(const ValueKey('meal-box-action-move')));
      await tester.pumpAndSettle();

      expect(find.text('Kunde inte flytta matlådan'), findsOneWidget);
    });

    testWidgets('Ändra antal och datum: the stepper sets what is left', (
      tester,
    ) async {
      await pump(tester);
      await openMenu(tester, 'Chili');
      await tester.tap(find.byKey(const ValueKey('meal-box-action-edit')));
      await tester.pumpAndSettle();

      final plus = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byKey(const ValueKey('meal-box-plus')),
      );
      await tester.tap(plus);
      await tester.pump();

      verify(() => boxes.setRemaining(any(), 3)).called(1);
    });

    Future<DateTime> pickDateOk(WidgetTester tester, MealBox box) async {
      when(() => boxes.list()).thenAnswer((_) async => [box]);
      await pump(tester);
      await openMenu(tester, box.recipeTitle);
      await tester.tap(find.byKey(const ValueKey('meal-box-action-edit')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('meal-box-edit-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      return verify(
            () => boxes.setStoredOn(box.id, captureAny()),
          ).captured.single
          as DateTime;
    }

    MealBox dated(DateTime storedOn) => MealBox(
      id: 'a',
      recipeTitle: 'Chili',
      location: MealBoxLocation.freezer,
      storedOn: storedOn,
      count: 2,
    );

    testWidgets('Ändra antal och datum: OK keeps the stored date', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 11, 25, 12)), () async {
        expect(
          await pickDateOk(tester, dated(DateTime(2026, 11, 20))),
          DateTime(2026, 11, 20),
        );
      });
    });

    testWidgets('a box stored more than a year ago still opens the picker', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 11, 25, 12)), () async {
        expect(
          await pickDateOk(tester, dated(DateTime(2025, 6, 2))),
          DateTime(2025, 6, 2),
        );
      });
    });

    testWidgets('a stored date after today opens on today', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 11, 25, 12)), () async {
        expect(
          await pickDateOk(tester, dated(DateTime(2026, 12, 3))),
          DateTime(2026, 11, 25),
        );
      });
    });

    testWidgets('the date is locked, with the reason, while a lunch is '
        'planned from the box', (tester) async {
      when(() => boxes.list()).thenAnswer(
        (_) async => [
          _box('a', 'Chili', 4, takes: {'2026-11-27': 1}),
        ],
      );
      await pump(tester);
      await openMenu(tester, 'Chili');
      await tester.tap(find.byKey(const ValueKey('meal-box-action-edit')));
      await tester.pumpAndSettle();

      expect(
        find.text('Datumet kan ändras när ingen lunch är planerad ur lådan'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('meal-box-edit-date')));
      await tester.pumpAndSettle();
      expect(find.text('OK'), findsNothing);
      verifyNever(() => boxes.setStoredOn(any(), any()));
    });

    testWidgets('Ta bort removes the box at once and Ångra restores the '
        'whole box', (tester) async {
      await pump(tester);
      await openMenu(tester, 'Linsgryta');

      await tester.tap(find.byKey(const ValueKey('meal-box-action-remove')));
      await tester.pumpAndSettle();

      verify(() => boxes.remove('b')).called(1);
      expect(find.text('Linsgryta'), findsNothing);
      expect(find.text('Linsgryta borttagen'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Ångra'));
      await tester.pump();
      await tester.pump();

      final restored =
          verify(
                () => boxes.restore(captureAny()),
              ).captured.single
              as MealBox;
      expect(restored.id, 'b');
      expect(restored.count, 1);
      expect(find.text('Linsgryta'), findsOneWidget);
    });

    testWidgets('a freezer box moved to the fridge says so', (tester) async {
      when(() => boxes.list()).thenAnswer(
        (_) async => [
          MealBox(
            id: 'f',
            recipeTitle: 'Gryta',
            location: MealBoxLocation.freezer,
            storedOn: DateTime(2026, 11, 9),
            count: 1,
          ),
        ],
      );
      await pump(tester);
      await openMenu(tester, 'Gryta');

      await tester.tap(find.byKey(const ValueKey('meal-box-action-move')));
      await tester.pumpAndSettle();

      verify(() => boxes.move(any(), MealBoxLocation.fridge)).called(1);
      expect(find.text('Gryta flyttad till kylen'), findsOneWidget);
    });

    testWidgets('a refused undo of the move says so', (tester) async {
      when(
        () => boxes.undoMove(any(), any()),
      ).thenAnswer((_) => Future.error(StateError('refused')));
      await pump(tester);
      await openMenu(tester, 'Chili');
      await tester.tap(find.byKey(const ValueKey('meal-box-action-move')));
      await tester.pumpAndSettle();

      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Ångra'));
      await tester.pumpAndSettle();

      verify(() => boxes.undoMove(any(), 'moved1')).called(1);
      expect(find.text('Kunde inte ångra flytten'), findsOneWidget);
    });

    testWidgets('a refused restore says so and the box stays gone', (
      tester,
    ) async {
      when(
        () => boxes.restore(any()),
      ).thenAnswer((_) => Future.error(StateError('refused')));
      await pump(tester);
      await openMenu(tester, 'Linsgryta');
      await tester.tap(find.byKey(const ValueKey('meal-box-action-remove')));
      await tester.pumpAndSettle();

      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Ångra'));
      await tester.pumpAndSettle();

      verify(() => boxes.restore(any())).called(1);
      expect(find.text('Kunde inte ångra borttagningen'), findsOneWidget);
      expect(find.text('Linsgryta'), findsNothing);
    });

    testWidgets('a refused date change says so and the old date stays', (
      tester,
    ) async {
      when(
        () => boxes.setStoredOn(any(), any()),
      ).thenAnswer((_) => Future.error(StateError('refused')));
      when(() => boxes.list()).thenAnswer(
        (_) async => [
          MealBox(
            id: 'a',
            recipeTitle: 'Chili',
            location: MealBoxLocation.freezer,
            storedOn: DateTime(2026, 11, 20),
            count: 2,
          ),
        ],
      );
      late String oldDate;
      await withClock(Clock.fixed(DateTime(2026, 11, 25, 12)), () async {
        await pump(tester);
        // The sv date symbols load with the app's locale, so format after it.
        oldDate = DateFormat.yMMMd('sv').format(DateTime(2026, 11, 20));
        await openMenu(tester, 'Chili');
        await tester.tap(find.byKey(const ValueKey('meal-box-action-edit')));
        await tester.pumpAndSettle();
        expect(find.text(oldDate), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('meal-box-edit-date')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('21'));
        await tester.pump();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      });

      verify(
        () => boxes.setStoredOn('a', DateTime(2026, 11, 21)),
      ).called(1);
      expect(find.text('Kunde inte ändra datumet'), findsOneWidget);
      expect(find.text(oldDate), findsOneWidget);
    });

    testWidgets('the edit sheet shows a refused stepper and keeps the number', (
      tester,
    ) async {
      when(
        () => boxes.setRemaining(any(), any()),
      ).thenAnswer((_) => Future.error(StateError('refused')));
      await pump(tester);
      await openMenu(tester, 'Chili');
      await tester.tap(find.byKey(const ValueKey('meal-box-action-edit')));
      await tester.pumpAndSettle();

      await tester.tap(inSheet(const ValueKey('meal-box-plus')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Kunde inte ändra antalet matlådor'), findsOneWidget);
      expect(sheetValue(tester), '2');
    });

    testWidgets('the edit sheet shows the new number at once', (tester) async {
      await pump(tester);
      await openMenu(tester, 'Chili');
      await tester.tap(find.byKey(const ValueKey('meal-box-action-edit')));
      await tester.pumpAndSettle();
      expect(sheetValue(tester), '2');

      await tester.tap(inSheet(const ValueKey('meal-box-plus')));
      await tester.pump();
      expect(sheetValue(tester), '3');

      await tester.tap(inSheet(const ValueKey('meal-box-minus')));
      await tester.pump();
      await tester.tap(inSheet(const ValueKey('meal-box-minus')));
      await tester.pump();
      expect(sheetValue(tester), '1');
    });

    testWidgets('a refused delete puts the box back and says so', (
      tester,
    ) async {
      when(() => boxes.remove(any())).thenThrow(StateError('refused'));
      await pump(tester);
      await openMenu(tester, 'Linsgryta');

      await tester.tap(find.byKey(const ValueKey('meal-box-action-remove')));
      await tester.pumpAndSettle();

      expect(find.text('Kunde inte ta bort matlådan'), findsOneWidget);
      expect(find.text('Linsgryta'), findsOneWidget);
    });
  });
}
