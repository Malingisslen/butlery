import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/mina_recept/library_switch.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Future<List<bool>> pumpSwitch(
    WidgetTester tester, {
    required bool showCookbooks,
    double textScale = 1.0,
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
            ).copyWith(textScaler: TextScaler.linear(textScale)),
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

  Matcher tab({required bool selected}) => containsSemantics(
    isButton: true,
    hasSelectedState: true,
    isSelected: selected,
  );

  testWidgets('both tabs render with their Swedish labels', (tester) async {
    await pumpSwitch(tester, showCookbooks: false);

    expect(find.text('Alla recept'), findsOneWidget);
    expect(find.text('Kokböcker'), findsOneWidget);
  });

  testWidgets('only the chosen tab reports itself as selected', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpSwitch(tester, showCookbooks: false);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Alla recept')),
        tab(selected: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Kokböcker')),
        tab(selected: false),
      );

      await pumpSwitch(tester, showCookbooks: true);
      await tester.pump();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Alla recept')),
        tab(selected: false),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Kokböcker')),
        tab(selected: true),
      );
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

  testWidgets('at 200 % text both tabs stay and are at least a touch target '
      'high', (tester) async {
    final changes = await pumpSwitch(
      tester,
      showCookbooks: false,
      textScale: 2.0,
    );

    expect(find.text('Alla recept'), findsOneWidget);
    expect(find.text('Kokböcker'), findsOneWidget);
    final tabs = find.byType(InkWell);
    expect(tabs, findsNWidgets(2));
    for (final tab in tabs.evaluate()) {
      expect(
        tester.getSize(find.byElementPredicate((e) => e == tab)).height,
        greaterThanOrEqualTo(AppDimensions.minTouchTarget),
      );
    }

    await tester.tap(find.text('Kokböcker'));
    await tester.pump();
    expect(changes, [true]);
    await tester.tap(find.text('Alla recept'));
    await tester.pump();
    expect(changes, [true, false]);
    expect(tester.takeException(), isNull);
  });
}
