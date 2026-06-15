import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_item_tiles.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/theme_constants.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('ShoppingItemTiles Widget Tests', () {
    late UnifiedShoppingItem basicItem;
    late UnifiedShoppingItem completedItem;
    late UnifiedShoppingItem itemWithNote;
    late UnifiedShoppingItem highPriorityItem;
    late UnifiedShoppingItem urgentPriorityItem;

    setUp(() {
      basicItem = UnifiedShoppingItem(
        id: 'test-1',
        name: 'Mjölk',
        amount: 1.5,
        unit: 'liter',
        category: 'Mejeri',
        bought: false,
      );

      completedItem = UnifiedShoppingItem(
        id: 'test-2',
        name: 'Bröd',
        amount: 2,
        unit: 'st',
        category: 'Bröd',
        bought: true,
      );

      itemWithNote = UnifiedShoppingItem(
        id: 'test-3',
        name: 'Ägg',
        amount: 12,
        unit: 'st',
        category: 'Mejeri',
        bought: false,
        note: 'Ekologiska om möjligt',
      );

      highPriorityItem = UnifiedShoppingItem(
        id: 'test-4',
        name: 'Medicin',
        amount: 1,
        unit: 'förpackning',
        category: 'Övrigt',
        bought: false,
        priority: 4,
      );

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
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: basicItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(basicItem.displayText), findsOneWidget);
        expect(find.byIcon(Icons.check), findsNothing);
        expect(find.byIcon(Icons.edit), findsOneWidget);
        expect(find.byIcon(Icons.delete), findsOneWidget);
      });

      testWidgets('renders completed item with strikethrough',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: completedItem,
              isCompleted: true,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check), findsOneWidget);

        final textWidget =
            tester.widget<Text>(find.text(completedItem.displayText));
        expect(textWidget.style?.decoration, TextDecoration.lineThrough);
      });

      testWidgets('renders item with note', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: itemWithNote,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(itemWithNote.displayText), findsOneWidget);
        expect(find.text(itemWithNote.note!), findsOneWidget);
      });
    });

    group('buildItemTile - Priority Indicators', () {
      testWidgets('shows no priority indicator for normal priority',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: basicItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the priority dot: a small Container with circular BoxDecoration
        final priorityIndicators = find.byWidgetPredicate(
          (widget) {
            if (widget is Container && widget.decoration is BoxDecoration) {
              final decoration = widget.decoration! as BoxDecoration;
              return decoration.shape == BoxShape.circle;
            }
            return false;
          },
        );

        expect(priorityIndicators, findsNothing);
      });

      testWidgets('shows primary color for high priority (4)',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: highPriorityItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final priorityIndicator = find.byWidgetPredicate(
          (widget) {
            if (widget is Container && widget.decoration is BoxDecoration) {
              final decoration = widget.decoration! as BoxDecoration;
              return decoration.shape == BoxShape.circle;
            }
            return false;
          },
        );

        expect(priorityIndicator, findsOneWidget);

        final container = tester.widget<Container>(priorityIndicator);
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, AppColors.lightColorScheme.primary);
      });

      testWidgets('shows primary color for urgent priority (5)',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: urgentPriorityItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final priorityIndicator = find.byWidgetPredicate(
          (widget) {
            if (widget is Container && widget.decoration is BoxDecoration) {
              final decoration = widget.decoration! as BoxDecoration;
              return decoration.shape == BoxShape.circle;
            }
            return false;
          },
        );

        expect(priorityIndicator, findsOneWidget);

        final container = tester.widget<Container>(priorityIndicator);
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, AppColors.lightColorScheme.primary);
      });
    });

    group('buildItemTile - User Interactions', () {
      testWidgets('handles item tap', (WidgetTester tester) async {
        UnifiedShoppingItem? tappedItem;

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: basicItem,
              isCompleted: false,
              onItemTap: (item) => tappedItem = item,
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();

        expect(tappedItem, equals(basicItem));
      });

      testWidgets('handles edit button tap', (WidgetTester tester) async {
        UnifiedShoppingItem? editedItem;

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: basicItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (item) => editedItem = item,
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle();

        expect(editedItem, equals(basicItem));
      });

      testWidgets('handles delete button tap', (WidgetTester tester) async {
        UnifiedShoppingItem? deletedItem;

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: basicItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (item) => deletedItem = item,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.delete));
        await tester.pumpAndSettle();

        expect(deletedItem, equals(basicItem));
      });

      testWidgets('shows correct tooltips on action buttons',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: basicItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final editButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.edit),
        );
        // Tooltip mirrors a11yEditItem(name) per AppIconButton — "Redigera <name>".
        expect(editButton.tooltip, 'Redigera Mjölk');

        final deleteButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.delete),
        );
        expect(deleteButton.tooltip, 'Ta bort Mjölk');
      });
    });

    group('buildItemTile - Visual States', () {
      testWidgets('applies correct styles for non-completed item',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: basicItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textWidget =
            tester.widget<Text>(find.text(basicItem.displayText));
        // Production uses cs.onSurface which maps to AppColors.textDark
        expect(textWidget.style?.color, AppColors.textDark);
        expect(
            textWidget.style?.decoration, anyOf(isNull, TextDecoration.none));
      });

      testWidgets('applies correct styles for completed item',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: completedItem,
              isCompleted: true,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textWidget =
            tester.widget<Text>(find.text(completedItem.displayText));
        // Production uses cs.onSurfaceVariant which maps to AppColors.textMedium
        expect(textWidget.style?.color, AppColors.textMedium);
        expect(textWidget.style?.decoration, TextDecoration.lineThrough);
      });

      testWidgets('applies correct styles for note on completed item',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: itemWithNote,
              isCompleted: true,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final noteWidget = tester.widget<Text>(find.text(itemWithNote.note!));
        expect(noteWidget.style?.decoration, TextDecoration.lineThrough);
      });

      testWidgets('handles long text with ellipsis',
          (WidgetTester tester) async {
        final longItem = UnifiedShoppingItem(
          id: 'long-test',
          name:
              'Detta är en väldigt lång produktnamn som borde klippas av med ellipsis för att inte ta upp för mycket plats',
          amount: 1,
          unit: 'st',
          category: 'Test',
          bought: false,
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: SizedBox(
                width: 300,
                child: ShoppingItemTile(
                  item: longItem,
                  isCompleted: false,
                  onItemTap: (_) {},
                  onEditItem: (_) {},
                  onDeleteItem: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textWidget = tester.widget<Text>(find.text(longItem.displayText));
        expect(textWidget.overflow, TextOverflow.ellipsis);
        expect(textWidget.maxLines, 2);
      });
    });

    group('buildEmptyState', () {
      testWidgets('renders empty state with all components',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(builder: (context) {
              return ShoppingItemTiles.buildEmptyState(
                context: context,
                title: 'Inga varor',
                message: 'Din inköpslista är tom',
                icon: Icons.shopping_cart_outlined,
              );
            }),
          ),
        );

        expect(find.text('Inga varor'), findsOneWidget);
        expect(find.text('Din inköpslista är tom'), findsOneWidget);
        expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);

        final icon =
            tester.widget<Icon>(find.byIcon(Icons.shopping_cart_outlined));
        expect(icon.size, 64);
      });

      testWidgets('centers empty state content', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(builder: (context) {
              return ShoppingItemTiles.buildEmptyState(
                context: context,
                title: 'Test Title',
                message: 'Test Message',
                icon: Icons.info,
              );
            }),
          ),
        );

        final center = find.byType(Center);
        expect(center, findsWidgets);

        final titleWidget = tester.widget<Text>(find.text('Test Title'));
        expect(titleWidget.textAlign, TextAlign.center);

        final messageWidget = tester.widget<Text>(find.text('Test Message'));
        expect(messageWidget.textAlign, TextAlign.center);
      });

      testWidgets('applies correct styles to empty state',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(builder: (context) {
              return ShoppingItemTiles.buildEmptyState(
                context: context,
                title: 'Empty',
                message: 'No items',
                icon: Icons.inbox,
              );
            }),
          ),
        );

        final titleWidget = tester.widget<Text>(find.text('Empty'));
        expect(titleWidget.style?.color, isNotNull);

        final messageWidget = tester.widget<Text>(find.text('No items'));
        expect(messageWidget.style?.color, isNotNull);

        final icon = tester.widget<Icon>(find.byIcon(Icons.inbox));
        expect(icon.color, isNotNull);
      });
    });

    group('Accessibility', () {
      testWidgets('has proper semantics for buttons',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: basicItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final editButton = find.widgetWithIcon(IconButton, Icons.edit);
        final deleteButton = find.widgetWithIcon(IconButton, Icons.delete);

        expect(editButton, findsOneWidget);
        expect(deleteButton, findsOneWidget);

        final editButtonWidget = tester.widget<IconButton>(editButton);
        final deleteButtonWidget = tester.widget<IconButton>(deleteButton);

        // Tooltips mirror a11yEditItem/a11yDeleteItem(name) — "<verb> <name>".
        expect(editButtonWidget.tooltip, 'Redigera Mjölk');
        expect(deleteButtonWidget.tooltip, 'Ta bort Mjölk');
      });

      testWidgets('maintains minimum touch target size',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: basicItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // AppIconButton doesn't pass explicit constraints to its inner
        // IconButton — it relies on Material's built-in 48dp interactive
        // minimum. Assert the rendered hit-area instead, which is what
        // actually matters for WCAG 2.5.5.
        final editButtonSize =
            tester.getSize(find.widgetWithIcon(IconButton, Icons.edit));
        expect(editButtonSize.width,
            greaterThanOrEqualTo(AppDimensions.minTouchTarget));
        expect(editButtonSize.height,
            greaterThanOrEqualTo(AppDimensions.minTouchTarget));
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
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: zeroItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

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
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: emptyNoteItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Empty note should not be displayed (only item text visible)
        final textWidgets = find.byType(Text);
        for (final element in textWidgets.evaluate()) {
          final text = element.widget as Text;
          expect(text.data, isNot(equals('')));
        }
      });

      testWidgets('handles rapid taps correctly', (WidgetTester tester) async {
        int tapCount = 0;

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: basicItem,
              isCompleted: false,
              onItemTap: (_) => tapCount++,
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(InkWell).first);
        await tester.tap(find.byType(InkWell).first);
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();

        expect(tapCount, 3);
      });
    });

    group('Check-off Animations', () {
      testWidgets('checkbox uses AnimatedContainer for fill transition',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: basicItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedContainer), findsOneWidget);
      });

      testWidgets('checkbox uses ScaleTransition for pulse',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: basicItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the ScaleTransition that wraps AnimatedContainer (our checkbox pulse),
        // not the one inside AnimatedSwitcher's default transition builder
        final checkboxScale = find.ancestor(
          of: find.byType(AnimatedContainer),
          matching: find.byType(ScaleTransition),
        );
        expect(checkboxScale, findsOneWidget);
      });

      testWidgets('checkbox uses AnimatedSwitcher for check icon',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: basicItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSwitcher), findsOneWidget);
      });

      testWidgets('pulse animation triggers on isCompleted change',
          (WidgetTester tester) async {
        bool isCompleted = false;

        // Finder for our checkbox ScaleTransition (ancestor of AnimatedContainer)
        final checkboxScaleFinder = find.ancestor(
          of: find.byType(AnimatedContainer),
          matching: find.byType(ScaleTransition),
        );

        late StateSetter setOuterState;
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                setOuterState = setState;
                return ShoppingItemTile(
                  item: basicItem,
                  isCompleted: isCompleted,
                  onItemTap: (_) {},
                  onEditItem: (_) {},
                  onDeleteItem: (_) {},
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify scale is 1.0 at rest
        final scaleTransition = tester.widget<ScaleTransition>(
          checkboxScaleFinder,
        );
        expect(scaleTransition.scale.value, 1.0);

        // Toggle completed
        setOuterState(() => isCompleted = true);

        // Pump a single frame to start the animation
        await tester.pump();

        // Pump partway through the animation (pulse should be > 1.0)
        await tester.pump(const Duration(milliseconds: 40));
        final midScale = tester.widget<ScaleTransition>(
          checkboxScaleFinder,
        );
        expect(midScale.scale.value, greaterThan(1.0));

        // Let animation complete
        await tester.pumpAndSettle();

        // Scale returns to 1.0
        final endScale = tester.widget<ScaleTransition>(
          checkboxScaleFinder,
        );
        expect(endScale.scale.value, 1.0);
      });

      testWidgets('checkbox fill color animates on toggle',
          (WidgetTester tester) async {
        bool isCompleted = false;

        late StateSetter setOuterState;
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                setOuterState = setState;
                return ShoppingItemTile(
                  item: basicItem,
                  isCompleted: isCompleted,
                  onItemTap: (_) {},
                  onEditItem: (_) {},
                  onDeleteItem: (_) {},
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify unchecked state: no check icon
        expect(find.byIcon(Icons.check), findsNothing);

        // Toggle to completed
        setOuterState(() => isCompleted = true);
        await tester.pumpAndSettle();

        // Verify checked state: check icon present
        expect(find.byIcon(Icons.check), findsOneWidget);

        // Toggle back to unchecked
        setOuterState(() => isCompleted = false);
        await tester.pumpAndSettle();

        // Verify unchecked again
        expect(find.byIcon(Icons.check), findsNothing);
      });

      testWidgets('AnimatedContainer uses theme duration and curve constants',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: basicItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final animatedContainer = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        expect(animatedContainer.duration, ThemeConstants.durationStandard);
        expect(animatedContainer.curve, ThemeConstants.standardCurve);
      });

      testWidgets('AnimatedSwitcher uses theme duration constant',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: basicItem,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final animatedSwitcher = tester.widget<AnimatedSwitcher>(
          find.byType(AnimatedSwitcher),
        );
        expect(animatedSwitcher.duration, ThemeConstants.durationFast);
      });
    });

    group('Static API backward compatibility', () {
      testWidgets('buildItemTile delegates to ShoppingItemTile widget',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
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
        );
        await tester.pumpAndSettle();

        // Verify the static method creates a ShoppingItemTile widget
        expect(find.byType(ShoppingItemTile), findsOneWidget);
        expect(find.text(basicItem.displayText), findsOneWidget);
      });

      testWidgets(
          'BUT-948: buildDraggableItemTile no longer wraps the whole tile in '
          'a long-press drag (freed for multi-select)',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ShoppingItemTiles.buildDraggableItemTile(
                context,
                basicItem,
                false,
                (_) {},
                (_) {},
                (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
            find.byType(LongPressDraggable<UnifiedShoppingItem>), findsNothing);
        expect(find.byType(ShoppingItemTile), findsOneWidget);
      });

      testWidgets(
          'BUT-948: a grip-handle drag appears only when category-move is '
          'allowed', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ShoppingItemTiles.buildItemTile(
                context,
                basicItem,
                false,
                (_) {},
                (_) {},
                (_) {},
                onMoveToCategory: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Draggable<UnifiedShoppingItem>), findsOneWidget,
            reason: 'reorder moved onto a per-row drag handle');
        expect(find.byIcon(Icons.drag_handle), findsOneWidget);
      });

      testWidgets(
          'buildDraggableItemTile skips drag wrapper for completed items',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ShoppingItemTiles.buildDraggableItemTile(
                context,
                completedItem,
                true,
                (_) {},
                (_) {},
                (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Completed items should NOT be draggable
        expect(
            find.byType(LongPressDraggable<UnifiedShoppingItem>), findsNothing);
        expect(find.byType(ShoppingItemTile), findsOneWidget);
      });
    });
  });
}
