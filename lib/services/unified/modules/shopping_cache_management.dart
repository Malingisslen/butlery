// lib/services/unified/modules/shopping_cache_management.dart

import 'dart:async';
import '../../../core/cache/json_cache_helper.dart';
import '../../../models/unified/unified_shopping_list.dart';
import '../../../core/utils/logger.dart';

/// Handles cache management for shopping lists
class ShoppingCacheManagement {
  final JsonCacheHelper _cacheHelper;
  
  static const String _activeListKey = 'active_list_id';

  ShoppingCacheManagement({
    required JsonCacheHelper cacheHelper,
  }) : _cacheHelper = cacheHelper;

  Future<void> saveToCache(UnifiedShoppingList list) async {
    try {
      final listData = list.toJson();
      await _cacheHelper.saveJson(list.id, listData);
      AppLogger.debug('Lista cachad: ${list.name}');
    } catch (e) {
      AppLogger.error('Fel vid sparande till cache: $e');
    }
  }

  Future<void> removeFromCache(String listId) async {
    try {
      await _cacheHelper.delete(listId);
      AppLogger.debug('Lista borttagen från cache: $listId');
    } catch (e) {
      AppLogger.error('Fel vid borttagning från cache: $e');
    }
  }

  Future<void> saveActiveListId(String? activeListId) async {
    try {
      if (activeListId != null) {
        await _cacheHelper.saveActiveId(_activeListKey, activeListId);
      }
    } catch (e) {
      AppLogger.error('Fel vid sparande av aktiv lista ID: $e');
    }
  }

  Future<String?> loadActiveListId() async {
    try {
      return await _cacheHelper.loadActiveId(_activeListKey);
    } catch (e) {
      AppLogger.error('Fel vid laddning av aktiv lista ID: $e');
      return null;
    }
  }

  Future<List<UnifiedShoppingList>> loadCachedLists() async {
    final lists = <UnifiedShoppingList>[];
    
    try {
      final cachedListIds = await _cacheHelper.getAllKeys();
      final dataKeys = cachedListIds.where((key) => key != _activeListKey).toList();

      for (final listId in dataKeys) {
        final listData = await _cacheHelper.loadJson(listId);
        if (listData != null) {
          try {
            final list = UnifiedShoppingList.fromJson(listData);
            lists.add(list);
            AppLogger.debug('Laddad cached lista: ${list.name}');
          } catch (e) {
            AppLogger.error('Fel vid parsing av cached lista $listId: $e');
            // Ta bort trasig cache
            await _cacheHelper.delete(listId);
          }
        }
      }

      AppLogger.debug('✅ ${lists.length} cached lists laddade');
    } catch (e) {
      AppLogger.error('Fel vid laddning av cached lists: $e');
    }

    return lists;
  }

  Future<void> clearCache() async {
    try {
      final cachedListIds = await _cacheHelper.getAllKeys();
      for (final listId in cachedListIds) {
        await _cacheHelper.delete(listId);
      }
      AppLogger.debug('Cache rensad');
    } catch (e) {
      AppLogger.error('Fel vid rensning av cache: $e');
    }
  }
}