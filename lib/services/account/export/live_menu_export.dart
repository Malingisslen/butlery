// lib/services/account/export/live_menu_export.dart

import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show ExportPaginationHelper, normalizeRecipeDocumentStamps, sanitizeForJson;

/// BUT-2151: the Article-15 section for live menus (`realtime_resources`) —
/// the menus the user owns or takes part in.
///
/// ADR-0023 (Malin, 2026-09-30): other participants' display names are
/// stripped and their user ids kept, as for shared shopping lists (BUT-1732),
/// including the copies inside each dish the menu stores (BUT-1798's nested
/// shape).
class LiveMenuExport {
  final FirebaseDataExportRepository _exports;

  static const String _logTag = 'LiveMenuExport';

  const LiveMenuExport(this._exports);

  /// Display-name keys and the id key naming whose name each one is, on the
  /// menu document itself. Kept when that id is the requester's, dropped
  /// otherwise.
  static const Map<String, String> nameKeysByOwnerIdKey = {
    'ownerDisplayName': 'ownerId',
    'lastEditedByDisplayName': 'lastEditedBy',
  };

  /// The same, inside each dish in `menuSnapshot`: the nested map, its name
  /// key and its id key (`RecipeSocialData.toJson`, `RecipeRealtimeData.toJson`).
  static const List<(String, String, String)> dishNameKeys = [
    ('socialData', 'ownerDisplayName', 'ownerId'),
    ('realtimeData', 'lastEditedByDisplayName', 'lastEditedByUserId'),
  ];

  Future<Map<String, dynamic>> export(String userId) async {
    try {
      final owned = await ExportPaginationHelper.fetchCapped(
        type: 'realtime_resources',
        fetch: (max) =>
            _exports.exportRealtimeResourcesOwned(userId, maxDocuments: max),
      );
      final joined = await ExportPaginationHelper.fetchCapped(
        type: 'realtime_resources',
        fetch: (max) => _exports.exportRealtimeResourcesAsParticipant(
          userId,
          maxDocuments: max,
        ),
      );

      final docs = <String, Map<String, dynamic>>{
        for (final row in [...owned.items, ...joined.items])
          row['id'] as String: (row['data'] as Map).cast<String, dynamic>(),
      };

      return {
        'total_count': docs.length,
        'live_menus': [
          for (final entry in docs.entries)
            {'menu_id': entry.key, 'data': minimise(entry.value, userId)},
        ],
        'data_minimisation':
            "Other participants' cached display names are omitted; their user "
            'IDs are retained.',
        if (owned.truncated || joined.truncated) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export live menus', e);
      // A stable token, never `e.toString()`: see SharedShoppingListExport.
      return {
        'error': 'Live menus could not be exported.',
        'error_code': 'live-menus-export-failed',
      };
    }
  }

  /// The JSON-safe menu document with other people's names removed at both
  /// depths and each dish's timestamps in UTC. A `menuSnapshot` entry that is
  /// not a list of maps is withheld rather than shipped unexamined.
  static Map<String, dynamic> minimise(
    Map<String, dynamic> source,
    String userId,
  ) {
    final copy = dropOtherPeoplesNames(source, userId);
    final snapshot = copy['menuSnapshot'];
    if (snapshot is Map) {
      copy['menuSnapshot'] = {
        for (final category in snapshot.entries)
          category.key.toString(): [
            if (category.value is List)
              for (final dish in category.value as List)
                if (dish is Map)
                  _minimiseDish(dish.cast<String, dynamic>(), userId),
          ],
      };
    } else {
      copy.remove('menuSnapshot');
    }
    final json = sanitizeForJson(copy) as Map<String, dynamic>;
    final dishes = json['menuSnapshot'];
    if (dishes is Map) {
      for (final category in dishes.values) {
        for (final dish in category as List) {
          normalizeRecipeDocumentStamps(dish as Map<String, dynamic>);
        }
      }
    }
    return json;
  }

  static Map<String, dynamic> _minimiseDish(
    Map<String, dynamic> dish,
    String userId,
  ) {
    final copy = Map<String, dynamic>.from(dish);
    for (final (mapKey, nameKey, idKey) in dishNameKeys) {
      final nested = copy[mapKey];
      if (nested is Map) {
        final inner = nested.cast<String, dynamic>();
        if (inner.containsKey(nameKey) && inner[idKey] != userId) {
          copy[mapKey] = Map<String, dynamic>.from(inner)..remove(nameKey);
        }
      }
    }
    return copy;
  }

  /// [source] with every top-level cached display name describing someone
  /// other than [userId] removed; the paired id stays.
  static Map<String, dynamic> dropOtherPeoplesNames(
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
