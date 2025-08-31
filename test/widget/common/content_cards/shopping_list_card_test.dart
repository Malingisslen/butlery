import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/content_cards/shopping_list_card.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';

// Comprehensive widget test for ShoppingListCard following ultrathink methodology
void main() {
  setUp(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('ShoppingListCard Tests', () {
    // Test data
    final testItems = [
      UnifiedShoppingItem(
        id: 'item1',
        name: 'Mjölk',
        amount: 1.0,
        unit: 'liter',
        category: 'Mejeriprodukter',
        bought: false,
      ),
      UnifiedShoppingItem(
        id: 'item2',
        name: 'Bröd',
        amount: 2.0,
        unit: 'st',
        category: 'Bageri',
        bought: true,
      ),
      UnifiedShoppingItem(
        id: 'item3',
        name: 'Ägg',
        amount: 12.0,
        unit: 'st',
        category: 'Mejeriprodukter',
        bought: false,
      ),
    ];

    final testShoppingList = UnifiedShoppingList(
      id: 'list123',
      name: 'Veckans inköp',
      ownerId: 'user123',
      ownerDisplayName: 'Anna Andersson',
      items: testItems,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
      type: ListType.personal,
      description: 'Lista för veckans mat',
    );

    group('Basic Rendering', () {
      testWidgets('renders with required shopping list', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
              ),
            ),
          ),
        );

        expect(find.byType(ShoppingListCard), findsOneWidget);
        expect(find.text('Veckans inköp'), findsOneWidget);
        expect(find.byIcon(Icons.shopping_cart), findsOneWidget);
      });

      testWidgets('displays item count in metadata', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                showMetadata: true,
              ),
            ),
          ),
        );

        expect(find.textContaining('3 föremål'), findsOneWidget);
        expect(find.textContaining('1 slutförda'), findsOneWidget);
      });

      testWidgets('shows empty state when no items', (WidgetTester tester) async {
        final emptyList = UnifiedShoppingList(
          id: 'empty123',
          name: 'Tom lista',
          ownerId: 'user123',
          ownerDisplayName: 'Anna',
          items: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          syncStatus: SyncStatus.synced,
          type: ListType.personal,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: emptyList,
                showPreview: true,
              ),
            ),
          ),
        );

        expect(find.text('Inga föremål i listan'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });
    });

    group('Card Styles', () {
      testWidgets('renders detailed style correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                style: ShoppingListCardStyle.detailed,
                showPreview: true,
                showMetadata: true,
              ),
            ),
          ),
        );

        expect(find.text('Föremål på listan:'), findsOneWidget);
        // displayText formats as "amount unit name"
        expect(find.textContaining('Mjölk'), findsOneWidget);
        expect(find.textContaining('Bröd'), findsOneWidget);
      });

      testWidgets('renders compact style correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                style: ShoppingListCardStyle.compact,
                showMetadata: true,
              ),
            ),
          ),
        );

        expect(find.byType(Row).first, findsOneWidget);
        expect(find.text('Veckans inköp'), findsOneWidget);
      });

      testWidgets('renders grid style correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                style: ShoppingListCardStyle.grid,
              ),
            ),
          ),
        );

        expect(find.byType(ShoppingListCard), findsOneWidget);
      });
    });

    group('Item Preview', () {
      testWidgets('shows first 4 items in preview', (WidgetTester tester) async {
        final manyItems = List.generate(10, (i) => UnifiedShoppingItem(
          id: 'item$i',
          name: 'Föremål $i',
          amount: 1.0,
          unit: 'st',
          category: 'Test',
          bought: false,
        ));

        final longList = testShoppingList.copyWith(items: manyItems);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: longList,
                showPreview: true,
              ),
            ),
          ),
        );

        // displayText formats as "amount unit name"
        expect(find.textContaining('Föremål 0'), findsOneWidget);
        expect(find.textContaining('Föremål 1'), findsOneWidget);
        expect(find.textContaining('Föremål 2'), findsOneWidget);
        expect(find.textContaining('Föremål 3'), findsOneWidget);
        expect(find.textContaining('Föremål 4'), findsNothing); // Not shown
        expect(find.textContaining('+ 6 fler föremål'), findsOneWidget);
      });

      testWidgets('shows completed items with strikethrough', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                showPreview: true,
              ),
            ),
          ),
        );

        // Find the completed item (Bröd) - displayText includes amount/unit
        final breadTexts = find.textContaining('Bröd').evaluate();
        if (breadTexts.isNotEmpty) {
          final breadText = breadTexts.first.widget as Text;
          expect(breadText.style?.decoration, equals(TextDecoration.lineThrough));
        }
      });

      testWidgets('shows check icons for completed items', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                showPreview: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.check_circle), findsOneWidget); // One completed item
        expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2)); // Two uncompleted
      });

      testWidgets('hides preview when showPreview is false', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                showPreview: false,
              ),
            ),
          ),
        );

        expect(find.text('Föremål på listan:'), findsNothing);
        expect(find.textContaining('Mjölk'), findsNothing);
      });
    });

    group('Completion Indicator', () {
      testWidgets('shows correct completion percentage', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                style: ShoppingListCardStyle.compact,
              ),
            ),
          ),
        );

        // 1 out of 3 items completed = 33%
        expect(find.textContaining('33%'), findsOneWidget);
      });

      testWidgets('shows "Klar" when all items completed', (WidgetTester tester) async {
        final completedItems = testItems.map((item) => UnifiedShoppingItem(
          id: item.id,
          name: item.name,
          amount: item.amount,
          unit: item.unit,
          category: item.category,
          bought: true,
        )).toList();
        final completedList = testShoppingList.copyWith(items: completedItems);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: completedList,
                style: ShoppingListCardStyle.compact,
              ),
            ),
          ),
        );

        expect(find.text('Klar'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsAtLeastNWidgets(1));
      });

      testWidgets('shows hourglass icon for incomplete list', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                style: ShoppingListCardStyle.compact,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      });
    });

    group('Sharing Status', () {
      testWidgets('shows sharing indicator for collaborative list', (WidgetTester tester) async {
        final sharedList = UnifiedShoppingList(
          id: testShoppingList.id,
          name: testShoppingList.name,
          ownerId: testShoppingList.ownerId,
          ownerDisplayName: testShoppingList.ownerDisplayName,
          items: testShoppingList.items,
          type: ListType.collaborative,
          memberPermissions: {
            'user456': SharedListPermission.edit,
            'user789': SharedListPermission.view,
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: sharedList,
                showSharingStatus: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.people), findsOneWidget);
        expect(find.textContaining('Delad med 2 personer'), findsOneWidget);
      });

      testWidgets('hides sharing indicator for personal list', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                showSharingStatus: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.people), findsNothing);
        expect(find.textContaining('Delad'), findsNothing);
      });

      testWidgets('shows compact sharing indicator in grid style', (WidgetTester tester) async {
        final sharedList = UnifiedShoppingList(
          id: testShoppingList.id,
          name: testShoppingList.name,
          ownerId: testShoppingList.ownerId,
          ownerDisplayName: testShoppingList.ownerDisplayName,
          items: testShoppingList.items,
          type: ListType.collaborative,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: sharedList,
                style: ShoppingListCardStyle.grid,
                showSharingStatus: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.people), findsOneWidget);
      });
    });

    group('Interactions', () {
      testWidgets('handles tap callback', (WidgetTester tester) async {
        bool wasTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                onTap: () {
                  wasTapped = true;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(InkWell));
        expect(wasTapped, isTrue);
      });

      testWidgets('handles long press callback', (WidgetTester tester) async {
        bool wasLongPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                onLongPress: () {
                  wasLongPressed = true;
                },
              ),
            ),
          ),
        );

        await tester.longPress(find.byType(InkWell));
        expect(wasLongPressed, isTrue);
      });
    });

    group('Date Formatting', () {
      testWidgets('displays "Idag" for today\'s list', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                showMetadata: true,
              ),
            ),
          ),
        );

        // Date is shown as part of metadata string
        expect(find.textContaining('Idag'), findsOneWidget);
      });

      testWidgets('displays "Igår" for yesterday\'s list', (WidgetTester tester) async {
        final yesterdayList = UnifiedShoppingList(
          id: testShoppingList.id,
          name: testShoppingList.name,
          ownerId: testShoppingList.ownerId,
          ownerDisplayName: testShoppingList.ownerDisplayName,
          items: testShoppingList.items,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: yesterdayList,
                showMetadata: true,
              ),
            ),
          ),
        );

        // Date is shown as part of metadata string  
        expect(find.textContaining('Igår'), findsOneWidget);
      });

      testWidgets('displays days ago for recent lists', (WidgetTester tester) async {
        final oldList = UnifiedShoppingList(
          id: testShoppingList.id,
          name: testShoppingList.name,
          ownerId: testShoppingList.ownerId,
          ownerDisplayName: testShoppingList.ownerDisplayName,
          items: testShoppingList.items,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: oldList,
                showMetadata: true,
              ),
            ),
          ),
        );

        expect(find.textContaining('5 dagar sedan'), findsOneWidget);
      });
    });

    group('Layout and Styling', () {
      testWidgets('applies correct container decoration', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(InkWell),
            matching: find.byType(Container),
          ).first,
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.backgroundLight));
        expect(decoration.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadiusM)));
      });

      testWidgets('applies custom margin when provided', (WidgetTester tester) async {
        const customMargin = EdgeInsets.all(20.0);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                margin: customMargin,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        expect(container.margin, equals(customMargin));
      });

      testWidgets('applies custom padding when provided', (WidgetTester tester) async {
        const customPadding = EdgeInsets.all(25.0);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                padding: customPadding,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(InkWell),
            matching: find.byType(Container),
          ).first,
        );
        expect(container.padding, equals(customPadding));
      });

      testWidgets('uses default padding based on style', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                style: ShoppingListCardStyle.compact,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(InkWell),
            matching: find.byType(Container),
          ).first,
        );
        expect(container.padding, equals(const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingS,
          vertical: AppDimensions.spacingS,
        )));
      });
    });

    group('Swedish Localization', () {
      testWidgets('displays Swedish text for items', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: testShoppingList,
                showMetadata: true,
                showPreview: true,
              ),
            ),
          ),
        );

        expect(find.textContaining('3 föremål'), findsOneWidget);
        expect(find.textContaining('1 slutförda'), findsOneWidget);
        expect(find.text('Föremål på listan:'), findsOneWidget);
      });

      testWidgets('displays Swedish text for empty state', (WidgetTester tester) async {
        final emptyList = testShoppingList.copyWith(items: []);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: emptyList,
                showPreview: true,
              ),
            ),
          ),
        );

        expect(find.text('Inga föremål i listan'), findsOneWidget);
      });

      testWidgets('displays Swedish text for completion', (WidgetTester tester) async {
        final completedItems = testItems.map((item) => UnifiedShoppingItem(
          id: item.id,
          name: item.name,
          amount: item.amount,
          unit: item.unit,
          category: item.category,
          bought: true,
        )).toList();
        final completedList = testShoppingList.copyWith(items: completedItems);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: completedList,
                style: ShoppingListCardStyle.compact,
              ),
            ),
          ),
        );

        expect(find.text('Klar'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('handles very long list name', (WidgetTester tester) async {
        final longNameList = testShoppingList.copyWith(
          name: 'Detta är en väldigt lång lista namn som borde trunkeras om den är för lång för att visas på en rad',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: ShoppingListCard(
                  shoppingList: longNameList,
                  style: ShoppingListCardStyle.compact,
                ),
              ),
            ),
          ),
        );

        final titleText = find.textContaining('Detta är en väldigt lång').evaluate().first.widget as Text;
        expect(titleText.overflow, equals(TextOverflow.ellipsis));
        expect(titleText.maxLines, equals(1));
      });

      testWidgets('handles list with no members', (WidgetTester tester) async {
        final noMembersList = UnifiedShoppingList(
          id: testShoppingList.id,
          name: testShoppingList.name,
          ownerId: testShoppingList.ownerId,
          ownerDisplayName: testShoppingList.ownerDisplayName,
          items: testShoppingList.items,
          memberPermissions: {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: noMembersList,
              ),
            ),
          ),
        );

        expect(find.byType(ShoppingListCard), findsOneWidget);
      });

      testWidgets('handles zero items gracefully', (WidgetTester tester) async {
        final emptyList = testShoppingList.copyWith(items: []);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShoppingListCard(
                shoppingList: emptyList,
                style: ShoppingListCardStyle.compact,
              ),
            ),
          ),
        );

        // Should not show completion indicator when no items
        expect(find.byIcon(Icons.hourglass_empty), findsNothing);
        expect(find.byIcon(Icons.check_circle), findsNothing);
      });
    });
  });
}