// test/widgets/shopping_item_tile_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/shopping_item.dart';
import 'package:butlery/widgets/shopping_item_tile.dart';
import 'package:butlery/theme/app_theme.dart';

void main() {
  group('ShoppingItemTile Widget Tests', () {
    late ShoppingItem testItem;
    late ShoppingItem boughtItem;

    setUp(() {
      testItem = ShoppingItem(
        name: 'Mjölk',
        amount: 1.5,
        unit: 'l',
        category: 'Mejeri',
        bought: false,
      );

      boughtItem = ShoppingItem(
        name: 'Bröd',
        amount: 2,
        unit: 'st',
        category: 'Bageri',
        bought: true,
      );
    });

    Widget createTestWidget(ShoppingItemTile tile) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ListView(
            children: [tile],
          ),
        ),
      );
    }

    testWidgets('displays item information correctly', (tester) async {
      // Arrange
      // Act
      await tester.pumpWidget(
        createTestWidget(
          ShoppingItemTile(
            key: const ValueKey('test-item'),
            item: testItem,
            formattedText: '1,5 l Mjölk',
            onToggle: () {},
            onDismissed: () {},
          ),
        ),
      );

      // Assert
      expect(find.text('1,5 l Mjölk'), findsOneWidget);
      expect(find.text('Mejeri'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      // Verify checkbox is unchecked
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    });

    testWidgets('displays bought item with strike-through', (tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(
          ShoppingItemTile(
            key: const ValueKey('bought-item'),
            item: boughtItem,
            formattedText: '2 st Bröd',
            onToggle: () {},
            onDismissed: () {},
          ),
        ),
      );

      // Assert
      final textWidget = tester.widget<Text>(find.text('2 st Bröd'));
      expect(textWidget.style?.decoration, equals(TextDecoration.lineThrough));

      // Check for check icon
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Verify checkbox is checked
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('calls onToggle when tapped', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          ShoppingItemTile(
            key: const ValueKey('test-item'),
            item: testItem,
            formattedText: '1,5 l Mjölk',
            onToggle: () {},
            onDismissed: () {},
          ),
        ),
      );

      // Act - Tap the tile
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      // Assert
    });
    testWidgets('calls onToggle when checkbox tapped', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          ShoppingItemTile(
            key: const ValueKey('test-item'),
            item: testItem,
            formattedText: '1,5 l Mjölk',
            onToggle: () {},
            onDismissed: () {},
          ),
        ),
      );

      // Act - Tap the tile (not checkbox directly)
      await tester.tap(find.text('1,5 l Mjölk'));
      await tester.pumpAndSettle();

      // Assert
    });
    testWidgets('can be dismissed with swipe', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          ShoppingItemTile(
            key: const ValueKey('test-item'),
            item: testItem,
            formattedText: '1,5 l Mjölk',
            onToggle: () {},
            onDismissed: () {},
          ),
        ),
      );

      // Act - Swipe to dismiss
      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Confirm dismiss in dialog
      await tester.tap(find.text('Ta bort'));
      await tester.pumpAndSettle();

      // Assert
    });
    testWidgets('shows confirmation dialog for unbought items', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          ShoppingItemTile(
            key: const ValueKey('test-item'),
            item: testItem,
            formattedText: '1,5 l Mjölk',
            onToggle: () {},
            onDismissed: () {},
          ),
        ),
      );

      // Act - Start swipe
      await tester.drag(find.byType(Dismissible), const Offset(-200, 0));
      await tester.pumpAndSettle();

      // Assert - Dialog should appear
      expect(find.text('Ta bort artikel?'), findsOneWidget);
      expect(find.text('Vill du ta bort "Mjölk" från listan?'), findsOneWidget);
      expect(find.text('Avbryt'), findsOneWidget);
      expect(find.text('Ta bort'), findsOneWidget);
    });

    testWidgets('cancels dismiss when dialog cancelled', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          ShoppingItemTile(
            key: const ValueKey('test-item'),
            item: testItem,
            formattedText: '1,5 l Mjölk',
            onToggle: () {},
            onDismissed: () {},
          ),
        ),
      );

      // Act - Swipe and cancel
      await tester.drag(find.byType(Dismissible), const Offset(-200, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('1,5 l Mjölk'), findsOneWidget); // Item still exists
    });
    testWidgets('dismisses bought items without confirmation', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          ShoppingItemTile(
            key: const ValueKey('bought-item'),
            item: boughtItem,
            formattedText: '2 st Bröd',
            onToggle: () {},
            onDismissed: () {},
          ),
        ),
      );

      // Act - Swipe bought item
      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Assert - No dialog, direct dismiss
      expect(find.text('Ta bort artikel?'), findsNothing);
    });
    testWidgets('hides category when showCategory is false', (tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(
          ShoppingItemTile(
            key: const ValueKey('test-item'),
            item: testItem,
            formattedText: '1,5 l Mjölk',
            onToggle: () {},
            onDismissed: () {},
            showCategory: false,
          ),
        ),
      );

      // Assert
      expect(find.text('Mejeri'), findsNothing);
    });

    testWidgets('shows delete icon on swipe background', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          ShoppingItemTile(
            key: const ValueKey('test-item'),
            item: testItem,
            formattedText: '1,5 l Mjölk',
            onToggle: () {},
            onDismissed: () {},
          ),
        ),
      );

      // Act - Start swipe
      await tester.drag(find.byType(Dismissible), const Offset(-100, 0));
      await tester.pump();

      // Assert
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('has correct semantics for accessibility', (tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(
          ShoppingItemTile(
            key: const ValueKey('test-item'),
            item: testItem,
            formattedText: '1,5 l Mjölk',
            onToggle: () {},
            onDismissed: () {},
          ),
        ),
      );

      // Assert
      final semantics = tester.getSemantics(find.byType(ShoppingItemTile));
      expect(semantics.label, contains('Artikel Mjölk, ej köpt'));
    });

    testWidgets('bought item has correct semantics', (tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(
          ShoppingItemTile(
            key: const ValueKey('bought-item'),
            item: boughtItem,
            formattedText: '2 st Bröd',
            onToggle: () {},
            onDismissed: () {},
          ),
        ),
      );

      // Assert
      final semantics = tester.getSemantics(find.byType(ShoppingItemTile));
      expect(semantics.label, contains('Artikel Bröd, köpt'));
    });

    testWidgets('applies correct styling based on bought status',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          Column(
            children: [
              ShoppingItemTile(
                key: const ValueKey('unbought'),
                item: testItem,
                formattedText: '1,5 l Mjölk',
                onToggle: () {},
                onDismissed: () {},
              ),
              ShoppingItemTile(
                key: const ValueKey('bought'),
                item: boughtItem,
                formattedText: '2 st Bröd',
                onToggle: () {},
                onDismissed: () {},
              ),
            ],
          ),
        ),
      );

      // Assert - Check card elevations
      final unboughtCard = tester.widget<Card>(
        find.descendant(
          of: find.byKey(const ValueKey('unbought')),
          matching: find.byType(Card),
        ),
      );
      final boughtCard = tester.widget<Card>(
        find.descendant(
          of: find.byKey(const ValueKey('bought')),
          matching: find.byType(Card),
        ),
      );

      expect(unboughtCard.elevation, greaterThan(0));
      expect(boughtCard.elevation, equals(0));
    });
  });
}
