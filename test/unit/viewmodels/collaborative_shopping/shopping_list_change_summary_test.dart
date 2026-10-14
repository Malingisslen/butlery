import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/viewmodels/collaborative_shopping/shopping_list_change_summary.dart';

import '../../../infrastructure/factories/shopping_list_factory.dart';

UnifiedShoppingItem _item(
  String id,
  String name, {
  double amount = 1,
  String unit = '',
  bool bought = false,
}) => ShoppingListFactory.buildItem(
  id: id,
  name: name,
  amount: amount,
  unit: unit,
  bought: bought,
);

String? _summary(
  List<UnifiedShoppingItem> previous,
  List<UnifiedShoppingItem> updated,
) => summarizeListChange(
  previous: previous,
  updated: updated,
  byName: 'Anna',
  l10n: AppLocalizationsSv(),
);

void main() {
  group('summarizeListChange', () {
    test('names the item and both values when a quantity changed', () {
      final result = _summary(
        [_item('a', 'Jordgubbar', amount: 2, unit: 'l')],
        [_item('a', 'Jordgubbar', amount: 3, unit: 'l')],
      );

      expect(result, 'Anna ändrade Jordgubbar: 2 l → 3 l');
    });

    test('names the item when only the unit changed', () {
      final result = _summary(
        [_item('a', 'Mjölk', amount: 2, unit: 'st')],
        [_item('a', 'Mjölk', amount: 2, unit: 'l')],
      );

      expect(result, 'Anna ändrade Mjölk: 2 st → 2 l');
    });

    test('shows 1 for a quantity the row does not print', () {
      final result = _summary(
        [_item('a', 'Bröd')],
        [_item('a', 'Bröd', amount: 2)],
      );

      expect(result, 'Anna ändrade Bröd: 1 → 2');
    });

    test('names both rows when the name changed', () {
      final result = _summary(
        [_item('a', 'Mjölk')],
        [_item('a', 'Havredryck')],
      );

      expect(result, 'Anna ändrade Mjölk → Havredryck');
    });

    test('names an added item', () {
      final result = _summary([], [_item('a', 'Smör')]);

      expect(result, 'Anna lade till Smör');
    });

    test('names a removed item', () {
      final result = _summary([_item('a', 'Smör')], []);

      expect(result, 'Anna tog bort Smör');
    });

    test('names a ticked item and an unticked one', () {
      expect(
        _summary([_item('a', 'Ägg')], [_item('a', 'Ägg', bought: true)]),
        'Anna bockade av Ägg',
      );
      expect(
        _summary([_item('a', 'Ägg', bought: true)], [_item('a', 'Ägg')]),
        'Anna bockade ur Ägg',
      );
    });

    test('counts the rest when several things changed', () {
      final result = _summary(
        [_item('a', 'Ägg'), _item('b', 'Smör')],
        [_item('a', 'Ägg', bought: true), _item('c', 'Ost')],
      );

      expect(result, 'Anna lade till Ost och 2 till');
    });

    test('a changed value comes before an added item and a tick', () {
      final result = _summary(
        [_item('a', 'Ägg'), _item('b', 'Smör', amount: 1)],
        [
          _item('a', 'Ägg', bought: true),
          _item('b', 'Smör', amount: 2),
          _item('c', 'Ost'),
        ],
      );

      expect(result, 'Anna ändrade Smör: 1 → 2 och 2 till');
    });

    test('an added item comes before a removed one', () {
      final result = _summary([_item('a', 'Smör')], [_item('b', 'Ost')]);

      expect(result, 'Anna lade till Ost och 1 till');
    });

    test('a removed item comes before a tick', () {
      final result = _summary(
        [_item('a', 'Smör'), _item('b', 'Ägg')],
        [_item('b', 'Ägg', bought: true)],
      );

      expect(result, 'Anna tog bort Smör och 1 till');
    });

    test('returns null when no row differs', () {
      final items = [_item('a', 'Ägg')];

      expect(_summary(items, [_item('a', 'Ägg')]), isNull);
    });
  });
}
