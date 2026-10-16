/// The saffron add square: busy keeps it saffron and named, with the plate
/// line, and a tap does nothing while it works.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/buttons/saffron_square_button.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

import '../../../test_support/semantics_announcement.dart';

/// Tabs until the focused element sits inside a widget of type [T].
Future<void> _tabInto<T extends Widget>(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus?.findAncestorWidgetOfExactType<T>() != null) return;
  }
  fail('focus never reached $T');
}

void main() {
  Widget host({required bool busy, required VoidCallback onPressed}) =>
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: SaffronSquareButton(
              semanticLabel: 'Lägg till',
              busyLabel: 'Lägger till …',
              busy: busy,
              onPressed: onPressed,
            ),
          ),
        ),
      );

  testWidgets('at rest it adds on tap and a screen reader can activate it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(host(busy: false, onPressed: () => taps++));

    expect(find.byType(ButtonPlateLine), findsNothing);
    expectActivatable(tester, find.bySemanticsLabel('Lägg till'));
    await tester.tap(find.byType(SaffronSquareButton));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('busy draws the plate line, says what it does and ignores taps', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(host(busy: true, onPressed: () => taps++));

    expect(find.byType(ButtonPlateLine), findsOneWidget);
    expect(find.bySemanticsLabel('Lägger till …'), findsOneWidget);
    await tester.tap(find.byType(SaffronSquareButton), warnIfMissed: false);
    expect(taps, 0);
    handle.dispose();
  });

  testWidgets('busy: Enter on the focused button activates nothing', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(host(busy: true, onPressed: () => taps++));

    await _tabInto<SaffronSquareButton>(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('not busy: Enter on the focused button activates it', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(host(busy: false, onPressed: () => taps++));

    await _tabInto<SaffronSquareButton>(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
  });
}
