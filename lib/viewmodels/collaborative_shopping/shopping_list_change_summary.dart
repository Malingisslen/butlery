import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

/// What someone else changed on an open shared list, in one line, or null
/// when the two snapshots differ in nothing a row shows.
///
/// Only the first change is named; the rest are counted. The order is the
/// order a person would want to hear it: a changed value first, then an added
/// or removed item, then a tick.
String? summarizeListChange({
  required List<UnifiedShoppingItem> previous,
  required List<UnifiedShoppingItem> updated,
  required String byName,
  required AppLocalizations l10n,
}) {
  final before = {for (final item in previous) item.id: item};
  final after = {for (final item in updated) item.id: item};

  final changes = <(int, String)>[];

  void add(int order, String line) => changes.add((order, line));

  for (final item in updated) {
    final old = before[item.id];
    if (old == null) continue;
    if (old.name != item.name) {
      add(
        0,
        l10n.shoppingListChangedItem(byName, old.displayText, item.displayText),
      );
    } else if (old.amount != item.amount || old.unit != item.unit) {
      add(
        0,
        l10n.shoppingListChangedQuantity(
          byName,
          item.name,
          _quantity(old),
          _quantity(item),
        ),
      );
    }
  }
  for (final item in updated) {
    if (!before.containsKey(item.id)) {
      add(1, l10n.shoppingListAddedItem(byName, item.name));
    }
  }
  for (final item in previous) {
    if (!after.containsKey(item.id)) {
      add(2, l10n.shoppingListRemovedItem(byName, item.name));
    }
  }
  for (final item in updated) {
    final old = before[item.id];
    if (old == null || old.bought == item.bought) continue;
    add(
      3,
      item.bought
          ? l10n.shoppingListBoughtItem(byName, item.name)
          : l10n.shoppingListUnboughtItem(byName, item.name),
    );
  }

  if (changes.isEmpty) return null;
  final first = changes.reduce((a, b) => b.$1 < a.$1 ? b : a).$2;
  final more = changes.length - 1;
  return more == 0 ? first : l10n.shoppingListMoreChanges(first, more);
}

String _quantity(UnifiedShoppingItem item) {
  final text = item.quantityText;
  return text.isEmpty ? '1' : text;
}
