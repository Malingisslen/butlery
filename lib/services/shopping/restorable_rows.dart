import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/unified/shopping_row_snapshot.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';

/// Pure logic for the 30-day "Återställ varor" history (BUT-2140): what counts
/// as a change worth keeping, what is pruned, and how many are held.
abstract final class RestorableRows {
  /// The history never holds more than this many removed rows, so the list
  /// document stays far from Firestore's 1 MiB limit.
  static const int maxRemoved = 30;

  /// Whether the user-typed content of two rows differs. A check-off, a claim,
  /// a priority or a price change is not content: it must not cost history.
  /// A missing note and an empty one are the same note.
  static bool contentChanged(UnifiedShoppingItem a, UnifiedShoppingItem b) =>
      a.name != b.name ||
      a.amount != b.amount ||
      a.unit != b.unit ||
      a.category != b.category ||
      a.note.orEmpty() != b.note.orEmpty();

  /// [after] carrying the right `previous`. A content edit makes [before]'s
  /// content the new `previous`, so two edits keep only the latest earlier
  /// version; anything else leaves `previous` exactly as it was on [before].
  static UnifiedShoppingItem withPrevious(
    UnifiedShoppingItem before,
    UnifiedShoppingItem after,
    DateTime now,
  ) => after.withPreviousSnapshot(
    contentChanged(before, after)
        ? ShoppingRowSnapshot.fromItem(before, now)
        : before.previous,
  );

  /// [list] with [rows] added to `recentlyRemoved`. A bought row is skipped:
  /// it was bought, not lost. Entries older than 30 days are pruned, a row
  /// removed twice keeps only its newest entry, and past [maxRemoved] the
  /// oldest entries go.
  static UnifiedShoppingList withRemoved(
    UnifiedShoppingList list,
    Iterable<UnifiedShoppingItem> rows,
    DateTime now,
  ) {
    final added = [
      for (final row in rows)
        if (!row.bought) ShoppingRowSnapshot.fromItem(row, now),
    ];
    final addedIds = {for (final s in added) s.id};
    final kept = [
      for (final s in list.recentlyRemoved)
        if (s.restorableAt(now) && !addedIds.contains(s.id)) s,
    ];

    // Position breaks ties so a batch removed at one instant caps in a stable
    // order.
    final indexed = [...kept, ...added].indexed.toList()
      ..sort((a, b) {
        final byTime = a.$2.at.compareTo(b.$2.at);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    final ordered = [for (final (_, s) in indexed) s];
    final capped = ordered.length > maxRemoved
        ? ordered.sublist(ordered.length - maxRemoved)
        : ordered;

    return list.copyWith(recentlyRemoved: capped, updatedAt: list.updatedAt);
  }

  /// The raw elements of a stored `recentlyRemoved` array whose `id` is in
  /// [ids], exactly as read, for an `arrayRemove`: it matches by value, and a
  /// value parsed and written back can differ from the stored one.
  static List<Object?> storedElements(Object? raw, Set<String> ids) => [
    if (raw is List)
      for (final element in raw)
        if (element is Map && ids.contains(element['id'])) element,
  ];

  /// The entries of [list] a user can still restore at [now], newest first.
  static List<ShoppingRowSnapshot> restorableAt(
    UnifiedShoppingList list,
    DateTime now,
  ) => [
    for (final s in list.recentlyRemoved)
      if (s.restorableAt(now)) s,
  ]..sort((a, b) => b.at.compareTo(a.at));

  /// The rows of [list] whose `previous` is still within 30 days at [now] and
  /// differs from what the row says now, newest first.
  static List<UnifiedShoppingItem> changedAt(
    UnifiedShoppingList list,
    DateTime now,
  ) => [
    for (final item in list.items)
      if (item.previous case final p?
          when p.restorableAt(now) && contentChanged(item, p.toItem()))
        item,
  ]..sort((a, b) => b.previous!.at.compareTo(a.previous!.at));

  static bool hasRestorable(UnifiedShoppingList list, DateTime now) =>
      restorableAt(list, now).isNotEmpty || changedAt(list, now).isNotEmpty;
}
