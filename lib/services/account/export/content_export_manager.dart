// lib/services/account/export/content_export_manager.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Handles export of user content: recipes, menus, shopping lists.
/// Part of GDPR Article 20 (Right to Data Portability) compliance.
class ContentExportManager {
  final FirebaseFirestore _firestore;
  static const String _logTag = 'ContentExportManager';

  ContentExportManager({required FirebaseFirestore firestore})
      : _firestore = firestore;

  /// Export all user recipes (personal and unified)
  Future<Map<String, dynamic>> exportRecipes(String userId) async {
    try {
      final recipes = <Map<String, dynamic>>[];

      // Personal recipes in user's subcollection
      final personalRecipes = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recipes')
          .get();

      for (final doc in personalRecipes.docs) {
        recipes.add({
          'recipe_id': doc.id,
          'type': 'personal',
          'data': doc.data(),
        });
      }

      // Unified recipes where user is owner
      final unifiedRecipes = await _firestore
          .collection('recipes')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in unifiedRecipes.docs) {
        recipes.add({
          'recipe_id': doc.id,
          'type': 'unified',
          'data': doc.data(),
        });
      }

      return {
        'total_count': recipes.length,
        'recipes': recipes,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export recipes', e);
      return {'error': e.toString()};
    }
  }

  /// Export all user menus (personal and shared)
  Future<Map<String, dynamic>> exportMenus(String userId) async {
    try {
      final menus = <Map<String, dynamic>>[];

      // Get personal menus
      final menusSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('menus')
          .get();

      for (final doc in menusSnapshot.docs) {
        menus.add({
          'menu_id': doc.id,
          'data': doc.data(),
        });
      }

      // Get menus from menus collection where user is owner
      final sharedMenus = await _firestore
          .collection('menus')
          .where('sharedByUserId', isEqualTo: userId)
          .get();

      for (final doc in sharedMenus.docs) {
        menus.add({
          'menu_id': doc.id,
          'type': 'shared',
          'data': doc.data(),
        });
      }

      return {
        'total_count': menus.length,
        'menus': menus,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export menus', e);
      return {'error': e.toString()};
    }
  }

  /// Export all user shopping lists with items
  Future<Map<String, dynamic>> exportShoppingLists(String userId) async {
    try {
      final lists = <Map<String, dynamic>>[];

      // Get personal shopping lists
      final shoppingLists = await _firestore
          .collection('users')
          .doc(userId)
          .collection('shopping_lists')
          .get();

      for (final listDoc in shoppingLists.docs) {
        final itemsList = <Map<String, dynamic>>[];
        final listData = {
          'list_id': listDoc.id,
          'list_info': listDoc.data(),
          'items': itemsList,
        };

        // Get items for this list (if they exist as subcollection)
        try {
          final items = await listDoc.reference.collection('items').get();
          for (final itemDoc in items.docs) {
            itemsList.add({
              'item_id': itemDoc.id,
              'data': itemDoc.data(),
            });
          }
        } catch (e) {
          // Items might be embedded in the list document
          app_logger.AppLogger.debug(
              '[$_logTag] No items subcollection for list ${listDoc.id}');
        }

        lists.add(listData);
      }

      return {
        'total_count': lists.length,
        'shopping_lists': lists,
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export shopping lists', e);
      return {'error': e.toString()};
    }
  }
}
