import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/input/portion_scaler.dart';

void main() {
  group('PortionScaler Orchestration Widget Tests', () {
    // Swedish test data - ultrathink realistic patterns
    final testIngredients = [
      '2 dl mjölk',
      '4 ägg',
      '3 dl mjöl',
      '1 tsk salt',
    ];

    final americanIngredients = [
      '1 cup milk',
      '4 eggs',
      '2 cups flour',
      '1 tsp salt',
    ];

    group('Widget Construction and Initialization', () {
      testWidgets('creates widget with required parameters successfully',
          (WidgetTester tester) async {
        bool callbackTriggered = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PortionScaler(
                originalPortions: 4,
                originalIngredients: testIngredients,
                onPortionChanged: (portions, ingredients) {
                  callbackTriggered = true;
                },
              ),
            ),
          ),
        );

        // Widget should be created successfully
        expect(find.byType(PortionScaler), findsOneWidget);
        expect(callbackTriggered, isFalse); // No callback on initial creation
      });

      testWidgets('initializes with custom min and max portions',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PortionScaler(
                originalPortions: 6,
                originalIngredients: testIngredients,
                onPortionChanged: (portions, ingredients) {},
                minPortions: 2,
                maxPortions: 12,
              ),
            ),
          ),
        );

        // Widget should accept custom bounds
        expect(find.byType(PortionScaler), findsOneWidget);
      });

      testWidgets('detects American units on initialization',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PortionScaler(
                originalPortions: 4,
                originalIngredients: americanIngredients,
                onPortionChanged: (portions, ingredients) {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should detect American units and show conversion toggle
        expect(find.text('Konvertera amerikanska enheter'), findsOneWidget);
      });

      testWidgets('does not show conversion toggle for Swedish ingredients',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PortionScaler(
                originalPortions: 4,
                originalIngredients: testIngredients,
                onPortionChanged: (portions, ingredients) {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should not show conversion toggle for Swedish ingredients
        expect(find.text('Konvertera amerikanska enheter'), findsNothing);
      });
    });

    group('State Management and Updates', () {
      testWidgets('updates portions and triggers callback',
          (WidgetTester tester) async {
        bool callbackTriggered = false;
        int finalPortions = 0;
        List<String> finalIngredients = [];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PortionScaler(
                originalPortions: 4,
                originalIngredients: testIngredients,
                onPortionChanged: (portions, ingredients) {
                  callbackTriggered = true;
                  finalPortions = portions;
                  finalIngredients = ingredients;
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Increase portions
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // Verify callback was triggered with correct values
        expect(callbackTriggered, isTrue);
        expect(finalPortions, equals(5));
        expect(finalIngredients.length, equals(testIngredients.length));
      });

      testWidgets('respects minimum portion bounds',
          (WidgetTester tester) async {
        int callbackCount = 0;
        int lastCallbackPortions = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PortionScaler(
                originalPortions: 1, // Start at minimum
                originalIngredients: testIngredients,
                onPortionChanged: (portions, ingredients) {
                  callbackCount++;
                  lastCallbackPortions = portions;
                },
                minPortions: 1,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Try to decrease below minimum
        await tester.tap(find.byIcon(Icons.remove));
        await tester.pumpAndSettle();

        // Should not trigger callback (no change)
        expect(callbackCount, equals(0));
        expect(lastCallbackPortions, equals(0)); // No callback triggered
      });

      testWidgets('respects maximum portion bounds',
          (WidgetTester tester) async {
        int callbackCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PortionScaler(
                originalPortions: 5, // Start at maximum
                originalIngredients: testIngredients,
                onPortionChanged: (portions, ingredients) {
                  callbackCount++;
                },
                maxPortions: 5,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Try to increase above maximum
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // Should not trigger callback (no change)
        expect(callbackCount, equals(0));
      });

      testWidgets('handles unit conversion toggle',
          (WidgetTester tester) async {
        bool callbackTriggered = false;
        List<String> finalIngredients = [];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PortionScaler(
                originalPortions: 4,
                originalIngredients: americanIngredients,
                onPortionChanged: (portions, ingredients) {
                  callbackTriggered = true;
                  finalIngredients = ingredients;
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Toggle unit conversion
        await tester.tap(find.text('Konvertera amerikanska enheter'));
        await tester.pumpAndSettle();

        // Verify conversion was triggered
        expect(callbackTriggered, isTrue);
        expect(finalIngredients.length, equals(americanIngredients.length));
      });
    });

    group('Animation Controller Management', () {
      testWidgets('manages animation controller lifecycle correctly',
          (WidgetTester tester) async {
        // Test that widget can be created and disposed without errors
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PortionScaler(
                originalPortions: 4,
                originalIngredients: testIngredients,
                onPortionChanged: (portions, ingredients) {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Widget should be present
        expect(find.byType(PortionScaler), findsOneWidget);

        // Dispose the widget by removing it
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));

        // Should not crash during disposal
        expect(tester.takeException(), isNull);
      });

      testWidgets('triggers animation on portion changes',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PortionScaler(
                originalPortions: 4,
                originalIngredients: testIngredients,
                onPortionChanged: (portions, ingredients) {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Change portions to trigger animation
        await tester.tap(find.byIcon(Icons.add));

        // Let animation start
        await tester.pump(const Duration(milliseconds: 50));

        // Animation should be running (widget still present)
        expect(find.byType(PortionScaler), findsOneWidget);

        // Wait for animation to complete
        await tester.pumpAndSettle();

        // Widget should still be present after animation
        expect(find.byType(PortionScaler), findsOneWidget);
      });
    });

    group('Integration with Logic Components', () {
      testWidgets('integrates with PortionScalerLogic for scaling',
          (WidgetTester tester) async {
        List<String> scaledIngredients = [];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PortionScaler(
                originalPortions: 4,
                originalIngredients: testIngredients,
                onPortionChanged: (portions, ingredients) {
                  scaledIngredients = ingredients;
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Double the portions
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // Verify ingredients were processed by logic component
        expect(scaledIngredients.length, equals(testIngredients.length));
        expect(scaledIngredients,
            isNot(equals(testIngredients))); // Should be different (scaled)
      });

      testWidgets('passes correct parameters to UI component',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PortionScaler(
                originalPortions: 6,
                originalIngredients: testIngredients,
                onPortionChanged: (portions, ingredients) {},
                minPortions: 2,
                maxPortions: 15,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // UI should show the correct initial portions
        expect(find.text('6'), findsOneWidget);
        expect(find.text('Portioner'), findsOneWidget);

        // Controls should be present
        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byIcon(Icons.remove), findsOneWidget);
      });
    });

    group('Error Handling and Edge Cases', () {
      testWidgets('handles empty ingredients list gracefully',
          (WidgetTester tester) async {
        bool callbackTriggered = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PortionScaler(
                originalPortions: 4,
                originalIngredients: const [],
                onPortionChanged: (portions, ingredients) {
                  callbackTriggered = true;
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should not crash with empty ingredients
        expect(find.byType(PortionScaler), findsOneWidget);

        // Should still allow portion changes
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        expect(callbackTriggered, isTrue);
      });

      testWidgets('handles rapid interactions without crashing',
          (WidgetTester tester) async {
        int callbackCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PortionScaler(
                originalPortions: 10,
                originalIngredients: testIngredients,
                onPortionChanged: (portions, ingredients) {
                  callbackCount++;
                },
                minPortions: 5,
                maxPortions: 15,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Rapidly tap buttons
        for (int i = 0; i < 3; i++) {
          await tester.tap(find.byIcon(Icons.add));
          await tester.pump(const Duration(milliseconds: 10));
        }

        for (int i = 0; i < 5; i++) {
          await tester.tap(find.byIcon(Icons.remove));
          await tester.pump(const Duration(milliseconds: 10));
        }

        await tester.pumpAndSettle();

        // Should handle rapid interactions
        expect(callbackCount, greaterThan(0));
        expect(find.byType(PortionScaler), findsOneWidget);
      });

      testWidgets('maintains state consistency during updates',
          (WidgetTester tester) async {
        int lastCallbackPortions = 0;
        List<String> lastCallbackIngredients = [];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PortionScaler(
                originalPortions: 4,
                originalIngredients: testIngredients,
                onPortionChanged: (portions, ingredients) {
                  lastCallbackPortions = portions;
                  lastCallbackIngredients = List.from(ingredients);
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Make a series of changes
        await tester.tap(find.byIcon(Icons.add)); // 5
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add)); // 6
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.remove)); // 5
        await tester.pumpAndSettle();

        // Final state should be consistent
        expect(lastCallbackPortions, equals(5));
        expect(lastCallbackIngredients.length, equals(testIngredients.length));
        expect(find.text('5'), findsOneWidget);
      });
    });
  });
}
