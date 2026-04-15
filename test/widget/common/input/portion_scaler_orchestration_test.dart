// test/widget/common/input/portion_scaler_orchestration_test.dart
// Tests for PortionScaler widget — construction, scaling, animation, edge cases.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/input/portion_scaler.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  final testIngredients = ['2 dl mjölk', '4 ägg', '3 dl mjöl', '1 tsk salt'];
  final americanIngredients = [
    '1 cup milk',
    '4 eggs',
    '2 cups flour',
    '1 tsp salt',
  ];

  Widget buildScaler({
    int originalPortions = 4,
    List<String>? ingredients,
    int minPortions = 1,
    int maxPortions = 20,
    Function(int, List<String>)? onPortionChanged,
  }) {
    return createLocalizedTestApp(
      child: PortionScaler(
        originalPortions: originalPortions,
        originalIngredients: ingredients ?? testIngredients,
        onPortionChanged: onPortionChanged ?? (_, __) {},
        minPortions: minPortions,
        maxPortions: maxPortions,
      ),
    );
  }

  // Helper to find the add/remove buttons inside InkWell controls
  Finder findControlIcon(IconData icon) => find.byIcon(icon);

  group('Construction and Initialization', () {
    testWidgets('creates widget successfully', (tester) async {
      bool called = false;

      await tester.pumpWidget(buildScaler(
        onPortionChanged: (_, __) => called = true,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PortionScaler), findsOneWidget);
      expect(called, isFalse);
    });

    testWidgets('accepts custom min and max portions', (tester) async {
      await tester.pumpWidget(buildScaler(
        originalPortions: 6,
        minPortions: 2,
        maxPortions: 12,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PortionScaler), findsOneWidget);
    });

    testWidgets('shows conversion toggle for American ingredients',
        (tester) async {
      await tester.pumpWidget(buildScaler(
        ingredients: americanIngredients,
      ));
      await tester.pumpAndSettle();

      // l10n sv: 'Konvertera amerikanska enheter'
      expect(find.text('Konvertera amerikanska enheter'), findsOneWidget);
    });

    testWidgets('hides conversion toggle for Swedish ingredients',
        (tester) async {
      await tester.pumpWidget(buildScaler());
      await tester.pumpAndSettle();

      expect(find.text('Konvertera amerikanska enheter'), findsNothing);
    });
  });

  group('State Management', () {
    testWidgets('increase button triggers callback with portions+1',
        (tester) async {
      int finalPortions = 0;
      List<String> finalIngredients = [];

      await tester.pumpWidget(buildScaler(
        onPortionChanged: (p, i) {
          finalPortions = p;
          finalIngredients = i;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(findControlIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(finalPortions, equals(5));
      expect(finalIngredients.length, equals(testIngredients.length));
    });

    testWidgets('does not go below minPortions', (tester) async {
      int callbackCount = 0;

      await tester.pumpWidget(buildScaler(
        originalPortions: 1,
        minPortions: 1,
        onPortionChanged: (_, __) => callbackCount++,
      ));
      await tester.pumpAndSettle();

      await tester.tap(findControlIcon(Icons.remove));
      await tester.pumpAndSettle();

      expect(callbackCount, equals(0));
    });

    testWidgets('does not go above maxPortions', (tester) async {
      int callbackCount = 0;

      await tester.pumpWidget(buildScaler(
        originalPortions: 5,
        maxPortions: 5,
        onPortionChanged: (_, __) => callbackCount++,
      ));
      await tester.pumpAndSettle();

      await tester.tap(findControlIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(callbackCount, equals(0));
    });

    testWidgets('unit conversion toggle triggers callback', (tester) async {
      bool called = false;
      List<String> finalIngredients = [];

      await tester.pumpWidget(buildScaler(
        ingredients: americanIngredients,
        onPortionChanged: (_, i) {
          called = true;
          finalIngredients = i;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Konvertera amerikanska enheter'));
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(finalIngredients.length, equals(americanIngredients.length));
    });
  });

  group('Animation Controller', () {
    testWidgets('disposes cleanly when widget removed', (tester) async {
      await tester.pumpWidget(buildScaler());
      await tester.pumpAndSettle();

      expect(find.byType(PortionScaler), findsOneWidget);

      // Remove widget
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('animation runs on portion change', (tester) async {
      await tester.pumpWidget(buildScaler());
      await tester.pumpAndSettle();

      await tester.tap(findControlIcon(Icons.add));
      await tester.pump(const Duration(milliseconds: 50));

      // Widget should still be present mid-animation
      expect(find.byType(PortionScaler), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('Integration with Logic', () {
    testWidgets('scaled ingredients differ from original after change',
        (tester) async {
      List<String> scaled = [];

      await tester.pumpWidget(buildScaler(
        onPortionChanged: (_, i) => scaled = i,
      ));
      await tester.pumpAndSettle();

      // Increase portions: 4 -> 5
      await tester.tap(findControlIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(scaled.length, equals(testIngredients.length));
      expect(scaled, isNot(equals(testIngredients)));
    });

    testWidgets('displays correct initial portion count', (tester) async {
      await tester.pumpWidget(buildScaler(originalPortions: 6));
      await tester.pumpAndSettle();

      expect(find.text('6'), findsOneWidget);
      // l10n sv: 'Portioner:'
      expect(find.text('Portioner:'), findsOneWidget);
    });
  });

  group('Edge Cases', () {
    testWidgets('handles empty ingredients list', (tester) async {
      bool called = false;

      await tester.pumpWidget(buildScaler(
        ingredients: const [],
        onPortionChanged: (_, __) => called = true,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PortionScaler), findsOneWidget);

      await tester.tap(findControlIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });

    testWidgets('handles rapid taps', (tester) async {
      int callbackCount = 0;

      await tester.pumpWidget(buildScaler(
        originalPortions: 10,
        minPortions: 5,
        maxPortions: 15,
        onPortionChanged: (_, __) => callbackCount++,
      ));
      await tester.pumpAndSettle();

      for (int i = 0; i < 3; i++) {
        await tester.tap(findControlIcon(Icons.add));
        await tester.pump(const Duration(milliseconds: 10));
      }
      for (int i = 0; i < 5; i++) {
        await tester.tap(findControlIcon(Icons.remove));
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      expect(callbackCount, greaterThan(0));
      expect(find.byType(PortionScaler), findsOneWidget);
    });

    testWidgets('maintains consistent state across up-down sequence',
        (tester) async {
      int lastPortions = 0;
      List<String> lastIngredients = [];

      await tester.pumpWidget(buildScaler(
        onPortionChanged: (p, i) {
          lastPortions = p;
          lastIngredients = List.from(i);
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(findControlIcon(Icons.add)); // 5
      await tester.pumpAndSettle();
      await tester.tap(findControlIcon(Icons.add)); // 6
      await tester.pumpAndSettle();
      await tester.tap(findControlIcon(Icons.remove)); // 5
      await tester.pumpAndSettle();

      expect(lastPortions, equals(5));
      expect(lastIngredients.length, equals(testIngredients.length));
      expect(find.text('5'), findsOneWidget);
    });
  });
}
