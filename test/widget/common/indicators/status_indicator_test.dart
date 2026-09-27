import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/status_indicator.dart';
import 'package:butlery/theme/app_dimensions.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';

// Comprehensive widget test for StatusIndicator following ultrathink methodology
void main() {
  setUp(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('StatusIndicator Tests', () {
    group('Basic Rendering', () {
      testWidgets('renders with required icon and color', (
        WidgetTester tester,
      ) async {
        const testIcon = ButleryIcons.circleCheck;
        const testColor = Colors.green;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusIndicator(
                icon: testIcon,
                color: testColor,
              ),
            ),
          ),
        );

        expect(find.byType(StatusIndicator), findsOneWidget);
        expect(find.byIcon(testIcon), findsOneWidget);
        expect(find.byType(Container), findsOneWidget);
        expect(find.byType(ButleryIcon), findsOneWidget);
      });

      testWidgets('applies correct icon color', (WidgetTester tester) async {
        const testColor = Colors.blue;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusIndicator(
                icon: ButleryIcons.info,
                color: testColor,
              ),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byType(ButleryIcon));
        expect(icon.color, equals(testColor));
      });

      testWidgets('applies correct background color with alpha', (
        WidgetTester tester,
      ) async {
        const testColor = Colors.red;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusIndicator(
                icon: ButleryIcons.triangleAlert,
                color: testColor,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(testColor.withValues(alpha: 0.1)));
      });

      testWidgets('applies correct border radius', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusIndicator(
                icon: ButleryIcons.triangleAlert,
                color: Colors.orange,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(
          decoration.borderRadius,
          equals(BorderRadius.circular(AppDimensions.radiusControl)),
        );
      });
    });

    group('Custom Properties', () {
      testWidgets('uses custom icon size when provided', (
        WidgetTester tester,
      ) async {
        const customSize = 32.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusIndicator(
                icon: ButleryIcons.star,
                color: Colors.amber,
                iconSize: customSize,
              ),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byType(ButleryIcon));
        expect(icon.size, equals(customSize));
      });

      testWidgets('uses default icon size when not provided', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusIndicator(
                icon: ButleryIcons.star,
                color: Colors.amber,
              ),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byType(ButleryIcon));
        expect(icon.size, equals(AppDimensions.iconSizeAction));
      });

      testWidgets('uses custom padding when provided', (
        WidgetTester tester,
      ) async {
        const customPadding = 16.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusIndicator(
                icon: ButleryIcons.heart,
                color: Colors.pink,
                padding: customPadding,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(const EdgeInsets.all(customPadding)));
      });

      testWidgets('uses default padding when not provided', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusIndicator(
                icon: ButleryIcons.heart,
                color: Colors.pink,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(
          container.padding,
          equals(EdgeInsets.all(AppDimensions.space4)),
        );
      });
    });

    group('Different Status Types', () {
      testWidgets('renders success status correctly', (
        WidgetTester tester,
      ) async {
        const successColor = Colors.green;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusIndicator(
                icon: ButleryIcons.circleCheck,
                color: successColor,
              ),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(ButleryIcons.circleCheck));
        expect(icon.color, equals(successColor));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(successColor.withValues(alpha: 0.1)));
      });

      testWidgets('renders warning status correctly', (
        WidgetTester tester,
      ) async {
        const warningColor = Colors.orange;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusIndicator(
                icon: ButleryIcons.triangleAlert,
                color: warningColor,
              ),
            ),
          ),
        );

        final icon = tester.widget<Icon>(
          find.byIcon(ButleryIcons.triangleAlert),
        );
        expect(icon.color, equals(warningColor));
      });

      testWidgets('renders error status correctly', (
        WidgetTester tester,
      ) async {
        const errorColor = Colors.red;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusIndicator(
                icon: ButleryIcons.triangleAlert,
                color: errorColor,
              ),
            ),
          ),
        );

        final icon = tester.widget<Icon>(
          find.byIcon(ButleryIcons.triangleAlert),
        );
        expect(icon.color, equals(errorColor));
      });

      testWidgets('renders info status correctly', (WidgetTester tester) async {
        const infoColor = Colors.blue;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusIndicator(
                icon: ButleryIcons.info,
                color: infoColor,
              ),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(ButleryIcons.info));
        expect(icon.color, equals(infoColor));
      });
    });

    group('Layout and Styling', () {
      testWidgets('renders correctly in Row layout', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  StatusIndicator(
                    icon: ButleryIcons.check,
                    color: Colors.green,
                  ),
                  StatusIndicator(
                    icon: ButleryIcons.x,
                    color: Colors.red,
                  ),
                  StatusIndicator(
                    icon: Icons.pending,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(StatusIndicator), findsNWidgets(3));
        expect(find.byIcon(ButleryIcons.check), findsOneWidget);
        expect(find.byIcon(ButleryIcons.x), findsOneWidget);
        expect(find.byIcon(Icons.pending), findsOneWidget);
      });

      testWidgets('renders correctly in Column layout', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  StatusIndicator(
                    icon: ButleryIcons.utensils,
                    color: Colors.brown,
                  ),
                  StatusIndicator(
                    icon: Icons.local_grocery_store,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(StatusIndicator), findsNWidgets(2));
      });

      testWidgets('maintains consistent size regardless of icon', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  StatusIndicator(
                    icon: Icons.home,
                    color: Colors.blue,
                  ),
                  StatusIndicator(
                    icon: ButleryIcons.check,
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ),
        );

        final firstSize = tester.getSize(find.byType(StatusIndicator).first);
        final secondSize = tester.getSize(find.byType(StatusIndicator).last);

        // Both indicators should have the same size
        expect(firstSize, equals(secondSize));
      });

      testWidgets('works with very small padding', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusIndicator(
                icon: ButleryIcons.star,
                color: Colors.yellow,
                padding: 2.0,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(const EdgeInsets.all(2.0)));
      });

      testWidgets('works with large padding', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusIndicator(
                icon: ButleryIcons.star,
                color: Colors.yellow,
                padding: 24.0,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(const EdgeInsets.all(24.0)));
      });
    });

    group('Accessibility', () {
      testWidgets('supports semantic labels through icon', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatusIndicator(
                icon: ButleryIcons.circleCheck,
                color: Colors.green,
              ),
            ),
          ),
        );

        // Icon widget supports semantics internally
        expect(find.byType(ButleryIcon), findsOneWidget);
      });

      testWidgets('renders correctly with different theme modes', (
        WidgetTester tester,
      ) async {
        // Test with light theme
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: StatusIndicator(
                icon: Icons.brightness_6,
                color: Colors.purple,
              ),
            ),
          ),
        );

        expect(find.byType(StatusIndicator), findsOneWidget);

        // Test with dark theme
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: StatusIndicator(
                icon: Icons.brightness_6,
                color: Colors.purple,
              ),
            ),
          ),
        );

        expect(find.byType(StatusIndicator), findsOneWidget);
      });
    });
  });
}
