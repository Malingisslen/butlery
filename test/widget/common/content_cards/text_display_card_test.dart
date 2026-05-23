/// Widget tests for TextDisplayCard.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/content_cards/text_display_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders the supplied text', (tester) async {
    await tester.pumpWidget(_wrap(
      const TextDisplayCard(text: 'OCR scan result'),
    ));
    expect(find.text('OCR scan result'), findsOneWidget);
  });

  testWidgets('scrollable=true (default) wraps in SingleChildScrollView',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const TextDisplayCard(text: 'content'),
    ));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('scrollable=false omits SingleChildScrollView wrapper',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const TextDisplayCard(text: 'content', scrollable: false),
    ));
    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  testWidgets('container decoration has border + rounded corners',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const TextDisplayCard(text: 'content'),
    ));
    final container = tester.widget<Container>(find.descendant(
      of: find.byType(TextDisplayCard),
      matching: find.byType(Container),
    ));
    final deco = container.decoration! as BoxDecoration;
    expect(deco.border, isA<Border>());
    expect(deco.borderRadius, isNotNull);
    expect(deco.color, isNotNull);
  });

  testWidgets('explicit backgroundColor wins over theme', (tester) async {
    await tester.pumpWidget(_wrap(
      const TextDisplayCard(
        text: 'content',
        backgroundColor: Colors.amber,
      ),
    ));
    final container = tester.widget<Container>(find.descendant(
      of: find.byType(TextDisplayCard),
      matching: find.byType(Container),
    ));
    expect((container.decoration! as BoxDecoration).color, Colors.amber);
  });

  testWidgets('explicit borderColor wins over theme', (tester) async {
    await tester.pumpWidget(_wrap(
      const TextDisplayCard(
        text: 'content',
        borderColor: Colors.red,
      ),
    ));
    final container = tester.widget<Container>(find.descendant(
      of: find.byType(TextDisplayCard),
      matching: find.byType(Container),
    ));
    final border = (container.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, Colors.red);
  });

  testWidgets('explicit padding wins over default', (tester) async {
    await tester.pumpWidget(_wrap(
      const TextDisplayCard(
        text: 'content',
        padding: EdgeInsets.all(8),
      ),
    ));
    final container = tester.widget<Container>(find.descendant(
      of: find.byType(TextDisplayCard),
      matching: find.byType(Container),
    ));
    expect(container.padding, const EdgeInsets.all(8));
  });

  testWidgets('explicit textStyle wins over default', (tester) async {
    await tester.pumpWidget(_wrap(
      const TextDisplayCard(
        text: 'content',
        textStyle: TextStyle(fontSize: 22, color: Colors.purple),
      ),
    ));
    final text = tester.widget<Text>(find.text('content'));
    expect(text.style!.fontSize, 22);
    expect(text.style!.color, Colors.purple);
  });

  testWidgets('renders multi-line content', (tester) async {
    final long = 'Line 1\n' * 20;
    await tester.pumpWidget(_wrap(
      TextDisplayCard(text: long),
    ));
    expect(find.byType(Text), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });
}
