/// Widget tests for InlineWarning.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/feedback/inline_warning.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders supplied text', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const InlineWarning(
          icon: ButleryIcons.triangleAlert,
          color: Colors.amber,
          text: 'Heads up',
        ),
      ),
    );
    expect(find.text('Heads up'), findsOneWidget);
  });

  testWidgets('renders supplied icon', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const InlineWarning(
          icon: ButleryIcons.info,
          color: Colors.blue,
          text: 'fyi',
        ),
      ),
    );
    expect(find.byIcon(ButleryIcons.info), findsOneWidget);
  });

  testWidgets('icon receives the supplied color', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const InlineWarning(
          icon: ButleryIcons.triangleAlert,
          color: Colors.red,
          text: 'oops',
        ),
      ),
    );
    final icon = tester.widget<Icon>(find.byType(ButleryIcon));
    expect(icon.color, Colors.red);
  });

  testWidgets('default text style is italic + uses supplied color', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const InlineWarning(
          icon: ButleryIcons.triangleAlert,
          color: Colors.red,
          text: 'oops',
        ),
      ),
    );
    final text = tester.widget<Text>(find.text('oops'));
    expect(text.style!.fontStyle, FontStyle.italic);
    expect(text.style!.color, Colors.red);
  });

  testWidgets('custom textStyle is honored when provided', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const InlineWarning(
          icon: ButleryIcons.info,
          color: Colors.blue,
          text: 'styled',
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
            fontSize: 22,
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text('styled'));
    expect(text.style!.fontWeight, FontWeight.bold);
    expect(text.style!.color, Colors.green);
    expect(text.style!.fontSize, 22);
  });

  testWidgets('layout: Row with Icon, Spacing, Expanded(Text)', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const InlineWarning(
          icon: ButleryIcons.triangleAlert,
          color: Colors.amber,
          text: 'x',
        ),
      ),
    );
    expect(find.byType(Row), findsOneWidget);
    expect(find.byType(ButleryIcon), findsOneWidget);
    expect(find.byType(Expanded), findsOneWidget);
  });

  testWidgets('long text wraps inside Expanded without overflow', (
    tester,
  ) async {
    final longText = 'A very long inline warning ' * 10;
    await tester.pumpWidget(
      _wrap(
        InlineWarning(
          icon: ButleryIcons.triangleAlert,
          color: Colors.amber,
          text: longText,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(ButleryIcon), findsOneWidget);
  });
}
