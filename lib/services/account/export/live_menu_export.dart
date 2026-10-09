// lib/services/account/export/live_menu_export.dart

import 'package:butlery/core/constants/firestore_collections.dart';
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

  /// BUT-2118: the user's own ballot documents: the votes they started, the
  /// dishes they proposed, what they voted for and how they settled their
  /// votes. Other people's ballots are not here; a vote's options are dishes
  /// in the menu's shape, so other people's names come out of them as they do
  /// from the menu.
  Future<Map<String, dynamic>> exportVotes(String userId) async {
    const note =
        'Your own votes on live menus. Who else voted, and for what, is not '
        'included.';
    try {
      final rows = await ExportPaginationHelper.fetchCapped(
        type: 'live_menu_votes',
        fetch: (max) =>
            _exports.exportLiveMenuVotesByUser(userId, maxDocuments: max),
      );
      final ballots = [
        for (final row in rows.items)
          if (row['parent_collection'] ==
              FirestoreCollections.realtimeResources)
            row,
      ];
      return {
        'total_count': ballots.length,
        'live_menu_votes': [
          for (final row in ballots)
            {
              'menu_id': row['menu_id'],
              'data': minimiseBallot(
                (row['data'] as Map).cast<String, dynamic>(),
                userId,
              ),
            },
        ],
        'note': note,
        if (rows.truncated) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export menu votes', e);
      return {
        'error': 'Live menu votes could not be exported.',
        'error_code': 'live-menu-votes-export-failed',
        'note': note,
      };
    }
  }

  /// The JSON-safe ballot document with other people's names removed from
  /// every option's dish.
  static Map<String, dynamic> minimiseBallot(
    Map<String, dynamic> source,
    String userId,
  ) {
    Map<String, dynamic> option(Object? o) {
      final copy = Map<String, dynamic>.from(o is Map ? o : const {});
      final dish = copy['dish'];
      if (dish is Map) {
        copy['dish'] = _minimiseDish(dish.cast<String, dynamic>(), userId);
      }
      return copy;
    }

    final copy = Map<String, dynamic>.from(source);
    final started = copy['started'];
    if (started is Map) {
      copy['started'] = {
        for (final e in started.entries)
          if (e.value is Map)
            e.key.toString(): {
              ...(e.value as Map).cast<String, dynamic>(),
              'options': [
                for (final o
                    in ((e.value as Map)['options'] as List? ?? const []))
                  option(o),
              ],
            },
      };
    }
    final proposals = copy['proposals'];
    if (proposals is Map) {
      copy['proposals'] = {
        for (final e in proposals.entries) e.key.toString(): option(e.value),
      };
    }
    return sanitizeForJson(copy) as Map<String, dynamic>;
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
