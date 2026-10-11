import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/views/mina_recept/library_switch.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Future<List<bool>> pumpSwitch(
    WidgetTester tester, {
    required bool showCookbooks,
  }) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: LibrarySwitch(
          showCookbooks: showCookbooks,
          onChanged: changes.add,
        ),
      ),
    );
    return changes;
  }

  // A single-choice SegmentedButton reports its chosen segment as checked
  // within a mutually exclusive group.
  Matcher chosen(bool isChosen) => containsSemantics(
    hasCheckedState: true,
    isChecked: isChosen,
    isInMutuallyExclusiveGroup: true,
  );

  testWidgets('both segments render with their Swedish labels', (tester) async {
    await pumpSwitch(tester, showCookbooks: false);

    expect(find.text('Alla recept'), findsOneWidget);
    expect(find.text('Kokböcker'), findsOneWidget);
  });

  testWidgets('only the chosen segment reports itself as selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpSwitch(tester, showCookbooks: false);
      expect(tester.getSemantics(find.text('Alla recept')), chosen(true));
      expect(tester.getSemantics(find.text('Kokböcker')), chosen(false));

      await pumpSwitch(tester, showCookbooks: true);
      await tester.pump();
      expect(tester.getSemantics(find.text('Alla recept')), chosen(false));
      expect(tester.getSemantics(find.text('Kokböcker')), chosen(true));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('tapping Kokböcker asks for the cookbooks', (tester) async {
    final changes = await pumpSwitch(tester, showCookbooks: false);

    await tester.tap(find.text('Kokböcker'));
    await tester.pump();

    expect(changes, [true]);
  });

  testWidgets('tapping Alla recept from the shelf asks for the library', (
    tester,
  ) async {
    final changes = await pumpSwitch(tester, showCookbooks: true);

    await tester.tap(find.text('Alla recept'));
    await tester.pump();

    expect(changes, [false]);
  });

  group('at large text on a narrow phone', () {
    Future<List<bool>> pumpLarge(
      WidgetTester tester, {
      required bool showCookbooks,
    }) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final changes = <bool>[];
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: LibrarySwitch(
                showCookbooks: showCookbooks,
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      );
      return changes;
    }

    ChoiceChip chip(WidgetTester tester, String label) =>
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

    testWidgets('the switch becomes two chips, not a segmented button', (
      tester,
    ) async {
      await pumpLarge(tester, showCookbooks: false);

      expect(find.byType(SegmentedButton<bool>), findsNothing);
      expect(find.byType(ChoiceChip), findsNWidgets(2));
      expect(find.text('Alla recept'), findsOneWidget);
      expect(find.text('Kokböcker'), findsOneWidget);
    });

    testWidgets('only the chosen chip is selected', (tester) async {
      await pumpLarge(tester, showCookbooks: true);

      expect(chip(tester, 'Alla recept').selected, isFalse);
      expect(chip(tester, 'Kokböcker').selected, isTrue);
    });

    testWidgets('tapping Kokböcker asks for the cookbooks, tapping the chip '
        'already chosen asks for nothing', (tester) async {
      final changes = await pumpLarge(tester, showCookbooks: false);

      await tester.tap(find.text('Alla recept'));
      await tester.pump();
      expect(changes, isEmpty);

      await tester.tap(find.text('Kokböcker'));
      await tester.pump();
      expect(changes, [true]);
    });
  });
}
