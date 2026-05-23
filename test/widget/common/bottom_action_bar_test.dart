/// Widget tests for BottomActionBar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/bottom_action_bar.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders the supplied child widget', (tester) async {
    await tester.pumpWidget(_wrap(
      const BottomActionBar(child: Text('action')),
    ));
    expect(find.text('action'), findsOneWidget);
  });

  testWidgets('wraps child in a Container with surface background',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const BottomActionBar(child: SizedBox.shrink()),
    ));
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.byType(SizedBox).first,
            matching: find.byType(Container),
          )
          .first,
    );
    expect(container.decoration, isA<BoxDecoration>());
    final deco = container.decoration! as BoxDecoration;
    expect(deco.color, isNotNull);
    expect(deco.border, isA<Border>());
  });

  testWidgets('border is a 1px top divider', (tester) async {
    await tester.pumpWidget(_wrap(
      const BottomActionBar(child: SizedBox.shrink()),
    ));
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.byType(SizedBox).first,
            matching: find.byType(Container),
          )
          .first,
    );
    final border = (container.decoration! as BoxDecoration).border! as Border;
    expect(border.top.width, 1);
    expect(border.left, BorderSide.none);
    expect(border.right, BorderSide.none);
    expect(border.bottom, BorderSide.none);
  });

  testWidgets('uses theme dividerColor for the top border', (tester) async {
    final theme = ThemeData.light().copyWith(dividerColor: Colors.red);
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: const Scaffold(
        body: BottomActionBar(child: SizedBox.shrink()),
      ),
    ));
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.byType(SizedBox).first,
            matching: find.byType(Container),
          )
          .first,
    );
    final border = (container.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, Colors.red);
  });

  testWidgets('child receives padding (AppDimensions.spacingL)',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const BottomActionBar(child: SizedBox.shrink()),
    ));
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.byType(SizedBox).first,
            matching: find.byType(Container),
          )
          .first,
    );
    expect(container.padding, isA<EdgeInsets>());
    final padding = container.padding! as EdgeInsets;
    // All four sides equal (uses EdgeInsets.all)
    expect(padding.left, padding.right);
    expect(padding.top, padding.bottom);
    expect(padding.left, padding.top);
    expect(padding.left, greaterThan(0));
  });
}
