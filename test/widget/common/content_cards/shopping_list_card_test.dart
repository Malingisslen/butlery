// test/widget/common/content_cards/shopping_list_card_test.dart
// Widget tests for ShoppingListCard — rewritten to match current production widget

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/content_cards/shopping_list_card.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  setUp(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('ShoppingListCard Tests', () {
    final testItems = [
      UnifiedShoppingItem(
        id: 'item1',
        name: 'Mj\u00f6lk',
        amount: 1.0,
        unit: 'liter',
        category: ShoppingCategory.dairy,
        bought: false,
      ),
      UnifiedShoppingItem(
        id: 'item2',
        name: 'Br\u00f6d',
        amount: 2.0,
        unit: 'st',
        category: ShoppingCategory.breadGrain,
        bought: true,
      ),
      UnifiedShoppingItem(
        id: 'item3',
        name: '\u00c4gg',
        amount: 12.0,
        unit: 'st',
        category: ShoppingCategory.dairy,
        bought: false,
      ),
    ];

    final testShoppingList = UnifiedShoppingList(
      id: 'list123',
      name: 'Veckans ink\u00f6p',
      ownerId: 'user123',
      ownerDisplayName: 'Anna Andersson',
      items: testItems,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
      type: ListType.personal,
      description: 'Lista f\u00f6r veckans mat',
    );

    Widget createCardApp({
      required UnifiedShoppingList shoppingList,
      ShoppingListCardStyle style = ShoppingListCardStyle.detailed,
      bool showPreview = true,
      bool showMetadata = true,
      bool showSharingStatus = false,
      VoidCallback? onTap,
      VoidCallback? onLongPress,
      EdgeInsets? margin,
      EdgeInsets? padding,
      double? constrainedWidth,
    }) {
      Widget card = ShoppingListCard(
        shoppingList: shoppingList,
        style: style,
        showPreview: showPreview,
        showMetadata: showMetadata,
        showSharingStatus: showSharingStatus,
        onTap: onTap,
        onLongPress: onLongPress,
        margin: margin,
        padding: padding,
      );

      if (constrainedWidth != null) {
        card = SizedBox(width: constrainedWidth, child: card);
      }

      return createLocalizedTestApp(child: card);
    }

    group('Basic Rendering', () {
      testWidgets('renders with list name and cart icon',
          (WidgetTester tester) async {
        await tester.pumpWidget(createCardApp(
          shoppingList: testShoppingList,
        ));
        await tester.pumpAndSettle();

        expect(find.byType(ShoppingListCard), findsOneWidget);
        expect(find.text('Veckans ink\u00f6p'), findsOneWidget);
        expect(find.byIcon(Icons.shopping_cart), findsOneWidget);
      });

      testWidgets('displays item count in metadata',
          (WidgetTester tester) async {
        await tester.pumpWidget(createCardApp(
          shoppingList: testShoppingList,
          showMetadata: true,
        ));
        await tester.pumpAndSettle();

        // Metadata joins with bullet: "3 artiklar . 1 slutf\u00f6rda . Idag"
        expect(find.textContaining('3 artiklar'), findsOneWidget);
      });

      testWidgets('shows empty preview when no items',
          (WidgetTester tester) async {
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

        await tester.pumpWidget(createCardApp(
          shoppingList: emptyList,
          showPreview: true,
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });
    });

    group('Card Styles', () {
      testWidgets('renders detailed style with preview',
          (WidgetTester tester) async {
        await tester.pumpWidget(createCardApp(
          shoppingList: testShoppingList,
          style: ShoppingListCardStyle.detailed,
          showPreview: true,
          showMetadata: true,
        ));
        await tester.pumpAndSettle();

        // Preview shows item names via displayText
        expect(find.textContaining('Mj\u00f6lk'), findsOneWidget);
        expect(find.textContaining('Br\u00f6d'), findsOneWidget);
      });

      testWidgets('renders compact style', (WidgetTester tester) async {
        await tester.pumpWidget(createCardApp(
          shoppingList: testShoppingList,
          style: ShoppingListCardStyle.compact,
          showMetadata: true,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Veckans ink\u00f6p'), findsOneWidget);
        expect(find.byType(ShoppingListCard), findsOneWidget);
      });

      testWidgets('renders grid style', (WidgetTester tester) async {
        await tester.pumpWidget(createCardApp(
          shoppingList: testShoppingList,
          style: ShoppingListCardStyle.grid,
        ));
        await tester.pumpAndSettle();

        expect(find.byType(ShoppingListCard), findsOneWidget);
      });
    });

    group('Item Preview', () {
      testWidgets('shows first 4 items and overflow count',
          (WidgetTester tester) async {
        final manyItems = List.generate(
          10,
          (i) => UnifiedShoppingItem(
            id: 'item$i',
            name: 'F\u00f6rem\u00e5l $i',
            amount: 1.0,
            unit: 'st',
            category: ShoppingCategory.other,
            bought: false,
          ),
        );

        final longList = testShoppingList.copyWith(items: manyItems);

        await tester.pumpWidget(createCardApp(
          shoppingList: longList,
          showPreview: true,
        ));
        await tester.pumpAndSettle();

        // displayText format: "1 st F\u00f6rem\u00e5l N"
        expect(find.textContaining('F\u00f6rem\u00e5l 0'), findsOneWidget);
        expect(find.textContaining('F\u00f6rem\u00e5l 1'), findsOneWidget);
        expect(find.textContaining('F\u00f6rem\u00e5l 2'), findsOneWidget);
        expect(find.textContaining('F\u00f6rem\u00e5l 3'), findsOneWidget);
        expect(find.textContaining('F\u00f6rem\u00e5l 4'), findsNothing);
      });

      testWidgets('shows check icons for completed items',
          (WidgetTester tester) async {
        await tester.pumpWidget(createCardApp(
          shoppingList: testShoppingList,
          showPreview: true,
        ));
        await tester.pumpAndSettle();

        // 1 bought (Br\u00f6d) = check_circle, 2 not bought = radio_button_unchecked
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
      });

      testWidgets('hides preview when showPreview is false',
          (WidgetTester tester) async {
        await tester.pumpWidget(createCardApp(
          shoppingList: testShoppingList,
          showPreview: false,
        ));
        await tester.pumpAndSettle();

        // No item text should appear in preview
        expect(find.textContaining('Mj\u00f6lk'), findsNothing);
      });

      testWidgets('applies strikethrough to completed items',
          (WidgetTester tester) async {
        await tester.pumpWidget(createCardApp(
          shoppingList: testShoppingList,
          showPreview: true,
        ));
        await tester.pumpAndSettle();

        // Find the completed item text (Br\u00f6d) and check decoration
        final breadTexts = find.textContaining('Br\u00f6d').evaluate();
        if (breadTexts.isNotEmpty) {
          final breadText = breadTexts.first.widget as Text;
          expect(
              breadText.style?.decoration, equals(TextDecoration.lineThrough));
        }
      });
    });

    group('Completion Indicator', () {
      testWidgets('shows percentage for incomplete list in compact style',
          (WidgetTester tester) async {
        await tester.pumpWidget(createCardApp(
          shoppingList: testShoppingList,
          style: ShoppingListCardStyle.compact,
        ));
        await tester.pumpAndSettle();

        // 1/3 = 33%
        expect(find.textContaining('33%'), findsOneWidget);
        expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      });

      testWidgets('shows complete state when all items bought',
          (WidgetTester tester) async {
        final completedItems = testItems
            .map((item) => UnifiedShoppingItem(
                  id: item.id,
                  name: item.name,
                  amount: item.amount,
                  unit: item.unit,
                  category: item.category,
                  bought: true,
                ))
            .toList();
        final completedList = testShoppingList.copyWith(items: completedItems);

        await tester.pumpWidget(createCardApp(
          shoppingList: completedList,
          style: ShoppingListCardStyle.compact,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Klar'), findsOneWidget);
      });

      testWidgets('hides indicator when no items', (WidgetTester tester) async {
        final emptyList = testShoppingList.copyWith(items: []);

        await tester.pumpWidget(createCardApp(
          shoppingList: emptyList,
          style: ShoppingListCardStyle.compact,
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.hourglass_empty), findsNothing);
        expect(find.byIcon(Icons.check_circle), findsNothing);
      });
    });

    group('Sharing Status', () {
      testWidgets('shows sharing indicator for collaborative list',
          (WidgetTester tester) async {
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

        await tester.pumpWidget(createCardApp(
          shoppingList: sharedList,
          showSharingStatus: true,
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.people), findsOneWidget);
      });

      testWidgets('hides sharing indicator for personal list',
          (WidgetTester tester) async {
        await tester.pumpWidget(createCardApp(
          shoppingList: testShoppingList,
          showSharingStatus: true,
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.people), findsNothing);
      });
    });

    group('Interactions', () {
      testWidgets('handles tap callback', (WidgetTester tester) async {
        bool wasTapped = false;

        await tester.pumpWidget(createCardApp(
          shoppingList: testShoppingList,
          onTap: () => wasTapped = true,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(InkWell));
        expect(wasTapped, isTrue);
      });

      testWidgets('handles long press callback', (WidgetTester tester) async {
        bool wasLongPressed = false;

        await tester.pumpWidget(createCardApp(
          shoppingList: testShoppingList,
          onLongPress: () => wasLongPressed = true,
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.byType(InkWell));
        expect(wasLongPressed, isTrue);
      });
    });

    group('Date Formatting', () {
      testWidgets('displays today for current date',
          (WidgetTester tester) async {
        await tester.pumpWidget(createCardApp(
          shoppingList: testShoppingList,
          showMetadata: true,
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('Idag'), findsOneWidget);
      });

      testWidgets('displays yesterday for one day ago',
          (WidgetTester tester) async {
        final yesterdayList = UnifiedShoppingList(
          id: testShoppingList.id,
          name: testShoppingList.name,
          ownerId: testShoppingList.ownerId,
          ownerDisplayName: testShoppingList.ownerDisplayName,
          items: testShoppingList.items,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        );

        await tester.pumpWidget(createCardApp(
          shoppingList: yesterdayList,
          showMetadata: true,
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('Ig\u00e5r'), findsOneWidget);
      });

      testWidgets('displays days ago for recent lists',
          (WidgetTester tester) async {
        final oldList = UnifiedShoppingList(
          id: testShoppingList.id,
          name: testShoppingList.name,
          ownerId: testShoppingList.ownerId,
          ownerDisplayName: testShoppingList.ownerDisplayName,
          items: testShoppingList.items,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        );

        await tester.pumpWidget(createCardApp(
          shoppingList: oldList,
          showMetadata: true,
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('5 dagar sedan'), findsOneWidget);
      });
    });

    group('Layout', () {
      testWidgets('applies custom margin', (WidgetTester tester) async {
        const customMargin = EdgeInsets.all(20.0);

        await tester.pumpWidget(createCardApp(
          shoppingList: testShoppingList,
          margin: customMargin,
        ));
        await tester.pumpAndSettle();

        // The outermost Container inside RepaintBoundary has the margin
        final containers = find
            .descendant(
              of: find.byType(RepaintBoundary),
              matching: find.byType(Container),
            )
            .evaluate();
        expect(containers, isNotEmpty);

        final container = containers.first.widget as Container;
        expect(container.margin, equals(customMargin));
      });

      testWidgets('handles very long list name with ellipsis',
          (WidgetTester tester) async {
        final longNameList = testShoppingList.copyWith(
          name:
              'Detta \u00e4r en v\u00e4ldigt l\u00e5ng lista namn som borde trunkeras',
        );

        await tester.pumpWidget(createCardApp(
          shoppingList: longNameList,
          style: ShoppingListCardStyle.compact,
          constrainedWidth: 300,
        ));
        await tester.pumpAndSettle();

        final titleTexts =
            find.textContaining('Detta \u00e4r en v\u00e4ldigt').evaluate();
        if (titleTexts.isNotEmpty) {
          final titleText = titleTexts.first.widget as Text;
          expect(titleText.overflow, equals(TextOverflow.ellipsis));
          expect(titleText.maxLines, equals(1));
        }
      });
    });

    group('Edge Cases', () {
      testWidgets('handles list with no members', (WidgetTester tester) async {
        final noMembersList = UnifiedShoppingList(
          id: testShoppingList.id,
          name: testShoppingList.name,
          ownerId: testShoppingList.ownerId,
          ownerDisplayName: testShoppingList.ownerDisplayName,
          items: testShoppingList.items,
          memberPermissions: {},
        );

        await tester.pumpWidget(createCardApp(
          shoppingList: noMembersList,
        ));
        await tester.pumpAndSettle();

        expect(find.byType(ShoppingListCard), findsOneWidget);
      });
    });
  });
}
