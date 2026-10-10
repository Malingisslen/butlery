/// BUT-2339: the report flag and the "not my dish" button on a dish credit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/menu/dish_credit_line.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onReport,
  VoidCallback? onNotMine,
  double textScale = 1,
  String name = 'Anna',
}) => tester.pumpWidget(
  MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: createLocalizedTestApp(
      child: SizedBox(
        width: 320,
        child: DishCreditLine(
          userId: 'u1',
          displayName: name,
          onReport: onReport,
          onNotMine: onNotMine,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('without callbacks neither button is shown', (tester) async {
    await _pump(tester);

    expect(find.byType(IconButton), findsNothing);
    expect(find.text('Det här är inte min rätt'), findsNothing);
  });

  testWidgets('onReport shows a 48dp flag button with its tooltip', (
    tester,
  ) async {
    var reported = 0;
    await _pump(tester, onReport: () => reported++);

    final button = find.byTooltip('Anmäl rätten');
    expect(button, findsOneWidget);
    final size = tester.getSize(button);
    expect(size.width, greaterThanOrEqualTo(AppDimensions.minTouchTarget));
    expect(size.height, greaterThanOrEqualTo(AppDimensions.minTouchTarget));

    await tester.tap(button);
    expect(reported, 1);
  });

  testWidgets(
    'the flag button is announced as a button with the report label',
    (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await _pump(tester, onReport: () {});

        final data = tester
            .getSemantics(find.byTooltip('Anmäl rätten'))
            .getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.tooltip, 'Anmäl rätten');
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets('onNotMine shows a button of at least 48dp under the row', (
    tester,
  ) async {
    var withdrawn = 0;
    await _pump(tester, onNotMine: () => withdrawn++);

    final button = find.text('Det här är inte min rätt');
    expect(button, findsOneWidget);
    expect(
      tester
          .getSize(find.ancestor(of: button, matching: find.byType(TextButton)))
          .height,
      greaterThanOrEqualTo(AppDimensions.minTouchTarget),
    );
    expect(
      tester.getTopLeft(button).dy,
      greaterThan(tester.getTopLeft(find.text('Recept av Anna')).dy),
    );

    await tester.tap(button);
    expect(withdrawn, 1);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('both controls fit at 200 % text without overflow', (
    tester,
  ) async {
    await _pump(
      tester,
      onReport: () {},
      onNotMine: () {},
      textScale: 2,
      name: 'Ett mycket långt visningsnamn som måste brytas över flera rader',
    );

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Anmäl rätten'), findsOneWidget);
    expect(find.text('Det här är inte min rätt'), findsOneWidget);
  });
}
