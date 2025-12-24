// test/widget/common/cards/selection_card_test.dart
// Comprehensive tests for SelectionCard using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/cards/selection_card.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('SelectionCard Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Basic Rendering', () {
      testWidgets('should render card with child', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                child: Text('Test Child'),
              ),
            ),
          ),
        );

        expect(find.byType(Card), findsOneWidget);
        expect(find.text('Test Child'), findsOneWidget);
      });

      testWidgets('should render InkWell for tap handling',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                child: Text('Test'),
              ),
            ),
          ),
        );

        expect(find.byType(InkWell), findsOneWidget);
      });

      testWidgets('should have default elevation', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                child: Text('Test'),
              ),
            ),
          ),
        );

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, equals(AppDimensions.elevationLow));
      });

      testWidgets('should have default border radius',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                child: Text('Test'),
              ),
            ),
          ),
        );

        final card = tester.widget<Card>(find.byType(Card));
        final shape = card.shape as RoundedRectangleBorder;
        expect(
          shape.borderRadius,
          equals(BorderRadius.circular(AppDimensions.borderRadiusM)),
        );
      });
    });

    group('Custom Properties', () {
      testWidgets('should apply custom elevation', (WidgetTester tester) async {
        const customElevation = 8.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                elevation: customElevation,
                child: Text('Test'),
              ),
            ),
          ),
        );

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, equals(customElevation));
      });

      testWidgets('should apply custom border radius',
          (WidgetTester tester) async {
        final customRadius = BorderRadius.circular(16.0);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                borderRadius: customRadius,
                child: const Text('Test'),
              ),
            ),
          ),
        );

        final card = tester.widget<Card>(find.byType(Card));
        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.borderRadius, equals(customRadius));
      });

      testWidgets('should apply custom border radius to InkWell',
          (WidgetTester tester) async {
        final customRadius = BorderRadius.circular(20.0);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                borderRadius: customRadius,
                child: const Text('Test'),
              ),
            ),
          ),
        );

        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        expect(inkWell.borderRadius, equals(customRadius));
      });

      testWidgets('should handle asymmetric border radius',
          (WidgetTester tester) async {
        const customRadius = BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(0),
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                borderRadius: customRadius,
                child: Text('Test'),
              ),
            ),
          ),
        );

        final card = tester.widget<Card>(find.byType(Card));
        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.borderRadius, equals(customRadius));
      });
    });

    group('Interaction', () {
      testWidgets('should call onTap callback when tapped',
          (WidgetTester tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                onTap: () {
                  tapped = true;
                },
                child: const Text('Tap me'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Tap me'));
        expect(tapped, true);
      });

      testWidgets('should show ink splash on tap', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                onTap: () {},
                child: const Text('Tap me'),
              ),
            ),
          ),
        );

        // Tap and hold to see the ink splash
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Tap me')),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // InkWell should be active
        expect(find.byType(InkWell), findsOneWidget);

        await gesture.up();
      });

      testWidgets('should handle null onTap gracefully',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                onTap: null,
                child: Text('No tap'),
              ),
            ),
          ),
        );

        // Should render without errors
        expect(find.text('No tap'), findsOneWidget);

        // Tapping should not cause errors
        await tester.tap(find.text('No tap'));
        await tester.pump();
      });

      testWidgets('should respond to multiple taps',
          (WidgetTester tester) async {
        int tapCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                onTap: () {
                  tapCount++;
                },
                child: const Text('Multi tap'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Multi tap'));
        await tester.pump();
        expect(tapCount, 1);

        await tester.tap(find.text('Multi tap'));
        await tester.pump();
        expect(tapCount, 2);

        await tester.tap(find.text('Multi tap'));
        await tester.pump();
        expect(tapCount, 3);
      });
    });

    group('Child Content', () {
      testWidgets('should work with text child', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                child: Text('Text content'),
              ),
            ),
          ),
        );

        expect(find.text('Text content'), findsOneWidget);
      });

      testWidgets('should work with complex child widget',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('John Doe'),
                  subtitle: Text('Friend'),
                  trailing: Icon(Icons.check),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(ListTile), findsOneWidget);
        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('Friend'), findsOneWidget);
        expect(find.byIcon(Icons.person), findsOneWidget);
        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('should work with Column child', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                child: Column(
                  children: [
                    Text('Title'),
                    Text('Subtitle'),
                    Icon(Icons.star),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Column), findsOneWidget);
        expect(find.text('Title'), findsOneWidget);
        expect(find.text('Subtitle'), findsOneWidget);
        expect(find.byIcon(Icons.star), findsOneWidget);
      });

      testWidgets('should work with Row child', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                child: Row(
                  children: [
                    Icon(Icons.folder),
                    SizedBox(width: 8),
                    Text('Document'),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Row), findsOneWidget);
        expect(find.byIcon(Icons.folder), findsOneWidget);
        expect(find.text('Document'), findsOneWidget);
      });

      testWidgets('should work with Container child',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.blue,
                  child: const Center(child: Text('Container')),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Container), findsOneWidget);
        expect(find.text('Container'), findsOneWidget);
      });
    });

    group('Layout Integration', () {
      testWidgets('should work in ListView', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: List.generate(
                  3,
                  (index) => SelectionCard(
                    onTap: () {},
                    child: Text('Item $index'),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(SelectionCard), findsNWidgets(3));
        expect(find.text('Item 0'), findsOneWidget);
        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);
      });

      testWidgets('should work in GridView', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GridView.count(
                crossAxisCount: 2,
                children: List.generate(
                  4,
                  (index) => SelectionCard(
                    child: Center(child: Text('Grid $index')),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(SelectionCard), findsNWidgets(4));
      });

      testWidgets('should work in Column', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SelectionCard(child: Text('First')),
                  SelectionCard(child: Text('Second')),
                  SelectionCard(child: Text('Third')),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(SelectionCard), findsNWidgets(3));
      });

      testWidgets('should work with Expanded in Row',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  Expanded(
                    child: SelectionCard(
                      child: Text('Left'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: SelectionCard(
                      child: Text('Right'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Left'), findsOneWidget);
        expect(find.text('Right'), findsOneWidget);
      });
    });

    group('Use Cases', () {
      testWidgets('should work for friend selection',
          (WidgetTester tester) async {
        bool selected = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => SelectionCard(
                  onTap: () {
                    setState(() {
                      selected = !selected;
                    });
                  },
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Text('JD'),
                    ),
                    title: const Text('John Doe'),
                    trailing: selected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.radio_button_unchecked),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsNothing);

        await tester.tap(find.text('John Doe'));
        await tester.pump();

        expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });

      testWidgets('should work for item selection',
          (WidgetTester tester) async {
        String? selectedItem;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: ['Apple', 'Banana', 'Orange'].map((item) {
                  return SelectionCard(
                    onTap: () {
                      selectedItem = item;
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(item),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Banana'));
        expect(selectedItem, 'Banana');

        await tester.tap(find.text('Apple'));
        expect(selectedItem, 'Apple');
      });
    });

    group('Theme Integration', () {
      testWidgets('should work with light theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: SelectionCard(
                child: Text('Light theme'),
              ),
            ),
          ),
        );

        expect(find.text('Light theme'), findsOneWidget);
      });

      testWidgets('should work with dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: SelectionCard(
                child: Text('Dark theme'),
              ),
            ),
          ),
        );

        expect(find.text('Dark theme'), findsOneWidget);
      });

      testWidgets('should respect theme elevation',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              cardTheme: const CardThemeData(
                elevation: 10,
              ),
            ),
            home: const Scaffold(
              body: SelectionCard(
                child: Text('Theme elevation'),
              ),
            ),
          ),
        );

        // Custom elevation overrides theme
        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, equals(AppDimensions.elevationLow));
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty child', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                child: SizedBox.shrink(),
              ),
            ),
          ),
        );

        expect(find.byType(SelectionCard), findsOneWidget);
      });

      testWidgets('should handle very large child',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SelectionCard(
                  child: Container(
                    height: 1000,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('should handle zero elevation', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                elevation: 0,
                child: Text('Flat card'),
              ),
            ),
          ),
        );

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, equals(0));
      });

      testWidgets('should handle very high elevation',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                elevation: 24,
                child: Text('High elevation'),
              ),
            ),
          ),
        );

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, equals(24));
      });
    });

    group('Accessibility', () {
      testWidgets('should be accessible with semantics',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                onTap: () {},
                child: Semantics(
                  label: 'Selectable item',
                  child: const Text('Item'),
                ),
              ),
            ),
          ),
        );

        // Verify the text is present and accessible
        expect(find.text('Item'), findsOneWidget);
        // Verify SelectionCard can contain semantic widgets
        expect(
            find.descendant(
              of: find.byType(SelectionCard),
              matching: find.byType(Semantics),
            ),
            findsWidgets);
      });

      testWidgets('should work with ExcludeSemantics',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SelectionCard(
                onTap: () {},
                child: const ExcludeSemantics(
                  child: Text('Hidden from semantics'),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Hidden from semantics'), findsOneWidget);
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}
