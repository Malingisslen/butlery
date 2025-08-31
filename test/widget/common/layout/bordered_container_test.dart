// test/widget/common/layout/bordered_container_test.dart
// Comprehensive tests for BorderedContainer using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/layout/bordered_container.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('BorderedContainer Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Basic Rendering', () {
      testWidgets('should render with required child', (WidgetTester tester) async {
        const testChild = Text('Test Content');
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                child: testChild,
              ),
            ),
          ),
        );

        expect(find.byType(BorderedContainer), findsOneWidget);
        expect(find.byType(Container), findsOneWidget);
        expect(find.text('Test Content'), findsOneWidget);
      });

      testWidgets('should have correct default border radius', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(
          decoration.borderRadius,
          equals(BorderRadius.circular(AppDimensions.borderRadiusM)),
        );
      });

      testWidgets('should use theme outline color by default', (WidgetTester tester) async {
        const themeOutlineColor = Colors.grey;
        
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light().copyWith(
                outline: themeOutlineColor,
              ),
            ),
            home: const Scaffold(
              body: BorderedContainer(
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        expect(border.top.color, equals(themeOutlineColor));
      });

      testWidgets('should have no default padding', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, isNull);
      });

      testWidgets('should have no default dimensions', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints, isNull);
      });
    });

    group('Custom Properties', () {
      testWidgets('should use custom border color', (WidgetTester tester) async {
        const customBorderColor = Colors.red;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                borderColor: customBorderColor,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        expect(border.top.color, equals(customBorderColor));
        expect(border.right.color, equals(customBorderColor));
        expect(border.bottom.color, equals(customBorderColor));
        expect(border.left.color, equals(customBorderColor));
      });

      testWidgets('should use custom padding', (WidgetTester tester) async {
        const customPadding = EdgeInsets.all(16);
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                padding: customPadding,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(customPadding));
      });

      testWidgets('should use custom height', (WidgetTester tester) async {
        const customHeight = 100.0;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                height: customHeight,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.minHeight, equals(customHeight));
        expect(container.constraints?.maxHeight, equals(customHeight));
      });

      testWidgets('should use custom width', (WidgetTester tester) async {
        const customWidth = 200.0;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                width: customWidth,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.minWidth, equals(customWidth));
        expect(container.constraints?.maxWidth, equals(customWidth));
      });

      testWidgets('should use all custom properties together', (WidgetTester tester) async {
        const customBorderColor = Colors.blue;
        const customPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 10);
        const customHeight = 80.0;
        const customWidth = 150.0;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                borderColor: customBorderColor,
                padding: customPadding,
                height: customHeight,
                width: customWidth,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        
        expect(border.top.color, equals(customBorderColor));
        expect(container.padding, equals(customPadding));
        expect(container.constraints?.minHeight, equals(customHeight));
        expect(container.constraints?.maxHeight, equals(customHeight));
        expect(container.constraints?.minWidth, equals(customWidth));
        expect(container.constraints?.maxWidth, equals(customWidth));
      });
    });

    group('Theme Integration', () {
      testWidgets('should work with light theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: BorderedContainer(
                child: Text('Content'),
              ),
            ),
          ),
        );

        expect(find.byType(BorderedContainer), findsOneWidget);
        expect(find.text('Content'), findsOneWidget);
        
        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.border, isNotNull);
      });

      testWidgets('should work with dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: BorderedContainer(
                child: Text('Content'),
              ),
            ),
          ),
        );

        expect(find.byType(BorderedContainer), findsOneWidget);
        expect(find.text('Content'), findsOneWidget);
        
        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.border, isNotNull);
      });

      testWidgets('should adapt to custom theme outline color', (WidgetTester tester) async {
        const customOutlineColor = Colors.purple;
        
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light().copyWith(
                outline: customOutlineColor,
              ),
            ),
            home: const Scaffold(
              body: BorderedContainer(
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        expect(border.top.color, equals(customOutlineColor));
      });

      testWidgets('should override theme color with custom border color', (WidgetTester tester) async {
        const themeOutlineColor = Colors.blue;
        const customBorderColor = Colors.red;
        
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light().copyWith(
                outline: themeOutlineColor,
              ),
            ),
            home: const Scaffold(
              body: BorderedContainer(
                borderColor: customBorderColor,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        expect(border.top.color, equals(customBorderColor));
        expect(border.top.color, isNot(equals(themeOutlineColor)));
      });
    });

    group('Layout Integration', () {
      testWidgets('should work with text content', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                padding: EdgeInsets.all(12),
                child: Text('This is some content inside the bordered container'),
              ),
            ),
          ),
        );

        expect(find.text('This is some content inside the bordered container'), findsOneWidget);
      });

      testWidgets('should work with button content', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                padding: const EdgeInsets.all(8),
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Click me'),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.text('Click me'), findsOneWidget);
      });

      testWidgets('should work with complex child widgets', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Header'),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.star),
                        SizedBox(width: 4),
                        Text('Rating'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Action'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Header'), findsOneWidget);
        expect(find.text('Rating'), findsOneWidget);
        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.text('Action'), findsOneWidget);
      });

      testWidgets('should work in lists', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: const [
                  BorderedContainer(
                    padding: EdgeInsets.all(8),
                    child: Text('Item 1'),
                  ),
                  SizedBox(height: 8),
                  BorderedContainer(
                    padding: EdgeInsets.all(8),
                    child: Text('Item 2'),
                  ),
                  SizedBox(height: 8),
                  BorderedContainer(
                    padding: EdgeInsets.all(8),
                    child: Text('Item 3'),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(BorderedContainer), findsNWidgets(3));
        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);
        expect(find.text('Item 3'), findsOneWidget);
      });

      testWidgets('should work in grids', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GridView.count(
                crossAxisCount: 2,
                children: const [
                  BorderedContainer(
                    padding: EdgeInsets.all(8),
                    child: Text('Grid Item 1'),
                  ),
                  BorderedContainer(
                    padding: EdgeInsets.all(8),
                    child: Text('Grid Item 2'),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(BorderedContainer), findsNWidgets(2));
        expect(find.text('Grid Item 1'), findsOneWidget);
        expect(find.text('Grid Item 2'), findsOneWidget);
      });
    });

    group('Use Cases', () {
      testWidgets('should work as selection container', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                borderColor: Colors.blue,
                padding: const EdgeInsets.all(12),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Selected item'),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.text('Selected item'), findsOneWidget);
      });

      testWidgets('should work as content box', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                height: 200,
                width: 300,
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recipe Card',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('A delicious recipe with amazing ingredients...'),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Recipe Card'), findsOneWidget);
        expect(find.text('A delicious recipe with amazing ingredients...'), findsOneWidget);
      });

      testWidgets('should work as form section', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                padding: const EdgeInsets.all(16),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Personal Information'),
                    SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(labelText: 'Name'),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(labelText: 'Email'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Personal Information'), findsOneWidget);
        expect(find.text('Name'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
      });

      testWidgets('should work as status indicator', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                borderColor: Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text('Completed', style: TextStyle(color: Colors.green)),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.check), findsOneWidget);
        expect(find.text('Completed'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty child', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                child: SizedBox.shrink(),
              ),
            ),
          ),
        );

        expect(find.byType(BorderedContainer), findsOneWidget);
        expect(find.byType(SizedBox), findsOneWidget);
      });

      testWidgets('should handle zero dimensions', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                height: 0,
                width: 0,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.minHeight, equals(0));
        expect(container.constraints?.maxHeight, equals(0));
        expect(container.constraints?.minWidth, equals(0));
        expect(container.constraints?.maxWidth, equals(0));
      });

      testWidgets('should handle transparent border color', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                borderColor: Colors.transparent,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        expect(border.top.color, equals(Colors.transparent));
      });

      testWidgets('should handle zero padding', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                padding: EdgeInsets.zero,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(EdgeInsets.zero));
      });

      testWidgets('should handle very large dimensions', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                height: 1000,
                width: 2000,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.minHeight, equals(1000));
        expect(container.constraints?.maxHeight, equals(1000));
        expect(container.constraints?.minWidth, equals(2000));
        expect(container.constraints?.maxWidth, equals(2000));
      });

      testWidgets('should handle asymmetric padding', (WidgetTester tester) async {
        const asymmetricPadding = EdgeInsets.only(
          left: 10,
          top: 20,
          right: 30,
          bottom: 40,
        );
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                padding: asymmetricPadding,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(asymmetricPadding));
      });

      testWidgets('should handle null properties gracefully', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BorderedContainer(
                height: null,
                width: null,
                borderColor: null,
                padding: null,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, isNull);
        
        // Should use theme outline color when borderColor is null
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.border, isNotNull);
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}