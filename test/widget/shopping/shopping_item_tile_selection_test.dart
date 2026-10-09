/// BUT-948: gates the shopping tile's multi-select behaviour — long-press enters
/// selection (showing the selection circle and reading as selected to a11y), tap
/// toggles, and per-item action buttons (edit/delete/handle) hide while
/// selecting. With no selection manager in scope the tile degrades to the plain
/// check-off tile (nullable provider).
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/viewmodels/shopping/shopping_selection_manager.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_item_tiles.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/semantics_announcement.dart';

void main() {
  final item = UnifiedShoppingItem(
    id: 's_1',
    name: 'Mjölk',
    amount: 1,
    unit: 'liter',
    category: 'Mejeri',
    bought: false,
  );

  Future<ShoppingSelectionManager> pumpTile(WidgetTester tester) async {
    final selection = ShoppingSelectionManager();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ChangeNotifierProvider<ShoppingSelectionManager>.value(
          value: selection,
          child: ShoppingItemTile(
            item: item,
            isCompleted: false,
            onItemTap: (_) {},
            onEditItem: (_) {},
            onDeleteItem: (_) {},
            onMoveToCategory: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return selection;
  }

  testWidgets('long-press enters selection and shows the selection circle', (
    tester,
  ) async {
    final selection = await pumpTile(tester);

    await tester.longPress(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(selection.isSelectionMode, isTrue);
    expect(selection.isSelected('s_1'), isTrue);
    expect(find.byIcon(ButleryIcons.circleCheck), findsOneWidget);
    // Per-item actions are hidden while selecting.
    expect(find.byIcon(ButleryIcons.trash2), findsNothing);
    expect(find.byIcon(ButleryIcons.drag), findsNothing);
  });

  testWidgets('a row in selection mode says "Markera" once, names the item '
      'once, is activatable and exposes its selected state', (tester) async {
    final handle = tester.ensureSemantics();
    final selection = await pumpTile(tester);
    // Another row is the selected one, so this row starts unselected.
    selection.enterSelectionMode('other');
    await tester.pumpAndSettle();

    final row = find.bySemanticsLabel(RegExp(r'^Markera'));
    expect(row, findsOneWidget);
    final lines = announcedLines(tester, row);
    expect(lines.where((l) => l == 'Markera'), hasLength(1), reason: '$lines');
    expect(
      lines.where((l) => l.contains('Mjölk')),
      hasLength(1),
      reason: 'the item name comes from the visible text only: $lines',
    );
    expectNothingAnnouncedTwice(tester, row);
    expectActivatable(tester, row);
    expect(
      tester.getSemantics(row).getSemanticsData().flagsCollection.isSelected,
      ui.Tristate.isFalse,
    );

    selection.toggleSelection('s_1');
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(row).getSemanticsData().flagsCollection.isSelected,
      ui.Tristate.isTrue,
    );
    handle.dispose();
  });

  testWidgets('the drag grip adds "Dra för att flytta kategori" to the row '
      'once, and the item name is still read once', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpTile(tester);

    final row = find.bySemanticsLabel(RegExp('Dra för att flytta kategori'));
    expect(row, findsOneWidget);
    final lines = announcedLines(tester, row);
    expect(
      lines.where((l) => l == 'Dra för att flytta kategori'),
      hasLength(1),
      reason: '$lines',
    );
    expect(
      lines.where((l) => l.contains('Mjölk')),
      hasLength(1),
      reason:
          'the grip must not restate the name the row already reads: '
          '$lines',
    );
    expectNothingAnnouncedTwice(tester, row);
    expectActivatable(tester, row);
    handle.dispose();
  });

  testWidgets('tapping the only selected row exits selection mode', (
    tester,
  ) async {
    final selection = await pumpTile(tester);
    selection.enterSelectionMode('s_1');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(selection.isSelectionMode, isFalse);
  });

  testWidgets('normal tap checks off (not select) when not in selection mode', (
    tester,
  ) async {
    var tapped = false;
    final selection = ShoppingSelectionManager();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ChangeNotifierProvider<ShoppingSelectionManager>.value(
          value: selection,
          child: ShoppingItemTile(
            item: item,
            isCompleted: false,
            onItemTap: (_) => tapped = true,
            onEditItem: (_) {},
            onDeleteItem: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(selection.isSelectionMode, isFalse);
  });
}
