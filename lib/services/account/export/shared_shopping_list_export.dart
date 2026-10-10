// lib/services/account/export/shared_shopping_list_export.dart

import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/models/unified/shopping_display_name_keys.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show ExportPaginationHelper, sanitizeForJson;

/// BUT-1732: the Article-15 section for SHARED shopping lists
/// (`unified_shared_shopping_lists`) — the lists the user owns or is a member
/// of.
///
/// `ContentExportManager.exportShoppingLists` only ever read
/// `users/{uid}/unified_shopping_lists`, so a household that does all its
/// shopping on a shared list received an export whose shopping section was
/// empty — while `account-deletion-cascade.ts` scrubs exactly these documents
/// under Article 17. Art. 15 has to cover at least what Art. 17 erases.
///
/// Split out of [ContentExportManager] purely to keep that facade under the
/// 500-line limit.
class SharedShoppingListExport {
  final FirebaseDataExportRepository _exports;

  static const String _logTag = 'SharedShoppingListExport';

  const SharedShoppingListExport(this._exports);

  /// Display-name keys that describe whoever the paired `*UserId` names. Kept
  /// when that id is the requester's, dropped otherwise.
  ///
  /// **Data minimisation (Art. 5(1)(c), Art. 15(4)).** A shared list is joint
  /// household data the requester can already read byte for byte in the app, so
  /// withholding the list itself would protect nobody and would gut the
  /// section. What the export does drop is the part that is another data
  /// subject's PROFILE rather than the requester's own record: the cached
  /// display names of other members, on the rows they added, on the
  /// assignments they made, on the owner line and on the activity stamp.
  ///
  /// Counterparty user IDs stay raw, following the BUT-1450 precedent — Art.
  /// 15(4) is a balancing test, and a pseudonymous id the requester already
  /// holds is not "the rights and freedoms of others"; a name is what turns the
  /// bundle into a copy of someone else's profile.
  ///
  /// This map must name EVERY `*DisplayName` field
  /// `UnifiedShoppingItem.toFirestore` and `UnifiedShoppingList.toFirestore`
  /// persist. Enumerating four of the six shipped the two most frequently
  /// written ones — `purchasedByDisplayName` and `lastModifiedByDisplayName`
  /// are stamped on every tick of a shared list — while [export]'s own
  /// `data_minimisation` line told the requester they had been dropped. A test
  /// pins the map against the models' key sets so a new attribution field
  /// cannot be added without appearing here.
  /// A stable identifier for an exported row.
  ///
  /// Position fallback rather than a bare `item['id']`: a legacy row written
  /// without an id (or with a blank one) would export as `"item_id": null`,
  /// and several such rows in one list would all be indistinguishable in a
  /// bundle whose whole purpose is to show the subject their own records.
  /// Real ids are UUIDs, so `row_<n>` cannot collide with one.
  static String _itemId(Object? rawId, int index) {
    final id = rawId?.toString().trim();
    return (id == null || id.isEmpty) ? 'row_$index' : id;
  }

  static const Map<String, String> nameKeysByOwnerIdKey =
      shoppingDisplayNameKeysByUserIdKey;

  Future<Map<String, dynamic>> export(String userId) async {
    try {
      final owned = await ExportPaginationHelper.fetchCapped(
        type: 'shared_shopping_lists',
        fetch: (max) =>
            _exports.exportSharedShoppingListsOwned(userId, maxDocuments: max),
      );
      final member = await ExportPaginationHelper.fetchCapped(
        type: 'shared_shopping_lists',
        fetch: (max) => _exports.exportSharedShoppingListsAsMember(
          userId,
          maxDocuments: max,
        ),
      );

      final roles = <String, Set<String>>{};
      final docs = <String, Map<String, dynamic>>{};
      void collect(Iterable<Map<String, dynamic>> rows, String role) {
        for (final row in rows) {
          final id = row['id'] as String;
          docs[id] = row;
          (roles[id] ??= <String>{}).add(role);
        }
      }

      collect(owned.items, 'owner');
      collect(member.items, 'member');

      final lists = [
        for (final entry in docs.entries)
          _minimiseList(
            listId: entry.key,
            data: (entry.value['data'] as Map).cast<String, dynamic>(),
            roles: roles[entry.key]!.toList()..sort(),
            userId: userId,
          ),
      ];

      return {
        'total_count': lists.length,
        'shared_shopping_lists': lists,
        'data_minimisation':
            "Other household members' cached display names are omitted; their "
            'user IDs are retained.',
        // Per-sub-query flags, not merged-length-vs-one-cap (BUT-1662).
        if (owned.truncated || member.truncated) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export shared shopping lists',
        e,
      );
      // A stable token, never `e.toString()`: a raw Firestore/permission string
      // carries uids and document paths into an artifact the data subject may
      // forward to a supervisory authority. `error_code` is also what lifts the
      // section into `export_metadata.warnings` — without it the bundle silently
      // claims to be complete while this whole section is missing. Same
      // convention as `family_export_manager.dart`.
      return {
        'error': 'Shared shopping lists could not be exported.',
        'error_code': 'shared-shopping-lists-export-failed',
      };
    }
  }

  Map<String, dynamic> _minimiseList({
    required String listId,
    required Map<String, dynamic> data,
    required List<String> roles,
    required String userId,
  }) {
    final items = (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              _dropOtherPeoplesNames(item.cast<String, dynamic>(), userId),
        )
        .toList();

    final listInfo = _dropOtherPeoplesNames(data, userId)..remove('items');

    return {
      'list_id': listId,
      'your_roles': roles,
      // Raw Firestore doc map: a Timestamp/GeoPoint left in here throws out of
      // the ENTIRE GDPR export at jsonEncode, not just this section.
      'list_info': sanitizeForJson(listInfo),
      'items': [
        // Position fallback: a legacy row written without `id` would otherwise
        // export as `"item_id": null` and be unidentifiable in the bundle.
        for (final (index, item) in items.indexed)
          {
            'item_id': _itemId(item['id'], index),
            'data': sanitizeForJson(item),
          },
      ],
    };
  }

  /// [source] with every cached display name describing someone other than
  /// [userId] removed. The paired `*UserId` stays, so a row is still
  /// attributable for the requester without shipping another member's profile.
  Map<String, dynamic> _dropOtherPeoplesNames(
    Map<String, dynamic> source,
    String userId,
  ) {
    final copy = Map<String, dynamic>.from(source);
    nameKeysByOwnerIdKey.forEach((nameKey, idKey) {
      if (copy.containsKey(nameKey) && copy[idKey] != userId) {
        copy.remove(nameKey);
      }
    });
    return copy;
  }
}
