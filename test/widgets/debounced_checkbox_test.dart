// test/widgets/debounced_checkbox_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/debounced_checkbox.dart';
import 'package:butlery/theme/app_theme.dart';

void main() {
  group('DebouncedCheckbox Widget Tests', () {
    Widget createTestWidget({
      required bool value,
      required ValueChanged<bool?>? onChanged,
      Color? activeColor,
      Duration? debounceDuration,
    }) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: DebouncedCheckbox(
              value: value,
              onChanged: onChanged,
              activeColor: activeColor,
              debounceDuration:
                  debounceDuration ?? const Duration(milliseconds: 300),
            ),
          ),
        ),
      );
    }

    testWidgets('displays checkbox with initial value', (tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(
          value: false,
          onChanged: (_) {},
        ),
      );

      // Assert
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    });

    testWidgets('displays checked state', (tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(
          value: true,
          onChanged: (_) {},
        ),
      );

      // Assert
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('debounces rapid clicks', (tester) async {
      // Arrange
      int changeCount = 0;
      bool? lastValue;

      await tester.pumpWidget(
        createTestWidget(
          value: false,
          onChanged: (value) {
            changeCount++;
            lastValue = value;
          },
          debounceDuration: const Duration(milliseconds: 100),
        ),
      );

      // Act - Rapid clicks
      await tester.tap(find.byType(Checkbox));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byType(Checkbox));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byType(Checkbox));

      // Wait for debounce
      await tester.pump(const Duration(milliseconds: 150));

      // Assert - Only one change should be registered
      expect(changeCount, equals(1));
      expect(lastValue, isTrue);
    });

    testWidgets('shows pending state during debounce', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          value: false,
          onChanged: (_) {},
          debounceDuration: const Duration(milliseconds: 100),
        ),
      );

      // Act
      await tester.tap(find.byType(Checkbox));
      await tester.pump(const Duration(milliseconds: 50));

      // Assert - Checkbox should show pending state
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue); // Shows pending value
    });

    testWidgets('animates scale during processing', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          value: false,
          onChanged: (_) {},
        ),
      );

      // Act
      await tester.tap(find.byType(Checkbox));
      await tester.pump(const Duration(milliseconds: 50));

      // Assert - Check for scale animation
      final animatedScale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(animatedScale.scale, equals(0.9));
    });

    testWidgets('returns to normal scale after debounce', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          value: false,
          onChanged: (_) {},
          debounceDuration: const Duration(milliseconds: 100),
        ),
      );

      // Act
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Assert
      final animatedScale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(animatedScale.scale, equals(1.0));
    });

    testWidgets('ignores taps when processing', (tester) async {
      // Arrange
      int changeCount = 0;

      await tester.pumpWidget(
        createTestWidget(
          value: false,
          onChanged: (_) => changeCount++,
          debounceDuration: const Duration(milliseconds: 200),
        ),
      );

      // Act
      await tester.tap(find.byType(Checkbox));
      await tester.pump(const Duration(milliseconds: 50));

      // Try to tap again while processing
      await tester.tap(find.byType(Checkbox));
      await tester.pump(const Duration(milliseconds: 50));

      // Wait for debounce to complete
      await tester.pump(const Duration(milliseconds: 200));

      // Assert - Only first tap should register
      expect(changeCount, equals(1));
    });

    testWidgets('disabled when onChanged is null', (tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(
          value: false,
          onChanged: null,
        ),
      );

      // Assert
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.onChanged, isNull);
    });

    testWidgets('uses custom active color', (tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(
          value: true,
          onChanged: (_) {},
          activeColor: Colors.red,
        ),
      );

      // Assert
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.activeColor, equals(Colors.red));
    });

    testWidgets('cancels timer on dispose', (tester) async {
      // Arrange
      int changeCount = 0;

      await tester.pumpWidget(
        createTestWidget(
          value: false,
          onChanged: (_) => changeCount++,
          debounceDuration: const Duration(seconds: 1),
        ),
      );

      // Act - Tap and immediately dispose
      await tester.tap(find.byType(Checkbox));
      await tester.pump(const Duration(milliseconds: 100));

      // Dispose by navigating away
      await tester.pumpWidget(Container());

      // Wait for what would have been the debounce duration
      await tester.pump(const Duration(seconds: 2));

      // Assert - Change should not have been called
      expect(changeCount, equals(0));
    });

    testWidgets('handles multiple state changes correctly', (tester) async {
      // Arrange
      final values = <bool?>[];

      await tester.pumpWidget(
        createTestWidget(
          value: false,
          onChanged: (value) => values.add(value),
          debounceDuration: const Duration(milliseconds: 100),
        ),
      );

      // Act - Multiple changes
      await tester.tap(find.byType(Checkbox)); // false -> true
      await tester.pump(const Duration(milliseconds: 150));

      await tester.tap(find.byType(Checkbox)); // true -> false
      await tester.pump(const Duration(milliseconds: 150));

      await tester.tap(find.byType(Checkbox)); // false -> true
      await tester.pump(const Duration(milliseconds: 150));

      // Assert
      expect(values, equals([true, false, true]));
    });

    testWidgets('updates display value immediately', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          value: false,
          onChanged: (_) {},
          debounceDuration: const Duration(milliseconds: 500),
        ),
      );

      // Initial state
      var checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);

      // Act - Tap
      await tester.tap(find.byType(Checkbox));
      await tester.pump(const Duration(milliseconds: 50));

      // Assert - Visual feedback is immediate
      checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('maintains correct shape', (tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(
          value: false,
          onChanged: (_) {},
        ),
      );

      // Assert
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.shape, isA<RoundedRectangleBorder>());

      final shape = checkbox.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, equals(AppTheme.smallRadius));
    });
  });
}
