// test/widget/common/indicators/status_indicator_ultrathink_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/indicators/status_indicator.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('StatusIndicator Widget Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to create test environment with theme support
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Scaffold(
          body: child,
        ),
      );
    }
    group('Construction Tests', () {
      testWidgets('creates widget with required parameters', (tester) async {
        const testIcon = Icons.star;
        const testColor = Colors.blue;

        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: testIcon,
              color: testColor,
            ),
          ),
        );

        expect(find.byType(StatusIndicator), findsOneWidget);
        expect(find.byIcon(testIcon), findsOneWidget);
      });

      testWidgets('creates widget with all parameters', (tester) async {
        const testIcon = Icons.check_circle;
        const testColor = Colors.green;
        const testIconSize = 32.0;
        const testPadding = 12.0;

        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: testIcon,
              color: testColor,
              iconSize: testIconSize,
              padding: testPadding,
            ),
          ),
        );

        expect(find.byType(StatusIndicator), findsOneWidget);
        expect(find.byIcon(testIcon), findsOneWidget);
      });

      testWidgets('accepts different icon types', (tester) async {
        const icons = [
          Icons.star,
          Icons.warning,
          Icons.error,
          Icons.check_circle,
          Icons.info,
        ];

        for (final icon in icons) {
          await tester.pumpWidget(
            createTestWidget(
              StatusIndicator(
                icon: icon,
                color: Colors.red,
              ),
            ),
          );

          expect(find.byIcon(icon), findsOneWidget);
        }
      });

      testWidgets('accepts different color values', (tester) async {
        const colors = [
          Colors.red,
          Colors.blue,
          Colors.green,
          Colors.orange,
          Colors.purple,
          Color(0xFF123456),
        ];

        for (final color in colors) {
          await tester.pumpWidget(
            createTestWidget(
              StatusIndicator(
                icon: Icons.star,
                color: color,
              ),
            ),
          );

          expect(find.byType(StatusIndicator), findsOneWidget);
        }
      });
    });

    group('Container Styling Tests', () {
      testWidgets('applies correct container decoration', (tester) async {
        const testColor = Colors.blue;

        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: Icons.star,
              color: testColor,
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;

        expect(decoration.color, testColor.withValues(alpha: 0.1));
        expect(decoration.borderRadius, BorderRadius.circular(AppDimensions.borderRadiusS));
      });

      testWidgets('applies default padding when not specified', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: Icons.star,
              color: Colors.blue,
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, EdgeInsets.all(AppDimensions.spacingS));
      });

      testWidgets('applies custom padding when specified', (tester) async {
        const customPadding = 16.0;

        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: Icons.star,
              color: Colors.blue,
              padding: customPadding,
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, const EdgeInsets.all(customPadding));
      });

      testWidgets('handles zero padding correctly', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: Icons.star,
              color: Colors.blue,
              padding: 0.0,
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, const EdgeInsets.all(0.0));
      });

      testWidgets('handles large padding values', (tester) async {
        const largePadding = 50.0;

        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: Icons.star,
              color: Colors.blue,
              padding: largePadding,
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, const EdgeInsets.all(largePadding));
      });
    });

    group('Icon Properties Tests', () {
      testWidgets('applies correct icon properties with defaults', (tester) async {
        const testIcon = Icons.star;
        const testColor = Colors.blue;

        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: testIcon,
              color: testColor,
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(testIcon));
        expect(icon.icon, testIcon);
        expect(icon.color, testColor);
        expect(icon.size, AppDimensions.iconSizeAction);
      });

      testWidgets('applies custom icon size when specified', (tester) async {
        const testIconSize = 28.0;

        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: Icons.star,
              color: Colors.blue,
              iconSize: testIconSize,
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(icon.size, testIconSize);
      });

      testWidgets('handles zero icon size', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: Icons.star,
              color: Colors.blue,
              iconSize: 0.0,
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(icon.size, 0.0);
      });

      testWidgets('handles very large icon size', (tester) async {
        const largeIconSize = 100.0;

        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: Icons.star,
              color: Colors.blue,
              iconSize: largeIconSize,
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(icon.size, largeIconSize);
      });

      testWidgets('icon color matches specified color', (tester) async {
        const testColor = Color(0xFF123456);

        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: Icons.star,
              color: testColor,
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(icon.color, testColor);
      });
    });

    group('Alpha Transparency Tests', () {
      testWidgets('applies correct alpha transparency to background', (tester) async {
        const testColor = Colors.red;

        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: Icons.star,
              color: testColor,
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        
        expect(decoration.color, testColor.withValues(alpha: 0.1));
        expect((decoration.color!.a * 255.0).round() & 0xff, (255 * 0.1).round());
      });

      testWidgets('icon retains full opacity while background has alpha', (tester) async {
        const testColor = Colors.green;

        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: Icons.star,
              color: testColor,
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.star));
        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;

        // Icon should have full opacity
        expect(icon.color, testColor);
        expect((icon.color!.a * 255.0).round() & 0xff, 255);

        // Background should have alpha transparency
        expect(decoration.color, testColor.withValues(alpha: 0.1));
        expect((decoration.color!.a * 255.0).round() & 0xff, (255 * 0.1).round());
      });

      testWidgets('alpha transparency works with different colors', (tester) async {
        const colors = [
          Colors.red,
          Colors.blue,
          Colors.green,
          Colors.orange,
          Color(0xFF123456),
        ];

        for (final color in colors) {
          await tester.pumpWidget(
            createTestWidget(
              StatusIndicator(
                icon: Icons.star,
                color: color,
              ),
            ),
          );

          final container = tester.widget<Container>(find.byType(Container));
          final decoration = container.decoration as BoxDecoration;
          
          expect(decoration.color, color.withValues(alpha: 0.1));
          expect((decoration.color!.a * 255.0).round() & 0xff, (255 * 0.1).round());
        }
      });
    });

    group('Theme Integration Tests', () {
      testWidgets('uses AppDimensions constants correctly', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: Icons.star,
              color: Colors.blue,
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final icon = tester.widget<Icon>(find.byIcon(Icons.star));

        // Check default padding uses AppDimensions.spacingS
        expect(container.padding, EdgeInsets.all(AppDimensions.spacingS));

        // Check border radius uses AppDimensions.borderRadiusS
        expect(decoration.borderRadius, BorderRadius.circular(AppDimensions.borderRadiusS));

        // Check default icon size uses AppDimensions.iconSizeAction
        expect(icon.size, AppDimensions.iconSizeAction);
      });

      testWidgets('overrides work with theme constants', (tester) async {
        const customPadding = 20.0;
        const customIconSize = 30.0;

        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: Icons.star,
              color: Colors.blue,
              padding: customPadding,
              iconSize: customIconSize,
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final icon = tester.widget<Icon>(find.byIcon(Icons.star));

        // Custom values should override defaults
        expect(container.padding, const EdgeInsets.all(customPadding));
        expect(icon.size, customIconSize);

        // Border radius should still use theme constant
        expect(decoration.borderRadius, BorderRadius.circular(AppDimensions.borderRadiusS));
      });
    });

    group('Widget Structure Tests', () {
      testWidgets('has correct widget hierarchy', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: Icons.star,
              color: Colors.blue,
            ),
          ),
        );

        // Should have Container as root
        expect(find.byType(Container), findsOneWidget);
        
        // Should have Icon as child
        expect(find.byType(Icon), findsOneWidget);

        // Should have the correct parent-child relationship
        final container = find.byType(Container);
        final icon = find.byType(Icon);
        
        expect(find.descendant(of: container, matching: icon), findsOneWidget);
      });

      testWidgets('maintains consistent structure with different parameters', (tester) async {
        const variations = [
          StatusIndicator(icon: Icons.star, color: Colors.blue),
          StatusIndicator(icon: Icons.warning, color: Colors.red, padding: 10.0),
          StatusIndicator(icon: Icons.check, color: Colors.green, iconSize: 20.0),
          StatusIndicator(icon: Icons.info, color: Colors.orange, padding: 8.0, iconSize: 24.0),
        ];

        for (final variation in variations) {
          await tester.pumpWidget(createTestWidget(variation));

          // Each variation should have same structure
          expect(find.byType(Container), findsOneWidget);
          expect(find.byType(Icon), findsOneWidget);
        }
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('handles extreme color values', (tester) async {
        const extremeColors = [
          Colors.transparent,
          Colors.black,
          Colors.white,
          Color(0x00000000), // Fully transparent
          Color(0xFFFFFFFF), // Fully opaque white
        ];

        for (final color in extremeColors) {
          await tester.pumpWidget(
            createTestWidget(
              StatusIndicator(
                icon: Icons.star,
                color: color,
              ),
            ),
          );

          expect(find.byType(StatusIndicator), findsOneWidget);
          
          final container = tester.widget<Container>(find.byType(Container));
          final decoration = container.decoration as BoxDecoration;
          expect(decoration.color, color.withValues(alpha: 0.1));
        }
      });

      testWidgets('handles very small positive values correctly', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const StatusIndicator(
              icon: Icons.star,
              color: Colors.blue,
              padding: 0.1,
              iconSize: 0.1,
            ),
          ),
        );

        expect(find.byType(StatusIndicator), findsOneWidget);
        
        final container = tester.widget<Container>(find.byType(Container));
        final icon = tester.widget<Icon>(find.byIcon(Icons.star));
        
        expect(container.padding, const EdgeInsets.all(0.1));
        expect(icon.size, 0.1);
      });
    });
  });
}