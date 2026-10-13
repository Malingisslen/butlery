/// Pins the category export text: plain headers and ☐/☑ rows, no pictograms (B-44).
library;

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/viewmodels/shopping/shopping_analytics_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  late ShoppingAnalyticsManager manager;

  setUp(() => manager = ShoppingAnalyticsManager(MockUnifiedShoppingService()));

  UnifiedShoppingItem item(String name, {required bool bought}) =>
      UnifiedShoppingItem(
        id: name,
        name: name,
        amount: 1.0,
        unit: 'st',
        category: 'Mejeri',
        bought: bought,
        addedAt: DateTime(2026, 10, 13),
      );

  test('exports title, category headers and ☐/☑ rows as plain text', () {
    final bought = item('Smör', bought: true);
    final open = item('Mjölk', bought: false);
    final list = UnifiedShoppingList(
      id: 'l1',
      name: 'Veckohandling',
      ownerId: 'u1',
      ownerDisplayName: 'Test',
      items: [open, bought],
      type: ListType.personal,
      createdAt: DateTime(2026, 10, 13),
      updatedAt: DateTime(2026, 10, 13),
    );

    final text = manager.exportListAsTextWithCategories(list, {
      'Mejeri': [open, bought],
    });

    expect(
      text,
      equals(
        'Veckohandling\n'
        '\n'
        'Mejeri:\n'
        '  ☐ ${open.displayText}\n'
        '  ☑ ${bought.displayText}\n'
        '\n'
        '${list.summary}\n',
      ),
    );
  });

  test('exports nothing without an active list', () {
    expect(manager.exportListAsTextWithCategories(null, {}), isEmpty);
  });
}
