/// Widget tests for TextDisplayCard.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/content_cards/text_display_card.dart';
import 'package:butlery/widgets/styled/styled_card.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('renders the supplied text', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TextDisplayCard(text: 'OCR scan result'),
      ),
    );
    expect(find.text('OCR scan result'), findsOneWidget);
  });

  testWidgets('scrollable=true (default) wraps in SingleChildScrollView', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const TextDisplayCard(text: 'content'),
      ),
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('scrollable=false omits SingleChildScrollView wrapper', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const TextDisplayCard(text: 'content', scrollable: false),
      ),
    );
    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  testWidgets('draws the one card: a StyledCard', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TextDisplayCard(text: 'content'),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(TextDisplayCard),
        matching: find.byType(StyledCard),
      ),
      findsOneWidget,
    );
  });

  testWidgets('explicit padding wins over default', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TextDisplayCard(
          text: 'content',
          padding: EdgeInsets.all(8),
        ),
      ),
    );
    final card = tester.widget<StyledCard>(find.byType(StyledCard));
    expect(card.padding, const EdgeInsets.all(8));
  });

  testWidgets('explicit textStyle wins over default', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TextDisplayCard(
          text: 'content',
          textStyle: TextStyle(fontSize: 22, color: Colors.purple),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text('content'));
    expect(text.style!.fontSize, 22);
    expect(text.style!.color, Colors.purple);
  });

  testWidgets('renders multi-line content', (tester) async {
    final long = 'Line 1\n' * 20;
    await tester.pumpWidget(
      _wrap(
        TextDisplayCard(text: long),
      ),
    );
    expect(find.byType(Text), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });
}
