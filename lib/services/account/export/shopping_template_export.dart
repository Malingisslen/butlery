// lib/services/account/export/shopping_template_export.dart

import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show ExportPaginationHelper, sanitizeForJson;
import 'package:butlery/services/account/export/shared_shopping_list_export.dart';

/// BUT-2354: the Article-15 section for the user's shopping-list templates
/// (`shopping_list_templates`), which the deletion cascade erases.
///
/// A template's `items` are copies of a list's rows, so a template saved from
/// a list the user shares carries other members' cached display names. Those
/// are dropped and their uids kept, by the same map and decision as
/// [SharedShoppingListExport] (BUT-1732).
class ShoppingTemplateExport {
  final FirebaseDataExportRepository _exports;

  static const String _logTag = 'ShoppingTemplateExport';

  const ShoppingTemplateExport(this._exports);

  Future<Map<String, dynamic>> export(String userId) async {
    try {
      final rows = await ExportPaginationHelper.fetchCapped(
        type: 'shopping_list_templates',
        fetch: (max) =>
            _exports.exportShoppingListTemplates(userId, maxDocuments: max),
      );

      return {
        'total_count': rows.items.length,
        'shopping_list_templates': [
          for (final row in rows.items)
            {
              'template_id': row['id'],
              'data': sanitizeForJson(
                minimise((row['data'] as Map).cast<String, dynamic>(), userId),
              ),
            },
        ],
        'data_minimisation':
            "Other people's cached display names on template items are "
            'omitted; their user IDs are retained.',
        if (rows.truncated) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export templates', e);
      // A stable token, never `e.toString()`: see SharedShoppingListExport.
      return {
        'error': 'Shopping list templates could not be exported.',
        'error_code': 'shopping-list-templates-export-failed',
      };
    }
  }

  /// [data] with every display name describing someone other than [userId]
  /// removed, on the template and on each of its items.
  static Map<String, dynamic> minimise(
    Map<String, dynamic> data,
    String userId,
  ) {
    Map<String, dynamic> dropNames(Map<String, dynamic> source) {
      final copy = Map<String, dynamic>.from(source);
      SharedShoppingListExport.nameKeysByOwnerIdKey.forEach((nameKey, idKey) {
        if (copy.containsKey(nameKey) && copy[idKey] != userId) {
          copy.remove(nameKey);
        }
      });
      return copy;
    }

    final copy = dropNames(data);
    final items = data['items'];
    if (items is List) {
      copy['items'] = [
        for (final item in items)
          if (item is Map) dropNames(item.cast<String, dynamic>()) else item,
      ];
    } else {
      // A shape no writer produces cannot be checked for names, so it is
      // left out rather than exported unfiltered.
      copy.remove('items');
    }
    return copy;
  }
}
