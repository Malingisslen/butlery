// test/widget/common/indicators/filter_indicator_dot_test.dart
// Comprehensive tests for FilterIndicatorDot using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/indicators/filter_indicator_dot.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('FilterIndicatorDot Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Rendering', () {
      testWidgets('should render with default properties', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FilterIndicatorDot(),
            ),
          ),
        );

        expect(find.byType(FilterIndicatorDot), findsOneWidget);
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('should use default size from AppDimensions', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FilterIndicatorDot(),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(FilterIndicatorDot),
        );
        expect(renderBox.size.width, equals(AppDimensions.spacingS));
        expect(renderBox.size.height, equals(AppDimensions.spacingS));
      });

      testWidgets('should use theme error color by default', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light(
                error: Colors.red,
              ),
            ),
            home: const Scaffold(
              body: FilterIndicatorDot(),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.red));
      });

      testWidgets('should have circular shape', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FilterIndicatorDot(),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.shape, equals(BoxShape.circle));
      });
    });

    group('Customization', () {
      testWidgets('should apply custom color', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FilterIndicatorDot(color: Colors.blue),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.blue));
      });

      testWidgets('should apply custom size', (WidgetTester tester) async {
        const customSize = 16.0;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FilterIndicatorDot(size: customSize),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(FilterIndicatorDot),
        );
        expect(renderBox.size.width, equals(customSize));
        expect(renderBox.size.height, equals(customSize));
      });

      testWidgets('should apply both custom color and size', (WidgetTester tester) async {
        const customSize = 20.0;
        const customColor = Colors.green;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FilterIndicatorDot(
                color: customColor,
                size: customSize,
              ),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(FilterIndicatorDot),
        );
        expect(renderBox.size.width, equals(customSize));
        expect(renderBox.size.height, equals(customSize));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(customColor));
      });
    });

    group('Size Variations', () {
      testWidgets('should handle very small size', (WidgetTester tester) async {
        const smallSize = 4.0;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FilterIndicatorDot(size: smallSize),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(FilterIndicatorDot),
        );
        expect(renderBox.size.width, equals(smallSize));
        expect(renderBox.size.height, equals(smallSize));
      });

      testWidgets('should handle medium size', (WidgetTester tester) async {
        const mediumSize = 12.0;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FilterIndicatorDot(size: mediumSize),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(FilterIndicatorDot),
        );
        expect(renderBox.size.width, equals(mediumSize));
        expect(renderBox.size.height, equals(mediumSize));
      });

      testWidgets('should handle large size', (WidgetTester tester) async {
        const largeSize = 24.0;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FilterIndicatorDot(size: largeSize),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(FilterIndicatorDot),
        );
        expect(renderBox.size.width, equals(largeSize));
        expect(renderBox.size.height, equals(largeSize));
      });

      testWidgets('should maintain circular shape at all sizes', (WidgetTester tester) async {
        final sizes = [4.0, 8.0, 12.0, 16.0, 20.0, 24.0];
        
        for (final size in sizes) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: FilterIndicatorDot(size: size),
              ),
            ),
          );

          final renderBox = tester.renderObject<RenderBox>(
            find.byType(FilterIndicatorDot),
          );
          expect(renderBox.size.width, equals(renderBox.size.height));
          expect(renderBox.size.width, equals(size));
        }
      });
    });

    group('Color Variations', () {
      testWidgets('should work with primary color', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light(
                primary: Colors.blue,
              ),
            ),
            home: const Scaffold(
              body: FilterIndicatorDot(color: Colors.blue),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.blue));
      });

      testWidgets('should work with success color', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FilterIndicatorDot(color: Colors.green),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.green));
      });

      testWidgets('should work with warning color', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FilterIndicatorDot(color: Colors.orange),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.orange));
      });

      testWidgets('should work with custom colors', (WidgetTester tester) async {
        const customColors = [
          Colors.purple,
          Colors.teal,
          Colors.indigo,
          Colors.amber,
        ];

        for (final color in customColors) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: FilterIndicatorDot(color: color),
              ),
            ),
          );

          final container = tester.widget<Container>(find.byType(Container));
          final decoration = container.decoration as BoxDecoration;
          expect(decoration.color, equals(color));
        }
      });
    });

    group('Layout Integration', () {
      testWidgets('should work in Row layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  FilterIndicatorDot(color: Colors.red),
                  SizedBox(width: 8),
                  Text('Filters Active'),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(FilterIndicatorDot), findsOneWidget);
        expect(find.text('Filters Active'), findsOneWidget);
      });

      testWidgets('should work in Stack layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey[300],
                  ),
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: FilterIndicatorDot(
                      color: Colors.red,
                      size: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(FilterIndicatorDot), findsOneWidget);
      });

      testWidgets('should work with multiple indicators', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  FilterIndicatorDot(color: Colors.red, size: 8),
                  SizedBox(width: 4),
                  FilterIndicatorDot(color: Colors.green, size: 8),
                  SizedBox(width: 4),
                  FilterIndicatorDot(color: Colors.blue, size: 8),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(FilterIndicatorDot), findsNWidgets(3));
      });

      testWidgets('should work as badge overlay', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () {},
                  ),
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: FilterIndicatorDot(
                      color: Colors.red,
                      size: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(FilterIndicatorDot), findsOneWidget);
        expect(find.byIcon(Icons.filter_list), findsOneWidget);
      });
    });

    group('Theme Integration', () {
      testWidgets('should adapt to light theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: Brightness.light,
              colorScheme: const ColorScheme.light(
                error: Colors.red,
              ),
            ),
            home: const Scaffold(
              body: FilterIndicatorDot(),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.red));
      });

      testWidgets('should adapt to dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: const ColorScheme.dark(
                error: Colors.redAccent,
              ),
            ),
            home: const Scaffold(
              body: FilterIndicatorDot(),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.redAccent));
      });

      testWidgets('should use custom theme error color', (WidgetTester tester) async {
        const customErrorColor = Color(0xFFFF5722);
        
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light(
                error: customErrorColor,
              ),
            ),
            home: const Scaffold(
              body: FilterIndicatorDot(),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(customErrorColor));
      });
    });

    group('Use Cases', () {
      testWidgets('should indicate active filters', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () {},
                  ),
                  const FilterIndicatorDot(
                    color: Colors.red,
                    size: 8,
                  ),
                  const Text(' 3 filters'),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(FilterIndicatorDot), findsOneWidget);
        expect(find.text(' 3 filters'), findsOneWidget);
      });

      testWidgets('should work as status indicator', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ListTile(
                title: Text('Item Name'),
                trailing: FilterIndicatorDot(
                  color: Colors.green,
                  size: 10,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(FilterIndicatorDot), findsOneWidget);
        expect(find.text('Item Name'), findsOneWidget);
      });

      testWidgets('should work as notification indicator', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Icon(Icons.notifications, size: 32),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: FilterIndicatorDot(
                      color: Colors.red,
                      size: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(FilterIndicatorDot), findsOneWidget);
        expect(find.byIcon(Icons.notifications), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle zero size gracefully', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FilterIndicatorDot(size: 0),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(FilterIndicatorDot),
        );
        expect(renderBox.size.width, equals(0));
        expect(renderBox.size.height, equals(0));
      });

      testWidgets('should handle transparent color', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FilterIndicatorDot(color: Colors.transparent),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.transparent));
      });

      testWidgets('should handle very large size', (WidgetTester tester) async {
        const largeSize = 100.0;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FilterIndicatorDot(size: largeSize),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(FilterIndicatorDot),
        );
        expect(renderBox.size.width, equals(largeSize));
        expect(renderBox.size.height, equals(largeSize));
      });

      testWidgets('should render multiple dots in different states', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  FilterIndicatorDot(), // Default
                  FilterIndicatorDot(color: Colors.green), // Custom color
                  FilterIndicatorDot(size: 12), // Custom size
                  FilterIndicatorDot(color: Colors.blue, size: 16), // Both custom
                ],
              ),
            ),
          ),
        );

        expect(find.byType(FilterIndicatorDot), findsNWidgets(4));
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}