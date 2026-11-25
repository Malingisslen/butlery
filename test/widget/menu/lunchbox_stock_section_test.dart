/// BUT-2486 part 5: "UR KYLEN OCH FRYSEN" in the lunchbox sheet. A box from
/// stock is saved as `Lunchbox.fromStock`, and a saved one keeps its box on
/// re-save.
library;

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/meal_box_service.dart';
import 'package:butlery/widgets/menu/calendar/lunchbox_sheet.dart';
import 'package:butlery/widgets/menu/calendar/lunchbox_stock_section.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

class _MockBoxes extends Mock implements MealBoxService {}

MealBox _box(
  String id,
  String title,
  int count, {
  MealBoxLocation location = MealBoxLocation.fridge,
  Map<String, int> takes = const {},
}) => MealBox(
  id: id,
  recipeId: 'r-$id',
  recipeTitle: title,
  location: location,
  storedOn: DateTime(2026, 11, 20),
  count: count,
  takes: takes,
);

void main() {
  Future<LunchboxSheetResult? Function()> open(
    WidgetTester tester, {
    Future<List<MealBox>?>? stock,
    Lunchbox? current,
    List<Recipe> suggestions = const [],
    Recipe? picked,
  }) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    LunchboxSheetResult? result;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showLunchboxSheet(
                context,
                day: DayOfWeek.wed,
                dayName: 'onsdag',
                current: current,
                currentTitle: null,
                leftoversTitle: 'Linsgryta',
                suggestions: suggestions,
                roster: const [],
                pickRecipe: (_) async => picked,
                stockBoxes: stock,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  Lunchbox saved(LunchboxSheetResult? Function() result) =>
      (result() as LunchboxSheetSave).box;

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('lunchbox-save')));
    await tester.pumpAndSettle();
  }

  int portions(WidgetTester tester) => int.parse(
    tester.widget<Text>(find.byKey(const ValueKey('lunchbox-portions'))).data!,
  );

  Future<void> plus(WidgetTester tester, int times) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.byKey(const ValueKey('lunchbox-portions-plus')));
      await tester.pump();
    }
  }

  testWidgets('no stock future: no section at all', (tester) async {
    await open(tester);

    expect(find.text('UR KYLEN OCH FRYSEN'), findsNothing);
  });

  testWidgets('loading: a muted row, and the sheet is already usable', (
    tester,
  ) async {
    final pending = Completer<List<MealBox>?>();
    await open(tester, stock: pending.future);

    expect(find.text('UR KYLEN OCH FRYSEN'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('lunchbox-stock-loading')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('lunchbox-source-leftovers')),
      findsOneWidget,
    );

    pending.complete([_box('a', 'Chili', 2)]);
    await tester.pumpAndSettle();
    expect(find.text('Chili'), findsOneWidget);
    expect(find.byKey(const ValueKey('lunchbox-stock-loading')), findsNothing);
  });

  testWidgets('failed read: a muted row', (tester) async {
    await open(tester, stock: Future.value(null));

    expect(find.text('Kunde inte hämta matlådorna'), findsOneWidget);
  });

  testWidgets('no boxes: the muted row says how to get some', (tester) async {
    await open(tester, stock: Future.value(<MealBox>[]));

    expect(
      find.text(
        'Spara rester som matlådor när du trycker Klart efter matlagningen',
      ),
      findsOneWidget,
    );
  });

  testWidgets('rows show where a box is and how many are left; empty ones '
      'are left out', (tester) async {
    await open(
      tester,
      stock: Future.value([
        _box('a', 'Chili', 2),
        _box('b', 'Linsgryta', 3, location: MealBoxLocation.freezer),
        _box('c', 'Pannkaka', 1, takes: {'2026-11-27': 1}),
      ]),
    );

    expect(find.text('I kylen · 2 kvar'), findsOneWidget);
    expect(find.text('Frysen · 3 kvar'), findsOneWidget);
    expect(find.text('Pannkaka'), findsNothing);
  });

  testWidgets('choosing a box saves Lunchbox.fromStock and caps the stepper '
      'at what is left', (tester) async {
    final result = await open(
      tester,
      stock: Future.value([_box('a', 'Chili', 2)]),
    );

    await tester.tap(find.byKey(const ValueKey('lunchbox-stock-a')));
    await tester.pump();
    await plus(tester, 5);
    expect(portions(tester), 2);
    await save(tester);

    final box = saved(result);
    expect(box.isFromStock, isTrue);
    expect(box.mealBoxId, 'a');
    expect(box.portions, 2);
    expect(box.recipeTitle, 'Chili');
    expect(box.mealBoxLocation, MealBoxLocation.fridge);
  });

  testWidgets('a box with one left never goes below 1 portion', (
    tester,
  ) async {
    await open(tester, stock: Future.value([_box('a', 'Chili', 1)]));

    await tester.tap(find.byKey(const ValueKey('lunchbox-stock-a')));
    await tester.pump();

    expect(portions(tester), 1);
    await plus(tester, 3);
    expect(portions(tester), 1);
  });

  testWidgets('choosing another source clears the box', (tester) async {
    final result = await open(
      tester,
      stock: Future.value([_box('a', 'Chili', 2)]),
    );

    await tester.tap(find.byKey(const ValueKey('lunchbox-stock-a')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lunchbox-source-leftovers')));
    await tester.pump();
    await save(tester);

    final box = saved(result);
    expect(box.isFromStock, isFalse);
    expect(box.mealBoxId, isNull);
    expect(box.followsMiddag, isTrue);
  });

  testWidgets('picking a recipe after a box clears the box', (tester) async {
    final result = await open(
      tester,
      stock: Future.value([_box('a', 'Chili', 2)]),
      picked: RecipeFactory.build(id: 'soup', title: 'Soppa'),
    );

    await tester.tap(find.byKey(const ValueKey('lunchbox-stock-a')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lunchbox-source-prepday')));
    await tester.pumpAndSettle();
    await save(tester);

    final box = saved(result);
    expect(box.isFromStock, isFalse);
    expect(box.mealBoxId, isNull);
    expect(box.source, LunchboxSource.prepDay);
    expect(box.recipeId, 'soup');
  });

  testWidgets('choosing a suggestion after a box clears the box', (
    tester,
  ) async {
    final result = await open(
      tester,
      stock: Future.value([_box('a', 'Chili', 2)]),
      suggestions: [RecipeFactory.build(id: 'pasta', title: 'Pasta')],
    );

    await tester.tap(find.byKey(const ValueKey('lunchbox-stock-a')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lunchbox-suggestion-pasta')));
    await tester.pump();
    await save(tester);

    final box = saved(result);
    expect(box.isFromStock, isFalse);
    expect(box.mealBoxId, isNull);
    expect(box.source, LunchboxSource.suggestion);
    expect(box.recipeId, 'pasta');
  });

  testWidgets('choosing a box clamps portions already raised past what is '
      'left', (tester) async {
    final result = await open(
      tester,
      stock: Future.value([_box('a', 'Chili', 2)]),
    );

    await tester.tap(find.byKey(const ValueKey('lunchbox-source-leftovers')));
    await tester.pump();
    await plus(tester, 3);
    expect(portions(tester), 4);
    await tester.tap(find.byKey(const ValueKey('lunchbox-stock-a')));
    await tester.pump();

    expect(portions(tester), 2);
    await save(tester);
    expect(saved(result).portions, 2);
  });

  group('a saved stock lunch', () {
    final current = Lunchbox.fromStock(
      _box('a', 'Chili', 5, location: MealBoxLocation.freezer),
      portions: 3,
      takerIds: const ['u'],
    );

    testWidgets('does not show as Rester and keeps its box on re-save', (
      tester,
    ) async {
      // Remaining 2 already leaves out this lunch's 3 (count 5, taken 3).
      final result = await open(
        tester,
        current: current,
        stock: Future.value([
          _box('a', 'Chili', 5, takes: {'2026-11-25': 3}),
        ]),
      );

      final leftovers = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const ValueKey('lunchbox-source-leftovers')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(leftovers.properties.selected, isNot(true));
      expect(portions(tester), 3);
      await save(tester);

      final box = saved(result);
      expect(box.isFromStock, isTrue);
      expect(box.mealBoxId, 'a');
      expect(box.mealBoxStoredOn, DateTime(2026, 11, 20));
      expect(box.portions, 3);
      expect(box.takerIds, ['u']);
      expect(box.recipeTitle, 'Chili');
      expect(box.mealBoxLocation, MealBoxLocation.freezer);
      expect(box.recipeId, 'r-a');
    });

    testWidgets('its own portions only raise the cap of its own box', (
      tester,
    ) async {
      await open(
        tester,
        current: current,
        stock: Future.value([
          _box('a', 'Chili', 5, takes: {'2026-11-25': 3}),
          _box('b', 'Gryta', 2),
        ]),
      );

      expect(portions(tester), 3);
      await tester.tap(find.byKey(const ValueKey('lunchbox-stock-b')));
      await tester.pump();
      await plus(tester, 5);

      expect(portions(tester), 2);
    });

    testWidgets('is saveable and keeps its box before the boxes have loaded '
        'or when they failed to', (tester) async {
      final result = await open(
        tester,
        current: current,
        stock: Future.value(null),
      );

      expect(find.byKey(const ValueKey('lunchbox-stock-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('lunchbox-stock-failed')), findsNothing);
      await save(tester);

      expect(saved(result).mealBoxId, 'a');
    });

    testWidgets('the stepper may reach remaining plus its own portions', (
      tester,
    ) async {
      await open(
        tester,
        current: current,
        stock: Future.value([
          _box('a', 'Chili', 5, takes: {'2026-11-25': 3}),
        ]),
      );

      await plus(tester, 5);
      expect(portions(tester), 5);
    });

    testWidgets('its own row stays shown with nothing left, selected', (
      tester,
    ) async {
      await open(
        tester,
        current: current,
        stock: Future.value([
          _box('a', 'Chili', 3, takes: {'2026-11-25': 3}),
        ]),
      );

      expect(find.byKey(const ValueKey('lunchbox-stock-a')), findsOneWidget);
      final handle = tester.ensureSemantics();
      try {
        final semantics = tester.getSemantics(
          find.byKey(const ValueKey('lunchbox-stock-a')),
        );
        expect(
          semantics.getSemanticsData().flagsCollection.isSelected,
          Tristate.isTrue,
        );
      } finally {
        handle.dispose();
      }
      await plus(tester, 3);
      expect(portions(tester), 3);
    });
  });

  group('startLunchboxStockLoad', () {
    test('flag off: the service is never read', () {
      final service = _MockBoxes();

      final started = startLunchboxStockLoad(
        enabled: () => false,
        service: () => service,
      );

      expect(started, isNull);
      verifyZeroInteractions(service);
    });

    test('flag on: reads once; a failing read resolves to null', () async {
      final service = _MockBoxes();
      when(() => service.list()).thenThrow(StateError('offline'));

      final started = startLunchboxStockLoad(
        enabled: () => true,
        service: () => service,
      );

      expect(await started, isNull);
      verify(() => service.list()).called(1);
    });
  });
}
