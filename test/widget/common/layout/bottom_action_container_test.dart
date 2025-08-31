// test/widget/common/layout/bottom_action_container_test.dart
// Comprehensive tests for BottomActionContainer using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/layout/bottom_action_container.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('BottomActionContainer Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Basic Rendering', () {
      testWidgets('should render with required child', (WidgetTester tester) async {
        const testChild = Text('Test Content');
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                child: testChild,
              ),
            ),
          ),
        );

        expect(find.byType(BottomActionContainer), findsOneWidget);
        expect(find.byType(Container), findsOneWidget);
        expect(find.byType(SafeArea), findsOneWidget);
        expect(find.text('Test Content'), findsOneWidget);
      });

      testWidgets('should have correct default padding', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(const EdgeInsets.all(AppDimensions.paddingL)));
      });

      testWidgets('should have correct default background color', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.backgroundBeige));
      });

      testWidgets('should have correct default border', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        
        expect(border.top.color, equals(AppColors.divider));
        expect(border.top.width, equals(1));
        expect(border.left, equals(BorderSide.none));
        expect(border.right, equals(BorderSide.none));
        expect(border.bottom, equals(BorderSide.none));
      });
    });

    group('Custom Properties', () {
      testWidgets('should use custom background color', (WidgetTester tester) async {
        const customColor = Colors.red;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                backgroundColor: customColor,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(customColor));
      });

      testWidgets('should use custom border color', (WidgetTester tester) async {
        const customBorderColor = Colors.blue;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
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
      });

      testWidgets('should use custom padding', (WidgetTester tester) async {
        const customPadding = EdgeInsets.all(24);
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                padding: customPadding,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(customPadding));
      });

      testWidgets('should use all custom properties together', (WidgetTester tester) async {
        const customColor = Colors.green;
        const customBorderColor = Colors.purple;
        const customPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 10);
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                backgroundColor: customColor,
                borderColor: customBorderColor,
                padding: customPadding,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        
        expect(decoration.color, equals(customColor));
        expect(border.top.color, equals(customBorderColor));
        expect(container.padding, equals(customPadding));
      });
    });

    group('SafeArea Integration', () {
      testWidgets('should wrap child in SafeArea', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                child: Text('Content'),
              ),
            ),
          ),
        );

        final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
        expect(safeArea.child, isA<Text>());
        
        final text = safeArea.child as Text;
        expect(text.data, equals('Content'));
      });

      testWidgets('should maintain SafeArea with complex child', (WidgetTester tester) async {
        final complexChild = Column(
          children: [
            ElevatedButton(onPressed: () {}, child: const Text('Button')),
            const Text('Additional content'),
          ],
        );
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                child: complexChild,
              ),
            ),
          ),
        );

        expect(find.byType(SafeArea), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.text('Button'), findsOneWidget);
        expect(find.text('Additional content'), findsOneWidget);
      });
    });

    group('Layout Integration', () {
      testWidgets('should work with action buttons', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(ElevatedButton), findsNWidgets(2));
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
      });

      testWidgets('should work with single action button', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Continue'),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.width, equals(double.infinity));
      });

      testWidgets('should work as bottom sheet', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const Center(child: Text('Main content')),
              bottomSheet: BottomActionContainer(
                child: Text('Bottom sheet content'),
              ),
            ),
          ),
        );

        expect(find.text('Main content'), findsOneWidget);
        expect(find.text('Bottom sheet content'), findsOneWidget);
        expect(find.byType(BottomActionContainer), findsOneWidget);
      });
    });

    group('Theme Integration', () {
      testWidgets('should work with light theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: BottomActionContainer(
                child: Text('Content'),
              ),
            ),
          ),
        );

        expect(find.byType(BottomActionContainer), findsOneWidget);
        expect(find.text('Content'), findsOneWidget);
      });

      testWidgets('should work with dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: BottomActionContainer(
                child: Text('Content'),
              ),
            ),
          ),
        );

        expect(find.byType(BottomActionContainer), findsOneWidget);
        expect(find.text('Content'), findsOneWidget);
      });

      testWidgets('should use theme colors when custom colors not provided', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            ),
            home: Scaffold(
              body: BottomActionContainer(
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        
        // Should use app default colors, not theme colors
        expect(decoration.color, equals(AppColors.backgroundBeige));
        
        final border = decoration.border as Border;
        expect(border.top.color, equals(AppColors.divider));
      });
    });

    group('Use Cases', () {
      testWidgets('should work in forms', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  const Expanded(
                    child: Center(child: Text('Form content')),
                  ),
                  BottomActionContainer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {},
                            child: const Text('Submit'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Form content'), findsOneWidget);
        expect(find.text('Submit'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('should work in modals', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AlertDialog(
                title: const Text('Dialog Title'),
                content: const Text('Dialog content'),
                actions: [
                  BottomActionContainer(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {},
                            child: const Text('Cancel'),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            child: const Text('OK'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Dialog Title'), findsOneWidget);
        expect(find.text('Dialog content'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('OK'), findsOneWidget);
      });

      testWidgets('should work in recipe forms', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: const Text('Add Recipe')),
              body: Column(
                children: [
                  const Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          TextField(decoration: InputDecoration(labelText: 'Recipe Name')),
                          TextField(decoration: InputDecoration(labelText: 'Instructions')),
                        ],
                      ),
                    ),
                  ),
                  BottomActionContainer(
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            child: const Text('Save Draft'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {},
                            child: const Text('Publish Recipe'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Add Recipe'), findsOneWidget);
        expect(find.text('Recipe Name'), findsOneWidget);
        expect(find.text('Save Draft'), findsOneWidget);
        expect(find.text('Publish Recipe'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty child', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                child: SizedBox.shrink(),
              ),
            ),
          ),
        );

        expect(find.byType(BottomActionContainer), findsOneWidget);
        expect(find.byType(SizedBox), findsOneWidget);
      });

      testWidgets('should handle transparent colors', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                backgroundColor: Colors.transparent,
                borderColor: Colors.transparent,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        
        expect(decoration.color, equals(Colors.transparent));
        expect(border.top.color, equals(Colors.transparent));
      });

      testWidgets('should handle zero padding', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                padding: EdgeInsets.zero,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(EdgeInsets.zero));
      });

      testWidgets('should handle null properties gracefully', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                backgroundColor: null,
                borderColor: null,
                padding: null,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        
        // Should use defaults when null
        expect(decoration.color, equals(AppColors.backgroundBeige));
        expect(border.top.color, equals(AppColors.divider));
        expect(container.padding, equals(const EdgeInsets.all(AppDimensions.paddingL)));
      });

      testWidgets('should handle very large padding', (WidgetTester tester) async {
        const largePadding = EdgeInsets.all(100);
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                padding: largePadding,
                child: Text('Content'),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(largePadding));
      });

      testWidgets('should handle complex nested children', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BottomActionContainer(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Text('Left'),
                              ElevatedButton(
                                onPressed: () {},
                                child: const Text('Button 1'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              const Text('Right'),
                              ElevatedButton(
                                onPressed: () {},
                                child: const Text('Button 2'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text('Footer'),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Left'), findsOneWidget);
        expect(find.text('Right'), findsOneWidget);
        expect(find.text('Button 1'), findsOneWidget);
        expect(find.text('Button 2'), findsOneWidget);
        expect(find.text('Footer'), findsOneWidget);
        expect(find.byType(Divider), findsOneWidget);
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}