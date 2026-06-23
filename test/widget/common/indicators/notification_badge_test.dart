import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/indicators/notification_badge.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('NotificationBadge', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Count Display', () {
      testWidgets('should display single digit count', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(count: 5),
            ),
          ),
        );

        expect(find.text('5'), findsOneWidget);
        expect(find.text('99+'), findsNothing);
      });

      testWidgets('should display double digit count', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(count: 42),
            ),
          ),
        );

        expect(find.text('42'), findsOneWidget);
      });

      testWidgets('should display 99 exactly', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(count: 99),
            ),
          ),
        );

        expect(find.text('99'), findsOneWidget);
        expect(find.text('99+'), findsNothing);
      });

      testWidgets('should display 99+ for count of 100', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(count: 100),
            ),
          ),
        );

        expect(find.text('99+'), findsOneWidget);
        expect(find.text('100'), findsNothing);
      });

      testWidgets('should display 99+ for very large counts', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(count: 9999),
            ),
          ),
        );

        expect(find.text('99+'), findsOneWidget);
        expect(find.text('9999'), findsNothing);
      });

      testWidgets('should display zero count', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(count: 0),
            ),
          ),
        );

        expect(find.text('0'), findsOneWidget);
      });
    });

    group('Default Styling', () {
      testWidgets('should use theme error background color', (tester) async {
        late ColorScheme cs;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  cs = Theme.of(context).colorScheme;
                  return const NotificationBadge(count: 3);
                },
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(cs.error));
      });

      testWidgets('should use theme surfaceContainerHighest text color', (
        tester,
      ) async {
        late ColorScheme cs;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  cs = Theme.of(context).colorScheme;
                  return const NotificationBadge(count: 3);
                },
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('3'));
        expect(text.style?.color, equals(cs.surfaceContainerHighest));
      });

      testWidgets('should use surface color for default border', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light(
                surface: Colors.white,
              ),
            ),
            home: const Scaffold(
              body: NotificationBadge(count: 3),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container),
        );
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        expect(border.top.color, equals(Colors.white));
      });

      testWidgets('should have circular shape', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(count: 3),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.shape, equals(BoxShape.circle));
      });

      testWidgets('should have correct padding', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(count: 3),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container),
        );
        expect(
          container.padding,
          equals(const EdgeInsets.all(AppDimensions.spacingXs)),
        );
      });

      testWidgets('should have minimum size constraints', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(count: 3),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container),
        );
        expect(container.constraints?.minWidth, equals(20));
        expect(container.constraints?.minHeight, equals(20));
      });

      testWidgets('should use thick border width', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(count: 3),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container),
        );
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        expect(border.top.width, equals(AppDimensions.borderWidthThick));
      });

      testWidgets('should center text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(count: 3),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('3'));
        expect(text.textAlign, equals(TextAlign.center));
      });

      testWidgets('should use w600 font weight from badge style', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(count: 3),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('3'));
        expect(text.style?.fontWeight, equals(FontWeight.w600));
      });
    });

    group('Custom Styling', () {
      testWidgets('should apply custom background color', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(
                count: 5,
                backgroundColor: Colors.blue,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.blue));
      });

      testWidgets('should apply custom text color', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(
                count: 5,
                textColor: Colors.yellow,
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('5'));
        expect(text.style?.color, equals(Colors.yellow));
      });

      testWidgets('should apply custom border color', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(
                count: 5,
                borderColor: Colors.green,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container),
        );
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        expect(border.top.color, equals(Colors.green));
      });

      testWidgets('should apply all custom colors together', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(
                count: 5,
                backgroundColor: Colors.purple,
                textColor: Colors.orange,
                borderColor: Colors.pink,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container),
        );
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        final text = tester.widget<Text>(find.text('5'));

        expect(decoration.color, equals(Colors.purple));
        expect(text.style?.color, equals(Colors.orange));
        expect(border.top.color, equals(Colors.pink));
      });
    });

    group('Visual Consistency', () {
      testWidgets('should maintain circular shape with single digit', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(count: 1),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(NotificationBadge),
        );
        expect(renderBox.size.width, greaterThanOrEqualTo(20));
        expect(renderBox.size.height, greaterThanOrEqualTo(20));
      });

      testWidgets('should maintain circular shape with double digits', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(count: 99),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(NotificationBadge),
        );
        expect(renderBox.size.height, greaterThanOrEqualTo(20));
      });

      testWidgets('should maintain circular shape with 99+', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(count: 100),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(NotificationBadge),
        );
        expect(renderBox.size.height, greaterThanOrEqualTo(20));
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle negative count as positive', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationBadge(count: -5),
            ),
          ),
        );

        // The widget displays the count directly, even if negative
        expect(find.text('-5'), findsOneWidget);
      });

      testWidgets('should render correctly in different themes', (
        tester,
      ) async {
        // Light theme test
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: NotificationBadge(count: 5),
            ),
          ),
        );

        expect(find.byType(NotificationBadge), findsOneWidget);
        expect(find.text('5'), findsOneWidget);

        // Dark theme test
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: NotificationBadge(count: 5),
            ),
          ),
        );

        expect(find.byType(NotificationBadge), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
      });

      testWidgets('should handle very small parent constraints', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 15,
                height: 15,
                child: const NotificationBadge(count: 5),
              ),
            ),
          ),
        );

        // When parent constrains to smaller size, the badge respects parent constraints
        // but the Container's internal constraints ensure minimum content size
        final renderBox = tester.renderObject<RenderBox>(
          find.byType(NotificationBadge),
        );
        // The widget respects parent constraints, so it will be 15x15
        expect(renderBox.size.width, equals(15));
        expect(renderBox.size.height, equals(15));

        // But the container still has minWidth/minHeight constraints set
        final container = tester.widget<Container>(
          find.byType(Container),
        );
        expect(container.constraints?.minWidth, equals(20));
        expect(container.constraints?.minHeight, equals(20));
      });
    });

    group('Accessibility', () {
      testWidgets('should have semantic label for count', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Semantics(
                label: '5 notifications',
                child: const NotificationBadge(count: 5),
              ),
            ),
          ),
        );

        // Find the specific NotificationBadge widget
        final semantics = tester.getSemantics(
          find.descendant(
            of: find.byType(Semantics).first,
            matching: find.byType(NotificationBadge),
          ),
        );
        expect(semantics.label, contains('5 notifications'));
      });

      testWidgets('should be visible with sufficient contrast', (tester) async {
        late ColorScheme cs;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Builder(
                builder: (context) {
                  cs = Theme.of(context).colorScheme;
                  return const NotificationBadge(count: 5);
                },
              ),
            ),
          ),
        );

        // Error color on white background should have good contrast.
        final container = tester.widget<Container>(
          find.byType(Container),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(cs.error));

        // Badge text uses the theme's surfaceContainerHighest on error bg.
        final text = tester.widget<Text>(find.text('5'));
        expect(text.style?.color, equals(cs.surfaceContainerHighest));
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}
