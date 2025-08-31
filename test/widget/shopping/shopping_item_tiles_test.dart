import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_item_tiles.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('ShoppingItemTiles Widget Tests', () {
    // Test data setup
    late UnifiedShoppingItem basicItem;
    late UnifiedShoppingItem completedItem;
    late UnifiedShoppingItem itemWithNote;
    late UnifiedShoppingItem highPriorityItem;
    late UnifiedShoppingItem urgentPriorityItem;

    setUp(() {
      // Basic item
      basicItem = UnifiedShoppingItem(
        id: 'test-1',
        name: 'Mjölk',
        amount: 1.5,
        unit: 'liter',
        category: 'Mejeri',
        bought: false,
      );

      // Completed item
      completedItem = UnifiedShoppingItem(
        id: 'test-2',
        name: 'Bröd',
        amount: 2,
        unit: 'st',
        category: 'Bröd',
        bought: true,
      );

      // Item with note
      itemWithNote = UnifiedShoppingItem(
        id: 'test-3',
        name: 'Ägg',
        amount: 12,
        unit: 'st',
        category: 'Mejeri',
        bought: false,
        note: 'Ekologiska om möjligt',
      );

      // High priority item (priority 4)
      highPriorityItem = UnifiedShoppingItem(
        id: 'test-4',
        name: 'Medicin',
        amount: 1,
        unit: 'förpackning',
        category: 'Övrigt',
        bought: false,
        priority: 4,
      );

      // Urgent priority item (priority 5)
      urgentPriorityItem = UnifiedShoppingItem(
        id: 'test-5',
        name: 'Barnmat',
        amount: 3,
        unit: 'burk',
        category: 'Barn',
        bought: false,
        priority: 5,
      );
    });

    group('buildItemTile - Basic Rendering', () {
      testWidgets('renders basic item correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                  basicItem,
                  false,
                  (_) {},
                  (_) {},
                  (_) {},
                ),
              ),
            ),
          ),
        );

        // Verify item text is displayed
        expect(find.text(basicItem.displayText), findsOneWidget);
        
        // Verify checkbox is not checked
        expect(find.byIcon(Icons.check), findsNothing);
        
        // Verify action buttons
        expect(find.byIcon(Icons.edit), findsOneWidget);
        expect(find.byIcon(Icons.delete), findsOneWidget);
      });

      testWidgets('renders completed item with strikethrough', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                completedItem,
                true,
                (_) {},
                (_) {},
                (_) {},
                ),
              ),
            ),
          ),
        );

        // Verify checkmark is displayed
        expect(find.byIcon(Icons.check), findsOneWidget);
        
        // Verify text has strikethrough decoration
        final textWidget = tester.widget<Text>(find.text(completedItem.displayText));
        expect(textWidget.style?.decoration, TextDecoration.lineThrough);
      });

      testWidgets('renders item with note', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                itemWithNote,
                false,
                (_) {},
                (_) {},
                (_) {},
                ),
              ),
            ),
          ),
        );

        // Verify both item text and note are displayed
        expect(find.text(itemWithNote.displayText), findsOneWidget);
        expect(find.text(itemWithNote.note!), findsOneWidget);
      });
    });

    group('buildItemTile - Priority Indicators', () {
      testWidgets('shows no priority indicator for normal priority', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                basicItem,
                false,
                (_) {},
                (_) {},
                (_) {},
                ),
              ),
            ),
          ),
        );

        // Priority indicator is only shown for priority > 3
        // Look for small circular containers (priority indicators)
        // We check the margin to identify the priority indicator specifically
        final priorityIndicators = find.byWidgetPredicate(
          (widget) {
            if (widget is Container) {
              final decoration = widget.decoration;
              final margin = widget.margin;
              // Priority indicator has left margin and circular decoration
              return decoration is BoxDecoration && 
                     decoration.shape == BoxShape.circle &&
                     margin is EdgeInsets &&
                     margin.left == 8;
            }
            return false;
          },
        );
        
        expect(priorityIndicators, findsNothing);
      });

      testWidgets('shows warning color for high priority (4)', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                highPriorityItem,
                false,
                (_) {},
                (_) {},
                (_) {},
                ),
              ),
            ),
          ),
        );

        // Find the priority indicator by its margin and shape
        final priorityIndicator = find.byWidgetPredicate(
          (widget) {
            if (widget is Container) {
              final decoration = widget.decoration;
              final margin = widget.margin;
              // Priority indicator has left margin and circular decoration
              return decoration is BoxDecoration && 
                     decoration.shape == BoxShape.circle &&
                     margin is EdgeInsets &&
                     margin.left == 8;
            }
            return false;
          },
        );
        
        expect(priorityIndicator, findsOneWidget);
        
        // Verify the color
        final container = tester.widget<Container>(priorityIndicator);
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, AppColors.warning);
      });

      testWidgets('shows error color for urgent priority (5)', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                urgentPriorityItem,
                false,
                (_) {},
                (_) {},
                (_) {},
                ),
              ),
            ),
          ),
        );

        // Find the priority indicator by its margin and shape
        final priorityIndicator = find.byWidgetPredicate(
          (widget) {
            if (widget is Container) {
              final decoration = widget.decoration;
              final margin = widget.margin;
              // Priority indicator has left margin and circular decoration
              return decoration is BoxDecoration && 
                     decoration.shape == BoxShape.circle &&
                     margin is EdgeInsets &&
                     margin.left == 8;
            }
            return false;
          },
        );
        
        expect(priorityIndicator, findsOneWidget);
        
        // Verify the color
        final container = tester.widget<Container>(priorityIndicator);
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, AppColors.error);
      });
    });

    group('buildItemTile - User Interactions', () {
      testWidgets('handles item tap', (WidgetTester tester) async {
        UnifiedShoppingItem? tappedItem;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                basicItem,
                false,
                (item) => tappedItem = item,
                (_) {},
                (_) {},
                ),
              ),
            ),
          ),
        );

        // Tap on the item (first InkWell is the main container)
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();

        expect(tappedItem, equals(basicItem));
      });

      testWidgets('handles edit button tap', (WidgetTester tester) async {
        UnifiedShoppingItem? editedItem;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                basicItem,
                false,
                (_) {},
                (item) => editedItem = item,
                (_) {},
                ),
              ),
            ),
          ),
        );

        // Tap edit button
        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle();

        expect(editedItem, equals(basicItem));
      });

      testWidgets('handles delete button tap', (WidgetTester tester) async {
        UnifiedShoppingItem? deletedItem;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                basicItem,
                false,
                (_) {},
                (_) {},
                (item) => deletedItem = item,
                ),
              ),
            ),
          ),
        );

        // Tap delete button
        await tester.tap(find.byIcon(Icons.delete));
        await tester.pumpAndSettle();

        expect(deletedItem, equals(basicItem));
      });

      testWidgets('shows correct tooltips on action buttons', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                basicItem,
                false,
                (_) {},
                (_) {},
                (_) {},
                ),
              ),
            ),
          ),
        );

        // Find IconButtons and verify tooltips
        final editButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.edit),
        );
        expect(editButton.tooltip, 'Redigera');

        final deleteButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.delete),
        );
        expect(deleteButton.tooltip, 'Ta bort');
      });
    });

    group('buildItemTile - Visual States', () {
      testWidgets('applies correct styles for non-completed item', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                basicItem,
                false,
                (_) {},
                (_) {},
                (_) {},
                ),
              ),
            ),
          ),
        );

        final textWidget = tester.widget<Text>(find.text(basicItem.displayText));
        expect(textWidget.style?.color, AppColors.textDark);
        expect(textWidget.style?.decoration, anyOf(isNull, TextDecoration.none));
      });

      testWidgets('applies correct styles for completed item', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                completedItem,
                true,
                (_) {},
                (_) {},
                (_) {},
                ),
              ),
            ),
          ),
        );

        final textWidget = tester.widget<Text>(find.text(completedItem.displayText));
        expect(textWidget.style?.color, AppColors.neutralMedium);
        expect(textWidget.style?.decoration, TextDecoration.lineThrough);
      });

      testWidgets('applies correct styles for note on completed item', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                itemWithNote,
                true,
                (_) {},
                (_) {},
                (_) {},
                ),
              ),
            ),
          ),
        );

        final noteWidget = tester.widget<Text>(find.text(itemWithNote.note!));
        expect(noteWidget.style?.decoration, TextDecoration.lineThrough);
      });

      testWidgets('handles long text with ellipsis', (WidgetTester tester) async {
        final longItem = UnifiedShoppingItem(
          id: 'long-test',
          name: 'Detta är en väldigt lång produktnamn som borde klippas av med ellipsis för att inte ta upp för mycket plats',
          amount: 1,
          unit: 'st',
          category: 'Test',
          bought: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300, // Constrain width to force ellipsis
                child: Builder(
                  builder: (context) => ShoppingItemTiles.buildItemTile(
                    context,
                    longItem,
                    false,
                    (_) {},
                    (_) {},
                    (_) {},
                  ),
                ),
              ),
            ),
          ),
        );

        final textWidget = tester.widget<Text>(find.text(longItem.displayText));
        expect(textWidget.overflow, TextOverflow.ellipsis);
        expect(textWidget.maxLines, 2);
      });
    });

    group('buildEmptyState', () {
      testWidgets('renders empty state with all components', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingItemTiles.buildEmptyState(
                title: 'Inga varor',
                message: 'Din inköpslista är tom',
                icon: Icons.shopping_cart_outlined,
              ),
            ),
          ),
        );

        // Verify all components are rendered
        expect(find.text('Inga varor'), findsOneWidget);
        expect(find.text('Din inköpslista är tom'), findsOneWidget);
        expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);

        // Verify icon size
        final icon = tester.widget<Icon>(find.byIcon(Icons.shopping_cart_outlined));
        expect(icon.size, 64);
      });

      testWidgets('centers empty state content', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingItemTiles.buildEmptyState(
                title: 'Test Title',
                message: 'Test Message',
                icon: Icons.info,
              ),
            ),
          ),
        );

        // Verify centering - the empty state creates a Center widget
        final center = find.byType(Center);
        expect(center, findsWidgets); // There might be multiple Center widgets in the tree

        // Verify text alignment
        final titleWidget = tester.widget<Text>(find.text('Test Title'));
        expect(titleWidget.textAlign, TextAlign.center);

        final messageWidget = tester.widget<Text>(find.text('Test Message'));
        expect(messageWidget.textAlign, TextAlign.center);
      });

      testWidgets('applies correct styles to empty state', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingItemTiles.buildEmptyState(
                title: 'Empty',
                message: 'No items',
                icon: Icons.inbox,
              ),
            ),
          ),
        );

        // Verify title style
        final titleWidget = tester.widget<Text>(find.text('Empty'));
        expect(titleWidget.style?.color, AppColors.neutralMedium);

        // Verify message style
        final messageWidget = tester.widget<Text>(find.text('No items'));
        expect(messageWidget.style?.color, AppColors.neutralMedium);

        // Verify icon color
        final icon = tester.widget<Icon>(find.byIcon(Icons.inbox));
        expect(icon.color, AppColors.neutralMedium);
      });
    });

    group('Accessibility', () {
      testWidgets('has proper semantics for buttons', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                basicItem,
                false,
                (_) {},
                (_) {},
                (_) {},
                ),
              ),
            ),
          ),
        );

        // Buttons should have tooltips for screen readers
        // Tooltips become semantics labels when present
        final editButton = find.widgetWithIcon(IconButton, Icons.edit);
        final deleteButton = find.widgetWithIcon(IconButton, Icons.delete);
        
        expect(editButton, findsOneWidget);
        expect(deleteButton, findsOneWidget);
        
        // Verify tooltips are set
        final editButtonWidget = tester.widget<IconButton>(editButton);
        final deleteButtonWidget = tester.widget<IconButton>(deleteButton);
        
        expect(editButtonWidget.tooltip, 'Redigera');
        expect(deleteButtonWidget.tooltip, 'Ta bort');
      });

      testWidgets('maintains minimum touch target size', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                basicItem,
                false,
                (_) {},
                (_) {},
                (_) {},
                ),
              ),
            ),
          ),
        );

        // Verify IconButton constraints
        final editButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.edit),
        );
        expect(editButton.constraints?.minWidth, AppDimensions.minTouchTarget);
        expect(editButton.constraints?.minHeight, AppDimensions.minTouchTarget);
      });
    });

    group('Edge Cases', () {
      testWidgets('handles item with zero amount', (WidgetTester tester) async {
        final zeroItem = UnifiedShoppingItem(
          id: 'zero',
          name: 'Test',
          amount: 0,
          unit: 'st',
          category: 'Test',
          bought: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                zeroItem,
                false,
                (_) {},
                (_) {},
                (_) {},
                ),
              ),
            ),
          ),
        );

        expect(find.text(zeroItem.displayText), findsOneWidget);
      });

      testWidgets('handles item with empty note', (WidgetTester tester) async {
        final emptyNoteItem = UnifiedShoppingItem(
          id: 'empty-note',
          name: 'Test',
          amount: 1,
          unit: 'st',
          category: 'Test',
          bought: false,
          note: '',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                emptyNoteItem,
                false,
                (_) {},
                (_) {},
                (_) {},
                ),
              ),
            ),
          ),
        );

        // Empty note should not be displayed
        expect(find.text(''), findsNothing);
      });

      testWidgets('handles rapid taps correctly', (WidgetTester tester) async {
        int tapCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShoppingItemTiles.buildItemTile(
                  context,
                basicItem,
                false,
                (_) => tapCount++,
                (_) {},
                (_) {},
                ),
              ),
            ),
          ),
        );

        // Rapidly tap the item (first InkWell is the main container)
        await tester.tap(find.byType(InkWell).first);
        await tester.tap(find.byType(InkWell).first);
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();

        expect(tapCount, 3);
      });
    });
  });
}