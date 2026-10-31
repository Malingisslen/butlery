/// Kärnflöde 8B: the marks that say which source wrote a row survive a save
/// and a read, so the next sync still knows its own rows.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';

void main() {
  final marked = UnifiedShoppingItem(
    id: 'a',
    name: 'mjölk',
    amount: 2,
    unit: 'dl',
    generatedFrom: 'plan',
    generatedAs: 'mjolk|dl|2|other|',
  );

  test('both marks survive Firestore and JSON round trips', () {
    final fromFirestore = UnifiedShoppingItem.fromFirestore(
      marked.toFirestore(),
    );
    final fromJson = UnifiedShoppingItem.fromJson(marked.toJson());

    for (final read in [fromFirestore, fromJson]) {
      expect(read.generatedFrom, 'plan');
      expect(read.generatedAs, 'mjolk|dl|2|other|');
    }
  });

  test('a row written before the marks existed reads with none', () {
    final plain = UnifiedShoppingItem(id: 'b', name: 'ost', amount: 1);

    final read = UnifiedShoppingItem.fromFirestore(plain.toFirestore());

    expect(read.generatedFrom, isNull);
    expect(read.generatedAs, isNull);
  });

  test('copyWith keeps the marks unless told otherwise', () {
    final edited = marked.copyWith(amount: 3);

    expect(edited.generatedFrom, 'plan');
    expect(edited.generatedAs, 'mjolk|dl|2|other|');
    expect(marked.copyWith(generatedFrom: 'menu').generatedFrom, 'menu');
  });
}
