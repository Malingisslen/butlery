// lib/services/account/export/content_export_manager.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show ExportPaginationHelper, sanitizeForJson;
import 'package:butlery/core/constants/firestore_collections.dart';

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
      final recipeLimit = ExportPaginationHelper.getLimitForType('recipes');

      // Personal recipes in user's subcollection (paginated)
      final personalRecipes =
          await ExportPaginationHelper.paginatedCollectionExport(
        collection: _firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection(FirestoreCollections.recipes),
        maxDocuments: recipeLimit,
      );

      for (final doc in personalRecipes) {
        recipes.add({
          'recipe_id': doc.id,
          'type': 'personal',
          'data': sanitizeForJson(doc.data()),
        });
      }

      // Unified recipes where user is owner (paginated)
      final unifiedRecipes = await ExportPaginationHelper.paginatedQuery(
        query: _firestore
            .collection(FirestoreCollections.recipes)
            .where('userId', isEqualTo: userId),
        maxDocuments: recipeLimit,
      );

      for (final doc in unifiedRecipes) {
        recipes.add({
          'recipe_id': doc.id,
          'type': 'unified',
          'data': sanitizeForJson(doc.data()),
        });
      }

      return {
        'total_count': recipes.length,
        'recipes': recipes,
        if (recipes.length >= recipeLimit) 'truncated': true,
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
      final menuLimit = ExportPaginationHelper.getLimitForType('menus');

      // Get personal menus (paginated)
      final menusSnapshot =
          await ExportPaginationHelper.paginatedCollectionExport(
        collection: _firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection(FirestoreCollections.menus),
        maxDocuments: menuLimit,
      );

      for (final doc in menusSnapshot) {
        menus.add({
          'menu_id': doc.id,
          'data': sanitizeForJson(doc.data()),
        });
      }

      // Get menus from menus collection where user is owner (paginated)
      final sharedMenus = await ExportPaginationHelper.paginatedQuery(
        query: _firestore
            .collection(FirestoreCollections.menus)
            .where('sharedByUserId', isEqualTo: userId),
        maxDocuments: menuLimit,
      );

      for (final doc in sharedMenus) {
        menus.add({
          'menu_id': doc.id,
          'type': 'shared',
          'data': sanitizeForJson(doc.data()),
        });
      }

      return {
        'total_count': menus.length,
        'menus': menus,
        if (menus.length >= menuLimit) 'truncated': true,
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
      final listLimit =
          ExportPaginationHelper.getLimitForType('shopping_lists');

      // Get personal shopping lists (paginated)
      final shoppingLists =
          await ExportPaginationHelper.paginatedCollectionExport(
        collection: _firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection(FirestoreCollections.userShoppingLists),
        maxDocuments: listLimit,
      );

      for (final listDoc in shoppingLists) {
        final itemsList = <Map<String, dynamic>>[];
        final listData = {
          'list_id': listDoc.id,
          'list_info': listDoc.data(),
          'items': itemsList,
        };

        // Get items for this list (if they exist as subcollection)
        // Items are limited to prevent timeout on very large lists
        try {
          final items = await listDoc.reference
              .collection(FirestoreCollections.items)
              .limit(500)
              .get();
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
        if (lists.length >= listLimit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export shopping lists', e);
      return {'error': e.toString()};
    }
  }

  /// Export all personal tags with embedded rules (GDPR Article 20)
  Future<Map<String, dynamic>> exportPersonalTags(String userId) async {
    try {
      final tags = <Map<String, dynamic>>[];
      final tagLimit = ExportPaginationHelper.getLimitForType('personal_tags');

      final tagsSnapshot =
          await ExportPaginationHelper.paginatedCollectionExport(
        collection: _firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection(FirestoreCollections.userPersonalTags),
        maxDocuments: tagLimit,
      );

      for (final doc in tagsSnapshot) {
        tags.add({
          'tag_id': doc.id,
          'data': sanitizeForJson(doc.data()),
        });
      }

      return {
        'total_count': tags.length,
        'personal_tags': tags,
        if (tags.length >= tagLimit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export personal tags', e);
      return {'error': e.toString()};
    }
  }

  /// Export all personal tag groups (GDPR Article 20)
  Future<Map<String, dynamic>> exportPersonalTagGroups(String userId) async {
    try {
      final groups = <Map<String, dynamic>>[];
      final groupLimit =
          ExportPaginationHelper.getLimitForType('personal_tag_groups');

      final groupsSnapshot =
          await ExportPaginationHelper.paginatedCollectionExport(
        collection: _firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection(FirestoreCollections.userPersonalTagGroups),
        maxDocuments: groupLimit,
      );

      for (final doc in groupsSnapshot) {
        groups.add({
          'group_id': doc.id,
          'data': sanitizeForJson(doc.data()),
        });
      }

      return {
        'total_count': groups.length,
        'personal_tag_groups': groups,
        if (groups.length >= groupLimit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export personal tag groups', e);
      return {'error': e.toString()};
    }
  }

  /// Export all cook snaps (GDPR Article 20)
  Future<Map<String, dynamic>> exportCookSnaps(String userId) async {
    try {
      final snaps = <Map<String, dynamic>>[];
      final snapLimit = ExportPaginationHelper.getLimitForType('cook_snaps');

      final snapsSnapshot = await ExportPaginationHelper.paginatedQuery(
        query: _firestore
            .collection(FirestoreCollections.cookSnaps)
            .where('userId', isEqualTo: userId),
        maxDocuments: snapLimit,
      );

      for (final doc in snapsSnapshot) {
        snaps.add({
          'snap_id': doc.id,
          'data': sanitizeForJson(doc.data()),
        });
      }

      return {
        'total_count': snaps.length,
        'cook_snaps': snaps,
        if (snaps.length >= snapLimit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export cook snaps', e);
      return {'error': e.toString()};
    }
  }

  /// Export all pantry items (GDPR Article 20)
  Future<Map<String, dynamic>> exportPantryItems(String userId) async {
    try {
      final items = <Map<String, dynamic>>[];
      final pantryLimit =
          ExportPaginationHelper.getLimitForType('pantry_items');

      final pantrySnapshot =
          await ExportPaginationHelper.paginatedCollectionExport(
        collection: _firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection(FirestoreCollections.pantry),
        maxDocuments: pantryLimit,
      );

      for (final doc in pantrySnapshot) {
        items.add({
          'item_id': doc.id,
          'data': sanitizeForJson(doc.data()),
        });
      }

      return {
        'total_count': items.length,
        'pantry_items': items,
        if (items.length >= pantryLimit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export pantry items', e);
      return {'error': e.toString()};
    }
  }

  /// Export all activity events (GDPR Article 20)
  Future<Map<String, dynamic>> exportActivityEvents(String userId) async {
    try {
      final events = <Map<String, dynamic>>[];
      final eventLimit =
          ExportPaginationHelper.getLimitForType('activity_events');

      final eventsSnapshot = await ExportPaginationHelper.paginatedQuery(
        query: _firestore
            .collection(FirestoreCollections.activityEvents)
            .where('actorId', isEqualTo: userId),
        maxDocuments: eventLimit,
      );

      for (final doc in eventsSnapshot) {
        events.add({
          'event_id': doc.id,
          'data': sanitizeForJson(doc.data()),
        });
      }

      return {
        'total_count': events.length,
        'activity_events': events,
        if (events.length >= eventLimit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export activity events', e);
      return {'error': e.toString()};
    }
  }

  /// Export all weekly menu plans (BUT-211, GDPR Article 20).
  /// Doc IDs are prefixed with `{userId}_` so a range query gives us only
  /// this user's plans without an additional Firestore index.
  Future<Map<String, dynamic>> exportWeeklyMenuPlans(String userId) async {
    try {
      final plans = <Map<String, dynamic>>[];
      final planLimit =
          ExportPaginationHelper.getLimitForType('weekly_menu_plans');

      final plansSnapshot = await ExportPaginationHelper.paginatedQuery(
        query: _firestore
            .collection(FirestoreCollections.weeklyMenuPlans)
            .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${userId}_')
            .where(FieldPath.documentId, isLessThan: '${userId}_\uf8ff'),
        maxDocuments: planLimit,
      );

      for (final doc in plansSnapshot) {
        plans.add({
          'plan_id': doc.id,
          'data': sanitizeForJson(doc.data()),
        });
      }

      return {
        'total_count': plans.length,
        'weekly_menu_plans': plans,
        if (plans.length >= planLimit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export weekly menu plans', e);
      return {'error': e.toString()};
    }
  }
}
