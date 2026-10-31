// lib/services/shopping/week_list_follow_notice.dart

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/shopping/menu_shopping_merge.dart';
import 'package:butlery/services/shopping/week_list_reconciler.dart';

/// What the follows of the week menu did to one list since the user last saw
/// it (Malin 2026-10-31, variant A): "Uppdaterad från veckomenyn: 3 nya,
/// 1 borttagen", with Ångra.
///
/// Several follows in a row are one notice, counted net: a row a follow added
/// and a later follow took off is neither new nor removed.
class WeekListFollowNotice {
  const WeekListFollowNotice({
    required this.listId,
    required this.addedIds,
    required this.removed,
    required this.changed,
    required this.updatedAt,
  });

  final String listId;
  final List<String> addedIds;

  /// The rows the follows took off, as they were before the first of them.
  final List<UnifiedShoppingItem> removed;

  /// The rows the follows overwrote, as they were before the first of them.
  final List<UnifiedShoppingItem> changed;
  final DateTime updatedAt;

  int get addedCount => addedIds.length;
  int get removedCount => removed.length;
  int get changedCount => changed.length;
  bool get isEmpty => addedIds.isEmpty && removed.isEmpty && changed.isEmpty;

  /// [previous] (null for the first follow since the notice was seen) with
  /// [receipt] on top.
  static WeekListFollowNotice merge(
    WeekListFollowNotice? previous,
    MenuShoppingMergeReceipt receipt,
  ) {
    final added = <String>[...?previous?.addedIds];
    final removed = {for (final r in previous?.removed ?? const []) r.id: r};
    final changed = {for (final c in previous?.changed ?? const []) c.id: c};

    for (final id in receipt.addedItemIds) {
      if (!added.contains(id)) added.add(id);
    }
    for (final row in receipt.changedItems) {
      // A row an earlier follow added is still new; one it overwrote keeps
      // its value from before that follow.
      if (added.contains(row.id) || changed.containsKey(row.id)) continue;
      changed[row.id] = row;
    }
    for (final row in receipt.removedItems) {
      if (added.remove(row.id)) continue;
      removed[row.id] = changed.remove(row.id) ?? row;
    }
    return WeekListFollowNotice(
      listId: receipt.listId,
      addedIds: List.unmodifiable(added),
      removed: List.unmodifiable(removed.values),
      changed: List.unmodifiable(changed.values),
      updatedAt: clock.now(),
    );
  }

  /// The Ångra for this notice against [current], the list as it is now.
  /// The notice can be shown long after the follow, so a row the user ticked
  /// or changed since is left as it is, and a removed row that is back is not
  /// put back twice.
  MenuShoppingMergeReceipt undoAgainst(UnifiedShoppingList current) {
    final now = {for (final item in current.items) item.id: item};
    bool asWritten(String id) {
      final row = now[id];
      return row != null && !row.bought && WeekListReconciler.isUntouched(row);
    }

    return MenuShoppingMergeReceipt(
      listId: listId,
      listName: current.name,
      addedItemIds: [
        for (final id in addedIds)
          if (asWritten(id)) id,
      ],
      removedItems: [
        for (final row in removed)
          if (!now.containsKey(row.id)) row,
      ],
      changedItems: [
        for (final row in changed)
          if (asWritten(row.id)) row,
      ],
      previousMenuItemIds: current.menuItemIds,
      createdList: false,
    );
  }

  /// This notice as the receipt of one follow, to merge an older notice
  /// under it.
  MenuShoppingMergeReceipt _asReceipt() => MenuShoppingMergeReceipt(
    listId: listId,
    listName: '',
    addedItemIds: addedIds,
    removedItems: removed,
    changedItems: changed,
    previousMenuItemIds: null,
    createdList: false,
  );

  Map<String, dynamic> toJson() => {
    'listId': listId,
    'addedIds': addedIds,
    'removed': [for (final r in removed) r.toJson()],
    'changed': [for (final c in changed) c.toJson()],
    'updatedAt': updatedAt.toIso8601String(),
  };

  static WeekListFollowNotice fromJson(Map<String, dynamic> json) {
    List<UnifiedShoppingItem> rows(String key) => [
      for (final r in json[key] as List<dynamic>)
        UnifiedShoppingItem.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
    return WeekListFollowNotice(
      listId: json['listId'] as String,
      addedIds: List.unmodifiable(json['addedIds'] as List<dynamic>),
      removed: List.unmodifiable(rows('removed')),
      changed: List.unmodifiable(rows('changed')),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// Keeps each list's [WeekListFollowNotice] on the device until the list is
/// opened, after a restart too. Nothing is written to the server, so the
/// notice shows only on the device the menu was changed on.
class WeekListFollowNoticeStore {
  WeekListFollowNoticeStore(this._preferences);

  /// Cleared at sign-out (`LocalUserDataRegistry`): it holds the user's rows.
  static const String storageKey = 'week_list_follow_notices_v1';

  /// A notice for a list nobody opened this long stops being kept.
  static const Duration keptFor = Duration(days: 14);

  /// Null where no device storage is wired: nothing is kept.
  final SharedPreferences? _preferences;

  /// Adds [receipt] to its list's notice. A follow that wrote nothing adds
  /// nothing.
  Future<void> record(MenuShoppingMergeReceipt receipt) async {
    final all = _readAll();
    final next = WeekListFollowNotice.merge(all[receipt.listId], receipt);
    if (next.isEmpty) {
      all.remove(receipt.listId);
    } else {
      all[receipt.listId] = next;
    }
    await _writeAll(all);
  }

  /// Takes the notice for [listId] off the device and returns it: once shown
  /// it is not shown again.
  Future<WeekListFollowNotice?> take(String listId) async {
    final all = _readAll();
    final notice = all.remove(listId);
    if (notice != null || _pruned) await _writeAll(all);
    return notice;
  }

  /// Puts back a [notice] that was taken but never shown, under any notice
  /// recorded for its list since.
  Future<void> putBack(WeekListFollowNotice notice) async {
    final all = _readAll();
    final since = all[notice.listId];
    all[notice.listId] = since == null
        ? notice
        : WeekListFollowNotice.merge(notice, since._asReceipt());
    await _writeAll(all);
  }

  /// Whether the last read left out a notice past [keptFor], so the next
  /// write takes it off the device too.
  var _pruned = false;

  Map<String, WeekListFollowNotice> _readAll() {
    _pruned = false;
    try {
      final raw = _preferences?.getString(storageKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final oldest = clock.now().subtract(keptFor);
      final all = {
        for (final entry in decoded.entries)
          entry.key: WeekListFollowNotice.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      };
      final count = all.length;
      all.removeWhere((_, notice) => notice.updatedAt.isBefore(oldest));
      _pruned = all.length != count;
      return all;
    } catch (e) {
      AppLogger.warning(
        'Could not read the week list notices: $e',
        'WeekListFollowNoticeStore',
      );
      return {};
    }
  }

  Future<void> _writeAll(Map<String, WeekListFollowNotice> all) async {
    try {
      if (all.isEmpty) {
        await _preferences?.remove(storageKey);
        return;
      }
      await _preferences?.setString(
        storageKey,
        jsonEncode({
          for (final entry in all.entries) entry.key: entry.value.toJson(),
        }),
      );
    } catch (e) {
      AppLogger.warning(
        'Could not keep the week list notice: $e',
        'WeekListFollowNoticeStore',
      );
    }
  }
}
