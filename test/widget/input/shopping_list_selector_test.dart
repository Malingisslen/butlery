// test/widget/input/shopping_list_selector_test.dart
// Basic tests for ShoppingListSelector using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/input/shopping_list_selector.dart';

// Test infrastructure
import '../../infrastructure/di/test_service_locator.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  group('ShoppingListSelector Widget Tests', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
    });

    tearDown(() async {
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Basic Widget Tests', () {
      testWidgets('should create ShoppingListSelector without crashing',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListSelector(),
            ),
          ),
        );

        // Should not crash and should render the widget
        expect(find.byType(ShoppingListSelector), findsOneWidget);
      });

      testWidgets('should handle optional callback parameter',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListSelector(
                onListSelected: () {}, // Provide callback
              ),
            ),
          ),
        );

        // Should render without issues
        expect(find.byType(ShoppingListSelector), findsOneWidget);
      });

      testWidgets('should handle optional menu parameter',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListSelector(
                menu: const {}, // Provide empty menu
              ),
            ),
          ),
        );

        // Should render without issues
        expect(find.byType(ShoppingListSelector), findsOneWidget);
      });

      testWidgets('should handle null menu gracefully',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListSelector(
                menu: null, // Explicit null
              ),
            ),
          ),
        );

        // Should render without crashing
        expect(find.byType(ShoppingListSelector), findsOneWidget);
      });

      testWidgets('should handle all parameters together',
          (WidgetTester tester) async {
        bool callbackCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListSelector(
                onListSelected: () => callbackCalled = true,
                menu: const {
                  'Test Day': [],
                },
              ),
            ),
          ),
        );

        // Should render properly with all parameters
        expect(find.byType(ShoppingListSelector), findsOneWidget);

        // Callback should not be called automatically
        expect(callbackCalled, isFalse);
      });
    });
  });
}
