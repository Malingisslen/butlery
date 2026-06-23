/// BUT-948: gates the shopping tile's multi-select behaviour — long-press enters
/// selection (showing the selection circle and reading as selected to a11y), tap
/// toggles, and per-item action buttons (edit/delete/handle) hide while
/// selecting. With no selection manager in scope the tile degrades to the plain
/// check-off tile (nullable provider).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/viewmodels/shopping/shopping_selection_manager.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_item_tiles.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

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
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    // Per-item actions are hidden while selecting.
    expect(find.byIcon(Icons.delete), findsNothing);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
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
