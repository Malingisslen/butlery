// The typing line names who is typing, in the app's language, and folds a
// crowd into "N andra" with the right singular.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/messaging/typing_indicator.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

Future<void> _pump(
  WidgetTester tester,
  List<String> names, {
  Locale locale = const Locale('sv'),
}) async {
  await tester.pumpWidget(
    createLocalizedTestApp(
      locale: locale,
      child: TypingIndicator(typingUserNames: names),
    ),
  );
  await tester.pump();
}

void main() {
  group('Swedish', () {
    testWidgets('one name', (tester) async {
      await _pump(tester, ['Anna']);
      expect(find.text('Anna skriver'), findsOneWidget);
    });

    testWidgets('two names', (tester) async {
      await _pump(tester, ['Anna', 'Bo']);
      expect(find.text('Anna och Bo skriver'), findsOneWidget);
    });

    testWidgets('three names count exactly one other', (tester) async {
      await _pump(tester, ['Anna', 'Bo', 'Cecilia']);
      expect(find.text('Anna, Bo och 1 annan skriver'), findsOneWidget);
    });

    testWidgets('four names count two others, plural', (tester) async {
      await _pump(tester, ['Anna', 'Bo', 'Cecilia', 'David']);
      expect(find.text('Anna, Bo och 2 andra skriver'), findsOneWidget);
    });
  });

  testWidgets('English reads in English for one, two and four names', (
    tester,
  ) async {
    const en = Locale('en');
    await _pump(tester, ['Anna'], locale: en);
    expect(find.text('Anna is typing'), findsOneWidget);

    await _pump(tester, ['Anna', 'Bo'], locale: en);
    expect(find.text('Anna and Bo are typing'), findsOneWidget);

    await _pump(tester, ['Anna', 'Bo', 'Cecilia', 'David'], locale: en);
    expect(find.text('Anna, Bo and 2 others are typing'), findsOneWidget);
  });
}
