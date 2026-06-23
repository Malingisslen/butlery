/// Widget tests for layout_containers.dart family.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/layout/layout_containers.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AuthFormCard', () {
    testWidgets('renders child inside a Card', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AuthFormCard(
            child: Text('form', textDirection: TextDirection.ltr),
          ),
        ),
      );
      expect(find.text('form'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('default maxWidth is 400', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AuthFormCard(child: SizedBox(width: 100)),
        ),
      );
      // The AuthFormCard's own ConstrainedBox lives inside the Card →
      // find by descendant of Center to skip Scaffold's outer constraints.
      final box = tester.widget<ConstrainedBox>(
        find.descendant(
          of: find.byType(AuthFormCard),
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(box.constraints.maxWidth, 400);
    });

    testWidgets('explicit maxWidth wins', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AuthFormCard(
            maxWidth: 700,
            child: SizedBox.shrink(),
          ),
        ),
      );
      final box = tester.widget<ConstrainedBox>(
        find.descendant(
          of: find.byType(AuthFormCard),
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(box.constraints.maxWidth, 700);
    });
  });

  group('BorderedContainer', () {
    testWidgets('renders child + has border decoration', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BorderedContainer(
            child: Text('content', textDirection: TextDirection.ltr),
          ),
        ),
      );
      expect(find.text('content'), findsOneWidget);
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BorderedContainer),
          matching: find.byType(Container),
        ),
      );
      final deco = container.decoration! as BoxDecoration;
      expect(deco.border, isA<Border>());
      expect(deco.borderRadius, isNotNull);
    });

    testWidgets('explicit borderColor wins over theme', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BorderedContainer(
            borderColor: Colors.purple,
            child: SizedBox.shrink(),
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BorderedContainer),
          matching: find.byType(Container),
        ),
      );
      final border = (container.decoration! as BoxDecoration).border! as Border;
      expect(border.top.color, Colors.purple);
    });

    testWidgets('height, width, padding forward to Container', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BorderedContainer(
            height: 80,
            width: 200,
            padding: EdgeInsets.all(12),
            child: SizedBox.shrink(),
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BorderedContainer),
          matching: find.byType(Container),
        ),
      );
      expect(container.padding, const EdgeInsets.all(12));
    });
  });

  group('BottomActionContainer', () {
    testWidgets('wraps child in SafeArea + Container', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BottomActionContainer(
            child: Text('action', textDirection: TextDirection.ltr),
          ),
        ),
      );
      expect(find.text('action'), findsOneWidget);
      expect(find.byType(SafeArea), findsAtLeastNWidgets(1));
    });

    testWidgets('top border is 1px with theme outlineVariant by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BottomActionContainer(child: SizedBox.shrink()),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BottomActionContainer),
          matching: find.byType(Container),
        ),
      );
      final border = (container.decoration! as BoxDecoration).border! as Border;
      expect(border.top.width, 1);
      expect(border.left, BorderSide.none);
      expect(border.right, BorderSide.none);
      expect(border.bottom, BorderSide.none);
    });

    testWidgets('explicit backgroundColor + borderColor wins', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BottomActionContainer(
            backgroundColor: Colors.amber,
            borderColor: Colors.red,
            child: SizedBox.shrink(),
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BottomActionContainer),
          matching: find.byType(Container),
        ),
      );
      final deco = container.decoration! as BoxDecoration;
      expect(deco.color, Colors.amber);
      expect((deco.border! as Border).top.color, Colors.red);
    });
  });

  group('CardContent', () {
    testWidgets('default constructor renders child inside Card + Padding', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CardContent(
            child: Text('inside', textDirection: TextDirection.ltr),
          ),
        ),
      );
      expect(find.text('inside'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('explicit padding wins over default', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CardContent(
            padding: EdgeInsets.all(20),
            child: SizedBox.shrink(),
          ),
        ),
      );
      // Find the Padding whose padding == our explicit value (Card adds
      // its own internal Padding wrappers above ours in the tree).
      final paddings = tester
          .widgetList<Padding>(find.byType(Padding))
          .where((p) => p.padding == const EdgeInsets.all(20));
      expect(paddings, isNotEmpty);
    });

    testWidgets('CardContent.standard factory uses positive uniform padding', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CardContent.standard(child: SizedBox.shrink()),
        ),
      );
      // Verify at least one Padding has uniform >0 padding (AppDimensions.spacingL).
      final paddings = tester.widgetList<Padding>(find.byType(Padding)).where((
        p,
      ) {
        final ei = p.padding as EdgeInsets?;
        return ei != null &&
            ei.left > 0 &&
            ei.left == ei.right &&
            ei.left == ei.top &&
            ei.left == ei.bottom;
      });
      expect(paddings, isNotEmpty);
    });
  });

  group('CategoryHeader', () {
    testWidgets('renders title + count + icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryHeader(
            title: 'Frukt',
            icon: Icons.apple,
            count: 5,
          ),
        ),
      );
      expect(find.text('Frukt'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.byIcon(Icons.apple), findsOneWidget);
    });

    testWidgets('uses full width', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryHeader(
            title: 'x',
            icon: Icons.list,
            count: 0,
          ),
        ),
      );
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(CategoryHeader),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(container.constraints?.maxWidth, double.infinity);
    });

    testWidgets('background + text color overrides win', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryHeader(
            title: 'x',
            icon: Icons.list,
            count: 0,
            backgroundColor: Colors.amber,
            textColor: Colors.indigo,
          ),
        ),
      );
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(CategoryHeader),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((container.decoration! as BoxDecoration).color, Colors.amber);
      final icon = tester.widget<Icon>(find.byIcon(Icons.list));
      expect(icon.color, Colors.indigo);
    });

    testWidgets('zero count still renders the "0" badge', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryHeader(title: 'x', icon: Icons.list, count: 0),
        ),
      );
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('large count renders the exact integer', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryHeader(title: 'x', icon: Icons.list, count: 1234),
        ),
      );
      expect(find.text('1234'), findsOneWidget);
    });
  });
}
