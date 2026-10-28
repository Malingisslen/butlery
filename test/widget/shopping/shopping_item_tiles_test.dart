import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/shopping/shopping_row.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_item_tiles.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_motion.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/semantics_announcement.dart';

// The row sets the name first and the amount after it, in one Text.rich.
String rowText(UnifiedShoppingItem item) =>
    item.quantityText.isEmpty ? item.name : '${item.name} ${item.quantityText}';

ColorScheme schemeOf(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(ShoppingRow))).colorScheme;

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(ShoppingRowMenu));
  await tester.pumpAndSettle();
}

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

        expect(find.text(rowText(basicItem)), findsOneWidget);
        expect(find.byIcon(ButleryIcons.check), findsNothing);
        // Edit and delete live behind the row's menu, not beside the name.
        expect(find.byType(ShoppingRowMenu), findsOneWidget);
        expect(find.byIcon(ButleryIcons.pencil), findsNothing);
        expect(find.byIcon(ButleryIcons.trash2), findsNothing);
      });

      testWidgets('the amount follows the name in the muted tone', (
        WidgetTester tester,
      ) async {
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

        final cs = schemeOf(tester);
        final text = tester.widget<Text>(find.text(rowText(basicItem)));
        final span = text.textSpan! as TextSpan;
        expect(span.children, hasLength(2));
        expect((span.children![0] as TextSpan).text, basicItem.name);
        final amount = span.children![1] as TextSpan;
        expect(amount.text!.trim(), basicItem.quantityText);
        expect(amount.style?.color, cs.onSurfaceVariant);
        expect(text.style?.color, cs.onSurface);
      });

      testWidgets('renders completed item with strikethrough', (
        WidgetTester tester,
      ) async {
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

        expect(find.byIcon(ButleryIcons.check), findsOneWidget);

        final textWidget = tester.widget<Text>(
          find.text(rowText(completedItem)),
        );
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

        expect(find.text(rowText(itemWithNote)), findsOneWidget);
        expect(find.text(itemWithNote.note!), findsOneWidget);
      });

      // BUT-2193 (Malin, 2026-10-03): a row may cut a long note at the
      // normal text size, and wraps it when the text is scaled up.
      for (final (scale, wraps) in [(1.0, false), (2.0, true)]) {
        testWidgets('a long note at ${scale}x ${wraps ? 'wraps' : 'is cut'}', (
          WidgetTester tester,
        ) async {
          const note =
              'Ekologiska om möjligt, annars de från gården vid vägen ut mot sjön';
          await tester.pumpWidget(
            createLocalizedTestApp(
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: SizedBox(
                  width: 360,
                  child: ShoppingItemTile(
                    item: itemWithNote.copyWith(note: note),
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

          final text = tester.widget<Text>(find.text(note));
          expect(text.maxLines, wraps ? isNull : 1);
          final lineHeight = tester
              .renderObject<RenderParagraph>(find.text(note))
              .preferredLineHeight;
          final height = tester.getSize(find.text(note)).height;
          expect(
            height,
            wraps ? greaterThan(lineHeight * 1.5) : lessThan(lineHeight * 1.5),
          );
        });
      }
    });

    group('buildItemTile - Priority Indicators', () {
      testWidgets('shows no priority indicator for normal priority', (
        WidgetTester tester,
      ) async {
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
        final priorityIndicators = find.byWidgetPredicate((widget) {
          if (widget is Container && widget.decoration is BoxDecoration) {
            final decoration = widget.decoration! as BoxDecoration;
            return decoration.shape == BoxShape.circle;
          }
          return false;
        });

        expect(priorityIndicators, findsNothing);
      });

      testWidgets('shows primary color for high priority (4)', (
        WidgetTester tester,
      ) async {
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

        final priorityIndicator = find.byWidgetPredicate((widget) {
          if (widget is Container && widget.decoration is BoxDecoration) {
            final decoration = widget.decoration! as BoxDecoration;
            return decoration.shape == BoxShape.circle;
          }
          return false;
        });

        expect(priorityIndicator, findsOneWidget);

        final container = tester.widget<Container>(priorityIndicator);
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, AppColors.lightColorScheme.primary);
      });

      testWidgets('shows primary color for urgent priority (5)', (
        WidgetTester tester,
      ) async {
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

        final priorityIndicator = find.byWidgetPredicate((widget) {
          if (widget is Container && widget.decoration is BoxDecoration) {
            final decoration = widget.decoration! as BoxDecoration;
            return decoration.shape == BoxShape.circle;
          }
          return false;
        });

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

      testWidgets('edit is in the menu and calls onEditItem', (
        WidgetTester tester,
      ) async {
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

        await openMenu(tester);
        await tester.tap(find.text('Redigera'));
        await tester.pumpAndSettle();

        expect(editedItem, equals(basicItem));
      });

      testWidgets('delete is in the menu and calls onDeleteItem', (
        WidgetTester tester,
      ) async {
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

        await openMenu(tester);
        await tester.tap(find.text('Ta bort'));
        await tester.pumpAndSettle();

        expect(deletedItem, equals(basicItem));
      });

      testWidgets('move is in the menu, calls onMoveToCategory and does not '
          'check the item off', (WidgetTester tester) async {
        var moved = false;
        var tapped = false;
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: basicItem,
              isCompleted: false,
              onItemTap: (_) => tapped = true,
              onEditItem: (_) {},
              onDeleteItem: (_) {},
              onMoveToCategory: () => moved = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await openMenu(tester);
        await tester.tap(find.text('Flytta till kategori'));
        await tester.pumpAndSettle();

        expect(moved, isTrue);
        expect(tapped, isFalse);
      });

      testWidgets('a ticked-off item cannot be moved', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: completedItem,
              isCompleted: true,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
              onMoveToCategory: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await openMenu(tester);
        expect(find.text('Redigera'), findsOneWidget);
        expect(find.text('Ta bort'), findsOneWidget);
        expect(find.text('Flytta till kategori'), findsNothing);
      });

      testWidgets('the menu button names its item in its tooltip', (
        WidgetTester tester,
      ) async {
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

        expect(
          tester
              .widget<PopupMenuButton<int>>(find.byType(PopupMenuButton<int>))
              .tooltip,
          'Fler val för Mjölk',
        );
      });
    });

    group('buildItemTile - Visual States', () {
      testWidgets('applies correct styles for non-completed item', (
        WidgetTester tester,
      ) async {
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

        final textWidget = tester.widget<Text>(find.text(rowText(basicItem)));
        expect(textWidget.style?.color, schemeOf(tester).onSurface);
        expect(
          textWidget.style?.decoration,
          anyOf(isNull, TextDecoration.none),
        );
      });

      testWidgets('applies correct styles for completed item', (
        WidgetTester tester,
      ) async {
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

        final textWidget = tester.widget<Text>(
          find.text(rowText(completedItem)),
        );
        expect(textWidget.style?.color, schemeOf(tester).onSurfaceVariant);
        expect(textWidget.style?.decoration, TextDecoration.lineThrough);
      });

      testWidgets('applies correct styles for note on completed item', (
        WidgetTester tester,
      ) async {
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

      testWidgets('handles long text with ellipsis', (
        WidgetTester tester,
      ) async {
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

        final textWidget = tester.widget<Text>(find.text(rowText(longItem)));
        expect(textWidget.overflow, TextOverflow.ellipsis);
        expect(textWidget.maxLines, 2);
      });
    });

    group('buildEmptyState', () {
      testWidgets('renders empty state with all components', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) {
                return ShoppingItemTiles.buildEmptyState(
                  context: context,
                  title: 'Inga varor',
                  message: 'Din inköpslista är tom',
                  icon: ButleryIcons.shoppingCart,
                );
              },
            ),
          ),
        );

        expect(find.text('Inga varor'), findsOneWidget);
        expect(find.text('Din inköpslista är tom'), findsOneWidget);
        expect(find.byIcon(ButleryIcons.shoppingCart), findsOneWidget);

        final icon = tester.widget<Icon>(
          find.byIcon(ButleryIcons.shoppingCart),
        );
        expect(icon.size, 64);
      });

      testWidgets('centers empty state content', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) {
                return ShoppingItemTiles.buildEmptyState(
                  context: context,
                  title: 'Test Title',
                  message: 'Test Message',
                  icon: ButleryIcons.info,
                );
              },
            ),
          ),
        );

        final center = find.byType(Center);
        expect(center, findsWidgets);

        final titleWidget = tester.widget<Text>(find.text('Test Title'));
        expect(titleWidget.textAlign, TextAlign.center);

        final messageWidget = tester.widget<Text>(find.text('Test Message'));
        expect(messageWidget.textAlign, TextAlign.center);
      });

      testWidgets('applies correct styles to empty state', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) {
                return ShoppingItemTiles.buildEmptyState(
                  context: context,
                  title: 'Empty',
                  message: 'No items',
                  icon: ButleryIcons.inbox,
                );
              },
            ),
          ),
        );

        final titleWidget = tester.widget<Text>(find.text('Empty'));
        expect(titleWidget.style?.color, isNotNull);

        final messageWidget = tester.widget<Text>(find.text('No items'));
        expect(messageWidget.style?.color, isNotNull);

        final icon = tester.widget<Icon>(find.byIcon(ButleryIcons.inbox));
        expect(icon.color, isNotNull);
      });
    });

    group('Accessibility', () {
      testWidgets('the menu button is a labelled button naming its item', (
        WidgetTester tester,
      ) async {
        final handle = tester.ensureSemantics();
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

        final menu = find.byTooltip('Fler val för Mjölk');
        expect(menu, findsOneWidget);
        final data = tester.getSemantics(menu).getSemanticsData();
        expect(data.tooltip, 'Fler val för Mjölk');
        expectActivatable(tester, menu);
        handle.dispose();
      });

      testWidgets('the row says what a tap does, once, in both states', (
        WidgetTester tester,
      ) async {
        final handle = tester.ensureSemantics();
        for (final (item, done, verb) in [
          (basicItem, false, 'Bocka av'),
          (completedItem, true, 'Ta bort bocken'),
        ]) {
          await tester.pumpWidget(
            createLocalizedTestApp(
              child: ShoppingItemTile(
                item: item,
                isCompleted: done,
                onItemTap: (_) {},
                onEditItem: (_) {},
                onDeleteItem: (_) {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          final row = find.bySemanticsLabel(RegExp('^$verb'));
          expect(row, findsOneWidget);
          expectActivatable(tester, row);
          expectNothingAnnouncedTwice(tester, row);
          expect(
            tester
                .getSemantics(row)
                .getSemanticsData()
                .flagsCollection
                .isChecked,
            done ? ui.CheckedState.isTrue : ui.CheckedState.isFalse,
          );
        }
        handle.dispose();
      });

      testWidgets('maintains minimum touch target size', (
        WidgetTester tester,
      ) async {
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

        // WCAG 2.5.5: assert the rendered hit areas of the row and its menu.
        for (final target in [
          find.byType(InkWell).first,
          find.byType(PopupMenuButton<int>),
        ]) {
          final size = tester.getSize(target);
          expect(
            size.height,
            greaterThanOrEqualTo(AppDimensions.minTouchTarget),
            reason: '$target',
          );
        }
        expect(
          tester.getSize(find.byType(PopupMenuButton<int>)).width,
          greaterThanOrEqualTo(AppDimensions.minTouchTarget),
        );
      });
    });

    group('Edge Cases', () {
      testWidgets('a lower-case name is shown with a capital first letter', (
        WidgetTester tester,
      ) async {
        final lowerCase = UnifiedShoppingItem(
          id: 'lower',
          name: 'citronsaft',
          amount: 1,
          unit: 'msk',
          category: 'Övrigt',
          bought: false,
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingItemTile(
              item: lowerCase,
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(rowText(lowerCase).replaceFirst('c', 'C')),
          findsOneWidget,
        );
      });

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

        expect(find.text(rowText(zeroItem)), findsOneWidget);
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
      testWidgets('checkbox uses AnimatedContainer for fill transition', (
        WidgetTester tester,
      ) async {
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

      testWidgets('checkbox uses ScaleTransition for pulse', (
        WidgetTester tester,
      ) async {
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

      testWidgets('checkbox uses AnimatedSwitcher for check icon', (
        WidgetTester tester,
      ) async {
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

      testWidgets('pulse animation triggers on isCompleted change', (
        WidgetTester tester,
      ) async {
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
        final midScale = tester.widget<ScaleTransition>(checkboxScaleFinder);
        expect(midScale.scale.value, greaterThan(1.0));

        // Let animation complete
        await tester.pumpAndSettle();

        // Scale returns to 1.0
        final endScale = tester.widget<ScaleTransition>(checkboxScaleFinder);
        expect(endScale.scale.value, 1.0);
      });

      testWidgets('checkbox fill color animates on toggle', (
        WidgetTester tester,
      ) async {
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
        expect(find.byIcon(ButleryIcons.check), findsNothing);

        // Toggle to completed
        setOuterState(() => isCompleted = true);
        await tester.pumpAndSettle();

        // Verify checked state: check icon present
        expect(find.byIcon(ButleryIcons.check), findsOneWidget);

        // Toggle back to unchecked
        setOuterState(() => isCompleted = false);
        await tester.pumpAndSettle();

        // Verify unchecked again
        expect(find.byIcon(ButleryIcons.check), findsNothing);
      });

      testWidgets('AnimatedContainer uses theme duration and curve constants', (
        WidgetTester tester,
      ) async {
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
        expect(animatedContainer.duration, AppMotion.micro);
        expect(animatedContainer.curve, AppMotion.curve);
      });

      testWidgets('AnimatedSwitcher uses theme duration constant', (
        WidgetTester tester,
      ) async {
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
        expect(animatedSwitcher.duration, AppMotion.micro);
      });
    });

    group('Static API backward compatibility', () {
      testWidgets('buildItemTile delegates to ShoppingItemTile widget', (
        WidgetTester tester,
      ) async {
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
        expect(find.text(rowText(basicItem)), findsOneWidget);
      });

      testWidgets('the row has no drag handle; moving is in its menu', (
        WidgetTester tester,
      ) async {
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

        expect(find.byType(Draggable<UnifiedShoppingItem>), findsNothing);
        expect(find.byIcon(ButleryIcons.drag), findsNothing);
        await tester.tap(find.byType(ShoppingRowMenu));
        await tester.pumpAndSettle();
        expect(find.text('Flytta till kategori'), findsOneWidget);
      });
    });
  });
}
