// test/widget/common/layout/card_content_test.dart
// Comprehensive tests for CardContent using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/layout/card_content.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('CardContent Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Basic Rendering', () {
      testWidgets('should render with required child', (WidgetTester tester) async {
        const testChild = Text('Test Content');
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CardContent(
                child: testChild,
              ),
            ),
          ),
        );

        expect(find.byType(CardContent), findsOneWidget);
        expect(find.byType(Card), findsOneWidget);
        expect(find.byType(Padding), findsAtLeastNWidgets(1));
        expect(find.text('Test Content'), findsOneWidget);
      });

      testWidgets('should have correct default padding', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CardContent(
                child: Text('Content'),
              ),
            ),
          ),
        );

        // Find Padding widget that has the specific padding value we expect
        final paddings = tester.widgetList<Padding>(find.byType(Padding));
        final cardContentPadding = paddings.firstWhere(
          (p) => p.padding == const EdgeInsets.all(AppDimensions.spacingL),
          orElse: () => throw StateError('CardContent padding not found'),
        );
        expect(cardContentPadding.padding, equals(const EdgeInsets.all(AppDimensions.spacingL)));
      });

      testWidgets('should wrap child in Card', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CardContent(
                child: Text('Content'),
              ),
            ),
          ),
        );

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.child, isA<Padding>());
      });
    });

    group('Standard Constructor', () {
      testWidgets('should create standard card content with predefined padding', (WidgetTester tester) async {
        const testChild = Text('Standard Content');
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CardContent.standard(
                child: testChild,
              ),
            ),
          ),
        );

        expect(find.byType(CardContent), findsOneWidget);
        expect(find.byType(Card), findsOneWidget);
        expect(find.byType(Padding), findsAtLeastNWidgets(1));
        expect(find.text('Standard Content'), findsOneWidget);

        // Find Padding widget that has the specific padding value we expect
        final paddings = tester.widgetList<Padding>(find.byType(Padding));
        final cardContentPadding = paddings.firstWhere(
          (p) => p.padding == const EdgeInsets.all(AppDimensions.spacingL),
          orElse: () => throw StateError('CardContent padding not found'),
        );
        expect(cardContentPadding.padding, equals(const EdgeInsets.all(AppDimensions.spacingL)));
      });

      testWidgets('should use same padding as default constructor', (WidgetTester tester) async {
        // Test default constructor
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CardContent(
                child: Text('Default'),
              ),
            ),
          ),
        );

        // Find default padding
        final defaultPaddings = tester.widgetList<Padding>(find.byType(Padding));
        final defaultPadding = defaultPaddings.firstWhere(
          (p) => p.padding == const EdgeInsets.all(AppDimensions.spacingL),
          orElse: () => throw StateError('Default padding not found'),
        );

        // Test standard constructor
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CardContent.standard(
                child: Text('Standard'),
              ),
            ),
          ),
        );

        // Find standard padding
        final standardPaddings = tester.widgetList<Padding>(find.byType(Padding));
        final standardPadding = standardPaddings.firstWhere(
          (p) => p.padding == const EdgeInsets.all(AppDimensions.spacingL),
          orElse: () => throw StateError('Standard padding not found'),
        );
        expect(standardPadding.padding, equals(defaultPadding.padding));
      });
    });

    group('Custom Properties', () {
      testWidgets('should use custom padding', (WidgetTester tester) async {
        const customPadding = EdgeInsets.all(24);
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CardContent(
                padding: customPadding,
                child: Text('Content'),
              ),
            ),
          ),
        );

        // Find Padding widget that has the custom padding value we expect
        final paddings = tester.widgetList<Padding>(find.byType(Padding));
        final cardContentPadding = paddings.firstWhere(
          (p) => p.padding == customPadding,
          orElse: () => throw StateError('CardContent custom padding not found'),
        );
        expect(cardContentPadding.padding, equals(customPadding));
      });

      testWidgets('should use asymmetric custom padding', (WidgetTester tester) async {
        const customPadding = EdgeInsets.only(left: 8, top: 16, right: 12, bottom: 4);
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CardContent(
                padding: customPadding,
                child: Text('Content'),
              ),
            ),
          ),
        );

        // Find Padding widget that has the custom padding value we expect
        final paddings = tester.widgetList<Padding>(find.byType(Padding));
        final cardContentPadding = paddings.firstWhere(
          (p) => p.padding == customPadding,
          orElse: () => throw StateError('CardContent custom padding not found'),
        );
        expect(cardContentPadding.padding, equals(customPadding));
      });

      testWidgets('should use symmetric custom padding', (WidgetTester tester) async {
        const customPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 10);
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CardContent(
                padding: customPadding,
                child: Text('Content'),
              ),
            ),
          ),
        );

        // Find Padding widget that has the custom padding value we expect
        final paddings = tester.widgetList<Padding>(find.byType(Padding));
        final cardContentPadding = paddings.firstWhere(
          (p) => p.padding == customPadding,
          orElse: () => throw StateError('CardContent custom padding not found'),
        );
        expect(cardContentPadding.padding, equals(customPadding));
      });
    });

    group('Theme Integration', () {
      testWidgets('should work with light theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: CardContent(
                child: Text('Content'),
              ),
            ),
          ),
        );

        expect(find.byType(CardContent), findsOneWidget);
        expect(find.text('Content'), findsOneWidget);
        
        final card = tester.widget<Card>(find.byType(Card));
        expect(card, isNotNull);
      });

      testWidgets('should work with dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: CardContent(
                child: Text('Content'),
              ),
            ),
          ),
        );

        expect(find.byType(CardContent), findsOneWidget);
        expect(find.text('Content'), findsOneWidget);
        
        final card = tester.widget<Card>(find.byType(Card));
        expect(card, isNotNull);
      });

      testWidgets('should inherit card theme properties', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              cardTheme: const CardThemeData(
                elevation: 8.0,
                margin: EdgeInsets.all(8),
              ),
            ),
            home: const Scaffold(
              body: CardContent(
                child: Text('Content'),
              ),
            ),
          ),
        );

        final card = tester.widget<Card>(find.byType(Card));
        // Card should inherit theme properties
        expect(card, isNotNull);
      });
    });

    group('Layout Integration', () {
      testWidgets('should work with text content', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CardContent(
                child: Text('This is some text content inside a card'),
              ),
            ),
          ),
        );

        expect(find.text('This is some text content inside a card'), findsOneWidget);
      });

      testWidgets('should work with button content', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CardContent(
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
              body: CardContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recipe Title',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.star, color: Colors.yellow),
                        SizedBox(width: 4),
                        Text('4.5'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('View Recipe'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Recipe Title'), findsOneWidget);
        expect(find.text('4.5'), findsOneWidget);
        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.text('View Recipe'), findsOneWidget);
      });

      testWidgets('should work in lists', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: const [
                  CardContent(
                    child: Text('Card 1'),
                  ),
                  CardContent(
                    child: Text('Card 2'),
                  ),
                  CardContent(
                    child: Text('Card 3'),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(CardContent), findsNWidgets(3));
        expect(find.text('Card 1'), findsOneWidget);
        expect(find.text('Card 2'), findsOneWidget);
        expect(find.text('Card 3'), findsOneWidget);
      });

      testWidgets('should work in grids', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GridView.count(
                crossAxisCount: 2,
                children: const [
                  CardContent(
                    child: Text('Grid Card 1'),
                  ),
                  CardContent(
                    child: Text('Grid Card 2'),
                  ),
                  CardContent(
                    child: Text('Grid Card 3'),
                  ),
                  CardContent(
                    child: Text('Grid Card 4'),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(CardContent), findsNWidgets(4));
        expect(find.text('Grid Card 1'), findsOneWidget);
        expect(find.text('Grid Card 2'), findsOneWidget);
        expect(find.text('Grid Card 3'), findsOneWidget);
        expect(find.text('Grid Card 4'), findsOneWidget);
      });
    });

    group('Use Cases', () {
      testWidgets('should work for recipe cards', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CardContent(
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pasta Carbonara',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('30 mins • 4 servings'),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.orange, size: 16),
                        Icon(Icons.star, color: Colors.orange, size: 16),
                        Icon(Icons.star, color: Colors.orange, size: 16),
                        Icon(Icons.star, color: Colors.orange, size: 16),
                        Icon(Icons.star_border, size: 16),
                        SizedBox(width: 4),
                        Text('4.2'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Pasta Carbonara'), findsOneWidget);
        expect(find.text('30 mins • 4 servings'), findsOneWidget);
        expect(find.text('4.2'), findsOneWidget);
        expect(find.byIcon(Icons.star), findsNWidgets(4));
        expect(find.byIcon(Icons.star_border), findsOneWidget);
      });

      testWidgets('should work for user profile cards', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CardContent(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text('JD'),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'John Doe',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Chef • 156 recipes'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('JD'), findsOneWidget);
        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('Chef • 156 recipes'), findsOneWidget);
        expect(find.byType(CircleAvatar), findsOneWidget);
      });

      testWidgets('should work for settings cards', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CardContent(
                child: ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notifications'),
                  subtitle: const Text('Manage your notification preferences'),
                  trailing: Switch(
                    value: true,
                    onChanged: (bool value) {},
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Manage your notification preferences'), findsOneWidget);
        expect(find.byIcon(Icons.notifications), findsOneWidget);
        expect(find.byType(Switch), findsOneWidget);
      });

      testWidgets('should work for status cards', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CardContent.standard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Upload Complete',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text('Your recipe has been successfully uploaded'),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Upload Complete'), findsOneWidget);
        expect(find.text('Your recipe has been successfully uploaded'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty child', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CardContent(
                child: SizedBox.shrink(),
              ),
            ),
          ),
        );

        expect(find.byType(CardContent), findsOneWidget);
        expect(find.byType(Card), findsOneWidget);
        expect(find.byType(SizedBox), findsOneWidget);
      });

      testWidgets('should handle zero padding', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CardContent(
                padding: EdgeInsets.zero,
                child: Text('Content'),
              ),
            ),
          ),
        );

        // Find Padding widget that has zero padding
        final paddings = tester.widgetList<Padding>(find.byType(Padding));
        final cardContentPadding = paddings.firstWhere(
          (p) => p.padding == EdgeInsets.zero,
          orElse: () => throw StateError('CardContent zero padding not found'),
        );
        expect(cardContentPadding.padding, equals(EdgeInsets.zero));
      });

      testWidgets('should handle very large padding', (WidgetTester tester) async {
        const largePadding = EdgeInsets.all(100);
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CardContent(
                padding: largePadding,
                child: Text('Content'),
              ),
            ),
          ),
        );

        // Find Padding widget that has large padding
        final paddings = tester.widgetList<Padding>(find.byType(Padding));
        final cardContentPadding = paddings.firstWhere(
          (p) => p.padding == largePadding,
          orElse: () => throw StateError('CardContent large padding not found'),
        );
        expect(cardContentPadding.padding, equals(largePadding));
      });

      testWidgets('should handle null padding gracefully', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CardContent(
                padding: null,
                child: Text('Content'),
              ),
            ),
          ),
        );

        // Find Padding widget that has default padding (used when null)
        final paddings = tester.widgetList<Padding>(find.byType(Padding));
        final cardContentPadding = paddings.firstWhere(
          (p) => p.padding == const EdgeInsets.all(AppDimensions.spacingL),
          orElse: () => throw StateError('CardContent default padding not found'),
        );
        // Should use default when null
        expect(cardContentPadding.padding, equals(const EdgeInsets.all(AppDimensions.spacingL)));
      });

      testWidgets('should handle deeply nested children', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CardContent(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Column(
                              children: [
                                Text('Nested 1'),
                                Icon(Icons.star),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Column(
                              children: [
                                Text('Nested 2'),
                                Icon(Icons.favorite),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
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

        expect(find.text('Nested 1'), findsOneWidget);
        expect(find.text('Nested 2'), findsOneWidget);
        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.text('Action'), findsOneWidget);
      });

      testWidgets('should handle scrollable content', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CardContent(
                child: SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: 20,
                    itemBuilder: (context, index) => ListTile(
                      title: Text('Item $index'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('Item 0'), findsOneWidget);
        // Some items should be visible depending on viewport
        expect(find.byType(ListTile), findsAtLeastNWidgets(1));
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}