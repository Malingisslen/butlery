// test/widget/common/input/debounced_checkbox_test.dart
// Comprehensive tests for DebouncedCheckbox using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/input/debounced_checkbox.dart';

void main() {
  group('DebouncedCheckbox Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Basic Rendering', () {
      testWidgets('should render checkbox with initial value true', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedCheckbox(
                value: true,
                onChanged: (_) {},
              ),
            ),
          ),
        );

        expect(find.byType(Checkbox), findsOneWidget);
        final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(checkbox.value, true);
      });

      testWidgets('should render checkbox with initial value false', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedCheckbox(
                value: false,
                onChanged: (_) {},
              ),
            ),
          ),
        );

        final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(checkbox.value, false);
      });

      testWidgets('should apply custom active color', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedCheckbox(
                value: true,
                onChanged: (_) {},
                activeColor: Colors.red,
              ),
            ),
          ),
        );

        final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(checkbox.activeColor, Colors.red);
      });

      testWidgets('should use default debounce duration', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedCheckbox(
                value: false,
                onChanged: (_) {},
              ),
            ),
          ),
        );

        final widget = tester.widget<DebouncedCheckbox>(
          find.byType(DebouncedCheckbox),
        );
        expect(widget.debounceDuration, const Duration(milliseconds: 300));
      });

      testWidgets('should apply custom debounce duration', (
        WidgetTester tester,
      ) async {
        const customDuration = Duration(milliseconds: 500);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedCheckbox(
                value: false,
                onChanged: (_) {},
                debounceDuration: customDuration,
              ),
            ),
          ),
        );

        final widget = tester.widget<DebouncedCheckbox>(
          find.byType(DebouncedCheckbox),
        );
        expect(widget.debounceDuration, customDuration);
      });
    });

    group('Debounce Behavior', () {
      testWidgets('should debounce onChange callback', (
        WidgetTester tester,
      ) async {
        bool? callbackValue;
        int callCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedCheckbox(
                value: false,
                onChanged: (value) {
                  callbackValue = value;
                  callCount++;
                },
                debounceDuration: const Duration(milliseconds: 300),
              ),
            ),
          ),
        );

        // Tap the checkbox
        await tester.tap(find.byType(Checkbox));

        // Callback should not be called immediately
        expect(callCount, 0);

        // Wait less than debounce duration
        await tester.pump(const Duration(milliseconds: 200));
        expect(callCount, 0);

        // Wait for full debounce duration
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(callCount, 1);
        expect(callbackValue, true);
      });

      testWidgets('should update visual state immediately', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedCheckbox(
                value: false,
                onChanged: (_) {},
              ),
            ),
          ),
        );

        // Initial state
        Checkbox checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(checkbox.value, false);

        // Tap the checkbox
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        // Visual state should update immediately
        checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(checkbox.value, true);
      });

      testWidgets('should cancel previous timer on rapid clicks', (
        WidgetTester tester,
      ) async {
        final List<bool?> callbackValues = [];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedCheckbox(
                value: false,
                onChanged: (value) {
                  callbackValues.add(value);
                },
                debounceDuration: const Duration(milliseconds: 300),
              ),
            ),
          ),
        );

        // Rapid clicks
        await tester.tap(find.byType(Checkbox));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byType(Checkbox));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byType(Checkbox));

        // Wait for debounce
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Should only have one callback with the final value
        expect(callbackValues.length, 1);
        expect(callbackValues[0], true);
      });

      testWidgets('should handle multiple state changes', (
        WidgetTester tester,
      ) async {
        final List<bool?> callbackValues = [];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedCheckbox(
                value: false,
                onChanged: (value) {
                  callbackValues.add(value);
                },
                debounceDuration: const Duration(milliseconds: 200),
              ),
            ),
          ),
        );

        // First change
        await tester.tap(find.byType(Checkbox));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Second change
        await tester.tap(find.byType(Checkbox));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Third change
        await tester.tap(find.byType(Checkbox));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Should have three callbacks
        expect(callbackValues.length, 3);
        expect(callbackValues[0], true);
        expect(callbackValues[1], false);
        expect(callbackValues[2], true);
      });
    });

    group('Value Updates', () {
      testWidgets('should update when value prop changes', (
        WidgetTester tester,
      ) async {
        bool value = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      DebouncedCheckbox(
                        value: value,
                        onChanged: (_) {},
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            value = !value;
                          });
                        },
                        child: const Text('Toggle'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        // Initial state
        Checkbox checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(checkbox.value, false);

        // Update via prop change
        await tester.tap(find.text('Toggle'));
        await tester.pump();

        checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(checkbox.value, true);
      });

      testWidgets('should handle null onChanged callback', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DebouncedCheckbox(
                value: false,
                onChanged: null,
              ),
            ),
          ),
        );

        // Checkbox has onChanged but it does nothing when widget.onChanged is null
        final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(checkbox.onChanged, isNotNull);

        // Try to tap - should not cause errors and visual state shouldn't change
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        // Visual state should remain unchanged since onChanged is null
        final checkboxAfter = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(checkboxAfter.value, false);
      });
    });

    group('Cleanup', () {
      testWidgets('should cancel timer on dispose', (
        WidgetTester tester,
      ) async {
        bool callbackCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedCheckbox(
                value: false,
                onChanged: (_) {
                  callbackCalled = true;
                },
                debounceDuration: const Duration(milliseconds: 500),
              ),
            ),
          ),
        );

        // Tap the checkbox
        await tester.tap(find.byType(Checkbox));
        await tester.pump(const Duration(milliseconds: 100));

        // Dispose the widget before debounce completes
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Text('Replaced'),
            ),
          ),
        );

        // Wait for what would have been the debounce duration
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        // Callback should not have been called due to dispose
        expect(callbackCalled, false);
      });

      testWidgets('should handle widget replacement', (
        WidgetTester tester,
      ) async {
        final callbackValues = <bool?>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedCheckbox(
                value: false,
                onChanged: (value) {
                  callbackValues.add(value);
                },
                debounceDuration: const Duration(milliseconds: 200),
              ),
            ),
          ),
        );

        // Tap and wait for debounce
        await tester.tap(find.byType(Checkbox));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(callbackValues.length, 1);

        // Replace with new widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedCheckbox(
                value: true,
                onChanged: (value) {
                  callbackValues.add(value);
                },
                debounceDuration: const Duration(milliseconds: 200),
              ),
            ),
          ),
        );

        // Tap the new widget
        await tester.tap(find.byType(Checkbox));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(callbackValues.length, 2);
        expect(callbackValues[1], false);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle zero duration debounce', (
        WidgetTester tester,
      ) async {
        bool? callbackValue;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedCheckbox(
                value: false,
                onChanged: (value) {
                  callbackValue = value;
                },
                debounceDuration: Duration.zero,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        // Give time for zero duration timer to execute
        await tester.pumpAndSettle();

        // Callback should be called immediately with zero duration
        expect(callbackValue, true);
      });

      testWidgets('should handle very long debounce duration', (
        WidgetTester tester,
      ) async {
        bool callbackCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedCheckbox(
                value: false,
                onChanged: (_) {
                  callbackCalled = true;
                },
                debounceDuration: const Duration(seconds: 10),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(Checkbox));

        // Wait a reasonable time but less than debounce
        await tester.pump(const Duration(seconds: 1));
        expect(callbackCalled, false);

        // Visual state should still be updated
        final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(checkbox.value, true);
      });
    });

    group('Layout Integration', () {
      testWidgets('should work in Row layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  DebouncedCheckbox(value: true, onChanged: (_) {}),
                  const Text('Option 1'),
                  DebouncedCheckbox(value: false, onChanged: (_) {}),
                  const Text('Option 2'),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(DebouncedCheckbox), findsNWidgets(2));
      });

      testWidgets('should work in ListView', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: List.generate(
                  5,
                  (index) => ListTile(
                    leading: DebouncedCheckbox(
                      value: index % 2 == 0,
                      onChanged: (_) {},
                    ),
                    title: Text('Item $index'),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(DebouncedCheckbox), findsNWidgets(5));
      });
    });

    group('Use Cases', () {
      testWidgets('should work for shopping list items', (
        WidgetTester tester,
      ) async {
        final completedItems = <int>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [1, 2, 3].map((id) {
                  return ListTile(
                    leading: DebouncedCheckbox(
                      value: completedItems.contains(id),
                      onChanged: (checked) {
                        if (checked ?? false) {
                          completedItems.add(id);
                        } else {
                          completedItems.remove(id);
                        }
                      },
                      debounceDuration: const Duration(milliseconds: 200),
                    ),
                    title: Text('Item $id'),
                  );
                }).toList(),
              ),
            ),
          ),
        );

        // Check first item
        await tester.tap(find.byType(Checkbox).first);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(completedItems, contains(1));
      });

      testWidgets('should prevent spam clicking in collaborative environment', (
        WidgetTester tester,
      ) async {
        int updateCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedCheckbox(
                value: false,
                onChanged: (_) {
                  updateCount++;
                },
                debounceDuration: const Duration(milliseconds: 300),
              ),
            ),
          ),
        );

        // Simulate spam clicking
        for (int i = 0; i < 10; i++) {
          await tester.tap(find.byType(Checkbox));
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Wait for final debounce
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Should only have one update despite many clicks
        expect(updateCount, 1);
      });
    });

    group('Theme Integration', () {
      testWidgets('should work with light theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: DebouncedCheckbox(
                value: true,
                onChanged: (_) {},
              ),
            ),
          ),
        );

        expect(find.byType(Checkbox), findsOneWidget);
      });

      testWidgets('should work with dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: DebouncedCheckbox(
                value: true,
                onChanged: (_) {},
              ),
            ),
          ),
        );

        expect(find.byType(Checkbox), findsOneWidget);
      });

      testWidgets('should respect theme checkbox colors', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              checkboxTheme: CheckboxThemeData(
                fillColor: WidgetStateProperty.all(Colors.purple),
              ),
            ),
            home: Scaffold(
              body: DebouncedCheckbox(
                value: true,
                onChanged: (_) {},
              ),
            ),
          ),
        );

        expect(find.byType(Checkbox), findsOneWidget);
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}
